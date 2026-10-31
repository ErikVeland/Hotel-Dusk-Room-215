import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from verify_artwork_candidate import verify


class ArtworkCandidateIntegrityTests(unittest.TestCase):
    def test_rejects_decoded_pixel_hash_mismatch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / '1x1-example.webp'
            Image.new('RGBA', (4, 4), (20, 30, 40, 255)).save(path, lossless=True)
            record = {'key': '1x1-example', 'width': 1, 'height': 1,
                      'scale': 4, 'file': path.name,
                      'pngSHA256': hashlib.sha256(path.read_bytes()).hexdigest(),
                      'outputRGBA256': '0' * 64}
            (root / 'ArtworkManifest.json').write_text(json.dumps(
                {'formatVersion': 1, 'images': [record]}))
            self.assertTrue(any('pixel hash' in issue for issue in verify(root)))

    def test_checks_hash_dimensions_and_safe_filename(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / '2x1-example.png'
            Image.new('RGBA', (8, 4), (20, 30, 40, 255)).save(path)
            record = {'key': '2x1-example', 'width': 2, 'height': 1,
                      'scale': 4, 'file': path.name,
                      'pngSHA256': hashlib.sha256(path.read_bytes()).hexdigest()}
            manifest = {'formatVersion': 1, 'scale': 4, 'complete': False, 'images': [record]}
            (root / 'ArtworkManifest.json').write_text(json.dumps(manifest))
            self.assertEqual(verify(root), [])
            record['pngSHA256'] = '0' * 64
            (root / 'ArtworkManifest.json').write_text(json.dumps(manifest))
            self.assertTrue(any('hash' in issue for issue in verify(root)))
            record['file'] = '../outside.png'
            (root / 'ArtworkManifest.json').write_text(json.dumps(manifest))
            self.assertTrue(any('filename' in issue for issue in verify(root)))


if __name__ == '__main__':
    unittest.main()
