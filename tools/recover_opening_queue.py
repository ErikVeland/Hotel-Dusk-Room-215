#!/usr/bin/env python3
"""Recover the initialized opening command data from an unmodified ROM trace.

This exports inert command parameters, not ARM instructions. Native Swift handlers
must implement each operation. The capture is after the initializer has finished
and before the first queued operation has run.
"""
from pathlib import Path
import hashlib
import json
import struct
import base64

ROOT = Path(__file__).resolve().parents[1]
RAM = ROOT / 'extracted/reference/opening-initializer/init03-ram.bin'
NEXT = ROOT / 'extracted/reference/opening-initializer/init04-ram.bin'
BASE = 0x022543F4


def recover():
    data = RAM.read_bytes()
    following = NEXT.read_bytes()
    assert len(data) == len(following) == 0x400000
    def word(address, memory=data):
        assert 0x02000000 <= address <= 0x023FFFFC
        return struct.unpack_from('<I', memory, address - 0x02000000)[0]
    assert word(BASE + 0x298) == 0, 'The first command has already run'
    first = word(BASE + 0x2A4)
    assert word(BASE + 0x298, following) == first, 'Next frame must activate the first command'
    commands, seen = [], set()
    node = first
    while node:
        assert node not in seen
        seen.add(node)
        obj = word(node)
        vtable = word(obj)
        size = word(obj - 32) - 32
        assert word(obj - 28) == 0xA5 and 8 <= size <= 0x400
        payload = data[obj - 0x02000000:obj - 0x02000000 + size]
        commands.append({'handlerAddress': word(vtable + 8),
                         'objectData': base64.b64encode(payload).decode()})
        node = word(node + 4)
    assert len(commands) == 459
    return {'schemaVersion': 1, 'initializerAddress': 0x020109B4,
            'updateAddress': 0x020A1A5C,
            'romSHA256': hashlib.sha256((ROOT / 'Source/ROM/Hotel Dusk - Room 215.nds').read_bytes()).hexdigest(),
            'captureSHA256': hashlib.sha256(data).hexdigest(),
            'trace': 'tools/reference/opening-initializer.txt',
            'handedness': 0, 'commands': commands}


if __name__ == '__main__':
    result = recover()
    destination = ROOT / 'Sources/HotelDuskDuoKit/Resources/Original/GameData/OriginalOpeningQueue.json'
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Recovered {len(result["commands"])} initialized original opening commands.')
