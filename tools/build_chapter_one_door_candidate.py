#!/usr/bin/env python3
"""Prepare, but do not activate, a matched Room 215 door candidate.

The 3D mapping must be checked in game before these files enter a pack.
"""
import json
import hashlib
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
EXPORT = ROOT / '.cache/original-art-export'
PLAQUE = ROOT / '.cache/plaque-test-output'
KNOB = ROOT / '.cache/door-correction-output'
DEST = ROOT / '.cache/chapter1-door-candidate'
STUDY = ROOT / 'generated_images/exec-893677cf-294d-4e94-a6ad-d77025bb9252.png'
WALL_STUDY = ROOT / 'generated_images/exec-d227b590-40ee-47b1-9a17-9961751be795.png'
WALL_STUDY_LIT = ROOT / 'generated_images/exec-3b764aca-ec2d-401a-8c12-acbe6843a837.png'
WALL_STUDY_NARROW = ROOT / 'generated_images/exec-c968c4bb-6d8d-4801-aa4e-a7497e0cd09c.png'
INSPECTION_WALL_STUDY = ROOT / 'generated_images/exec-d004fb5c-4f7b-42fc-843d-d9a5e32e270a.png'
manifest = json.loads((EXPORT / 'ExportManifest.json').read_text())
DEST.mkdir(parents=True, exist_ok=True)
models = {}

def find(fragment):
    return next(r for r in manifest['images'] if any(fragment in s for s in r['sources']))

def image(folder, record):
    return Image.open(folder / (record['key'] + '.png')).convert('RGBA')

def save(record, art):
    assert art.size == (record['width'] * 4, record['height'] * 4)
    art.save(DEST / (record['key'] + '.png'))

def restored(record, folder, model_name):
    path = folder / (record['key'] + '.png')
    if path.exists():
        return image(folder, record)
    from upscale_original_art import load_model, preserve_source_detail, upscale
    source = image(EXPORT, record).transpose(Image.Transpose.ROTATE_90)
    if model_name not in models:
        models[model_name] = load_model(ROOT / '.cache/upscale-models' / model_name)
    result = preserve_source_detail(source, upscale(source, models[model_name])).transpose(Image.Transpose.ROTATE_270)
    folder.mkdir(parents=True, exist_ok=True)
    result.save(path)
    return result

# Trim the transparent edge of the study before it becomes an opaque 3D texture.
study = Image.open(STUDY).convert('RGBA').crop((780, 12, 1321, 1074))

# Remove the study's baked-in knob; the source knob is a separate layer.
left = study.copy()
left.paste(left.crop((0, 320, 75, 400)), (0, 505))
upright = left.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
width = 148 * 4
height = round(width * upright.height / upright.width)
upright = upright.resize((width, height), Image.Resampling.LANCZOS)
upright = upright.crop((0, 0, width, 234 * 4))

close = find('/SearchUp/door01.bin#transparent')
source = image(EXPORT, close).transpose(Image.Transpose.ROTATE_90)
canvas = Image.new('RGBA', (source.width * 4, source.height * 4))
canvas.paste(upright, (22 * 4, 22 * 4))
canvas.putalpha(source.getchannel('A').resize(canvas.size, Image.Resampling.NEAREST))
save(close, canvas.transpose(Image.Transpose.ROTATE_270))

knob = find('/SearchUp/nob01R.bin#transparent')
knob_image = restored(knob, KNOB, '4x-Nomos8kSC.pth').transpose(Image.Transpose.ROTATE_90)
mask = Image.new('L', knob_image.size)
ImageDraw.Draw(mask).ellipse((150 * 4, 167 * 4, 169 * 4, 186 * 4), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(2))
knob_image.putalpha(ImageChops.multiply(knob_image.getchannel('A'), mask))
save(knob, knob_image.transpose(Image.Transpose.ROTATE_270))

material = find('OriginalTextures/map/R213/R213/door.dtx')
material_image = left.resize((material['width'] * 4, material['height'] * 4), Image.Resampling.LANCZOS)
material_image.putalpha(image(EXPORT, material).getchannel('A').resize(material_image.size, Image.Resampling.NEAREST))
# Use the same original round handle in both views, mirrored for the 3D UVs.
handle = knob_image.crop((150 * 4, 167 * 4, 169 * 4, 186 * 4))
handle = handle.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((7 * 4, 7 * 4), Image.Resampling.LANCZOS)
material_image.alpha_composite(handle, (0, 62 * 4))
material_image.putalpha(image(EXPORT, material).getchannel('A').resize(material_image.size, Image.Resampling.NEAREST))
save(material, material_image)

plaque_records = []
for number in range(211, 221):
    # Keep each original framed numeral rather than drawing a replacement font.
    plaque = find(f'/SearchUp/plate{number}.bin#transparent')
    plaque_image = restored(plaque, PLAQUE, '4x-Manga109Attempt.pth')
    save(plaque, plaque_image)
    sign = find(f'OriginalTextures/map/R213/R213/{number}.dtx')
    # The plaque mesh fills the door's UV gap from v=55/16 to v=222/16.
    sign_image = material_image.crop((0, round(55 / 16 * 4), 64 * 4, round(222 / 16 * 4)))
    sign_image = sign_image.resize((sign['width'] * 4, sign['height'] * 4), Image.Resampling.LANCZOS)
    # The opposite wall reverses the plaque mesh's U direction relative to
    # the door mesh; mirror the wood there to keep the seam aligned.
    if number >= 216:
        sign_image = sign_image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    upright_plaque = plaque_image.transpose(Image.Transpose.ROTATE_90)
    frame = upright_plaque.crop((73 * 4, 37 * 4, 119 * 4, 56 * 4))
    # Plaque text has opposite screen orientation on the two corridor walls.
    if number <= 215:
        frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    frame = frame.resize((24 * 4, 10 * 4), Image.Resampling.LANCZOS)
    sign_image.alpha_composite(frame, (20 * 4, 4))
    save(sign, sign_image)
    plaque_records.extend((plaque, sign))

wall_records = []
for filename, reference in [('kabe01.dtx', WALL_STUDY), ('kabe02.dtx', WALL_STUDY_LIT),
                            ('kabe03.dtx', WALL_STUDY_NARROW)]:
    wall = find('OriginalTextures/map/R213/R213/' + filename)
    wall_image = Image.open(reference).convert('RGBA').resize((wall['width'] * 4, wall['height'] * 4), Image.Resampling.LANCZOS)
    wall_image.putalpha(image(EXPORT, wall).getchannel('A').resize(wall_image.size, Image.Resampling.NEAREST))
    save(wall, wall_image)
    wall_records.append(wall)

inspection_wall = find('/SearchUp/wall01.bin#opaque')
wall_image = Image.open(INSPECTION_WALL_STUDY).convert('RGBA').resize((768, 1024), Image.Resampling.LANCZOS)
# The study placed the opening four source pixels too high. Align its top
# jamb with the original layer before compositing the unchanged door geometry.
aligned = Image.new('RGBA', wall_image.size)
aligned.paste(wall_image.crop((0, 0, 768, 16 * 4)).resize((768, 20 * 4), Image.Resampling.LANCZOS), (0, 0))
aligned.paste(wall_image.crop((0, 16 * 4, 768, 1024)).resize((768, 236 * 4), Image.Resampling.LANCZOS), (0, 20 * 4))
wall_image = aligned
wall_image = wall_image.transpose(Image.Transpose.ROTATE_270)
wall_image.putalpha(image(EXPORT, inspection_wall).getchannel('A').resize(wall_image.size, Image.Resampling.NEAREST))
save(inspection_wall, wall_image)

records = []
for record in (close, knob, material, inspection_wall, *wall_records, *plaque_records):
    path = DEST / (record['key'] + '.png')
    records.append({**record, 'file': path.name, 'scale': 4,
                    'pngSHA256': hashlib.sha256(path.read_bytes()).hexdigest()})
(DEST / 'ArtworkManifest.json').write_text(json.dumps({
    'formatVersion': 1, 'scale': 4, 'complete': True,
    'scope': 'isolated-room-215-candidate', 'images': records,
}, indent=2) + '\n')
print(f'Prepared {len(records)} review candidates; no game assets were activated.')
