# Original graphics recovery

The native graphics backend decodes the original game data. It does not draw
replacement characters, assign a guessed frame rate, or substitute an image when
a stream is unsupported. Asset recovery is not a complete port of the original
character renderer or game logic.

## Verified coverage

The supplied WPF archives contain 347 ANM files with 3,025 frames, 54 MTC files
with 289 colour-grid frames, 2,957 DTX textures, and 296 MDF model resources.

| Resource | Native recovery status |
| --- | --- |
| 346 ANM files, 3,021 frames | All commands, bounds, full index buffers, palettes and upright RGBA frames decoded and hashed. |
| `Br_bracelet_.anm`, 4 frames | Preserved; rejected because its first frame does not conform to the recovered ARM9 codec. No replacement is shown. |
| 54 MTC files, 289 frames | Original 17 × 33 RGB555 vertex-colour grids decoded and hashed. Mesh placement and blending remain to be ported. |
| All 347 ANM and 54 MTC payloads | Bundled without byte changes; the 32-byte WPF inline directory record is removed and separately hashed. |
| 2,921 DTX textures | Original palettes, texel buffers and RGBA images decoded and hashed independently in Python and Swift. |
| 36 DTX textures | Preserved. Unchecked compressed block layouts or invalid palette references remain unsupported. |
| 235 MDF models | 7,123 hierarchical nodes, 621,884 visible vertices and 594,401 hit-test vertices decoded. Original transforms, UVs, colours and draw order are retained. |
| 61 MDF models | 60 `MDF_GL_100` test/effect resources and one older group-layout resource remain unsupported. |
| 19 LRIM opening animations, 135 frames | All Nintendo LZ10 streams and original tile deltas decoded. Full frame hashes and checkpoint continuity are verified independently. |

The reproducible report is [original-animation-report.json](original-animation-report.json).
It includes source and payload SHA-256 hashes, per-frame index/palette/RGBA
hashes, original header values, and explicit unsupported records.

## Evidence from the supplied executable

The main executable is mapped at `0x02004000`. The animation decoder's file
address `0x020fe818` maps to runtime ITCM address `0x01ff9158`. The corrected
Ghidra export is `extracted/decompiled/arm9/01ff9158.c`.

| Address | Recovered behavior |
| --- | --- |
| `0x020fe818`–`0x020fe9b8` | Frame decoder: compression mode 1 copies raw bytes; mode 0 uses literal, repeated-byte and skip commands. Skip commands leave the previous index buffer intact. |
| `0x020fe914`–`0x020fe978` | Command bit 7 skips `command - 128` pixels; otherwise bit 6 repeats one byte `command - 64` times; remaining commands copy that many literal bytes. Literal `0xff` is a real pixel, not a skip marker. |
| `0x020915c8`–`0x020915dc`, `0x020c37fc`–`0x020c387c` | ANM header word at offset 12 initializes the texture buffer through a DMA 32-bit fill. Values 0, 29 and 30 are not frame rates. |
| `0x02091460`–`0x02091470` | At the end of an animation, the next index is `header.u16(24) - header.u16(20) + 1`. Looping must retain the previous index buffer. |
| `0x020921a4`–`0x020921bc`, constant at `0x02092b98` | Texture setup uses `0x46d00000`, which selects DS A3I5 texture format with a 32-entry palette. |
| `0x020928c8`–`0x02092a44` | The renderer reads MTC colour words as a 17 × 33 vertex mesh. It emits 16 strips with 33 pairs of vertices. These resources are not image layers to scale and overlay. |

The RGB palette is RGB555. A3I5 alpha expands to the original five-bit value
`(a3 << 2) | (a3 >> 1)`, then to eight bits for PNG/Core Graphics. RGB uses the
same five-to-eight-bit expansion. Original indices and palette words remain
available, so a Metal renderer can retain the source precision. The current
RGBA view is a frame preview, not a claim of identical DS rasterization.

The 90-degree counterclockwise rotation converts the DS framebuffer coordinates
to the upright 192 × 256 book-page orientation without resampling. Neither the
decoder nor the frame view smooths or recolours the artwork.

The external format notes by [Jason Harley](https://jasonharley2o.com/reverse/hoteldusk/)
helped locate the structure. Several tentative interpretations in those notes
are deliberately not used: frame pixels are A3I5, skip commands preserve the
index buffer, palettes affect the complete frame, and MTC data starts after a
32-byte header. The texture format and alpha expansion are described in
[GBATEK](https://mgba-emu.github.io/gbatek/#ds-3d-texture-formats).

## Native API

`OriginalAnimationLibrary.bundled()` loads the manifest and verifies each asset
hash when it is opened. `load(id: "Hy_hanas_")` returns an
`OriginalAnimationClip`. `OriginalAnimationDecoder.advance()` applies one
original delta frame and returns an `OriginalAnimationFrame` with a Core
Graphics image. `OriginalAnimationFrameView` draws that image in SwiftUI.

The decoder is independent of wall-clock time. Its caller must use the recovered
game animation state machine. The original engine includes asynchronous frame
loading, a minimum display interval, transition blending, and state-specific
holds. Calling the header word at offset 12 “30 FPS” was incorrect.

`checkpoint()` and `restore(_:)` preserve the exact index buffer, palette, frame
index and loop count. Checkpoints are bound to the payload hash, so they cannot
be applied to a different animation. A fold/reopen or scene interruption does
not require reconstructing a character's current pose from a guessed timer.

`loadColourGrid(id:)` exposes the original MTC colour words. It intentionally does
not blend them onto a frame until the original mesh placement, transitions and
texture modulation are implemented.

## Reproduce

```sh
python3 tools/decode_anm.py \
  --bundle Sources/HotelDuskDuoKit/Resources/OriginalAnimations \
  --preview Hy_hanas_ --preview An_TanaMove_ --preview Dn_mae_
```

The tool uses only Python's standard library. It validates the WPF record size,
ANM header, descriptors, frame offsets, command bounds, exact decoded sizes and
palette lengths. An unsupported stream becomes an explicit report entry.

`OriginalAnimationTests` compares every recovered Swift frame with the independent
Python decoder's index, palette and RGBA hashes. Additional checks cover original
loop restart, checkpoint restoration, unsupported-data rejection and all MTC
frame hashes. These checks establish decoding agreement; they do not validate
the whole game's character timing or complete scene composition.

The [Kyle contact sheet](previews/original-animations/KyleContactSheet.png) shows
the 11 original `Hy_hanas_` frames in order. It uses a plain preview background
to make alpha visible. The individual PNGs retain transparency. The warehouse
sequence in `previews/original-animations/An_TanaMove_` also confirms palette
colour and accumulated delta frames through the door reveal.

## Original textures

DTX headers identify 1,603 mode-3 indexed images, 1,140 mode-7 compressed textures,
108 mode-1 A3I5 textures, and 106 mode-2 A5I3 textures. The game's mode numbers do
not directly equal the DS GPU format numbers. `OriginalTexture` maps them to
A3I5, A5I3, opaque indexed RGB555 and DS 4 × 4 compression, as selected by
the original function at `0x02083cd0`. The 4 × 4 palette blends are calculated
in five-bit colour space before expansion. The native decoder matches the
independent Python decoder for all 2,921 manifest-supported textures.

Allocated, logical and stored dimensions remain distinct. Original padding
present in a payload is retained; omitted texels are not manufactured.
`0x020840b0` places the compressed-info pointer at
`logicalWidth * logicalHeight / 4` bytes after the texels. The upload routine
at `0x02083534` derives its transfer size from allocated width and logical
height. The lobby work recovers the partial block row in `R102/laungr.dtx`
where logical and allocated widths agree. Missing blocks remain transparent
and are discarded. See [Lobby to bell](lobby-to-bell.md) for the transfer rule
and checks. Room 215 also uses this decoder for the 32×36 `telephoe.dtx` payload. The 36 remaining manifest entries include unchecked block streams,
width crops and invalid palette references. Full regeneration can decode more
equivalent block streams, but those entries need separate review before promotion.

```sh
python3 tools/decode_dtx.py \
  --bundle Sources/HotelDuskDuoKit/Resources/OriginalTextures
```

`OriginalTextureLibrary.bundled().load(path:)` verifies the payload hash and
returns source data, decoded RGBA, a Core Graphics image, or an exact texel
upload through `makeMetalTexture(device:)`. The report is
[original-texture-report.json](original-texture-report.json).

## Original models and native Metal preview

The original model loader at `0x0208b0f4` verifies the `MDF_DS_100` signature.
The 48-byte header points to 48-byte material records and 96-byte nodes.
Each node contains its original name, parent index, draw-group table and
Float32 transform. The loader converts the matrix to signed 20.12 fixed
point, with the original rounding. Parent transforms are concatenated with
signed 64-bit products and an arithmetic shift, matching `0x020bc948`.

The draw functions at `0x0208b6f0` and `0x0208baac` establish the 16-byte group
format: visible and hit-test display-list offsets, two byte counts, material
index and flags. These are separate meshes. The visible lists contain GX
BEGIN/END, TEXCOORD, COLOR and VTX16 commands; hit lists contain the original
positions. The recovered lists use triangles and quads. Original position
and UV precision is retained in a 12-byte native vertex record: signed
16-bit x/y/z/u/v followed by the original RGB555 word. Quads are expanded
to two triangles for Metal, with the original vertex order retained.

`OriginalModelLibrary.bundled().load(path: "map/R212/R212/R212.mdf")` exposes
the complete hierarchy, materials and both sets of geometry. The nodes
include original interaction identifiers such as `search01`, `in_r213` and
`hyde_point00`. They are not replaced with generated hotspots.
`OriginalModelGeometry.makeMetalBuffers(device:)` uploads the recovered
vertices and indices directly.

`cameraMarkers(index:)` reads the exact `cam_pos1/2` and `cam_at1/2` or
`cam_at` coordinates from the original hierarchy. The source marker loader
at `0x0209cb80` and copy helper at `0x0209d7ec` use the same world-matrix
translation words. The second target uses the first target when absent.
Free-exploration models without fixed camera markers return a missing-data
error; they do not acquire a generated camera.

`OriginalModelMetalPreview` is a native diagnostic renderer. Its caller
supplies the camera matrix and visible node indices. It loads original DTX
materials from the model's archive directory and uses the original repeat
and flip switches from `0x02083cd0`. Missing materials stop preparation.
It never supplies a gameplay camera or scene interaction logic. Its raster
output still needs comparison for DS colour quantization, quad interpolation,
translucent polygon order and depth behaviour. Undefined texture padding is
discarded in this diagnostic preview and must be resolved before gameplay.

```sh
python3 tools/decode_mdf.py \
  --bundle Sources/HotelDuskDuoKit/Resources/OriginalModels
HOTEL_DUSK_MODEL_PREVIEW="$PWD/docs/previews/original-models/R212-native-metal.png" \
  swift test --filter OriginalModelMetalTests
```

`OriginalModelTests` passed for all 235 supported models, comparing decoded
bytes, vertex/index hashes and every local/world fixed-point matrix against
the independent Python decoder. The report is
[original-model-report.json](original-model-report.json). The unsupported
`map/R123/R123_s04/R123_s04.mdf` contains eight-byte group records, while the
recovered game loader consumes sixteen-byte records. Its original bytes are
retained; it is not silently interpreted as the later format.

## Opening animation frames

The 19 `.bin` members in `show/op2/0829OPAni` contain `LRIM` animation
containers. They use a different format from character ANM resources.
The header stores the frame count, offset table and length table. Each
frame is compressed with Nintendo LZ10. The first frame is a complete
256 × 192 tiled bitmap with a 256-colour RGB555 palette. Later frames
contain a 96-byte, most-significant-bit-first mask followed by one 64-byte
tile for each set bit. Unchanged tiles retain their previous indices.

The original dispatcher at `0x020941f4` selects LRIM. The decompressors at
`0x02094088` and `0x02094120` select LZ10 for compression type `0x10`.
The worker at `0x02094e28` passes each decompressed delta to `0x02094b84`,
which replaces selected 8 × 8 tiles. `0x02094b68` establishes the bit order.
The palette remains the first frame's original palette throughout the clip.

`OriginalTileAnimationLibrary.bundled().load(path:)` reads the original
payload already retained in `OriginalBitmaps`. The new manifest adds no
duplicate copies of these assets. `OriginalTileAnimationDecoder.advance()`
and `seek(frame:)` return `OriginalBitmap` frames. The existing bitmap API
leaves transparency and page rotation to the original layer controller.
Animation timing and repetition remain under script control.

Checkpoints retain the exact 49,152 tiled pixel indices, current frame and
source hash. Restoring a different clip's checkpoint fails. All 135 frames
match independent decompressed-buffer, tile-buffer and RGBA hashes in
[original-tile-animation-report.json](original-tile-animation-report.json).

```sh
python3 tools/decode_lrim.py
swift test --filter OriginalTileAnimationTests
```

The original frames in `previews/original-tile-animations/05-05R` show Kyle
turning and raising the telephone. Their lossless page rotation is only for
inspection. The native decoder retains source tile coordinates.

## Opening date and location cards

The native `OriginalOpeningStripReveal` translates the three variants of
the original controller at `0x020ad384`, `0x020ad634` and `0x020ada00`.
These are the date/location cards. The first displays Friday, December 24,
1976 on one page and New York, 5:07 P.M. on the other. Their lettering comes
from the original textures, with no replacement font or retyped text.

`tools/recover_opening_graphics.py` extracts the five source tables at
`0x020e234c`, `0x020e238c`, `0x020e23cc`, `0x020e240c` and `0x020e248c`.
The manifest records every original 32-byte row, its address, image name,
position, strip boundaries and reveal interval. All 35 `show/op2/op3d` BIN
textures are decoded independently. These contain DTX-format texels:
14 A3I5 images, 18 palette-zero-transparent images and three opaque indexed
images. The original texture binder at `0x02083cd0` enables index-zero
transparency for mode 4. The other palette entries remain opaque.

The controller initializes its counter to one. Each original update tests
the old counter against the source intervals, emits at most one sound
request, then increments the counter. At counter 231 it starts the original
30-update fade and waits for the shared fade controller to finish. The
native implementation emits the exact source fade and sound requests.
It does not invent audio, a frame rate or an independent fade duration.
Its checkpoint retains the variant, phase and counter for exact continuation.

The original draw helper at `0x02084d54` maps the source texels to upright
192 × 256 coordinates. `drawCommands(page:)` retains each strip's crop,
position, depth and polygon ID. The full-screen background is texture
bank 1, index 1, loaded from `data/map/sys_black.dtx` by `0x0208595c`.
`makePortraitImage(page:library:)` supplies a native pixel surface, and
`OriginalOpeningCardPage` displays it with the original aspect ratio.
Shared display fades remain the host's responsibility. Exact DS raster
quantization and the alternate handedness branch still need comparison.

```sh
python3 tools/recover_opening_graphics.py
swift test --filter OriginalOpeningGraphicsTests
```

The report is [original-opening-graphics-report.json](original-opening-graphics-report.json).
Lossless previews for all three variants are in `previews/original-opening-cards`.

## Remaining work

The native port still needs the complete character timing/transition state
machine, MTC mesh rendering, the exceptional bracelet resource investigation,
and complete original scene visibility, camera, material and lighting logic.
Original assets being
present is not evidence that all original graphics are already used in game.
