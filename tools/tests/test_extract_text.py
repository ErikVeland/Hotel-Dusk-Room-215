import importlib.util
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("extract_text", Path(__file__).parents[1] / "extract_text.py")
extract_text = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extract_text)


class MapTextTests(unittest.TestCase):
    def test_export_preserves_map_ids_and_placeholder_names(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "local/us/maptext.dat"
            source.parent.mkdir(parents=True)
            records = [(3, "2F Room 215"), (1, "1F Lobby"), (2, "---"), (4, "")]
            source.write_bytes(struct.pack("<I", len(records)) + b"".join(
                struct.pack("<H32s", map_id, label.encode("ascii")) for map_id, label in records))
            output = root / "catalog.json"
            extract_text.export_all_text(root, output)
            self.assertEqual(json.loads(output.read_text())["maps"],
                             ["1F Lobby", "---", "2F Room 215", ""])

    def test_binary_strings_include_the_final_unterminated_string(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "items.dat"
            source.write_bytes(b"First item\0---\xffSecond item\x01Final item")
            self.assertEqual(extract_text.parse_dat_strings(source),
                             ["First item", "Second item", "Final item"])

    def test_export_accepts_a_filename_in_the_current_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = os.getcwd()
            os.chdir(directory)
            try:
                extract_text.export_all_text("missing", "catalog.json")
                self.assertTrue(Path("catalog.json").is_file())
            finally:
                os.chdir(previous)

    def test_default_output_is_the_bundled_catalog(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(Path(extract_text.__file__).resolve())],
                                    cwd=directory, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            output = Path(directory) / "Sources/HotelDuskDuoKit/Resources/GameText.json"
            self.assertTrue(output.is_file())


if __name__ == "__main__":
    unittest.main()
