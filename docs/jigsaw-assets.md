# Melissa's jigsaw assets

The port uses the graphics decoded from the supplied ROM extraction under `extracted/unpacked_wpf/trick/zig`. No replacement illustration or text was drawn. Run `python3 tools/decode_jigsaw.py` from the repository root to reproduce the PNG files and manifest.

The decoder removes the WPF inline record, decompresses the CiNG container, expands the original BGR555 palettes, preserves the A3I5 piece alpha, and rotates each raster 90 degrees counterclockwise to match the game's upright book orientation. It does not resize the source PNGs. The manifest records the SHA-256 of each source record and output PNG.

| Source | Output | Meaning |
| --- | --- | --- |
| `zig00.bin` through `zig43.bin` | `JigsawPiece00` through `JigsawPiece43` | Twenty original Pinkie Rabbit picture pieces, five rows by four columns upright. The last column uses narrower source rasters. |
| `zig_00.bin` through `zig_43.bin` | `JigsawBackPiece00` through `JigsawBackPiece43` | Original gray reverse faces of the individual pieces. |
| `table.bin` | `JigsawTray` | Original empty assembly tray on the wooden table. |
| `table_bk.bin` | `JigsawTable` | Original wooden tabletop without the tray. |
| `zig_ura_01.bin` | `JigsawFront` | Original completed Pinkie Rabbit picture in its tray, in the later fold sequence. |
| `zig_ura_02.bin` | `JigsawFoldTray` | Original empty tray in the fold sequence. |
| `zig_ura_03.bin` | `JigsawReverse` | Original reverse picture with the handwritten message already present in the pixels. |
| `local/us/SystemIcon/left1.bin`, `right2.bin` | `JigsawRotateLeft`, `JigsawRotateRight` | Original curved rotation buttons, decoded from DS 8 by 8 tile data. |

`JigsawManifest.json` uses a 192 by 256 upright stage for all placements. The assembly tray and the later fold tray have different original positions and sizes. Do not use the later fold tray underneath the movable pieces. The decoded 40-pixel picture cells are displayed at 13/16 scale in the assembly tray; the 13-pixel transparent sprite padding is included in each placement. The solved assembly occupies the gray opening at approximately x=30, y=20, width=131, height=164. These display placements were reconstructed against the source tray and visually checked. They are port placement metadata, not coordinates extracted from the original executable.

The original Chapter 3 sequence in Room 219 uses all twenty pieces. The completed picture moves to the left display, and closing then opening the DS turns it over onto the right display. There is no fully-flat hinge requirement. The reverse message is contained in `zig_ura_03.bin`; the port must not overlay a new typed version or expose the message before the fold.

Sources:

- [Nintendo's original Hotel Dusk guide, Chapter 3](https://www.guiasnintendo.com/0_NINTENDO_DS/Hotel_Dusk/hotel_dusk_sp/cap_03_pas_02.html), confirming twenty pieces and the left-to-right closing action.
- [Jason Harley's CiNG file format research](https://jasonharley2o.com/reverse/hoteldusk/), used to decode the supplied graphics.
- The local game records listed above, which are the source of all puzzle pixels.
