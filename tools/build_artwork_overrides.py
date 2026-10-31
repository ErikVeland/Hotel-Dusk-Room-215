#!/usr/bin/env python3
"""Retired exploratory door and lettering prototype; do not use for a pack."""
import argparse
import json
from pathlib import Path
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFont
import torch

from upscale_original_art import ROOT, load_model, upscale, preserve_source_detail


def lettering(image, box, text):
    result = image.copy()
    x0, y0, x1, y1 = [int(value) for value in box]
    w, h = x1 - x0, y1 - y0
    original = np.asarray(result.crop(box)).astype(np.float32)
    base = np.median(original[:, :, :3].reshape(-1, 3), axis=0)
    base = base * .73
    yy, xx = np.mgrid[:h, :w]
    grain = np.random.default_rng(215).normal(0, 1.7, (h, w, 1))
    patch = np.zeros_like(original)
    patch[:, :, :3] = np.clip(base + grain + (yy[:, :, None] / max(1, h) - .5) * 6, 0, 255)
    patch[:, :, 3] = original[:, :, 3]
    result.paste(Image.fromarray(patch.astype(np.uint8)), (x0, y0))
    scale = 8
    canvas = Image.new("RGBA", (w * scale, h * scale))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia Bold.ttf", h * scale)
    bounds = draw.textbbox((0, 0), text, font=font)
    glyph = Image.new("RGBA", (bounds[2] - bounds[0] + 12, bounds[3] - bounds[1] + 12))
    writer = ImageDraw.Draw(glyph)
    writer.text((6 - bounds[0] + 3, 6 - bounds[1] + 3), text, font=font, fill=(65, 43, 21, 255))
    writer.text((6 - bounds[0], 6 - bounds[1]), text, font=font, fill=(232, 204, 145, 255))
    glyph.thumbnail((w * scale, h * scale), Image.Resampling.LANCZOS)
    canvas.alpha_composite(glyph, ((canvas.width - glyph.width) // 2, (canvas.height - glyph.height) // 2))
    result.alpha_composite(canvas.resize((w, h), Image.Resampling.LANCZOS), (x0, y0))
    result.putalpha(image.getchannel("A"))
    return result


def main(args):
    args.output.mkdir(parents=True, exist_ok=True)
    export = json.loads((args.input / "ExportManifest.json").read_text())
    model = load_model(args.models / "4x-Nomos8kSC.pth")
    records = []
    for record in export["images"]:
        sign = next((re.search(r"OriginalTextures/map/R213/R213/(21[1-9]|220)\.dtx$", s)
                     for s in record["sources"] if re.search(r"OriginalTextures/map/R213/R213/(21[1-9]|220)\.dtx$", s)), None)
        close = next((re.search(r"/SearchUp/plate(21[1-9]|220)\.bin", s)
                      for s in record["sources"] if re.search(r"/SearchUp/plate(21[1-9]|220)\.bin", s)), None)
        if not sign and not close:
            continue
        source = Image.open(args.input / (record["key"] + ".png")).convert("RGBA")
        upright = source.transpose(Image.Transpose.ROTATE_90) if close else source
        result = preserve_source_detail(upright, upscale(upright, model))
        if sign:
            result = lettering(result, (44, 5, 82, 20), sign.group(1))
            number = sign.group(1)
        else:
            result = lettering(result, (154, 80, 230, 106), close.group(1))
            result = result.transpose(Image.Transpose.ROTATE_270)
            number = close.group(1)
        result.save(args.output / (record["key"] + ".png"))
        records.append({"key": record["key"], "kind": "verified-room-lettering", "text": number,
                        "sources": record["sources"]})
    door = next(r for r in export["images"] if "OriginalTextures/map/R213/R213/door.dtx" in r["sources"])
    study = Image.open(args.door_study).convert("RGBA")
    right = study.crop((study.width // 2, 0, study.width, study.height))
    alpha = np.asarray(right.getchannel("A"))
    yy, xx = np.where(alpha > 245)
    right = right.crop((int(xx.min()), int(yy.min()) + 8, int(xx.max()) + 1, int(yy.max()) - 8))
    right = right.resize((door["width"] * 2, door["height"] * 2), Image.Resampling.LANCZOS)
    original = Image.open(args.input / (door["key"] + ".png")).convert("RGBA")
    alpha = np.asarray(original.getchannel("A").resize(right.size, Image.Resampling.LANCZOS)).copy()
    support = np.repeat(np.repeat(np.asarray(original.getchannel("A")) > 0, 2, axis=0), 2, axis=1)
    alpha[~support] = 0
    right.putalpha(Image.fromarray(alpha))
    right.save(args.output / (door["key"] + ".png"))
    records.append({"key": door["key"], "kind": "reviewed-illustrative-door", "sources": door["sources"],
                    "reference": str(args.door_study.relative_to(ROOT))})
    (args.output / "Overrides.json").write_text(json.dumps({"formatVersion": 1, "images": records}, indent=2) + "\n")
    print(json.dumps({"overrides": len(records)}))


if __name__ == "__main__":
    raise SystemExit("Retired: this prototype distorted the door and plaque. Use build_chapter_one_door_candidate.py for the isolated candidate.")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / ".cache/original-art-export")
    parser.add_argument("--output", type=Path, default=ROOT / "tools/artwork-overrides")
    parser.add_argument("--models", type=Path, default=ROOT / ".cache/upscale-models")
    torch.set_num_threads(4)
    main(parser.parse_args())
