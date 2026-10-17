#!/usr/bin/env python3
"""Recover original opening textures and ARM9 type-on card tables."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import struct
from decode_anm import payload, require, sha
from decode_dtx import Texture
from decode_talk_bg import write_png

ROOT = Path(__file__).resolve().parents[1]
BASE = 0x02004000
TABLES = [(0x020e240c, 0x020e23cc), (0x020e248c, 0x020e234c), (0x020e248c, 0x020e238c)]


def portrait(texture):
    """02084d54 maps upright x/y to stored width-1-y/x."""
    source = texture.rgba()
    result = bytearray(len(source))
    for y in range(texture.width):
        for x in range(texture.height):
            a = (x * texture.width + texture.width - 1 - y) * 4
            b = (y * texture.height + x) * 4
            result[b:b+4] = source[a:a+4]
    return result


def render(records, textures, tick):
    result = bytearray(bytes((0, 0, 0, 255)) * (192 * 256))
    for record in records:
        count = min(tick // record['period'], len(record['stripEnds']))
        width = record['stripEnds'][count - 1] if count else 0
        tex = textures[record['texture']]
        image = portrait(tex)
        for y in range(record['height']):
            for x in range(width):
                dx, dy = record['x'] + x, record['y'] + y
                require(0 <= dx < 192 and 0 <= dy < 256, 'Card outside original viewport')
                a = (y * tex.height + x) * 4
                b = (dy * 192 + dx) * 4
                alpha = image[a+3]
                for channel in range(3):
                    result[b+channel] = (image[a+channel] * alpha + result[b+channel] * (255-alpha) + 127) // 255
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arm9', type=Path, default=ROOT / 'extracted/recovered_logic/binaries/arm9.bin')
    parser.add_argument('--source', type=Path, default=ROOT / 'extracted/unpacked_wpf')
    parser.add_argument('--bundle', type=Path, default=ROOT / 'Sources/HotelDuskDuoKit/Resources/OriginalBitmaps')
    parser.add_argument('--report', type=Path, default=ROOT / 'docs/original-opening-graphics-report.json')
    parser.add_argument('--previews', type=Path, default=ROOT / 'docs/previews/original-opening-cards')
    args = parser.parse_args()
    arm9 = args.arm9.read_bytes()
    textures, entries = {}, []
    for path in sorted((args.source / 'show/op2/op3d').glob('*.bin')):
        relative = path.relative_to(args.source).as_posix()
        raw = payload(path)
        texture = Texture(raw)
        textures[relative] = texture
        entries.append({'source': relative, 'payloadSHA256': sha(raw),
                        'decodedSHA256': sha(texture.data), 'mode': texture.mode,
                        'width': texture.width, 'height': texture.height,
                        'paletteSHA256': sha(texture.palette), 'pixelDataSHA256': sha(texture.pixel_data),
                        'rgbaSHA256': sha(texture.rgba()), 'portraitRGBA_SHA256': sha(portrait(texture))})
        # Assets already reside in this resource tree. Refuse to replace them.
        require((args.bundle / relative).read_bytes() == raw, 'Bundled BIN differs from original payload')
    variants = []
    for variant, tables in enumerate(TABLES):
        pages = []
        for page, (address, count) in enumerate(zip(tables, (4, 2))):
            records = []
            for index in range(count):
                at = address + index * 32 - BASE
                raw = arm9[at:at+32]
                polygon, x, y, height, strips, period, name_pointer = struct.unpack_from('<6hI', raw)
                name_offset = name_pointer - BASE
                name = arm9[name_offset:arm9.index(0, name_offset)].decode('ascii')
                ends = list(struct.unpack_from('<8h', raw, 16)[:strips])
                relative = f'show/op2/op3d/{name}.bin'
                require(relative in textures and period > 0 and ends == sorted(set(ends)), 'Unknown card record')
                require(ends[-1] <= textures[relative].height and height <= textures[relative].width,
                        'Card references unavailable pixels')
                records.append({'address': f'{address + index * 32:08x}', 'rawHex': raw.hex(),
                                'polygonID': polygon, 'x': x, 'y': y, 'height': height,
                                'period': period, 'texture': relative, 'stripEnds': ends})
            pages.append(records)
            rgba = render(records, textures, 180)
            write_png(192, 256, rgba, str(args.previews / f'variant{variant}-page{page}.png'))
        variants.append({'variant': variant, 'duration': 181, 'tail': 50,
                         'pages': pages,
                         'pageRGBA180': [sha(render(records, textures, 180)) for records in pages]})
    report = {'formatVersion': 1, 'arm9SHA256': sha(arm9),
              'sourceFunctions': ['020ad384', '020ad634', '020ad9c0', '020ad9e0', '020ada00', '02084d54', '0208595c'],
              'background': {'texture': 'data/map/sys_black.dtx', 'bank': 1, 'index': 1,
                             'zFixed': 8602, 'alpha': 31, 'polygonID': 10, 'colour': 32767},
              'textures': entries, 'variants': variants}
    encoded = json.dumps(report, indent=2) + '\n'
    args.report.write_text(encoded)
    (args.bundle / 'OriginalOpeningGraphicsManifest.json').write_text(encoded)
    print(f'{len(entries)} original textures and {len(variants)} original card variants recovered')


if __name__ == '__main__':
    main()
