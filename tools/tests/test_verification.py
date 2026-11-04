import importlib.util
import base64
import hashlib
import json
import struct
from subprocess import CompletedProcess
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
import re
import sys
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1]))
import audit_story_coverage

spec = importlib.util.spec_from_file_location("verify", Path(__file__).parents[1] / "verify.py")
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerificationTests(unittest.TestCase):
    @staticmethod
    def route_state(chapter, map_id):
        state = bytearray(0x7D58)
        struct.pack_into("<H", state, 0, chapter)
        struct.pack_into("<h", state, 4, map_id)
        return bytes(state)

    @classmethod
    def route_save(cls, chapter, map_id, version=1):
        state = cls.route_state(chapter, map_id)
        record = {"version": version, "state": base64.b64encode(state).decode(),
                  "stateSHA256": hashlib.sha256(state).hexdigest()}
        if version == 2:
            record["progress"] = {"version": 1, "note": "ending"}
            progress = json.dumps(record["progress"], sort_keys=True, separators=(",", ":"),
                                  ensure_ascii=False, allow_nan=False).encode("utf-8")
            record["progressSHA256"] = hashlib.sha256(progress).hexdigest()
        return record

    def test_temporary_route_probe_is_excluded_from_release_profiles(self):
        groups = verify.classify_tests()
        self.assertNotIn('OriginalChapterFourProbe', sum(groups.values(), []))
        self.assertIn('OriginalChapterFourProbe', verify.DIAGNOSTIC_TESTS)

    def test_shared_system_processes_are_included_in_story_coverage(self):
        report = audit_story_coverage.audit()
        shared = report["sharedSystemProcesses"]
        self.assertEqual(report["schemaVersion"], 2)
        self.assertEqual({item["processID"] for item in shared}, {
            29, 32, 33, 35, 50, 53, 54, 57, 58, 68, 69, 70, 71, 87, 89,
        })
        self.assertTrue(all(item["hasNativeHandler"] for item in shared))
        self.assertTrue(any(item["processID"] == 87 for item in shared))

    def test_filter_matches_classes_without_matching_the_module_name(self):
        pattern = verify.test_filter(['HotelDuskDuoTests', 'AudioControllerTests'])
        self.assertIsNotNone(re.search(pattern, 'HotelDuskDuoTests.HotelDuskDuoTests/testTitle'))
        self.assertIsNotNone(re.search(pattern, 'HotelDuskDuoTests.AudioControllerTests/testMute'))
        self.assertIsNone(re.search(pattern, 'HotelDuskDuoTests.OriginalStoryContinuationTests/testRoute'))
        self.assertIsNone(re.search(pattern, 'HotelDuskDuoTests.AudioControllerTestsExtra/testMute'))

    def test_case_filter_matches_only_checkpoint_dependent_tests(self):
        pattern = verify.test_filter_cases({
            ('HotelDuskDuoTests.OriginalStoryContinuationTests', 'testChapterSix01ReachesBarFromChapterFiveSave')
        })
        self.assertIsNotNone(re.search(pattern,
            'HotelDuskDuoTests.OriginalStoryContinuationTests/testChapterSix01ReachesBarFromChapterFiveSave'))
        self.assertIsNone(re.search(pattern,
            'HotelDuskDuoTests.OriginalStoryContinuationTests/testChapterSevenLeavesRoom215ForSecondFloorHallway'))
        self.assertIsNone(re.search(pattern,
            'HotelDuskDuoTests.OriginalPantryTraceTests/testCardsReadCheckpointPantryActionCompletesQuizAndEntersChapterTen'))

    def test_route_dependency_skips_are_selected_for_another_pass(self):
        output = """/repo/Tests/OriginalCellarTraceTests.swift:101: -[HotelDuskDuoTests.OriginalCellarTraceTests testCellarBackShelfCloseupLayersFromNormalRoute] : Test skipped - The normal Chapter 10 cellar entry checkpoint is not available
Test Case '-[HotelDuskDuoTests.OriginalCellarTraceTests testCellarBackShelfCloseupLayersFromNormalRoute]' skipped (0.001 seconds).
"""
        self.assertEqual(verify.route_dependency_cases(output), {
            ('OriginalCellarTraceTests', 'testCellarBackShelfCloseupLayersFromNormalRoute')
        })
        prereq = "-[HotelDuskDuoTests.OriginalStoryContinuationTests testChapterSix01ReachesBarFromChapterFiveSave] : Test skipped - Generate the Chapter 6 bar checkpoint through the Chapter 5 route first"
        self.assertEqual(verify.route_dependency_cases(prereq), {
            ('OriginalStoryContinuationTests', 'testChapterSix01ReachesBarFromChapterFiveSave')
        })
        final_route = "-[HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenR302RevealedPaintingCompletesNormalEnding] : Test skipped - Complete the R302 painting route first"
        self.assertEqual(verify.route_dependency_cases(final_route), {
            ('OriginalChapterReviewTests', 'testChapterTenR302RevealedPaintingCompletesNormalEnding')
        })

    def test_checkpoint_fingerprint_changes_when_a_save_changes(self):
        with TemporaryDirectory() as temporary_directory:
            checkpoint_directory = Path(temporary_directory)
            save = checkpoint_directory / 'chapter' / 'resume.json'
            save.parent.mkdir()
            save.write_text('{"step":1}')
            first = verify.route_checkpoint_state(checkpoint_directory)
            save.write_text('{"step":2}')
            second = verify.route_checkpoint_state(checkpoint_directory)
        self.assertNotEqual(first, second)

    def test_fresh_route_gate_checks_chapter_three_and_ending_saves(self):
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            records = {
                "chapter3-entry": self.route_save(2, 31),
                "chapter10-ending": self.route_save(9, 31, version=2),
            }
            for name, record in records.items():
                directory = root / name
                directory.mkdir()
                (directory / "resume.json").write_text(json.dumps(record))

            result = verify.fresh_route_checkpoint_result(root)

        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["passed"], 2)
        self.assertEqual(result["failed"], 0)
        self.assertEqual(result["cases"], {
            "fresh-route-checkpoints/chapter3-entry": "passed",
            "fresh-route-checkpoints/chapter10-ending": "passed",
        })
        self.assertEqual(result["reasons"], {})

    def test_fresh_route_gate_fails_for_missing_handoffs(self):
        with TemporaryDirectory() as temporary_directory:
            result = verify.fresh_route_checkpoint_result(Path(temporary_directory))

        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["passed"], 0)
        self.assertEqual(result["failed"], 2)
        self.assertTrue(all("missing" in reason for reason in result["reasons"].values()))

    def test_fresh_route_gate_fails_for_damaged_handoff(self):
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            entry = root / "chapter3-entry"
            entry.mkdir()
            (entry / "resume.json").write_text(json.dumps(self.route_save(2, 31)))
            ending = root / "chapter10-ending"
            ending.mkdir()
            damaged = self.route_save(9, 31, version=2)
            damaged["stateSHA256"] = "damaged"
            (ending / "resume.json").write_text(json.dumps(damaged))

            result = verify.fresh_route_checkpoint_result(root)

        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["passed"], 1)
        self.assertEqual(result["failed"], 1)
        self.assertEqual(result["cases"]["fresh-route-checkpoints/chapter10-ending"], "failed")
        self.assertIn("checksum", result["reasons"]["fresh-route-checkpoints/chapter10-ending"])

    def test_fresh_route_gate_fails_for_a_valid_save_at_the_wrong_location(self):
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            entry = root / "chapter3-entry"
            entry.mkdir()
            (entry / "resume.json").write_text(json.dumps(self.route_save(2, 14)))
            ending = root / "chapter10-ending"
            ending.mkdir()
            (ending / "resume.json").write_text(json.dumps(self.route_save(9, 31, version=2)))

            result = verify.fresh_route_checkpoint_result(root)

        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["passed"], 1)
        self.assertEqual(result["failed"], 1)
        self.assertIn("Chapter 3, map 31",
                      result["reasons"]["fresh-route-checkpoints/chapter3-entry"])

    def test_fresh_route_gate_rejects_version_two_save_without_progress_checksum(self):
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            entry = root / "chapter3-entry"
            entry.mkdir()
            (entry / "resume.json").write_text(json.dumps(self.route_save(2, 31)))
            ending = root / "chapter10-ending"
            ending.mkdir()
            record = self.route_save(9, 31, version=2)
            record.pop("progressSHA256")
            (ending / "resume.json").write_text(json.dumps(record))

            result = verify.fresh_route_checkpoint_result(root)

        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["passed"], 1)
        self.assertEqual(result["failed"], 1)
        self.assertIn("invalid checksum",
                      result["reasons"]["fresh-route-checkpoints/chapter10-ending"])

    def test_fresh_route_gate_rejects_damaged_version_two_progress(self):
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            entry = root / "chapter3-entry"
            entry.mkdir()
            (entry / "resume.json").write_text(json.dumps(self.route_save(2, 31)))
            ending = root / "chapter10-ending"
            ending.mkdir()
            record = self.route_save(9, 31, version=2)
            record["progressSHA256"] = "0" * 64
            (ending / "resume.json").write_text(json.dumps(record))

            result = verify.fresh_route_checkpoint_result(root)

        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["passed"], 1)
        self.assertEqual(result["failed"], 1)
        self.assertIn("invalid checksum",
                      result["reasons"]["fresh-route-checkpoints/chapter10-ending"])

    def test_fresh_route_gate_accepts_content_addressed_journey_sketches(self):
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            entry = root / "chapter3-entry"
            entry.mkdir()
            (entry / "resume.json").write_text(json.dumps(self.route_save(2, 31)))
            ending = root / "chapter10-ending"
            ending.mkdir()
            record = self.route_save(9, 31, version=2)
            pixels = b"saved pencil drawing"
            digest = hashlib.sha256(pixels).hexdigest()
            fingerprint = {"notebook": {"book": {"entries": [{"viewSHA256": digest}]}}}
            record["progressSHA256"] = hashlib.sha256(json.dumps(
                fingerprint, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            record["progress"] = json.loads(json.dumps(fingerprint))
            record["progress"]["notebook"]["book"]["entries"][0]["viewPNG"] = base64.b64encode(pixels).decode()
            (ending / "resume.json").write_text(json.dumps(record))
            self.assertEqual(verify.fresh_route_checkpoint_result(root)["status"], "passed")
            record["progress"]["notebook"]["book"]["entries"][0].pop("viewPNG")
            (ending / "resume.json").write_text(json.dumps(record))
            self.assertEqual(verify.fresh_route_checkpoint_result(root)["status"], "failed")
            art = ending / "book-art"
            art.mkdir()
            (art / (digest + ".png")).write_bytes(pixels)
            self.assertEqual(verify.fresh_route_checkpoint_result(root)["status"], "passed")

    def test_reference_result_keeps_failures_from_earlier_passes(self):
        case = 'OriginalStoryContinuationTests/testChapterNineRoute'
        results = [
            {"command": [], "status": "failed", "exitCode": 0, "seconds": 1,
             "log": "first.log", "cases": {case: "failed"}},
            {"command": [], "status": "passed", "exitCode": 0, "seconds": 1,
             "log": "second.log", "cases": {case: "passed"}},
        ]
        merged = verify.merge_test_results('swift-reference', results)
        self.assertEqual(merged['status'], 'failed')

    def test_reference_runner_retries_missing_checkpoint_cases(self):
        with TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            output_directory = root / 'output'
            output_directory.mkdir()
            checkpoint_directory = root / 'checkpoints'
            checkpoint_directory.mkdir()
            case = ('OriginalCellarTraceTests', 'testCellarBackShelfCloseupLayersFromNormalRoute')
            calls = []

            def fake_run(name, command, directory, env, strict):
                calls.append(command)
                log_path = directory / f'{name}.log'
                if len(calls) == 1:
                    saved = checkpoint_directory / 'chapter10-entry'
                    saved.mkdir()
                    (saved / 'resume.json').write_text('{}')
                    log_path.write_text("""/repo/OriginalCellarTraceTests.swift:1: -[HotelDuskDuoTests.OriginalCellarTraceTests testCellarBackShelfCloseupLayersFromNormalRoute] : Test skipped - The cellar entry checkpoint is not available
Test Case '-[HotelDuskDuoTests.OriginalCellarTraceTests testCellarBackShelfCloseupLayersFromNormalRoute]' skipped (0.001 seconds).
""")
                    cases = {f'{case[0]}/{case[1]}': 'skipped'}
                else:
                    log_path.write_text(
                        "Test Case '-[HotelDuskDuoTests.OriginalCellarTraceTests "
                        "testCellarBackShelfCloseupLayersFromNormalRoute]' passed (0.1 seconds).\n")
                    cases = {f'{case[0]}/{case[1]}': 'passed'}
                return {"name": name, "command": command, "status": "passed", "exitCode": 0,
                        "seconds": 0.1, "log": str(log_path), "passed": int(len(calls) > 1),
                        "failed": 0, "skipped": int(len(calls) == 1), "cases": cases}

            with patch.object(verify, 'run_group', side_effect=fake_run):
                result = verify.run_reference_group(['OriginalCellarTraceTests'], output_directory, {}, True,
                    checkpoint_directory, ['swift', 'test'])

        self.assertEqual(result['attempts'], 2)
        self.assertEqual(result['status'], 'passed')
        self.assertEqual(result['routeCheckpointStopReason'], 'noDeferredCases')
        self.assertEqual(result['pendingRouteDependencyCases'], [])
        self.assertEqual(result['cases'][f'{case[0]}/{case[1]}'], 'passed')
        self.assertIn(verify.test_filter_cases({case}), calls[1])

    def test_xctest_discovery_is_enabled_when_swiftpm_supports_it(self):
        help_output = "--enable-xctest/--disable-xctest --enable-swift-testing/--disable-swift-testing"
        self.assertEqual(verify.xctest_flags(help_output),
                         ["--enable-xctest", "--disable-swift-testing"])

    def test_xctest_discovery_flags_are_omitted_for_older_swiftpm(self):
        self.assertEqual(verify.xctest_flags("Usage: swift test [options]"), [])

    def test_xctest_preflight_reports_missing_test_framework(self):
        self.assertEqual(
            verify.xctest_preflight_failure(1, "error: no such module 'XCTest'"),
            "The selected Swift toolchain does not provide XCTest.",
        )

    def test_xctest_preflight_reports_compiler_sdk_mismatch(self):
        self.assertEqual(
            verify.xctest_preflight_failure(1, "error: SDK is not supported by the compiler"),
            "The selected Swift compiler and SDK versions do not match.",
        )

    def test_xctest_preflight_accepts_a_successful_import(self):
        self.assertIsNone(verify.xctest_preflight_failure(0, ""))

    def test_xctest_preflight_uses_platform_frameworks_when_the_default_search_path_misses_xctest(self):
        missing = "error: no such module 'XCTest'\n"
        env = {"DEVELOPER_DIR": "/selected/Xcode.app/Contents/Developer"}
        with TemporaryDirectory() as directory:
            platform = Path(directory) / "MacOSX.platform"
            frameworks = platform / "Developer/Library/Frameworks"
            frameworks.mkdir(parents=True)
            with patch.object(verify.subprocess, "run", side_effect=[
                CompletedProcess([], 1, "", missing),
                CompletedProcess([], 0, str(platform) + "\n", ""),
                CompletedProcess([], 0, "", ""),
            ]) as run:
                reason, output = verify.xctest_preflight(env)
            self.assertIsNone(reason)
            self.assertIn(missing, output)
            self.assertEqual(run.call_args_list[1].args[0],
                             ["xcrun", "--sdk", "macosx", "--show-sdk-platform-path"])
            retry = run.call_args_list[2]
            self.assertEqual(retry.args[0], ["swiftc", "-typecheck", "-", "-F", str(frameworks)])
            self.assertEqual(retry.kwargs["env"], env)
            self.assertEqual(retry.kwargs["input"], "import XCTest\n")

    def test_xctest_preflight_preserves_missing_module_diagnostics_without_xcrun(self):
        missing = "error: no such module 'XCTest'\n"
        with patch.object(verify.subprocess, "run", side_effect=[
            CompletedProcess([], 1, "", missing), FileNotFoundError("xcrun"),
        ]):
            reason, output = verify.xctest_preflight({})
        self.assertEqual(reason, "The selected Swift toolchain does not provide XCTest.")
        self.assertEqual(output, missing)

    def test_xctest_preflight_does_not_retry_without_platform_frameworks(self):
        missing = "error: no such module 'XCTest'\n"
        with TemporaryDirectory() as directory:
            with patch.object(verify.subprocess, "run", side_effect=[
                CompletedProcess([], 1, "", missing),
                CompletedProcess([], 0, directory + "\n", ""),
            ]) as run:
                reason, output = verify.xctest_preflight({})
        self.assertEqual(reason, "The selected Swift toolchain does not provide XCTest.")
        self.assertEqual(output, missing)
        self.assertEqual(run.call_count, 2)

    def test_xctest_preflight_keeps_retry_failure_reason_and_both_compiler_diagnostics(self):
        missing = "error: no such module 'XCTest'\n"
        mismatch = "error: SDK is not supported by the compiler\n"
        with TemporaryDirectory() as directory:
            platform = Path(directory)
            (platform / "Developer/Library/Frameworks").mkdir(parents=True)
            with patch.object(verify.subprocess, "run", side_effect=[
                CompletedProcess([], 1, "", missing),
                CompletedProcess([], 0, directory + "\n", ""),
                CompletedProcess([], 1, "", mismatch),
            ]):
                reason, output = verify.xctest_preflight({})
        self.assertEqual(reason, "The selected Swift compiler and SDK versions do not match.")
        self.assertEqual(output, missing + mismatch)

    def test_xctest_preflight_does_not_discover_frameworks_after_success_or_an_sdk_mismatch(self):
        for code, diagnostic in ((0, ""), (1, "error: SDK is not supported by the compiler\n")):
            with self.subTest(code=code), patch.object(verify.subprocess, "run", return_value=
                CompletedProcess([], code, "", diagnostic)) as run:
                reason, output = verify.xctest_preflight({})
                self.assertEqual(reason, verify.xctest_preflight_failure(code, diagnostic))
                self.assertEqual(output, diagnostic)
                self.assertEqual(run.call_count, 1)

    def test_fresh_route_checkpoints_use_a_new_retained_directory(self):
        with TemporaryDirectory() as temporary_directory:
            output_directory = Path(temporary_directory)
            first = verify.route_checkpoint_directory(None, True, output_directory)
            second = verify.route_checkpoint_directory(None, True, output_directory)

        self.assertNotEqual(first, second)
        self.assertEqual(first.parent, output_directory)
        self.assertEqual(second.parent, output_directory)

    def test_explicit_route_checkpoint_directory_cannot_be_combined_with_fresh_mode(self):
        with TemporaryDirectory() as temporary_directory:
            checkpoint_directory = Path(temporary_directory) / "existing"
            with self.assertRaisesRegex(ValueError, "cannot be used together"):
                verify.route_checkpoint_directory(checkpoint_directory, True, Path(temporary_directory))

    def test_reference_and_all_profiles_default_to_fresh_route_checkpoints(self):
        self.assertTrue(verify.should_use_fresh_route_checkpoints("reference", None, False))
        self.assertTrue(verify.should_use_fresh_route_checkpoints("all", None, False))
        self.assertFalse(verify.should_use_fresh_route_checkpoints("fast", None, False))
        self.assertFalse(verify.should_use_fresh_route_checkpoints("reference", Path("saved"), False))
        self.assertTrue(verify.should_use_fresh_route_checkpoints("reference", None, True))

    def test_xctest_cases_are_not_counted_again_in_suite_totals(self):
        text = """Test Case '-[KitTests.SourceTests testValid]' passed (0.1 seconds).
Test Case '-[KitTests.SourceTests testMissingFixture]' skipped (0.0 seconds).
Test Case '-[KitTests.SourceTests testBroken]' failed (0.1 seconds).
Executed 3 tests, with 1 failure (0 unexpected)
Executed 3 tests, with 1 failure (0 unexpected)"""
        counts = verify.parse_tests(text)
        self.assertEqual([counts[k] for k in ["passed", "failed", "skipped"]], [1, 1, 1])

    def test_strict_mode_rejects_skipped_coverage(self):
        counts = {"passed": 2, "failed": 0, "skipped": 1}
        self.assertEqual(verify.group_status(0, counts), "passed")
        self.assertEqual(verify.group_status(0, counts, strict=True), "failed")
        self.assertEqual(verify.group_status(6, counts), "failed")

    def test_python_result_preserves_errors_and_skips(self):
        counts = verify.parse_tests("Ran 8 tests in 0.2s\n\nFAILED (failures=1, errors=2, skipped=1)\n")
        self.assertEqual([counts[k] for k in ["passed", "failed", "skipped"]], [4, 3, 1])
        self.assertEqual(verify.parse_tests("Ran 4 tests in 0.1s\n\nOK\n")["passed"], 4)

    def test_profiles_partition_test_classes_and_keep_reference_tests_explicit(self):
        groups = verify.classify_tests()
        classes = sum(groups.values(), [])
        self.assertEqual(len(classes), len(set(classes)))
        self.assertIn("RecordedMusicTests", groups["audio"])
        self.assertIn("OriginalStoryContinuationTests", groups["reference"])
        self.assertNotIn("OriginalStoryContinuationTests", groups["fast"])
        self.assertIn("OriginalDoorWireTests", groups["native"])
        self.assertIn("OriginalThickWireRendererTests", groups["native"])


if __name__ == "__main__":
    unittest.main()
