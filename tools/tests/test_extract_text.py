import importlib.util
import json
from pathlib import Path
import struct
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


if __name__ == "__main__":
    unittest.main()
