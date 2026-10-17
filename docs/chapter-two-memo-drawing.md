# Chapter 2 memo drawing

Process 34 now displays the original memo and accepts drawing input. The office route opens the torn memo after acquisition and returns to cabinet inspection. Inventory can open the memo again. The checked native route then completes crowbar lifting, opens the joined memo and returns to cabinet inspection.

The supplied walkthroughs identify this puzzle in `CHP216`. The memo is a scratchpad. It does not check drawn answers or solve the cabinet. The player reads the symbols and enters the code in the separate cabinet puzzle.

## Recovered behaviour

Overlay 14 supplies the paper selection, symbol geometry, ink rules and toolbar timing.

| Source | Behaviour |
| --- | --- |
| `0x021FCC60` | Initialise process 34 and select the paper asset. |
| `0x02027CF4` | Initialise or reuse the saved random value. |
| `0x021FE4F8`, `0x021FE50C` | Digit point counts and coordinates. |
| `0x021FE2DC` | Sample held touches and check the paper mask. |
| `0x021FDD94` | Draw line segments with the original rounding and endpoint rules. |
| `0x021FDC30` | Stamp a clipped three-by-three ink mark. |
| `0x021FDBA4` | Clear the ink buffer. |

The random value lives at game-state offset `0x13D4`. A nonzero value persists across reopening and native checkpoint restoration. The source generator multiplies its seed by `0x5D588B65`, adds `0x269EC3` and takes the upper 16 bits. It repeats if that value is zero. The code is the saved value modulo ten, plus 127.

The original seeds this generator from hardware ticks. The native session receives an injected seed provider. Route checks use a seed that reproduces the captured value of 100 and code 127. Ordinary play uses a host random seed.

Inventory item 63 selects the whole memo. Item 13 selects the joined memo. Otherwise, the process shows the torn memo. Original assets are `memo02`, `memo00` and `memo01` under `trick/pointtie`. The original texture loader ignores duplicate IDs, so its later `memo01` request does not replace the whole-memo texture.

The process adds the original numbered labels and three symbol groups. The torn-paper layout shifts the points down by 59 pixels. Ink uses the original 49,152-byte buffer and excludes mask value 1. Each opening starts with blank ink. Clear removes ink without changing the saved code.

The toolbar enters from position 256 to 228. Back becomes available after 29 controller updates. Exit fades for 60 updates and returns result 2. No drawing-completion result exists in this controller.

## Native boundaries

- `OriginalMemoDrawing` owns points, ink, clipping and line interpolation.
- `OriginalMemoDrawingProcess` owns input timing, toolbar state, sound requests and exit.
- `OriginalMemoDrawingImage` composes the original paper, glyphs and ink.
- `OriginalPlaySession` connects input, fades, audio and script or inventory return.
- `OriginalMemoDrawingView` displays the image and forwards drawing, Clear and Back.

## Evidence

Reference scripts use ordinary input. They remain under `tools/reference`. Captures remain local under `extracted/reference`.

| Script prefix | Evidence |
| --- | --- |
| `chapter-two-memo-torn-return` | Process entry, original random value and symbol records. |
| `chapter-two-memo-drawing-ink` | Dot, line, diagonal, off-paper movement and release. |
| `chapter-two-memo-drawing-clear` | Cleared original ink buffer. |
| `chapter-two-memo-drawing-quit` | Return from the story-opened memo. |
| `chapter-two-memo-drawing-reopen` | Inventory selection and reopening. |
| `chapter-two-memo-drawing-reopen-return` | Return from the inventory-opened memo. |
| `chapter-two-memo-joined-ready` | Joined memo after the entry fade. |
| `chapter-two-crowbar-whole-memo` | Whole memo from the alternative crowbar route. |

The native checks compare the symbol records and complete ink buffers. The torn, joined and whole memo images match every RGB5 channel in the top 192×220 pixels. The toolbar is outside that image comparison. Route checks cover pause, Clear, Back, inventory reopening and complete original game-state comparisons.

## Validation

The final route run passed 19 tests with no failures or skips. It included the full new-game route, Chapter 2 route, memo drawing, memo pulling and office checks. A subsequent seven-test memo run added joined and whole-paper image comparisons. All seven passed with no skips. These runs cover 21 distinct tests.

The inventory route check found an old close-up left active after memo pulling. Process completion now clears that view before returning to cabinet inspection. Both story routes pass with the correction.

```sh
SNAPSHOT_DIR=/tmp/hotel-memo-drawing-final \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter 'OriginalMemoDrawingTests|OriginalChapterTwoRouteTests|OriginalMemoPullTests|OriginalOfficeTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

The additional image checks used `swift test --filter 'OriginalMemoDrawingTests'` with the same environment. `git diff --check` passed. Native memo snapshots were inspected. Physical Duo touch and hinge behaviour remain unverified.

## Remaining work

- Reproduce the original process caption and animated toolbar graphics.
- Compare sound timing and playback with original recordings.
- Complete the later game-over sequence after a loud cabinet drop. Crowbar success and the first failure return now have native checks. See [Crowbar recovery](chapter-two-crowbar-recovery.md).
- Continue the later office events. Cabinet combination entry and red-box acquisition are connected. See [Cabinet combination](chapter-two-cabinet-combination.md).

The complete game remains unfinished.
