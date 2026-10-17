# Original touch pictures

Opcode 8 now waits for player input. The native route covers the three registration pictures, the dropped jigsaw piece, Louie's parcel and his recognition picture. Unsupported picture modes stop explicitly.

## Recovered behaviour

| Original source | Native responsibility |
| --- | --- |
| `0x0203FD30` | Read the picture ID and block the event runner. |
| `0x0205B2A4`, `0x0205B2F0` | Read the 44 records in `data/map/sdata/touchevent.lst`. Each record has 40 bytes. |
| `0x0200F214`, `0x0200F324` | Load the foreground and optional background. Enter picture selection and return after confirmation. |
| `0x020100C0` | Pack four 2×2 occupancy blocks into each mask byte. |
| `0x0200FF7C` | Select on the first press. Confirm on a later press while the object remains selected. |
| `0x0200FC38` | Draw the selected mask over the foreground. |
| `0x0203FBFC` | The following opcode adds the item and opens its text notice. |

The hit check reads a whole mask byte. It does not extract the touched two-bit field. The native model retains this coarse hit area. Moving a held touch outside the object clears selection. Holding the original press does not confirm it. Release preserves selection.

A record with a background uses a 256×192 source image. An empty background selects a 128×128 image at the record's page position. Input uses the original 192×256 book orientation and touch bounds. Mode 1 remains unsupported.

Selection plays archive 8, entry 1. Confirmation plays archive 8, entry 0. The return waits for the original 20-update fade and following process stages. The native host loads resources synchronously and enters selection without reproducing the original loading and cursor-start stages.

## Dropped piece

R117 event 52 uses picture 4. Its foreground is `check/TouchEvent/TCG0104.bin`. Its background is `check/StilBG/TCB0104.bin`. Both are already in the bitmap bundle.

After confirmation, opcode 6 adds item 3. The original enlarged image is `system/ItemImage/item003.bin`. The native notice uses this image over the retained stairs background. It does not award the item during selection.

The bitmap decoder now handles Nintendo `0x30` run-length streams, kind 3 indexed backgrounds and kind 1 A3I5 item images. Truncated streams, output overflow and trailing bytes cause errors. Kind 4 retains caller-controlled palette-zero transparency.

| Compared data | SHA-256 | Original RAM offset |
| --- | --- | --- |
| Picture 4 mask, 3,072 bytes | `4afab132aa751bc271df4280052b4d4fe5ce3d316dfcb355f06c5e6534895320` | `0x2B6340`, before selection |
| Decoded stairs background | `c00510952c25b783e6b3c420e67218d0f33783b444616b2a1c7bc7f017870bf6` | `0x335150`, acquired capture |
| Decoded enlarged piece | `8546f1b8641f678141fc7186e859c76d4f569b9bcc5a08312a065493bfadc973` | `0x328F30`, acquired capture |

Offsets are relative to ARM9 main RAM at `0x02000000`. Tests compare the complete byte ranges when the local captures exist.

## Original execution

[`tools/reference/dropped-piece.txt`](../tools/reference/dropped-piece.txt) replays ordinary input from `jigsaw-aftermath2/after139.mln`. Its two raw touches are `(127,100)`, or page `(100,128)`.

The replay completed in `extracted/reference/dropped-piece-combined`:

| Checkpoint | Observed state | Savestate SHA-256 |
| --- | --- | --- |
| `selected` | Talk controller state `0x13`, operation index 6. Piece selected. | `a009ef3a508d7d2e50608510f764af0a3e36856376439383c7e7bacb3520ca5f` |
| `acquired` | State `0x15`, operation index 7. Enlarged item and acquisition text. | `a57be653233099b25c20606fe19369189ae8fcfeaccbf148d07427a93baf74e4` |
| `upstairs` | Current map 39, previous map 17. Hallway exploration. | `e86da48a5f09cad2ae6e3a5308a2d8ba2732da56b07fe0eb5400eb8f860625a3` |

The ROM and runner revision remain those recorded in [Chapter 1 jigsaw](chapter-one-jigsaw.md). Captures and savestates remain local and ignored.

## Native checks and limits

The normal session check uses all three registration pictures, completes the jigsaw, selects the dropped piece, confirms it and checks item 3. Dialogue input cannot bypass the picture phase. No process result or inventory item is injected into that route.

Dedicated checks cover table bounds, mask bytes, crop positions, coarse hit areas, held touches, outside touches, confirmation, return stages, item timing and malformed compression. The captured item and background decode byte-for-byte. Native page captures show the small piece and the enlarged item on the stairs.

On 17 October 2026, the combined picture, jigsaw, map and session run passed 46 Swift checks with no skips. Seven Python recovery checks also passed. The Swift run built the macOS app and captured the native route pages.

The native display omits original cursor animation, portrait composition and visible fades. The highlight uses the captured default RGB5 colour `(24,16,3)`. The selected mask now uses the original polygon alpha 15, giving 50% blending. This corrects the opaque silhouette found in the Louie capture. Custom highlight settings and the foreground fade remain unconnected. Loading and transition timing have not been compared frame-by-frame. Physical Duo input and iOS builds remain unchecked.

Native play now enters R213 and starts Jeff's entrance. See [Upstairs corridor](upstairs-corridor.md). Room entry and selected item uses now have comparisons. See [Room 215](room215.md) and [Louie's delivery](louie-delivery.md) for the current route.
