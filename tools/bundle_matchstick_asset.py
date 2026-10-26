#!/usr/bin/env python3
"""Bundle the standalone original match texture, outside the WPF archives."""
import hashlib
import json
from pathlib import Path
from decode_dtx import Texture

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'extracted/root/data/trick/sticktex.bin'
raw = source.read_bytes()
Texture(raw)  # Validate the source texture before changing the manifest.
folder = ROOT / 'Sources/HotelDuskDuoKit/Resources/OriginalBitmaps'
(folder / 'trick/sticktex.bin').write_bytes(raw)
path = folder / 'OriginalBitmapManifest.json'
manifest = json.loads(path.read_text())
manifest['images'] = [r for r in manifest['images'] if r['source'] != 'trick/sticktex.bin']
manifest['images'].append({'source': 'trick/sticktex.bin', 'payloadSHA256': hashlib.sha256(raw).hexdigest(),
                           'status': 'unresolved', 'error': 'DTX texture; decoded by OriginalTexture',
                           'standaloneSource': 'data/trick/sticktex.bin'})
manifest['images'].sort(key=lambda r: r['source'])
count = sum(r['status'] == 'decoded' for r in manifest['images'])
manifest['coverage'] = {'files': len(manifest['images']), 'decoded': count, 'unresolved': len(manifest['images']) - count}
path.write_text(json.dumps(manifest, indent=2) + '\n')
