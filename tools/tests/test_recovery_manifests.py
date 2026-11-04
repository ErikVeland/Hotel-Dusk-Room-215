import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RecoveryManifestTests(unittest.TestCase):
    def test_model_bundle_keeps_runtime_fields_and_the_report_keeps_diagnostics(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            identity = [1.0 if row == column else 0.0 for row in range(4) for column in range(4)]
            model = (b"MDF_DS_100" + bytes(6) + b"example".ljust(16, b"\0") +
                     struct.pack("<4I", 1, 0, 48, 48) + b"node".ljust(16, b"\0") +
                     struct.pack("<hh3I16f", 0, -1, 144, 0, 0, *identity))
            for name, data in (("example.mdf", model), ("unsupported.mdf", b"unknown")):
                (source / name).write_bytes(bytes(24) + struct.pack("<II", len(data), 0) + data)
            report_path = root / "reports/models.json"
            result = subprocess.run([
                sys.executable, str(ROOT / "tools/decode_mdf.py"), "--source", str(source),
                "--bundle", str(root / "bundle"), "--report", str(report_path),
            ], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(report_path.read_text())
            bundled = json.loads((root / "bundle/OriginalModelManifest.json").read_text())
            self.assertEqual(bundled["coverage"], report["coverage"])
            keys = {"source", "payloadSHA256", "status", "error", "decodedSHA256", "geometrySHA256", "nodes"}
            self.assertEqual(bundled["models"], [
                {key: value for key, value in record.items() if key in keys}
                for record in report["models"]
            ])
            self.assertIn("materials", report["models"][0])
            self.assertIn("groups", report["models"][0])
            self.assertEqual(bundled["models"][1]["status"], "unsupported")
            self.assertIn("error", bundled["models"][1])


if __name__ == "__main__":
    unittest.main()
