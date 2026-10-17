#!/usr/bin/env python3
"""Recover original LRIM tiled animation frames and preserve source hashes."""
from pathlib import Path
import json
import struct
from decode_anm import payload, require, sha
from decode_bitmap import Bitmap
from decode_talk_bg import write_png

ROOT = Path(__file__).resolve().parents[1]


def lz10(data):
    require(len(data) >= 4 and data[0] == 0x10, "Unsupported Nintendo compression")
    length = int.from_bytes(data[1:4], "little")
    require(0 < length <= 64 * 1024 * 1024, "Invalid LZ10 output size")
    output, cursor = bytearray(), 4
    while len(output) < length:
        require(cursor < len(data), "Truncated LZ10 flags")
        flags = data[cursor]
        cursor += 1
        for bit in range(7, -1, -1):
            if len(output) == length:
                break
            if flags >> bit & 1:
                require(cursor + 2 <= len(data), "Truncated LZ10 reference")
                high, low = data[cursor:cursor + 2]
                cursor += 2
                count, distance = (high >> 4) + 3, ((high & 15) << 8 | low) + 1
                require(distance <= len(output) and len(output) + count <= length, "Invalid LZ10 reference")
                for _ in range(count):
                    output.append(output[-distance])
            else:
                require(cursor < len(data), "Truncated LZ10 literal")
                output.append(data[cursor])
                cursor += 1
    require(cursor == len(data), "Unconsumed LZ10 data")
    return bytes(output)


class TileAnimation:
    def __init__(self, data):
        require(len(data) >= 16 and data[:4] == b"LRIM", "Unsupported tiled animation")
        count, offsets, sizes = struct.unpack_from("<3I", data, 4)
        require(0 < count <= 255 and offsets == 16 and sizes == 16 + count * 4,
                "Unsupported LRIM table layout")
        end = 16 + count * 8
        require(end <= len(data), "Truncated LRIM tables")
        self.frames = []
        for i in range(count):
            at = struct.unpack_from("<I", data, offsets + i * 4)[0]
            size = struct.unpack_from("<I", data, sizes + i * 4)[0]
            require(at >= end and size >= 4 and at + size <= len(data), "Invalid LRIM frame bounds")
            self.frames.append(lz10(data[at:at + size]))
            end = at + size
        initial = Bitmap(self.frames[0])
        require((initial.width, initial.height, initial.palette_count) == (256, 192, 256),
                "Unsupported LRIM initial bitmap")
        self.header_palette = self.frames[0][:528]
        self.initial_pixels = initial.pixels

    def decode(self):
        pixels = bytearray(self.initial_pixels)
        for i, frame in enumerate(self.frames):
            if i:
                require(len(frame) >= 96, "Truncated LRIM tile mask")
                cursor = 96
                for tile in range(768):
                    if frame[tile // 8] & (0x80 >> (tile & 7)):
                        require(cursor + 64 <= len(frame), "Truncated LRIM replacement tile")
                        pixels[tile * 64:tile * 64 + 64] = frame[cursor:cursor + 64]
                        cursor += 64
                require(cursor == len(frame), "Unconsumed LRIM delta bytes")
            yield Bitmap(self.header_palette + pixels)


def main():
    source = ROOT / "extracted/unpacked_wpf"
    entries, total = [], 0
    for path in sorted(source.rglob("*.bin")):
        data = payload(path)
        if data[:4] != b"LRIM":
            continue
        clip = TileAnimation(data)
        frames = []
        for index, bitmap in enumerate(clip.decode()):
            frames.append({"frame": index, "decompressedSHA256": sha(clip.frames[index]),
                           "pixelsSHA256": sha(bitmap.pixels), "rgbaSHA256": sha(bitmap.rgba)})
            total += 1
            if path.stem == "05-05R":
                upright = bytearray(len(bitmap.rgba))
                for y in range(bitmap.height):
                    for x in range(bitmap.width):
                        src = (y * bitmap.width + x) * 4
                        dst = ((bitmap.width - 1 - x) * bitmap.height + y) * 4
                        upright[dst:dst + 4] = bitmap.rgba[src:src + 4]
                write_png(192, 256, upright, str(ROOT / f"docs/previews/original-tile-animations/05-05R/{index:03}.png"))
        entries.append({"source": path.relative_to(source).as_posix(), "payloadSHA256": sha(data),
                        "frameCount": len(frames), "frames": frames})
    report = {"formatVersion": 1, "coverage": {"animations": len(entries), "frames": total}, "animations": entries}
    text = json.dumps(report, indent=2) + "\n"
    (ROOT / "docs/original-tile-animation-report.json").write_text(text)
    (ROOT / "Sources/HotelDuskDuoKit/Resources/OriginalBitmaps/OriginalTileAnimationManifest.json").write_text(text)
    print(report["coverage"])


if __name__ == "__main__":
    main()
