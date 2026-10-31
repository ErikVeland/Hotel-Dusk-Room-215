# Original notebook

The native notebook now opens from hallway exploration and conversation question menus. It retains the parent map or conversation until the player selects **Back**.

The checked Chapter 1 route opens it after returning Melissa’s puzzle piece. Three writable pages precede her drawing on page 4. The viewer uses the original acquired drawing, not a generated replacement.

## Data and behaviour

`OriginalNotebook` owns the page index, packed pages, current ink, undo buffer, pen state and held touch. It receives an asset loader. Views forward input through `OriginalPlaySession`.

| Original source | Native behaviour |
| --- | --- |
| `0x020797CC` | Load three writable pages, then acquired drawings in flag order. Clear the notebook notification. |
| `0x02078EB4` | Expand packed bits from least significant to most significant. |
| `0x02079CC8` | Wrap previous and next page selection. Disable editing on acquired drawings. |
| `0x020784AC` | Retain the first touch and copy the undo buffer. Draw on subsequent held samples. |
| `0x02078B14` | Interpolate a stroke with the original slope and rounding rules. |
| `0x020789F4` | Apply a 2×2 pen or 5×5 eraser. |
| `0x02078930` | Address the original 8×8 ink tiles and apply page bounds. |
| `0x020788B0` | Swap current and undo buffers. A second Undo restores the edit. |
| `0x02078DA8` | Pack writable ink on page change and close. |
| `0x020797CC` | Append the apple-note overview and each collected detail page. Clear uncollected regions from the overview using the five tile positions at `0x020E195C` and the mask at state offset `0x13D8`. |

Each page has 6,144 packed bytes and 49,152 expanded pixels. Writable pages start at game offset `0x3558`. Lock bytes start at `0x13C8`. Acquired drawing flags start at `0x87B`. Opening clears the notification byte at `0x87D`.

`OriginalBitmapLibrary.loadNotebookData` checks the existing manifest hash and decodes the CiNG container. These assets have no palette-bitmap header. `OriginalNotebookImage` converts their tile order to upright page pixels.

The session samples held ink at its existing original update rate. Pause releases the touch. Opening the notebook clears held walking input. Closing restores the retained parent phase. Writable ink survives notebook close and reopen within the running session.

## Original comparisons

Reference inputs are in these files:

- `tools/reference/melissa-notebook-open.txt`
- `tools/reference/melissa-notebook-pages.txt`
- `tools/reference/notebook-strokes.txt`
- `tools/reference/notebook-angled-strokes.txt`

The captures continue the modified delivery fixture described in [Louie’s delivery](louie-delivery.md). These sequences add no memory writes. They establish component behaviour, not a complete unmodified ROM playthrough.

| Checkpoint | Save-state SHA-256 |
| --- | --- |
| `melissa-notebook-pages/page4` | `7527b49bff475e0561d738874eab4835f25d80b023e9cf70ec3be5c9bd1808a0` |
| `notebook-angled-strokes/erasureStored` | `e5cd41916b2eb5b6e3e50eaf5b047bbbc953cbf031f6695dc459be4bc5830814` |

`OriginalNotebookTests` checks complete game state after opening and page navigation. The acquired drawing’s complete packed and expanded arrays match original RAM. Vertical, shallow, steep, reversed and erased strokes produce the original stored game state. Undo, redo, clear, drawing protection, page wrapping, bounds and malformed data also have targeted checks.

The full native route opens Melissa’s drawing from the conversation, pauses, closes and continues her departure. It then opens the notebook from walking, draws, closes and checks the retained ink after reopening.

## Validation on 18 October 2026

The combined run passed 13 targeted Swift checks with no failures or skips. These cover notebook behaviour, game-state storage, Melissa, shown-item selection and both native Chapter 1 routes. The README’s `swift test` command was used with suite filters and `SNAPSHOT_DIR`. GPU, audio and window-server checks required sandbox escalation.

The native drawing snapshot was inspected. It shows the original drawing upright with a visible `4/4` page count and navigation controls. `git diff --check` passed.

## Remaining work

- Compare later grouped-note page breaks with original captures that contain mixed memo groups.
- Recover original menu graphics, paper layers, cursor, page-turn animation and sound cues.
- Compare locked writable pages and additional stroke edge cases with original execution.
- Connect notebook viewing requests from later dialogue and puzzles, including mode-25 conversation responses.
- Add original persistent save and restore. The current checks cover the running session only.
- Verify physical Duo touch, hinge and lifecycle behaviour.

The native controls expose notebook editing directly. The original notebook’s wider menu, character records, plot summary, map, settings and save interface remain unfinished.
