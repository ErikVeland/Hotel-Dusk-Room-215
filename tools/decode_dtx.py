#!/usr/bin/env python3
"""Strict original DTX texture recovery. Unknown crops remain unsupported."""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import struct

from cing_container import decompress
from decode_anm import DecodeError, payload, require, sha
from decode_talk_bg import write_png

ROOT = Path(__file__).resolve().parents[1]


def expand(value):
    return (value << 3) | (value >> 2)


class Texture:
    def __init__(self, original):
        self.data = decompress(original) if original[:3] == bytes.fromhex("123dda") else original
        data = self.data
        require(len(data) >= 32 and data[:16] == bytes(16), "Unknown DTX header")
        (self.allocated_width, self.allocated_height, self.logical_width,
         self.logical_height, self.mode, palette_count, palette_offset) = struct.unpack_from("<6HI", data, 16)
        require(palette_offset == 32, "Unknown DTX palette offset")
        require(self.mode in (1, 2, 3, 4, 7), f"Unknown DTX mode {self.mode}")
        require(0 < self.logical_width <= self.allocated_width <= 1024 and
                0 < self.logical_height <= self.allocated_height <= 1024, "Invalid DTX dimensions")
        require(0 < palette_count <= 32768 and 32 + palette_count * 2 <= len(data), "Invalid DTX palette")
        expected_palette = {1: 32, 2: 8, 3: 256, 4: 256}.get(self.mode)
        require(expected_palette is None or palette_count == expected_palette, "Incorrect DTX palette count")
        self.palette = data[32:32 + palette_count * 2]
        self.pixel_data = data[32 + palette_count * 2:]
        self.colours = [tuple((packed >> shift) & 31 for shift in (0, 5, 10))
                        for packed in struct.unpack("<" + "H" * palette_count, self.palette)]
        def size(w, h):
            return w * h * 3 // 8 if self.mode == 7 else w * h
        self.width, self.height = self.logical_width, self.logical_height
        if len(self.pixel_data) != size(self.width, self.height):
            require(len(self.pixel_data) == size(self.allocated_width, self.allocated_height),
                    "DTX pixel length matches neither logical nor allocated dimensions")
            self.width, self.height = self.allocated_width, self.allocated_height
        if self.mode == 7:
            encoded_width, encoded_height = self.width, self.height
            # 0x02083CD0 sets the GPU block-row width from the allocation.
            if self.width % 4:
                self.width = self.allocated_width
            require(self.width % 4 == 0 and len(self.pixel_data) % 6 == 0 and
                    (self.height % 4 == 0 or self.width == self.allocated_width),
                    "DTX compressed block layout")
            require(len(self.pixel_data) == encoded_width * encoded_height * 3 // 8,
                    "Invalid compressed DTX data length")
            blocks_per_row = self.width // 4
            self.height = ((len(self.pixel_data) // 6 + blocks_per_row - 1) // blocks_per_row) * 4

    def rgba(self):
        rgba = bytearray(self.width * self.height * 4)
        def colour(index):
            require(0 <= index < len(self.colours), "Compressed texture references an absent palette entry")
            return self.colours[index]
        def store(index, rgb, alpha):
            rgba[index * 4:index * 4 + 4] = bytes((*map(expand, rgb), expand(alpha)))
        if self.mode != 7:
            for i, value in enumerate(self.pixel_data):
                if self.mode == 1:
                    a3 = value >> 5
                    store(i, colour(value & 31), (a3 << 2) | (a3 >> 1))
                elif self.mode == 2:
                    store(i, colour(value & 7), value >> 3)
                else:
                    store(i, colour(value), 0 if self.mode == 4 and value == 0 else 31)
            return rgba
        blocks = len(self.pixel_data) // 6
        info_offset = blocks * 4
        for block in range(blocks):
            texels = struct.unpack_from("<I", self.pixel_data, block * 4)[0]
            info = struct.unpack_from("<H", self.pixel_data, info_offset + block * 2)[0]
            mode, base = info >> 14, (info & 0x3fff) * 2
            c0, c1 = colour(base), colour(base + 1)
            colours = [c0, c1]
            if mode in (0, 2):
                colours.append(colour(base + 2))
                colours.append(colour(base + 3) if mode == 2 else (0, 0, 0))
            elif mode == 1:
                colours += [tuple((a + b) // 2 for a, b in zip(c0, c1)), (0, 0, 0)]
            else:
                colours += [tuple((a * 5 + b * 3) // 8 for a, b in zip(c0, c1)),
                            tuple((a * 3 + b * 5) // 8 for a, b in zip(c0, c1))]
            bx, by = block % (self.width // 4), block // (self.width // 4)
            for pixel in range(16):
                value = (texels >> (pixel * 2)) & 3
                x, y = bx * 4 + pixel % 4, by * 4 + pixel // 4
                store(y * self.width + x, colours[value], 0 if mode < 2 and value == 3 else 31)
        return rgba


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "extracted/unpacked_wpf")
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--report", type=Path, default=ROOT / "docs/original-texture-report.json")
    parser.add_argument("--preview-prefix", action="append", default=[])
    parser.add_argument("--preview-directory", type=Path, default=ROOT / ".cache/previews/original-textures")
    args = parser.parse_args()
    entries = []
    stats = Counter()
    for path in sorted(args.source.rglob("*.dtx")):
        raw = payload(path)
        relative = path.relative_to(args.source).as_posix()
        record = {"source": relative, "sourceSHA256": sha(path.read_bytes()), "payloadSHA256": sha(raw),
                  "payloadBytes": len(raw)}
        try:
            texture = Texture(raw)
            rgba = texture.rgba()
            record.update({"status": "decoded", "mode": texture.mode,
                           "allocatedWidth": texture.allocated_width, "allocatedHeight": texture.allocated_height,
                           "logicalWidth": texture.logical_width, "logicalHeight": texture.logical_height,
                           "storedWidth": texture.width, "storedHeight": texture.height,
                           "decodedSHA256": sha(texture.data), "paletteSHA256": sha(texture.palette),
                           "pixelDataSHA256": sha(texture.pixel_data), "rgbaSHA256": sha(rgba)})
            stats["decoded"] += 1
            stats[f"mode{texture.mode}"] += 1
            if any(relative.startswith(prefix) for prefix in args.preview_prefix):
                out = args.preview_directory / Path(relative).with_suffix(".png")
                write_png(texture.width, texture.height, rgba, str(out))
        except (DecodeError, ValueError) as error:
            record.update({"status": "unsupported", "error": str(error)})
            stats["unsupported"] += 1
        entries.append(record)
        if args.bundle:
            out = args.bundle / relative
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(raw)
    report = {"formatVersion": 1, "coverage": {"textures": len(entries), **dict(stats)}, "textures": entries}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    if args.bundle:
        (args.bundle / "OriginalTextureManifest.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report["coverage"]))
    for entry in entries:
        if entry["status"] == "unsupported":
            print(entry["source"], entry["error"])


if __name__ == "__main__":
    main()
