import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
import re
import sys

sys.path.insert(0, str(Path(__file__).parents[1]))
import audit_story_coverage

spec = importlib.util.spec_from_file_location("verify", Path(__file__).parents[1] / "verify.py")
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerificationTests(unittest.TestCase):
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
