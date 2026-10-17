#!/usr/bin/env python3
"""Read Cing archive members without interpreting their payload.

The reference format is documented by its researcher at
https://jasonharley2o.com/reverse/hoteldusk/ . The zero-filled dictionary
is modelled directly, including initial and overlapping references.
"""
import struct


def decompress(data: bytes) -> bytes:
    """Decode a 16-byte Cing envelope; reject malformed streams."""
    if len(data) < 16 or data[:3] != bytes.fromhex('123dda'):
        raise ValueError('Missing Cing envelope')
    mode = data[3]
    size, compressed_size, reserved = struct.unpack_from('<III', data, 4)
    if reserved != 0:
        raise ValueError('Unexpected Cing reserved field')
    if mode == 0:
        if compressed_size != 0xFFFFFFFF or len(data) != 16 + size:
            raise ValueError('Invalid uncompressed envelope length')
        return data[16:]
    if mode != 1 or len(data) != 16 + compressed_size:
        raise ValueError('Invalid compressed envelope length or mode')
    dictionary = bytearray(65536)
    write = 65536 - 259
    source = memoryview(data)[16:]
    output = bytearray()
    cursor = 0
    while cursor < len(source):
        flags = source[cursor]
        cursor += 1
        for bit in range(8):
            if cursor == len(source):
                break
            if flags & (1 << bit):
                values = [source[cursor]]
                cursor += 1
                read = None
            else:
                if cursor + 3 > len(source):
                    raise ValueError('Truncated dictionary token')
                read = struct.unpack_from('<H', source, cursor)[0]
                values = range(source[cursor + 2] + 4)
                cursor += 3
            for value in values:
                if read is not None:
                    value = dictionary[read]
                    read = (read + 1) & 65535
                if len(output) >= size:
                    raise ValueError('Dictionary token exceeds declared output')
                output.append(value)
                dictionary[write] = value
                write = (write + 1) & 65535
    if len(output) != size:
        raise ValueError('Decoded size does not match envelope')
    return bytes(output)


def decode_member(data: bytes) -> bytes:
    """Validate and strip the 32-byte WPF record, then decode its envelope."""
    if len(data) < 48:
        raise ValueError('Truncated WPF member')
    size = struct.unpack_from('<I', data, 24)[0]
    if size != len(data) - 32:
        raise ValueError('WPF member length does not match its record')
    return decompress(data[32:])
