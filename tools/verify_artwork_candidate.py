#!/usr/bin/env python3
"""Check candidate file integrity without approving or enabling artwork."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

from artwork_manifest import valid_artwork_filename


def verify(root: Path) -> list[str]:
    issues = []
    try:
        manifest = json.loads((root / 'ArtworkManifest.json').read_text())
    except (OSError, ValueError) as error:
        return [f'manifest: {error}']
    if not isinstance(manifest, dict) or manifest.get('formatVersion') != 1 or not isinstance(manifest.get('images'), list):
        return ['manifest: unsupported format']
    seen = set()
    files = {}
    for record in manifest['images']:
        if not isinstance(record, dict):
            issues.append('manifest: invalid image record')
            continue
        key = record.get('key')
        filename = record.get('file')
        if not valid_artwork_filename(record):
            issues.append(f'filename: {filename!r}')
            continue
        if key in seen:
            issues.append(f'duplicate key: {key}')
            continue
        seen.add(key)
        width, height = record.get('width'), record.get('height')
        scale = record.get('scale', manifest.get('scale'))
        if not all(type(value) is int and value > 0 for value in (width, height, scale)) or scale > 8:
            issues.append(f'dimensions: {filename}')
            continue
        path = root / filename
        try:
            if filename not in files:
                file_hash = hashlib.sha256(path.read_bytes()).hexdigest()
                with Image.open(path) as image:
                    pixel_hash = hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest()
                    files[filename] = image.size, file_hash, pixel_hash
            size, file_hash, pixel_hash = files[filename]
            if file_hash != record.get('pngSHA256'):
                issues.append(f'hash: {filename}')
            if size != (width * scale, height * scale):
                issues.append(f'dimensions: {filename}')
            expected_pixels = record.get('outputRGBA256')
            if expected_pixels is not None and pixel_hash != expected_pixels:
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
