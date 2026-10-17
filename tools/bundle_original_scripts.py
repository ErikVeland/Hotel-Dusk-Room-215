#!/usr/bin/env python3
"""Bundle source records for the native Swift reader, without inventing commands."""
from pathlib import Path
import hashlib
import json
import shutil
from cing_container import decode_member

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'extracted/unpacked_wpf/local/us/textdata_usa'
DESTINATION = ROOT / 'Sources/HotelDuskDuoKit/Resources/Original/Scripts'


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    records = []
    for source in sorted(SOURCE.iterdir()):
        if not source.is_file():
            continue
        data = source.read_bytes()
        shutil.copyfile(source, DESTINATION / source.name)
        decoded = decode_member(data)
        records.append({'name': source.name, 'sha256': hashlib.sha256(data).hexdigest(),
                        'decodedSHA256': hashlib.sha256(decoded).hexdigest()})
    rom = ROOT / 'Source/ROM/Hotel Dusk - Room 215.nds'
    manifest = {
        'romSHA256': hashlib.sha256(rom.read_bytes()).hexdigest(),
        'source': 'extracted/unpacked_wpf/local/us/textdata_usa',
        'status': 'Original data records; command semantics are not fully recovered.',
        'files': records,
    }
    (DESTINATION / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Bundled {len(records)} byte-exact source records.')


if __name__ == '__main__':
    main()
