#!/usr/bin/env python3
"""Resolve decompiler literal references through the ROM's runtime memory map.

Values are source bytes, not inferred game state. Uninitialized memory is recorded
as unknown. Autoload data must be addressed through ITCM/DTCM after relocation.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct

ROOT = Path(__file__).resolve().parents[1]


def runtime_segments(data):
    base = 0x02004000
    table, end, source, bss, bss_end = struct.unpack_from('<5I', data, 0xb68)
    segments = [(base, data[:bss-base], 'arm9-main')]
    unknown = [(bss, bss_end, 'arm9-bss')]
    for offset in range(table-base, end-base, 12):
        address, length, zero = struct.unpack_from('<3I', data, offset)
        segments.append((address, data[source-base:source-base+length], 'arm9-autoload'))
        unknown.append((address+length, address+length+zero, 'autoload-bss'))
        source += length
    return segments, unknown


def arm7_segments(data):
    base=0x02380000
    table,end,source,bss,bss_end=struct.unpack_from('<5I',data,0x198)
    segments=[(base,data[:0x1b0],'arm7-startup')]
    unknown=[(bss,bss_end,'arm7-bss')]
    for offset in range(table-base,end-base,12):
        address,length,zero=struct.unpack_from('<3I',data,offset)
        segments.append((address,data[source-base:source-base+length],'arm7-autoload'))
        unknown.append((address+length,address+length+zero,'arm7-autoload-bss'))
        source+=length
    return segments,unknown


def read_bytes(segments, address, count):
    for base, data, name in segments:
        if base <= address and address + count <= base + len(data):
            return data[address-base:address-base+count]
    return None


def printable_string(segments, address):
    chars = bytearray()
    for offset in range(256):
        byte = read_bytes(segments, address+offset, 1)
        if not byte:
            return None
        if byte == b'\0':
            return chars.decode('ascii') if len(chars) >= 3 else None
        if byte[0] not in (9,10,13) and not 32 <= byte[0] < 127:
            return None
        chars += byte
    return None


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory',type=Path,default=ROOT/'extracted/decompiled/arm9')
    args=parser.parse_args()
    processor='arm7' if args.directory.name=='arm7' else 'arm9'
    path=ROOT/'extracted/recovered_logic/binaries'/f'{processor}.bin'
    data=path.read_bytes()
    segments, unknown=(arm7_segments if processor=='arm7' else runtime_segments)(data)
    overlay_hash=None
    if args.directory.name.startswith('overlay_'):
        metadata=json.loads((ROOT/'extracted/recovered_logic/index.json').read_text())
        record=next(r for r in metadata['binaries'] if r['name']==args.directory.name)
        overlay=(ROOT/'extracted/recovered_logic/binaries'/f"{record['name']}.bin").read_bytes()
        segments.append((record['address'],overlay,record['name']))
        unknown.append((record['address']+len(overlay),record['address']+len(overlay)+record['bssBytes'],'overlay-bss'))
        overlay_hash=hashlib.sha256(overlay).hexdigest()
    references={}
    for file in sorted(args.directory.glob('*.c')):
        for match in re.finditer(r'\b(?:DAT|PTR|UNK|s)_(?:[A-Za-z0-9_]*_)?([0-9a-fA-F]{8})\b',file.read_text()):
            address=int(match[1],16)
            references.setdefault(address,set()).add(file.stem)
    results=[]
    for address,callers in sorted(references.items()):
        record={'address':f'{address:08x}','functions':sorted(callers)}
        raw=read_bytes(segments,address,4)
        if raw:
            value=struct.unpack('<I',raw)[0]
            record.update(raw=raw.hex(),u32=value,hex32=f'{value:08x}')
            literal=printable_string(segments,address)
            pointed=printable_string(segments,value)
            if literal: record['stringAtAddress']=literal
            if pointed: record['pointedString']=pointed
            destination=read_bytes(segments,value,32)
            if destination: record['pointedBytes32']=destination.hex()
        else:
            record['uninitialized']=any(start<=address<end for start,end,_ in unknown)
        results.append(record)
    output={'schemaVersion':1,f'{processor}SHA256':hashlib.sha256(data).hexdigest(),
            'semantics':'Literal source values only. BSS game state is unknown.',
            'references':results}
    if overlay_hash:output['overlaySHA256']=overlay_hash
    (args.directory/'globals.json').write_text(json.dumps(output,indent=2)+'\n')
    print(f'Resolved {sum("raw" in x for x in results)}/{len(results)} global references')

if __name__=='__main__': main()
