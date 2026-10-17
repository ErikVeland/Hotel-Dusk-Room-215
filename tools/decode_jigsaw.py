#!/usr/bin/env python3
"""Decode Melissa's original jigsaw graphics from the supplied Hotel Dusk assets.

CiNG container/LZ format reference: https://jasonharley2o.com/reverse/hoteldusk/
No graphics are drawn or synthesized. PNGs retain the decoded source pixels.
"""
from pathlib import Path
import hashlib
import json
import struct
from decode_talk_bg import write_png

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'extracted/unpacked_wpf/trick/zig'
DESTINATION = ROOT / 'Sources/HotelDuskDuoKit/Resources/Images/Puzzles/Jigsaw'


from cing_container import decompress


def decode(path):
    data = decompress(path.read_bytes()[32:])  # WPF inline directory record
    width, height, w_check, h_check, mode, count = struct.unpack_from('<6H', data, 16)
    assert 0 < w_check <= width and 0 < h_check <= height
    # Reverse edge sprites retain a 64-pixel texture with a 51-pixel logical crop.
    assert (mode, count) in ((1, 32), (4, 256))
    palette = []
    for packed in struct.unpack_from('<' + 'H' * count, data, 32):
        channels = [(packed >> shift) & 31 for shift in (0, 5, 10)]
        palette.append(tuple((value << 3) | (value >> 2) for value in channels))
    pixels = data[32 + count * 2:]
    assert len(pixels) == width * height
    rgba = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            value = pixels[y * width + x]
            index = value & 31 if mode == 1 else value
            alpha = ((value >> 5) * 255 + 3) // 7 if mode == 1 else 255
            # Assets are stored sideways. This is a lossless 90-degree rotation.
            output = ((width - 1 - x) * height + y) * 4
            rgba[output:output + 4] = bytes((*palette[index], alpha))
    return height, width, rgba


def decode_icon(path):
    data = path.read_bytes()[32:]
    # SystemIcon members can contain raw tiled data without a Cing envelope.
    if data[:3] == bytes.fromhex('123dda'):
        data = decompress(data)
    palette_count, width, height = struct.unpack_from('<3H', data, 2)
    assert palette_count == 16 and width % 8 == 0 and height % 8 == 0
    assert len(data) == 16 + palette_count * 2 + width * height // 2
    palette = []
    for index, packed in enumerate(struct.unpack_from('<16H', data, 16)):
        channels = [(packed >> shift) & 31 for shift in (0, 5, 10)]
        palette.append(bytes((*[(v << 3) | (v >> 2) for v in channels], 255)) if index else bytes(4))
    pixels = data[48:]
    rgba = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            tile = (y // 8) * (width // 8) + x // 8
            index = tile * 64 + (y % 8) * 8 + x % 8
            value = pixels[index // 2]
            color = (value >> 4) & 15 if index % 2 else value & 15
            output = ((width - 1 - x) * height + y) * 4
            rgba[output:output + 4] = palette[color]
    return height, width, rgba


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    files = {
        'zig_ura_01': 'JigsawFront',
        'zig_ura_02': 'JigsawFoldTray',
        'zig_ura_03': 'JigsawReverse',
        'table': 'JigsawTray',
        'table_bk': 'JigsawTable',
    }
    pieces = []
    # The original assembly view uses a 130 x 162.5 picture in its tray. A
    # 40-pixel native cell becomes 32.5 stage pixels; the 13-pixel sprite padding
    # remains part of each original alpha image, including the projecting tabs.
    scale = 13 / 16
    for row in range(5):
        for column in range(4):
            piece_id = f'{row}{column}'
            original = f'zig{piece_id}'
            asset = f'JigsawPiece{piece_id}'
            files[original] = asset
            files[f'zig_{piece_id}'] = f'JigsawBackPiece{piece_id}'
            width, height, rgba = decode(SOURCE / f'{original}.bin')
            points = [(i // 4 % width, i // 4 // width) for i in range(0, len(rgba), 4) if rgba[i + 3]]
            xmin, xmax = min(x for x, y in points), max(x for x, y in points)
            ymin, ymax = min(y for x, y in points), max(y for x, y in points)
            pieces.append({
                'id': piece_id,
                'image': asset,
                'x': 31 + (column * 40 - 13) * scale,
                'y': 21 + (row * 40 - 13) * scale,
                'width': width * scale,
                'height': height * scale,
                'nativeWidth': width,
                'nativeHeight': height,
                'alphaBounds': {'x': xmin, 'y': ymin, 'width': xmax - xmin + 1, 'height': ymax - ymin + 1},
                'row': row,
                'column': column,
            })
    provenance = []
    for original, asset in files.items():
        source = SOURCE / f'{original}.bin'
        width, height, rgba = decode(source)
        destination = DESTINATION / f'{asset}.png'
        write_png(width, height, rgba, str(destination))
        provenance.append({
            'image': asset,
            'source': str(source.relative_to(ROOT)),
            'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'pngSHA256': hashlib.sha256(destination.read_bytes()).hexdigest(),
            'width': width,
            'height': height,
        })
    for original, asset in [('left1', 'JigsawRotateLeft'), ('right2', 'JigsawRotateRight')]:
        source = ROOT / 'extracted/unpacked_wpf/local/us/SystemIcon' / f'{original}.bin'
        width, height, rgba = decode_icon(source)
        destination = DESTINATION / f'{asset}.png'
        write_png(width, height, rgba, str(destination))
        provenance.append({
            'image': asset,
            'source': str(source.relative_to(ROOT)),
            'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'pngSHA256': hashlib.sha256(destination.read_bytes()).hexdigest(),
            'width': width,
            'height': height,
        })
    manifest = {
        'boardWidth': 192,
        'boardHeight': 256,
        'pieces': pieces,
        'frontImage': 'JigsawFront',
        'reverseImage': 'JigsawReverse',
        'tableImage': 'JigsawTable',
        'trayImage': 'JigsawTray',
        'foldTrayImage': 'JigsawFoldTray',
        'rotateLeftImage': 'JigsawRotateLeft',
        'rotateRightImage': 'JigsawRotateRight',
        'assemblyPictureBounds': {'x': 30, 'y': 20, 'width': 131, 'height': 164},
        'sourceNativeCellSize': 40,
        'sourceNativePadding': 13,
        'assemblyScale': scale,
        'provenance': provenance,
    }
    (DESTINATION / 'JigsawManifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Decoded {len(provenance)} original images and 20 piece placements into {DESTINATION}')


if __name__ == '__main__':
    main()
