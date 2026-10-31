#!/usr/bin/env python3
"""Recover original ANM frames without drawing replacement art.

The delta codec, initial fill, loop restart and texture format are confirmed
against the supplied ARM9. See docs/original-graphics.md for addresses/limits.
Only Python's standard library is required. Unknown streams fail explicitly.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct

from decode_talk_bg import write_png

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "extracted/unpacked_wpf"
DESTINATION = ROOT / "Sources/HotelDuskDuoKit/Resources/OriginalAnimations"


class DecodeError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise DecodeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def payload(path):
    """Validate and remove the WPF inline record; retain the original payload."""
    raw = path.read_bytes()
    require(len(raw) >= 32, "Missing WPF inline record")
    size = struct.unpack_from("<I", raw, 24)[0]
    require(size == len(raw) - 32, "WPF record size differs from payload")
    return raw[32:]


class Animation:
    def __init__(self, data):
        self.data = data
        require(len(data) >= 32, "Truncated ANM header")
        (self.version, self.frame_count, self.descriptor_bytes, self.clear_word,
         self.width, self.height, self.first_number, self.last_number,
         self.loop_number, r0, r1, r2) = struct.unpack_from("<4I8H", data)
        require(self.version == 1, f"Unknown ANM version {self.version}")
        require(0 < self.width <= 1024 and 0 < self.height <= 1024,
                "Invalid ANM dimensions")
        require(0 < self.frame_count <= 4096, "Invalid ANM frame count")
        require(self.descriptor_bytes == self.frame_count * 16,
                "Invalid ANM descriptor table length")
        require(32 + self.descriptor_bytes <= len(data), "Truncated descriptor table")
        require((r0, r1, r2) == (0, 0, 0), "Unknown ANM header flags")
        self.loop_start = self.loop_number - self.first_number + 1
        require(0 <= self.loop_start < self.frame_count, "Invalid ANM loop restart")
        self.descriptors = []
        previous_end = 32 + self.descriptor_bytes
        for i in range(self.frame_count):
            offset, size, tag = struct.unpack_from("<II8s", data, 32 + i * 16)
            require(tag == b"0123\0\0\0\0", f"Unknown frame {i} tag")
            require(offset >= previous_end and size >= 16 and offset + size <= len(data),
                    f"Invalid frame {i} bounds")
            self.descriptors.append((offset, size))
            previous_end = offset + size

    def initial_pixels(self):
        # ARM9 calls DMA fill32, so this is a repeated word, not repeated byte.
        count = self.width * self.height
        return bytearray((struct.pack("<I", self.clear_word) * ((count + 3) // 4))[:count])

    def apply(self, index, previous):
        require(0 <= index < self.frame_count, "Frame index outside animation")
        require(len(previous) == self.width * self.height, "Incorrect previous buffer size")
        offset, size = self.descriptors[index]
        mode, stream_size, palette_size, next_offset = struct.unpack_from("<4I", self.data, offset)
        require(mode in (0, 1), f"Unknown frame compression {mode}")
        require(palette_size == 64, f"Unknown palette size {palette_size}")
        start = offset + 16
        end = start + stream_size
        require(end + palette_size <= offset + size, f"Frame {index}: truncated payload")
        require(next_offset == offset + size, f"Frame {index}: invalid next offset")
        pixels = bytearray(previous)
        output = 0
        cursor = start
        commands = Counter()
        if mode == 1:
            require(stream_size == len(pixels), "Raw frame has incorrect pixel count")
            pixels[:] = self.data[start:end]
            output = len(pixels)
            cursor = end
            commands["raw"] = stream_size
        while cursor < end:
            command = self.data[cursor]
            cursor += 1
            if command & 0x80:
                count = command - 0x80
                require(count > 0, f"Frame {index}: empty skip")
                require(output + count <= len(pixels), f"Frame {index}: skip exceeds pixel buffer")
                commands["skip"] += count
            elif command & 0x40:
                count = command - 0x40
                require(count > 0 and cursor < end, f"Frame {index}: truncated repeat")
                require(output + count <= len(pixels), f"Frame {index}: repeat exceeds pixel buffer")
                pixels[output:output + count] = bytes([self.data[cursor]]) * count
                cursor += 1
                commands["repeat"] += count
            else:
                count = command
                require(count > 0 and cursor + count <= end, f"Frame {index}: truncated literal")
                require(output + count <= len(pixels), f"Frame {index}: literal exceeds pixel buffer")
                pixels[output:output + count] = self.data[cursor:cursor + count]
                cursor += count
                commands["literal"] += count
            output += count
        require(cursor == end and output == len(pixels), f"Frame {index}: incorrect decoded size {output}")
        palette = self.data[end:end + palette_size]
        return pixels, palette, dict(commands)

    def rgba(self, pixels, palette):
        """A3I5 to upright RGBA; no compositing, rescaling or palette substitution."""
        colors = []
        for packed in struct.unpack("<32H", palette):
            channels = [(packed >> shift) & 31 for shift in (0, 5, 10)]
            colors.append(tuple((v << 3) | (v >> 2) for v in channels))
        result = bytearray(self.width * self.height * 4)
        for i, value in enumerate(pixels):
            # The DS converts 3-bit alpha to 5-bit before compositing.
            a3 = value >> 5
            a5 = (a3 << 2) | (a3 >> 1)
            a8 = (a5 << 3) | (a5 >> 2)
            x, y = i % self.width, i // self.width
            target = ((self.width - 1 - x) * self.height + y) * 4
            result[target:target + 4] = bytes((*colors[value & 31], a8))
        return result


def inspect_mtc(data):
    require(len(data) >= 32, "Truncated MTC header")
    count, width, height, first, last, loop = struct.unpack_from("<I5H", data)
    require(0 < count <= 4096, "Invalid MTC frame count")
    require(len(data) == 32 + count * 17 * 33 * 2, "Invalid MTC vertex colour data length")
    return {"frameCount": count, "width": width, "height": height,
            "firstFrameNumber": first, "lastFrameNumber": last, "loopFrameNumber": loop,
            "gridColumns": 17, "gridRows": 33,
            "frameSHA256": [sha(data[32 + i * 1122:32 + (i + 1) * 1122]) for i in range(count)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--bundle", type=Path, help="Copy original payloads and write runtime manifest")
    parser.add_argument("--report", type=Path, default=ROOT / "docs/original-animation-report.json")
    parser.add_argument("--preview", action="append", default=[], help="ANM basename to export as PNG frames")
    parser.add_argument("--preview-directory", type=Path, default=ROOT / ".cache/previews/original-animations")
    args = parser.parse_args()
    source = args.source.resolve()
    records = []
    overlays = []
    stats = Counter()
    if args.bundle:
        args.bundle.mkdir(parents=True, exist_ok=True)
    for path in sorted(source.rglob("*.anm")):
        data = payload(path)
        relative = path.relative_to(source).as_posix()
        record = {"id": path.stem, "source": relative, "payloadSHA256": sha(data),
                  "sourceSHA256": sha(path.read_bytes()), "payloadBytes": len(data), "frames": []}
        try:
            animation = Animation(data)
            record.update({"frameCount": animation.frame_count, "nativeWidth": animation.width,
                           "nativeHeight": animation.height, "clearWord": animation.clear_word,
                           "firstFrameNumber": animation.first_number,
                           "lastFrameNumber": animation.last_number, "loopFrameNumber": animation.loop_number,
                           "loopStartIndex": animation.loop_start})
            pixels = animation.initial_pixels()
            for i in range(animation.frame_count):
                pixels, palette, commands = animation.apply(i, pixels)
                rgba = animation.rgba(pixels, palette)
                frame = {"index": i, "indexSHA256": sha(pixels), "paletteSHA256": sha(palette),
                         "rgbaSHA256": sha(rgba), "commands": commands}
                record["frames"].append(frame)
                stats["decodedFrames"] += 1
                if path.stem in args.preview or path.name in args.preview:
                    out = args.preview_directory / path.stem / f"{i:03}.png"
                    write_png(animation.height, animation.width, rgba, str(out))
            record["status"] = "decoded"
            stats["decodedAnimations"] += 1
        except DecodeError as error:
            record["status"] = "unsupported"
            record["error"] = str(error)
            stats["unsupportedAnimations"] += 1
        records.append(record)
        if args.bundle:
            destination = args.bundle / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
    for path in sorted(source.rglob("*.mtc")):
        data = payload(path)
        relative = path.relative_to(source).as_posix()
        record = {"id": path.stem, "source": relative, "payloadSHA256": sha(data),
                  "sourceSHA256": sha(path.read_bytes()), **inspect_mtc(data)}
        overlays.append(record)
        if args.bundle:
            destination = args.bundle / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
    manifest = {"formatVersion": 1, "animations": records, "colourOverlays": overlays,
                "coverage": {"animations": len(records), "frames": sum(r["frameCount"] for r in records),
                             "colourOverlays": len(overlays), **dict(stats)},
                "remaining": ["Br_bracelet_.anm frame zero does not conform to the recovered codec.",
                              "Character playback pacing, crossfades and state-specific timing need a native state-machine port.",
                              "MTC vertex colours are preserved; complete original mesh positioning/compositing needs a renderer port."]}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(manifest, indent=2) + "\n")
    if args.bundle:
        (args.bundle / "OriginalAnimationManifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest["coverage"]))
    for record in records:
        if record["status"] != "decoded":
            print(record["source"], record["error"])


if __name__ == "__main__":
    main()
