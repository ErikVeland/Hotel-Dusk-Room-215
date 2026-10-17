#!/usr/bin/env python3
"""Read original sound lookup tables and initial state defaults without inference."""
from pathlib import Path
import hashlib
import json
import struct
from resolve_original_globals import runtime_segments, read_bytes, printable_string

ROOT = Path(__file__).resolve().parents[1]


def recover():
    arm9 = (ROOT / 'extracted/recovered_logic/binaries/arm9.bin').read_bytes()
    segments, _ = runtime_segments(arm9)
    music = []
    for index in range(36):
        address = 0x020ddf8c + index * 8
        name, sequence = struct.unpack('<2I', read_bytes(segments, address, 8))
        music.append({'address': f'{address:08x}', 'name': printable_string(segments, name),
                      'sequenceID': sequence})
    sounds = []
    for index in range(197):
        address = 0x020de79c + index * 12
        name, field4, field8 = struct.unpack('<3I', read_bytes(segments, address, 12))
        sounds.append({'address': f'{address:08x}', 'name': printable_string(segments, name),
                       'output1': field8, 'output2': field4})
    defaults = {}
    for filename, header, stride, count_format in [
        ('door_flg.bin', 16, 16, '<h'), ('onoffobjs.dat', 4, 48, '<I')
    ]:
        data = (ROOT / 'extracted/root/data/map/sdata' / filename).read_bytes()
        count, = struct.unpack_from(count_format, data)
        assert len(data) == header + stride * count
        defaults[filename] = {'sha256': hashlib.sha256(data).hexdigest(), 'count': count,
                              'headerBytes': header, 'stride': stride,
                              'records': [{'sourceOffset': header + index * stride,
                                           'id': struct.unpack_from('<h', data, header + index * stride)[0],
                                           'initialValue': struct.unpack_from('<h', data, header + index * stride + (2 if stride == 16 else 8))[0]}
                                          for index in range(count)]}
    return {'schemaVersion': 1, 'arm9SHA256': hashlib.sha256(arm9).hexdigest(),
            'musicLookupFunction': '0200ae18', 'soundLookupFunction': '0200ad94',
            'music': music, 'sounds': sounds, 'initialDefaults': defaults,
            'overlayLoader': {'function': '0200b2d8', 'table': '020e92a4',
                              'slotToOverlayID': list(struct.unpack('<44I', read_bytes(segments, 0x020e92a4, 44 * 4)))}}


if __name__ == '__main__':
    result = recover()
    path = ROOT / 'extracted/recovered_logic/runtime-tables.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Recovered {len(result["music"])} music and {len(result["sounds"])} sound mappings.')
