from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from unpack_wpf import unpack_wpf


class WPFExtractionTests(unittest.TestCase):
    @staticmethod
    def record(name, size, offset):
        return struct.pack("<24sII", name.encode("ascii"), size, offset)

    def test_preserves_inline_record_and_does_not_count_the_empty_terminator(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            table = self.record("\\example.bin", 4, 0)
            inline = self.record("\\example.bin", 4, 36)
            (root / "source.tbl").write_bytes(table + bytes(32))
            (root / "source.wpf").write_bytes(inline + b"data")
            count = unpack_wpf(root / "source.tbl", root / "source.wpf", root / "output")
            self.assertEqual((root / "output/example.bin").read_bytes(), inline + b"data")
            self.assertEqual(count, 1)

    def test_rejects_an_incomplete_table_record(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "source.tbl").write_bytes(b"partial")
            (root / "source.wpf").write_bytes(b"")
            with self.assertRaisesRegex(ValueError, "table"):
                unpack_wpf(root / "source.tbl", root / "source.wpf", root / "output")

    def test_rejects_a_truncated_archive_member(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            record = self.record("\\example.bin", 4, 0)
            (root / "source.tbl").write_bytes(record)
            (root / "source.wpf").write_bytes(record + b"dat")
            with self.assertRaisesRegex(ValueError, "Truncated"):
                unpack_wpf(root / "source.tbl", root / "source.wpf", root / "output")


if __name__ == "__main__":
    unittest.main()
