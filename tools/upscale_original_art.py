#!/usr/bin/env python3
"""Reproducible offline artwork pack. Inference never runs in the game."""
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path
import time

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt
from scipy.ndimage import gaussian_filter
import torch
from spandrel import ModelLoader

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def upscale(image, model, tile=320, overlap=24, scale=4):
    source = np.asarray(image.convert("RGBA")).copy()
    h, w, _ = source.shape
    rgb = source[:, :, :3].copy()
    alpha = source[:, :, 3]
    if not np.any(alpha):
        return Image.new("RGBA", (w * scale, h * scale))
    if np.any(alpha == 0):
        nearest = distance_transform_edt(alpha == 0, return_distances=False, return_indices=True)
        rgb[alpha == 0] = rgb[nearest[0], nearest[1]][alpha == 0]
    pad = 16
    padded = np.pad(rgb, ((pad, pad), (pad, pad), (0, 0)), mode="symmetric")
    ph, pw, _ = padded.shape
    output = np.empty((ph * model.scale, pw * model.scale, 3), np.uint8)
    with torch.inference_mode():
        for top in range(0, ph, tile):
            for left in range(0, pw, tile):
                bottom, right = min(top + tile, ph), min(left + tile, pw)
                x0, y0 = max(0, left - overlap), max(0, top - overlap)
                x1, y1 = min(pw, right + overlap), min(ph, bottom + overlap)
                tensor = torch.from_numpy(padded[y0:y1, x0:x1].copy()).permute(2, 0, 1).unsqueeze(0).float().div_(255)
                tensor = tensor.to(device=model.device, dtype=model.dtype)
                result = model(tensor).squeeze(0).clamp_(0, 1).mul_(255).round_().byte().permute(1, 2, 0).cpu().numpy()
                s = model.scale
                output[top * s:bottom * s, left * s:right * s] = result[
                    (top - y0) * s:(bottom - y0) * s, (left - x0) * s:(right - x0) * s]
    s = model.scale
    result = Image.fromarray(output[pad * s:(pad + h) * s, pad * s:(pad + w) * s])
    if s != scale:
        result = result.resize((w * scale, h * scale), Image.Resampling.LANCZOS)
    coverage = Image.fromarray(alpha).resize((w * scale, h * scale), Image.Resampling.LANCZOS)
    coverage_array = np.asarray(coverage).copy()
    support = np.repeat(np.repeat(alpha != 0, scale, axis=0), scale, axis=1)
    coverage_array[~support] = 0
    result.putalpha(Image.fromarray(coverage_array))
    return result


def load_model(path):
    model = ModelLoader().load_from_file(path).eval()
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    return model.to(device)


def preserve_source_detail(source, output):
    source = source.convert("RGBA")
    original = np.asarray(source).copy()
    alpha = original[:, :, 3]
    rgb = original[:, :, :3]
    if np.any(alpha) and np.any(alpha == 0):
        nearest = distance_transform_edt(alpha == 0, return_distances=False, return_indices=True)
        rgb[alpha == 0] = rgb[nearest[0], nearest[1]][alpha == 0]
    values = np.asarray(output.convert("RGB")).astype(np.float32)
    for _ in range(3):
        reduced = np.asarray(Image.fromarray(values.clip(0, 255).round().astype(np.uint8)).resize(
            source.size, Image.Resampling.BICUBIC)).astype(np.float32)
        residual = rgb.astype(np.float32) - reduced
        correction = np.stack([np.asarray(Image.fromarray(residual[:, :, c]).resize(
            output.size, Image.Resampling.BICUBIC)) for c in range(3)], axis=-1)
        values += correction * .8
    result = Image.fromarray(values.clip(0, 255).round().astype(np.uint8))
    result.putalpha(output.getchannel("A"))
    return result


def illustrated_material(image, key):
    values = np.asarray(image).astype(np.float32)
    rgb = values[:, :, :3]
    luminance = rgb @ np.array([.2126, .7152, .0722], np.float32)
    h, w = luminance.shape
    seed = int(hashlib.sha256(key.encode()).hexdigest()[:16], 16)
    rng = np.random.default_rng(seed)
    noise = gaussian_filter(rng.normal(0, 1, (h, w)), .35)
    yy, xx = np.mgrid[:h, :w]
    strokes = np.maximum(0, np.cos((xx + yy * .65) * 2 * np.pi / 5.5 + noise * .2)) ** 10
    shade = np.clip((175 - luminance) / 150, 0, 1)
    grain = noise * 2.2
    marks = (strokes - .15) * shade * 10
    fine_edges = luminance - gaussian_filter(luminance, .65)
    adjustment = grain - marks + fine_edges * .18
    values[:, :, :3] = np.clip(rgb + adjustment[:, :, None], 0, 255)
    return Image.fromarray(values.round().astype(np.uint8))


def compare(args, manifest):
    choices = [
        ("RealESRGAN_x2plus.pth", "Real-ESRGAN 2x"),
        ("HDCube3.pth", "HDCube 3 -> 2x"),
        ("RealESRGAN_anime6B.pth", "Real-ESRGAN line art -> 2x"),
    ]
    samples = []
    for fragment in ["/plate215.bin#opaque", "/item001.bin", "/Hy_hanas_", "/R213/R213/", "Images/Backgrounds/R213"]:
        match = next((r for r in manifest["images"] if any(fragment in s for s in r["sources"])), None)
        if match and match not in samples:
            samples.append(match)
    if not samples:
        samples = manifest["images"][:4]
    args.output.mkdir(parents=True, exist_ok=True)
    rows = []
    for record in samples:
        image = Image.open(args.input / (record["key"] + ".png")).convert("RGBA")
        rows.append([image.resize((image.width * 2, image.height * 2), Image.Resampling.NEAREST)])
    for filename, label in choices:
        model = load_model(args.models / filename)
        for row, record in zip(rows, samples):
            started = time.monotonic()
            image = Image.open(args.input / (record["key"] + ".png"))
            output = upscale(image, model)
            output.save(args.output / (filename + "-" + record["key"] + ".png"))
            row.append(output)
            print(label, record["sources"][0], round(time.monotonic() - started, 2), flush=True)
        del model
    column_width = max(image.width for row in rows for image in row) + 24
    row_heights = [max(image.height for image in row) + 48 for row in rows]
    sheet = Image.new("RGB", (column_width * 4, sum(row_heights) + 40), (220, 216, 207))
    draw = ImageDraw.Draw(sheet)
    for i, label in enumerate(["Original (nearest 2x)"] + [x[1] for x in choices]):
        draw.text((i * column_width + 12, 12), label, fill="black")
    y = 40
    for row, record, row_height in zip(rows, samples, row_heights):
        for x, image in enumerate(row):
            sheet.paste(image, (x * column_width + 12, y + 24), image)
        draw.text((12, y), record["sources"][0], fill="black")
        y += row_height
    sheet.save(args.output / "ModelComparison.png")


def run(args, manifest):
    if args.chapter_one and not args.skip_animation:
        raise ValueError("The current animation finish was rejected; replace it before building a Chapter 1 pack")
    args.output.mkdir(parents=True, exist_ok=True)
    # Keep short-lived files outside the bundled resource directory: Xcode may
    # copy that directory while the offline asset job is running.
    staging = args.output.parent / ("." + args.output.name + "-staging")
    staging.mkdir(parents=True, exist_ok=True)
    names = ["4x-Manga109Attempt.pth", "4x-Nomos8kSC.pth", "2xHDCube_Compact.pth"] if args.model == "mixed" else [args.model]
    fingerprints = {name: sha(args.models / name) for name in names}
    settings = {"model": args.model, "modelSHA256": fingerprints, "scale": 4, "animationScale": 8,
                "tile": 320, "overlap": 24, "edgePadding": "symmetric-16",
                "alpha": "Lanczos with original transparent support preserved", "version": 5,
                "detail": "Three source-consistency back-projection steps; no denoising",
                "materialFinish": "Restrained graphite hatching, dry grain and fine-edge emphasis",
                "orientation": "Bitmap archive images inferred upright, then returned to source orientation"}
    settings_path = args.output / "Settings.json"
    if settings_path.exists() and json.loads(settings_path.read_text()) != settings:
        raise ValueError("Output pack belongs to another model or settings; use another output folder")
    settings_path.write_text(json.dumps(settings, indent=2) + "\n")
    models = {name: load_model(args.models / name) for name in names}
    records = []
    started = time.monotonic()
    selection = manifest["images"]
    if args.chapter_one:
        from chapter_one_art import select, selected_clips
        clips = selected_clips()
        selection = [r for r in selection if select(r, clips)]
    if args.skip_animation:
        selection = [r for r in selection if r["category"] != "animation"]
    if args.limit:
        selection = selection[:args.limit]
    for index, record in enumerate(selection):
        target = args.output / (record["key"] + ".png")
        override = args.overrides / target.name
        if args.model == "mixed":
            name = ("4x-Manga109Attempt.pth" if record["category"] == "animation" else
                    "4x-Nomos8kSC.pth" if record["category"] in ("texture", "linear", "bitmap", "map") else "4x-Nomos8kSC.pth")
        else:
            name = args.model
        if override.exists():
            temporary = staging / (target.stem + ".tmp")
            shutil.copyfile(override, temporary)
            os.replace(temporary, target)
        elif not target.exists():
            image = Image.open(args.input / target.name)
            upright = record["category"] in ("linear", "bitmap", "cinematic") or (
                record["category"] == "texture" and record["sources"][0].startswith("OriginalBitmaps/"))
            if upright:
                image = image.transpose(Image.Transpose.ROTATE_90)
            result = upscale(image, models[name])
            result = preserve_source_detail(image, result)
            if record["category"] == "animation":
                master = result
                # One tile fits the 768×1024 animation master. This avoids
                # repeated GPU dispatches; compared with 320px overlapping
                # tiles, a representative frame produced identical output pixels.
                result = upscale(master, models["2xHDCube_Compact.pth"], tile=1536, scale=2)
                result = preserve_source_detail(master, result)
            if record["category"] == "texture":
                result = illustrated_material(result, record["key"])
            if upright:
                result = result.transpose(Image.Transpose.ROTATE_270)
            temporary = staging / (target.stem + ".tmp")
            result.save(temporary, format="PNG", compress_level=6)
            os.replace(temporary, target)
        with Image.open(target) as output:
            scale = 8 if record["category"] == "animation" else 4
            if output.size != (record["width"] * scale, record["height"] * scale) or output.mode != "RGBA":
                raise ValueError("Incorrect enhanced dimensions or transparency: " + str(target))
            output_hash = hashlib.sha256(output.tobytes()).hexdigest()
        records.append({**record, "file": target.name, "pngSHA256": sha(target),
                        "outputRGBA256": output_hash, "model": name, "scale": scale,
                        "overrideSHA256": sha(override) if override.exists() else None})
        if index % 50 == 0 or index == len(selection) - 1:
            elapsed = time.monotonic() - started
            print(f"{index + 1}/{len(selection)} images; {elapsed:.1f}s", flush=True)
    result = {"formatVersion": 1, **settings, "complete": args.limit is None and not args.skip_animation,
              "scope": "chapter1-conservative" if args.chapter_one else "all",
              "coverage": manifest["coverage"], "images": records, "excluded": manifest["excluded"],
              "seconds": round(time.monotonic() - started, 2)}
    path = args.output / "ArtworkManifest.json"
    temporary = staging / "ArtworkManifest.tmp"
    temporary.write_text(json.dumps(result, indent=2) + "\n")
    os.replace(temporary, path)
    print(json.dumps({"images": len(records), "complete": result["complete"], "seconds": result["seconds"]}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / ".cache/original-art-export")
    parser.add_argument("--output", type=Path, default=ROOT / "Sources/HotelDuskDuoKit/Resources/EnhancedArtwork")
    parser.add_argument("--models", type=Path, default=ROOT / ".cache/upscale-models")
    parser.add_argument("--overrides", type=Path, default=ROOT / "tools/artwork-overrides")
    parser.add_argument("--model", default="mixed")
    parser.add_argument("--compare", action="store_true")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--chapter-one", action="store_true")
    parser.add_argument("--skip-animation", action="store_true", help="process textures only; leave the pack incomplete")
    parser.add_argument("--threads", type=int, default=8)
    options = parser.parse_args()
    torch.set_num_threads(options.threads)
    exported = json.loads((options.input / "ExportManifest.json").read_text())
    if options.compare:
        compare(options, exported)
    else:
        run(options, exported)
