#!/usr/bin/env python3
"""Export decoded artwork without altering original game data."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image

from cing_container import decompress
from decode_anm import Animation
from decode_bitmap import Bitmap
from decode_dtx import Texture
from decode_lrim import TileAnimation

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Sources/HotelDuskDuoKit/Resources"


def unpack(data):
    if data[:3] == bytes.fromhex("123dda"):
        return decompress(data)
    if data[0] != 0x30:
        return data
    length = int.from_bytes(data[:4], "little") >> 8
    output = bytearray()
    cursor = 4
    while len(output) < length:
        control = data[cursor]
        cursor += 1
        count = (control & 127) + (3 if control & 128 else 1)
        if control & 128:
            output.extend([data[cursor]] * count)
            cursor += 1
        else:
            output.extend(data[cursor:cursor + count])
            cursor += count
    if len(output) != length or cursor != len(data):
        raise ValueError("Invalid run-length bitmap")
    return bytes(output)


def linear(data):
    data = unpack(data)
    if len(data) < 32 or data[:16] != bytes(16):
        raise ValueError("Not a linear bitmap")
    w, h, aw, ah, kind, count, offset = struct.unpack_from("<7H", data, 16)
    if (w, h) != (aw, ah) or kind not in (1, 3, 4) or offset != 32:
        raise ValueError("Not a linear bitmap")
    if count != (32 if kind == 1 else 256) or len(data) != offset + count * 2 + w * h:
        raise ValueError("Invalid linear bitmap sections")
    indices = np.frombuffer(data, np.uint8, offset=offset + count * 2).reshape(h, w)
    palette = np.frombuffer(data, "<u2", count=count, offset=offset)
    colours = np.stack([((palette >> s) & 31) for s in (0, 5, 10)], axis=-1)
    colours = ((colours << 3) | (colours >> 2)).astype(np.uint8)
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[:, :, :3] = colours[indices & 31 if kind == 1 else indices]
    if kind == 1:
        a3 = indices >> 5
        a5 = (a3 << 2) | (a3 >> 1)
        rgba[:, :, 3] = (a5 << 3) | (a5 >> 2)
    else:
        rgba[:, :, 3] = 255
    return rgba, indices, kind


def mapped(data):
    data = unpack(data)
    kind, count, w, h, tiles, map_count, palette_size = struct.unpack_from("<6HI", data)
    if kind != 0 or count != 256 or palette_size != 512 or w % 8 or h % 8:
        raise ValueError("Not a mapped bitmap")
    if not (0 < tiles <= 1024 and 0 < w <= 2048 and 0 < h <= 2048):
        raise ValueError("Invalid mapped dimensions")
    if map_count != w * h // 64 or len(data) != 528 + tiles * 64 + map_count * 2:
        raise ValueError("Invalid mapped bitmap sections")
    palette = np.frombuffer(data, "<u2", count=256, offset=16)
    colours = np.stack([((palette >> s) & 31) for s in (0, 5, 10)], axis=-1)
    colours = ((colours << 3) | (colours >> 2)).astype(np.uint8)
    pixels = np.frombuffer(data, np.uint8, count=tiles * 64, offset=528).reshape(tiles, 8, 8)
    entries = np.frombuffer(data, "<u2", offset=528 + tiles * 64)
    rgba = np.full((h, w, 4), 255, np.uint8)
    for i, entry in enumerate(entries):
        tile = pixels[entry & 1023]
        if entry & 1024:
            tile = tile[:, ::-1]
        if entry & 2048:
            tile = tile[::-1]
        y, x = divmod(i, w // 8)
        rgba[y * 8:y * 8 + 8, x * 8:x * 8 + 8, :3] = colours[tile]
    return np.rot90(rgba)


def export(destination):
    destination.mkdir(parents=True, exist_ok=True)
    images = {}
    excluded = []
    coverage = Counter()

    def emit(rgba, source, category):
        rgba = np.asarray(rgba, dtype=np.uint8)
        h, w, _ = rgba.shape
        digest = hashlib.sha256(rgba.tobytes()).hexdigest()
        key = f"{w}x{h}-{digest}"
        if key not in images:
            images[key] = {"key": key, "width": w, "height": h, "rgbaSHA256": digest,
                           "category": category, "sources": []}
            Image.fromarray(rgba).save(destination / (key + ".png"))
        images[key]["sources"].append(source)
        coverage[category] += 1

    root = RESOURCES / "OriginalTextures"
    manifest = json.loads((root / "OriginalTextureManifest.json").read_text())
    for record in manifest["textures"]:
        if record["status"] != "decoded":
            excluded.append({"source": "OriginalTextures/" + record["source"], "reason": record.get("error")})
            continue
        texture = Texture((root / record["source"]).read_bytes())
        rgba = np.frombuffer(texture.rgba(), np.uint8).reshape(texture.height, texture.width, 4)
        assert hashlib.sha256(rgba.tobytes()).hexdigest() == record["rgbaSHA256"]
        emit(rgba, "OriginalTextures/" + record["source"], "texture")

    root = RESOURCES / "OriginalAnimations"
    manifest = json.loads((root / "OriginalAnimationManifest.json").read_text())
    for record in manifest["animations"]:
        if record["status"] != "decoded":
            excluded.append({"source": "OriginalAnimations/" + record["source"], "reason": record.get("error")})
            continue
        clip = Animation((root / record["source"]).read_bytes())
        pixels = clip.initial_pixels()
        for index in range(clip.frame_count):
            pixels, palette, _ = clip.apply(index, pixels)
            rgba = np.frombuffer(clip.rgba(pixels, palette), np.uint8).reshape(clip.width, clip.height, 4)
            assert hashlib.sha256(rgba.tobytes()).hexdigest() == record["frames"][index]["rgbaSHA256"]
            emit(rgba, f"OriginalAnimations/{record['source']}#{index}", "animation")

    root = RESOURCES / "OriginalBitmaps"
    manifest = json.loads((root / "OriginalBitmapManifest.json").read_text())
    for record in manifest["images"]:
        path = root / record["source"]
        data = path.read_bytes()
        source = "OriginalBitmaps/" + record["source"]
        if data[:4] == b"LRIM":
            for index, bitmap in enumerate(TileAnimation(data).decode()):
                rgba = np.frombuffer(bitmap.rgba, np.uint8).reshape(bitmap.height, bitmap.width, 4)
                emit(rgba, f"{source}#{index}", "cinematic")
            continue
        try:
            bitmap = Bitmap(data)
            rgba = np.frombuffer(bitmap.rgba, np.uint8).reshape(bitmap.height, bitmap.width, 4).copy()
            emit(rgba, source + "#opaque", "bitmap")
            palette_zero = np.zeros((bitmap.height, bitmap.width), bool)
            for y in range(bitmap.height):
                for x in range(bitmap.width):
                    at = ((y // 8) * (bitmap.width // 8) + x // 8) * 64 + (y % 8) * 8 + x % 8
                    value = bitmap.pixels[at] if bitmap.palette_count == 256 else (bitmap.pixels[at // 2] >> (4 * (at % 2))) & 15
                    palette_zero[y, x] = value == 0
            rgba[:, :, 3][palette_zero] = 0
            emit(rgba, source + "#transparent", "bitmap")
            continue
        except (ValueError, IndexError, struct.error):
            pass
        try:
            texture = Texture(data)
            emit(np.frombuffer(texture.rgba(), np.uint8).reshape(texture.height, texture.width, 4), source, "texture")
            continue
        except (ValueError, IndexError, struct.error):
            pass
        try:
            rgba, indices, kind = linear(data)
            emit(rgba, source + "#opaque", "linear")
            if kind != 1:
                rgba[:, :, 3][indices == 0] = 0
                emit(rgba, source + "#transparent", "linear")
            continue
        except (ValueError, IndexError, struct.error):
            pass
        try:
            emit(mapped(data), source, "map")
            continue
        except (ValueError, IndexError, struct.error):
            excluded.append({"source": source, "reason": "Non-image data or an unrecovered image format"})

    for path in sorted((RESOURCES / "Images").rglob("*.png")):
        if "Cover" in path.parts:
            continue
        emit(np.asarray(Image.open(path).convert("RGBA")), "Images/" + path.relative_to(RESOURCES / "Images").as_posix(), "png")

    result = {"formatVersion": 1, "coverage": dict(coverage), "uniqueImages": len(images),
              "pixels": sum(r["width"] * r["height"] for r in images.values()),
              "images": list(images.values()), "excluded": excluded}
    (destination / "ExportManifest.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k not in ("images", "excluded")}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".cache/original-art-export")
    export(parser.parse_args().output)
