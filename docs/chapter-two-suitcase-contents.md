# Chapter 2 suitcase contents

## Route and current boundary

The detailed walkthrough section `CHP213` says to move the pencil, take the cash and store the client list before leaving. The spoiler-free walkthrough gives the same order. Both files are under `Source/Walkthrough`.

The native game now runs process 35 after the thick-wire puzzle. It opens either compartment, moves objects, presents shared descriptions and takes available items. The checked route moves the pencil, takes the cash and returns to room inspection. Client-list storage uses the existing item-use script.

## Recovered interaction rules

`OriginalSuitcaseContents` implements the object layout, visibility, hit detection, drag movement and second-selection actions from overlay 24.

| Source | Recovered behaviour |
| --- | --- |
| `0x021FCC50` | Initial positions for six upper objects and eleven lower objects. |
| `0x02203560`, `0x02203620` | Drawing origins, texture sizes, initial positions and hit rectangles. These dimensions can differ. |
| `0x02201EA4` | Upper rectangles, object priority and the unselectable strip at page Y 167–183. |
| `0x02202084` | Lower A3I5 alpha checks and object priority. The pencil uses its rectangle without an alpha check. |
| `0x02202D90` | Drag offset, quarter-distance movement and screen bounds. |
| `0x021FDD94`, `0x021FE308` | A second selection describes an object or takes an available item. |
| `0x02202518`, `0x020282A4` | Shared System response, mode 20, pair A 12 and the object-specific pair B. |
| `0x02202A6C` | Item acquisition precedes its presentation and shared dialogue. `OriginalSuitcaseContentsProcess` owns the shade, scale, hold and restoration counters. |

The original retains the selected object after release. Selecting it again can inspect it after the separate double-tap timer expires. A new selection starts dragging. The process controller gates input during fades, acquisition and dialogue.

`OriginalPlaySession` retains the parent runner while the System response runs. It copies the returned state back before resuming the contents process. The original destructor sets puzzle flag 11 on exit. The native runner does the same.

## Presentation

The renderer loads `trick/searchbag/kaban.mdf` for the overview. Nodes 1–4 use the lid rotation. Other visible nodes use the base rotation. The lower and upper compartments use separate source backgrounds and object textures. The upper strap covers the source document layers.

`OriginalBitmapLibrary.loadTexture` checks the payload hash and passes DTX data directly to the texture decoder. This preserves dimensions that differ between allocation and logical content. The linear-bitmap decoder rejects those dimensions and is unsuitable for these textures.

The native view forwards touches and Back to the process. Screen brightness uses the existing effect controller. Item acquisition shades the contents and scales the original item image about the page centre. The original sound IDs are connected, including movement-dependent drag volume.

The overview, both compartments and cash image were visually compared. Exact DS rasterisation, cursor feedback, selection tint, original caption and Back artwork remain unfinished. The view currently uses the native Back button. Acoustic fidelity and physical-device input remain unverified.

Visibility uses original game flags, chapter and inventory. Later items have transcribed conditions and response IDs. Their complete story routes have not been compared.

## Original traces and checks

The reproducible ordinary-input traces are:

- `tools/reference/chapter-two-suitcase-open.txt`: finish the lock dialogue and enter the lower compartment.
- `tools/reference/chapter-two-suitcase-cash.txt`: select and move the pencil, select the cash and finish its dialogue.
- `tools/reference/chapter-two-suitcase-upper.txt`: enter the upper compartment and inspect the map.
- `tools/reference/chapter-two-suitcase-item-timing.txt`: record the acquisition shade, scale, hold and response counters.
- `tools/reference/chapter-two-suitcase-exit.txt`: return through the overview to room inspection.
- `tools/reference/chapter-two-suitcase-store-items.txt` and `store.txt`: select the client list and store it in the suitcase.
- `tools/reference/chapter-two-suitcase-geometry.txt`: read original submitted geometry and texture memory.

They write captures under matching `extracted/reference/chapter-two-suitcase-*` directories. The captured process controller is at `0x02221A40`. Upper positions start at `+0x484`, lower positions at `+0x4BC`, and selection at `+0x524`.

The earlier `chapter-two-thick-wire-opening/returned` checkpoint still contains Kyle's dialogue. It has not entered process 35. The new contents trace advances that dialogue before checking process state.

Six targeted native checks passed on 18 October 2026:

- Initial positions match both original compartments.
- The pencil drag and cash selection match the recorded input and exact captured floating-point positions.
- Alpha masks, upper selection priority and the unselectable strip behave as recovered.
- Drag bounds and selection reset behave as recovered.
- Original flags and inventory control object visibility.
- Cash acquisition and its shared script response match all 32,088 original game-state bytes after the response returns.

Those six checks exercise the interaction and script components directly. A later four-check run passed the Chapter 2 native route and two process checks. A subsequent twelve-check run passed the full new-game route, bitmap checks and suitcase interaction, timing and rendering checks. No checks failed or skipped. The normal route now compares complete state after cash pickup and after the contents process exits.

The final ten-check run also passed client-list storage through normal new-game input. It compares all original game-state bytes after storage. The client list leaves inventory and game flag 51 records storage. `git diff --check` passed.

The timing checks match the original item stage, timer, shade, visibility and floating-point scale at eight checkpoints. Native texture upload completion is supplied separately. Its duration is not claimed to match DS resource I/O.

Run the targeted checks with the repository's Swift test command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --filter 'OriginalSuitcaseContents|OriginalChapterTwoRouteTests'
```

## Remaining work

1. Complete cursor, selection feedback and original control presentation.
2. Compare additional object descriptions, later item branches and re-entry paths.
3. Continue from the now-connected [payment route](chapter-two-payment.md) into Dunning's office.

The complete port, later item branches, device input and presentation fidelity remain unverified.
