#!/usr/bin/env python3
"""Check candidate file integrity without approving or enabling artwork."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def verify(root: Path) -> list[str]:
    issues = []
    try:
        manifest = json.loads((root / 'ArtworkManifest.json').read_text())
    except (OSError, ValueError) as error:
        return [f'manifest: {error}']
    if manifest.get('formatVersion') != 1 or not isinstance(manifest.get('images'), list):
        return ['manifest: unsupported format']
    seen = set()
    for record in manifest['images']:
        key = record.get('key')
        filename = record.get('file')
        if not isinstance(key, str) or filename not in (key + '.png', key + '.webp') or Path(filename).name != filename:
            issues.append(f'filename: {filename!r}')
            continue
        if key in seen:
            issues.append(f'duplicate key: {key}')
            continue
        seen.add(key)
        width, height = record.get('width'), record.get('height')
        scale = record.get('scale', manifest.get('scale'))
        if not all(isinstance(value, int) and value > 0 for value in (width, height, scale)) or scale > 8:
            issues.append(f'dimensions: {filename}')
            continue
        path = root / filename
        try:
            if hashlib.sha256(path.read_bytes()).hexdigest() != record.get('pngSHA256'):
                issues.append(f'hash: {filename}')
            with Image.open(path) as image:
                if image.size != (width * scale, height * scale):
                    issues.append(f'dimensions: {filename}')
                pixels = image.convert('RGBA').tobytes()
                expected_pixels = record.get('outputRGBA256')
                if expected_pixels is not None and hashlib.sha256(pixels).hexdigest() != expected_pixels:
                    issues.append(f'pixel hash: {filename}')
        except (OSError, ValueError) as error:
            issues.append(f'file: {filename}: {error}')
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    issues = verify(args.directory)
    for issue in issues:
        print(issue)
    if issues:
        print(f'Found {len(issues)} integrity issues.')
        return 1
    print('Candidate file hashes, dimensions and recorded pixel hashes passed. Visual and device review are separate.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
