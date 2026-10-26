import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("verify", Path(__file__).parents[1] / "verify.py")
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerificationTests(unittest.TestCase):
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
