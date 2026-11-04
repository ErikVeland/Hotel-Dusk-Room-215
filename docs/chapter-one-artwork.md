# Enhanced artwork

The active pack lives in
`Sources/HotelDuskDuoKit/Resources/EnhancedArtwork`. Its manifest enables 7,564
image records and records source exclusions. These records cover the full game,
including shared and Chapter 1 assets. The manifest is complete for loading;
that flag does not establish visual or device approval.

Textures and bitmaps use 4× dimensions. Character frames use 8× dimensions.
Original game coordinates, geometry, hit masks, poses and frame order stay fixed.
Records use the original decoded pixels as lookup keys. Byte-identical output
images share a file while retaining their separate source records.

`OriginalArtwork` checks dimensions and file hashes before accepting an override.
Missing or invalid files fall back to original artwork. Its decoded-image cache
is bounded. Original source payloads remain bundled.

## Verify and regenerate

The integrity checker and beta packaging need Pillow. Use an environment with
that dependency installed:

```sh
python3 tools/verify_artwork_candidate.py Sources/HotelDuskDuoKit/Resources/EnhancedArtwork
```

This checks filenames, file hashes, dimensions and recorded output-pixel hashes.
It does not assess visual quality, animation timing, model alignment or device
performance. See [TestFlight artwork packaging](testflight-beta.md#artwork-packaging)
for the separate smaller beta pack.

`tools/upscale_original_art.py` builds candidates offline. It requires NumPy,
Pillow, SciPy, PyTorch, Spandrel, local model weights and exported source images.
Read its command-line options before running a large job. Inference never runs
inside the game. `tools/artwork_scalers.py` selects the model pipeline.
`tools/artwork-overrides` contains source-specific corrections used by that job.

A new candidate must retain original alpha support and logical dimensions.
Preserve the source pack until the candidate passes integrity and visual checks.
Enable a candidate only after reviewing its intended coverage.

## Art direction and open checks

Use graphite linework, uneven dry hatching and warm illustrated materials.
Preserve original lettering, crop, scene geometry and character identities.
Texture studies that change a plaque, handle, motif or tiling scale are unsuitable
for production even when their file checks pass.

The earlier corridor-door overrides changed the original crop and details.
The retained corrections restore the source sign frame, separate room digits and
handle region. Check corridor, opposite UV orientations and close-up views together.

Character rendering desaturates available frames and blends their white regions
with the paper. This preserves existing linework but does not recover missing
detail. A frame-consistent pencil treatment and full motion review remain open.

The excluded `Br_bracelet_.anm` has a possible literal-block interpretation of its
first frame. That interpretation is not verified against the original decoder.
Keep it excluded until an independent source comparison confirms the format.
Fourteen `system/note/memo/*_M.bin` files are packed notebook ink rather than
palette bitmaps. The notebook decoder handles their original pixels separately.

A full playthrough and target-device performance check remain necessary.
