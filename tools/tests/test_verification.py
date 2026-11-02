import importlib.util
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
