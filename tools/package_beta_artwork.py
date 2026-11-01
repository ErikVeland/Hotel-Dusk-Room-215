#!/usr/bin/env python3
"""Create a separate 4x animation pack for the beta. Requires Pillow 12.0.0."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path

from PIL import Image


def digest(data):
    return hashlib.sha256(data).hexdigest()


def package_record(record, source, output, default_scale):
    record = dict(record)
    filename = record['file']
    if Path(filename).name != filename or filename not in (record['key'] + '.png', record['key'] + '.webp'):
        raise ValueError(f'Invalid artwork filename: {filename}')
    original = source / filename
    data = original.read_bytes()
    if digest(data) != record['pngSHA256']:
        raise ValueError(f'Artwork checksum failed: {filename}')
    scale = record.get('scale', default_scale)
    animation = any(name.startswith('OriginalAnimations/') for name in record['sources'])
    if not animation or scale <= 4:
        os.link(original, output / filename)
        return record

    with Image.open(original) as image:
        if image.size != (record['width'] * scale, record['height'] * scale):
            raise ValueError(f'Artwork dimensions failed: {filename}')
        rgba = image.convert('RGBA')
        size = (record['width'] * 4, record['height'] * 4)
        resized = rgba.resize(size, Image.Resampling.LANCZOS)
        # Area sampling keeps transparent source regions outside the silhouette.
        resized.putalpha(rgba.getchannel('A').resize(size, Image.Resampling.BOX))
        filename = record['key'] + '.webp'
        target = output / filename
        resized.save(target, 'WEBP', lossless=True, exact=True, method=1)
        pixels = resized.tobytes()
        with Image.open(target) as decoded:
            if decoded.size != size or decoded.convert('RGBA').tobytes() != pixels:
                raise ValueError(f'Lossless artwork check failed: {filename}')

    record.update(file=filename, scale=4, pngSHA256=digest(target.read_bytes()),
                  outputRGBA256=digest(pixels), betaSourceSHA256=digest(data))
    return record


def package(source, output, workers=4, exclusions=None):
    source, output = Path(source).resolve(), Path(output).resolve()
    manifest = json.loads((source / 'ArtworkManifest.json').read_text())
    if manifest.get('formatVersion') != 1 or not manifest.get('complete'):
        raise ValueError('A complete format-version-1 source manifest is required.')
    keys = [record['key'] for record in manifest['images']]
    if len(keys) != len(set(keys)):
        raise ValueError('The source manifest contains duplicate image keys.')
    exclusions = exclusions or {}
    if not set(exclusions).issubset(keys):
        raise ValueError('A beta artwork exclusion has no source record.')
    output.mkdir(parents=True, exist_ok=False)
    # Write the manifest last. An interrupted pack cannot be loaded by the game.
    with ThreadPoolExecutor(max_workers=workers) as pool:
        records = list(pool.map(
            lambda record: package_record(record, source, output, manifest['scale']),
            [record for record in manifest['images'] if record['key'] not in exclusions]))
    manifest['images'] = records
    manifest['animationScale'] = 4
    manifest['candidateBytes'] = sum((output / record['file']).stat().st_size for record in records)
    manifest['betaPackaging'] = {
        'sourceManifestSHA256': digest((source / 'ArtworkManifest.json').read_bytes()),
        'animationScale': 4,
        'filter': 'Lanczos RGB with area-sampled alpha; lossless WebP',
        'originalArtworkFallbacks': exclusions,
    }
    (output / 'ArtworkManifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest['candidateBytes']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--exclusions', type=Path)
    args = parser.parse_args()
    exclusions = json.loads(args.exclusions.read_text()) if args.exclusions else {}
    print(f'Beta artwork bytes: {package(args.source, args.output, exclusions=exclusions):,}')
