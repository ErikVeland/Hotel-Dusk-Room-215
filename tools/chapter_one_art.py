#!/usr/bin/env python3
"""Conservative Chapter 1 artwork selection, derived from bundled scripts."""
from pathlib import Path
import re
import struct

from cing_container import decompress
from decode_anm import payload

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'Sources/HotelDuskDuoKit/Resources/Original/Scripts'
ROOMS = ('R000', 'R101', 'R102', 'R103', 'R117', 'R205', 'R213')


def selected_clips():
    expressions = {}
    person = None
    text = decompress(payload(SCRIPTS / 'ExpList.def')).decode('latin1')
    for line in text.splitlines():
        fields = line.split('//')[0].split()
        if len(fields) == 2 and fields[0] == 'ID':
            person = int(fields[1])
        elif len(fields) == 2 and fields[0].isdigit() and person:
            expressions[person, int(fields[0])] = fields[1].lower() + '_'
    poses = set()
    for path in [*SCRIPTS.glob('EP1_*.blk'), SCRIPTS / 'System.blk']:
        data = decompress(payload(path))
        offset, count = struct.unpack_from('<II', data, 24)
        for i in range(count):
            row = data[offset + i * 16:offset + (i + 1) * 16]
            if len(row) != 16 or row[0] != 4:
                continue
            rows = [row]
            if row[1] == 2 and i + 1 < count:
                rows.append(data[offset + (i + 1) * 16:offset + (i + 2) * 16])
            for presentation in rows:
                if len(presentation) != 16:
                    continue
                person, pose = struct.unpack_from('bb', presentation, 2)
                if 1 <= person <= 17:
                    poses.add((person, pose if pose > 0 else 2))
    return {expressions[p] for p in poses if p in expressions}


def select(record, clips):
    sources = record['sources']
    if record['category'] == 'animation':
        return any(Path(s.split('#')[0]).stem.lower() in clips for s in sources)
    if record['category'] == 'texture':
        return any(not s.startswith('OriginalTextures/map/') or
                   any(s.startswith('OriginalTextures/map/' + room + '/') for room in ROOMS)
                   for s in sources)
    if record['category'] == 'png':
        return any(not s.startswith('Images/Backgrounds/R') or
                   any('/' + room in s for room in ROOMS) for s in sources)
    return True
