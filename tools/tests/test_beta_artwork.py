import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from package_beta_artwork import package


class BetaArtworkTests(unittest.TestCase):
    def test_preserves_sources_and_scene_pixels_with_verified_animation_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source'
            source.mkdir()
            records = []
            for key, scale, category in [('animation', 8, 'OriginalAnimations'), ('scene', 4, 'Images')]:
                image = Image.new('RGBA', (2 * scale, scale))
                image.paste((90, 40, 10, 255), (0, 0, scale, scale))
                path = source / (key + '.png')
                image.save(path)
                records.append(dict(key=key, width=2, height=1, scale=scale, file=path.name,
                                    sources=[category + '/fixture'],
                                    pngSHA256=hashlib.sha256(path.read_bytes()).hexdigest()))
            manifest = dict(formatVersion=1, scale=4, complete=True, images=records)
            (source / 'ArtworkManifest.json').write_text(json.dumps(manifest))
            output = Path(directory) / 'output'
            package(source, output)
            packed = json.loads((output / 'ArtworkManifest.json').read_text())
            for before, after in zip(records, packed['images']):
                self.assertEqual(hashlib.sha256((source / before['file']).read_bytes()).hexdigest(), before['pngSHA256'])
                self.assertEqual(hashlib.sha256((output / after['file']).read_bytes()).hexdigest(), after['pngSHA256'])
            self.assertEqual((output / 'scene.png').read_bytes(), (source / 'scene.png').read_bytes())
            with Image.open(output / 'animation.webp') as image:
                self.assertEqual(image.size, (8, 4))
                self.assertEqual(image.convert('RGBA').getpixel((7, 0))[3], 0)
                self.assertEqual(hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest(), packed['images'][0]['outputRGBA256'])
            with self.assertRaises(FileExistsError):
                package(source, output)
            (source / 'scene.png').write_bytes(b'corrupt')
            failed = Path(directory) / 'failed'
            with self.assertRaisesRegex(ValueError, 'checksum'):
                package(source, failed)
            self.assertFalse((failed / 'ArtworkManifest.json').exists())
            fallback = Path(directory) / 'fallback'
            package(source, fallback, exclusions={'scene': 'Use original artwork.'})
            packed = json.loads((fallback / 'ArtworkManifest.json').read_text())
            self.assertEqual([record['key'] for record in packed['images']], ['animation'])
            self.assertEqual(packed['betaPackaging']['originalArtworkFallbacks'], {'scene': 'Use original artwork.'})


if __name__ == '__main__':
    unittest.main()
