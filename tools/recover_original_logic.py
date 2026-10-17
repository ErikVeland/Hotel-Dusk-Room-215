#!/usr/bin/env python3
"""Recover exact data structures for analysis; this is not a game interpreter."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
from cing_container import decode_member
from wrap_elf import create_arm_elf

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def decompress_code(data):
    """Decode the supplied ROM's Nintendo backwards-LZ code format.

    Format reference: https://github.com/RoadrunnerWMC/ndspy/blob/master/ndspy/codeCompression.py
    This implementation requires exact input/output bounds and does not repair
    invalid offsets or guess whether arbitrary input is compressed.
    """
    packed, extra = struct.unpack_from('<II', data, len(data) - 8)
    header_size, compressed_size = packed >> 24, packed & 0xFFFFFF
    if not (8 <= header_size <= compressed_size <= len(data)) or not extra:
        raise ValueError('Invalid backwards-LZ footer')
    if any(v != 255 for v in data[len(data) - header_size:len(data) - 8]):
        raise ValueError('Invalid backwards-LZ padding')
    start = len(data) - compressed_size
    output = bytearray(data) + bytearray(extra)
    read, write = len(data) - header_size, len(output)
    while write > start:
        read -= 1
        if read < start:
            raise ValueError('Truncated backwards-LZ flag')
        flags = data[read]
        for bit in range(7, -1, -1):
            if write == start:
                break
            if flags & (1 << bit):
                read -= 2
                if read < start:
                    raise ValueError('Truncated backwards-LZ token')
                first, second = data[read + 1], data[read]
                length = (first >> 4) + 3
                distance = ((first & 15) << 8 | second) + 3
                if write - length < start or write - 1 + distance >= len(output):
                    raise ValueError('Invalid backwards-LZ reference')
                for _ in range(length):
                    write -= 1
                    output[write] = output[write + distance]
            else:
                read -= 1
                write -= 1
                if read < start:
                    raise ValueError('Truncated backwards-LZ literal')
                output[write] = data[read]
    if read != start:
        raise ValueError('Backwards-LZ did not consume its source')
    return bytes(output)


def cstring(data):
    # Preserve every byte, including original inline controls, losslessly.
    return data.split(b'\0', 1)[0].decode('latin-1')


def parse_text(data):
    count = struct.unpack_from('<I', data)[0]
    base = 4 + count * 4
    if base > len(data):
        raise ValueError('Text offset table exceeds payload')
    offsets = struct.unpack_from('<' + 'I' * count, data, 4)
    records = []
    for index, offset in enumerate(offsets):
        absolute = base + offset
        if absolute >= len(data):
            raise ValueError('Text offset exceeds payload')
        end = data.find(b'\0', absolute)
        if end < 0:
            raise ValueError('Text is not NUL terminated')
        records.append({'index': index, 'relativeOffset': offset,
                        'byteOffset': absolute, 'rawText': cstring(data[absolute:end])})
    return {'kind': 'indexedText', 'count': count, 'dataOffset': base, 'records': records}


def parse_blocks(data):
    header = struct.unpack_from('<8I', data)
    tables = []
    for index, stride in enumerate((16, 16, 20, 16)):
        offset, count = header[index * 2:index * 2 + 2]
        end = header[(index + 1) * 2] if index < 3 else len(data)
        if offset + count * stride != end:
            raise ValueError(f'Block table {index} bounds differ from its records')
        records = []
        for record in range(count):
            position = offset + record * stride
            raw = data[position:position + stride]
            records.append({'index': record, 'byteOffset': position,
                            'u16': list(struct.unpack('<' + 'H' * (stride // 2), raw)),
                            'hex': raw.hex()})
        tables.append({'index': index, 'byteOffset': offset,
                       'count': count, 'recordSize': stride, 'records': records})
    # Cross-table addresses follow the native selector at 0x020551B8.
    for source, destination in ((0, 1), (1, 2)):
        for row in tables[source]['records']:
            _, relative, count, _ = struct.unpack('<4I', bytes.fromhex(row['hex']))
            target = tables[destination]
            if relative % target['recordSize'] or relative + count * target['recordSize'] > target['count'] * target['recordSize']:
                raise ValueError('Block child span exceeds table')
            row['childStartIndex'] = relative // target['recordSize']
            row['childCount'] = count
    for row in tables[2]['records']:
        raw = bytes.fromhex(row['hex'])
        count = struct.unpack_from('<H', raw, 6)[0]
        relative = struct.unpack_from('<I', raw, 8)[0]
        if relative % 16 or relative + count * 16 > tables[3]['count'] * 16:
            raise ValueError('Block operation span exceeds table')
        row['operationStartIndex'] = relative // 16
        row['operationCount'] = count
    return {'kind': 'blockTables', 'tables': tables}


def parse_records(data, stride, string_bytes, string_offset=0):
    if len(data) % stride:
        raise ValueError('Fixed record table has trailing data')
    records = []
    for offset in range(0, len(data), stride):
        raw = data[offset:offset + stride]
        row = {'index': offset // stride, 'byteOffset': offset, 'hex': raw.hex(),
               'rawText': cstring(raw[string_offset:string_offset + string_bytes])}
        if string_offset == 2:
            row['key'] = struct.unpack_from('<H', raw)[0]
        if stride == 64:
            row['rawFields'] = list(struct.unpack_from('<4I', raw, 48))
        records.append(row)
    return {'kind': 'fixedRecords', 'recordSize': stride, 'records': records}


def parse_checks(data, event_count):
    header_bytes = event_count * 16
    if len(data) < header_bytes:
        raise ValueError('Check header is shorter than the paired event table')
    entries = []
    for event in range(event_count):
        spans = []
        for half in (0, 8):
            offset, count = struct.unpack_from('<II', data, event * 16 + half)
            if offset == count == 0xFFFFFFFF:
                spans.append(None)
                continue
            if offset < header_bytes or offset % 16 or offset + count * 16 > len(data):
                raise ValueError('Check span exceeds payload')
            rows = []
            for index in range(count):
                position = offset + index * 16
                raw = data[position:position + 16]
                rows.append({'index': index, 'byteOffset': position, 'kindByte': raw[0],
                             'signedKind': struct.unpack_from('<b', raw)[0],
                             'hex': raw.hex(), 'u16': list(struct.unpack('<8H', raw))})
            spans.append({'byteOffset': offset, 'count': count, 'records': rows})
        entries.append({'eventIndex': event, 'byteOffset': event * 16,
                        'driveConditions': spans[0], 'secondSpan': spans[1]})
    return {'kind': 'checkTables', 'eventCount': event_count, 'entries': entries}


def recover_dispatch(arm9, script_output):
    base, table = 0x02004000, 0x0203BEC0
    handlers = []
    for opcode in range(54):
        address = table + opcode * 4
        word = struct.unpack_from('<I', arm9, address - base)[0]
        if word >> 24 != 0xEA:
            raise ValueError('Expected unconditional ARM branch in operation table')
        relative = word & 0xFFFFFF
        if relative & 0x800000:
            relative -= 0x1000000
        handlers.append({'opcode': opcode, 'branchAddress': address,
                         'handlerAddress': address + 8 + relative * 4,
                         'observedCount': 0, 'example': None})
    for path in sorted(script_output.glob('*.blk.json')):
        for operation in json.loads(path.read_text())['tables'][3]['records']:
            raw = bytes.fromhex(operation['hex'])
            opcode = raw[0]
            if opcode >= len(handlers):
                raise ValueError('Operation code outside recovered dispatch range')
            handler = handlers[opcode]
            handler['observedCount'] += 1
            if handler['example'] is None:
                handler['example'] = {'script': path.name[:-5], 'byteOffset': operation['byteOffset'],
                                      'operationIndex': operation['index'], 'hex': operation['hex']}
    return {'arm9DecodedSHA256': digest(arm9), 'dispatchAddress': 0x0203BEB4,
            'tableAddress': table, 'recordSize': 16, 'opcodeByteOffset': 0,
            'scope': 'Verified dispatch targets, not complete operation semantics.',
            'handlers': handlers}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'extracted/recovered_logic')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    source = ROOT / 'extracted/unpacked_wpf/local/us/textdata_usa'
    script_output = args.output / 'scripts'
    script_output.mkdir(exist_ok=True)
    reports = []
    for path in sorted(source.iterdir()):
        if not path.is_file():
            continue
        raw = path.read_bytes()
        data = decode_member(raw)
        report = {'name': path.name, 'source': str(path.relative_to(ROOT)),
                  'sourceSHA256': digest(raw), 'decodedSHA256': digest(data),
                  'sourceBytes': len(raw), 'decodedBytes': len(data)}
        decoded_path = script_output / path.name
        decoded_path.write_bytes(data)
        structure = None
        if path.name.endswith('_BOOK.txt'):
            structure = {'kind': 'plainChapterText', 'rawText': data.decode('latin-1')}
        elif path.suffix == '.txt':
            structure = parse_text(data)
        elif path.suffix == '.blk':
            structure = parse_blocks(data)
        elif path.suffix == '.chk':
            paired = decode_member(path.with_suffix('.blk').read_bytes())
            event_count = struct.unpack_from('<I', paired, 20)[0]
            structure = parse_checks(data, event_count)
        elif path.suffix == '.dbg':
            structure = parse_records(data, 32, 30, 2)
        elif path.suffix == '.kif':
            structure = parse_records(data, 64, 48)
        if structure is not None:
            (script_output / (path.name + '.json')).write_text(json.dumps(structure, indent=2) + '\n')
            report['structure'] = structure['kind']
            if 'records' in structure:
                report['recordCount'] = len(structure['records'])
            if 'tables' in structure:
                report['tableCounts'] = [t['count'] for t in structure['tables']]
        else:
            report['structure'] = 'opaquePreservedPayload'
        reports.append(report)

    rom_path = ROOT / 'Source/ROM/Hotel Dusk - Room 215.nds'
    rom = rom_path.read_bytes()
    binaries_output = args.output / 'binaries'
    binaries_output.mkdir(exist_ok=True)
    binaries = []
    for name, header in [('arm9', 0x20), ('arm7', 0x30)]:
        offset, entry, address, length = struct.unpack_from('<4I', rom, header)
        raw = rom[offset:offset + length]
        compressed = name == 'arm9'
        decoded = decompress_code(raw) if compressed else raw
        path = binaries_output / (name + '.bin')
        path.write_bytes(decoded)
        create_arm_elf(str(path), str(path.with_suffix('.elf')), address, entry)
        binaries.append({'name': name, 'romOffset': offset, 'address': address, 'entry': entry,
                         'sourceBytes': length, 'decodedBytes': len(decoded), 'compressed': compressed,
                         'sourceSHA256': digest(raw), 'decodedSHA256': digest(decoded)})
    table, table_bytes = struct.unpack_from('<2I', rom, 0x50)
    fat, _ = struct.unpack_from('<2I', rom, 0x48)
    for position in range(table, table + table_bytes, 32):
        number, address, length, bss, init_start, init_end, file_id, flags = struct.unpack_from('<8I', rom, position)
        start, end = struct.unpack_from('<2I', rom, fat + file_id * 8)
        raw = rom[start:end]
        compressed = bool(flags & 0x01000000)
        decoded = decompress_code(raw) if compressed else raw
        if len(decoded) != length:
            raise ValueError('Overlay size differs from its load table')
        path = binaries_output / f'overlay_{number:04}.bin'
        path.write_bytes(decoded)
        binaries.append({'name': path.stem, 'romOffset': start, 'address': address,
                         'bssBytes': bss, 'initializersStart': init_start, 'initializersEnd': init_end,
                         'fileID': file_id, 'flags': flags, 'sourceBytes': len(raw),
                         'decodedBytes': len(decoded), 'compressed': compressed,
                         'sourceSHA256': digest(raw), 'decodedSHA256': digest(decoded)})
    index = {'schemaVersion': 1, 'romSHA256': digest(rom),
             'semantics': 'Structural recovery only; no inferred opcodes are executed.',
             'scripts': reports, 'binaries': binaries}
    (args.output / 'index.json').write_text(json.dumps(index, indent=2) + '\n')
    dispatch = recover_dispatch((binaries_output / 'arm9.bin').read_bytes(), script_output)
    (args.output / 'dispatch.json').write_text(json.dumps(dispatch, indent=2) + '\n')
    print(f'Recovered {len(reports)} script members and {len(binaries)} code images into {args.output}')


if __name__ == '__main__':
    main()
