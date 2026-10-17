# Suitcase key

The native Chapter 1 route now reaches the suitcase after Rachel's telephone call. The player can inspect it, select the suitcase key, insert it and break it. Original dialogue then replaces item 21 with broken key item 29. The paperclip sequence remains unfinished.

## Checked route

1. Leave dresser inspection after Rachel's call.
2. Walk east around the bed, then south to the suitcase.
3. Select **Inspect**, then select the suitcase twice.
4. Advance its original inspection dialogue.
5. Select **Items**, select the suitcase key, then select the suitcase twice.
6. Drag the key into the lock.
7. Turn the inserted key until it breaks.
8. Advance the original broken-key dialogue.

These instructions describe the recovered interaction. They are not added as in-game hints.

The route uses search area 3 and `R205_s03`. Position `(9773,12288,18858)` and page point `(130,155)` select `obj04`. Dynamic search selection now loads each area's original cameras and hit geometry. The dresser remains area 1.

## Original mechanics

| Behaviour | Original evidence | Native implementation |
| --- | --- | --- |
| First suitcase inspection | R205 event 16, mode 10 | Returns to the retained inspection view. |
| Key use | Item 21, area 3, subarea 4, mode 16 | Event 21 on the checked route leads to event 22. |
| Puzzle selection | Factory `0x0200B334`, process 37, overlay 12, variant 2 | `OriginalSuitcaseKeyProcess` owns state and input rules. |
| Insertion | `0x021FD78C`, `0x021FDA08` | Original hit rectangles, quarter-step movement and target distance. |
| Camera and alignment | `0x021FE6F8` stages 0–4 | Key alignment, camera knots at 0/45/60 updates, then turning. |
| Key turning | `0x021FE6F8` stage 5 | Fresh grabs and alternating vertical endpoints increase the counter. The caption at count 11 also advances it. |
| Break | Counter greater than 21 | Original broken-key model, animation state and return value 0. |
| Quit before insertion | Return value 2 | Event 24 restores inspection. |
| Quit after insertion | Return value 1 | Event 23 runs its original response. |
| Successful exit | `0x02026DD4` | Sets puzzle flag 13 only for return value 0. |
| Story return | R205 event 25 | Original inventory replacement and dialogue. |
| Retry checkpoint | Search request 8, `0x020340D0`, `0x020987CC` | Copies `0x1AAC` live bytes into the retry buffer. It does not create an on-disk save. |

The renderer uses `trick/bag/kaban.mdf`, `KEY_01.mdf`, `KEY_02.mdf` and their original BIN textures. Models share a Metal colour and depth target. The DS camera uses negative X as its up vector before framebuffer rotation.

## Reference captures

All listed captures use normal input with the supplied ROM. The input files are under `tools/reference/room215-suitcase-*.txt`. Captures remain local under the ignored `extracted/reference` directory.

| Checkpoint | Save-state SHA-256 |
| --- | --- |
| `room215-suitcase-inspect/inspect` | `140cf550c6e3d9a76cb33551db3e50dc2b9650961fe854a4a204f67bbe1c758a` |
| `room215-suitcase-look2/looked` | `60d52cf3b846e4aeeceb4d5ba804e99be4829a234283d2fe08337a0b69b052b4` |
| `room215-suitcase-key2/puzzle` | `d7fba85e89bb40f127f85c3101bd56079506f457d4e9299be5279df6d5a74fe7` |
| `room215-suitcase-insert/inserted` | `d17f7d57b61a410c6e6f7de0a3c7ec737db9bd806de4b2c6c163e3ce28dcd5c5` |
| `room215-suitcase-turn/broken` | `fe16434134975217843842ae5c3c12508c7bde17cbe60212cbaee56798524ee5` |
| `room215-suitcase-aftermath/step8` | `13e41c643fd9ffa7d6f93e72956c72b0b1f0c6e520bb6574632dafbba1e05cc5` |

The complete 32,088-byte game state matches after inspection, at puzzle entry and after the broken-key dialogue and retry checkpoint. Separate quit comparisons cover all bytes after the 24-byte map header. Later A presses in those captures can store map position.

The native route check starts at arrival and uses ordinary session input through key breakage. It does not inject a puzzle result. Separate process checks cover insertion, the first turn's key position, the turn counter, failed touches and both quit results.

## Validation

On 17 October 2026, 48 targeted Swift checks passed in one run with no failures or skips. These cover the normal route, suitcase mechanics, quit branches, map searches, doors, event completion, textures and rendering. The native start, inserted-key and broken-key images were inspected against the original captures.

## Remaining differences

- Native trigonometry approximates the original touch-ray lookup. The fixed-point segment retains rounding, but complete per-frame position equivalence is unverified.
- Metal texture filtering, rasterisation and scene lighting do not match every original pixel.
- Original puzzle captions 2, 19, 20 and 29 are retained as unrendered presentation records. Their portraits and text are not yet drawn. Caption-related frame timing remains unverified.
- Fade durations control process completion but are not yet applied to the displayed puzzle image.
- Original start and stop cues use the recovered effect bank. Acoustic output and precise playback timing still need comparison.
- Inventory selection and the Back control use native text buttons.
- Paperclip straightening, wire use, later story routes and persistent saves remain open. [Paperclip acquisition](paperclip.md) is now connected.
- iOS, physical Duo, touch accessibility and left-handed interaction require separate checks.
