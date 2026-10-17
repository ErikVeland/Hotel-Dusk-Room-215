# Chapter 2 trapped memo

Process 27 now has a native drag controller and renderer. It uses the original cabinet, wall and paper assets. The office route can select the trapped paper, pull it until it tears and receive item 7. The following memo-drawing process, process 34, is connected. See [Memo drawing](chapter-two-memo-drawing.md).

## Route and source evidence

The detailed walkthrough describes the trapped paper at the end of `CHP215` and the torn memo in `CHP216`. The spoiler-free guide also describes the alternative crowbar route. Pulling the paper does not replace the later crowbar puzzle.

The reference scripts start from the completed office records and calendar route. They use ordinary input without changing original memory.

| Script | Capture directory | Purpose |
| --- | --- | --- |
| `chapter-two-office-cabinet-approach` | Same name | Walk to the numbered cabinet and enter search area 2. |
| `chapter-two-memo-paper`, `chapter-two-memo-inspect` | Same names | Select the paper and open close-up 119. |
| `chapter-two-memo-pull-entry` | `chapter-two-memo-pull-ready` | Select event 121 and start process 27. |
| `chapter-two-memo-pull-drag` | Same name | A large drag loses contact with the paper. |
| `chapter-two-memo-pull-wiggle` | Same name | Small sideways movements reach the tear threshold. |
| `chapter-two-memo-torn-return` | Same name | Torn-paper dialogue, item acquisition and memo-drawing entry. |
| `chapter-two-memo-quit`, `chapter-two-memo-partial-quit` | Same names | Untouched and partial-pull quit responses. |

Scripts are under `tools/reference`. Captures remain local under `extracted/reference`.

## Recovered controller

The process factory at `0x0200B334` selects overlay 6 for process 27.

| Source function | Behaviour |
| --- | --- |
| `0x021FD478` | Grab, hold, release and loss of paper contact. |
| `0x021FD620` | Angle limits, pull increments, sounds and tear threshold. |
| `0x021FD8F8` | Tear movement and the 121-update return delay. |
| `0x021FDABC` | Fade and result selection. |
| `0x021FFCDC` | Fixed-point touch ray. |
| `0x021FFECC`, `0x021FFFD0` | Translated paper hit rectangle and drag plane. |
| `0x020254C8` | Signed angle around the original pivot. |

The pull starts at `0.15`. A qualifying angle change adds `0.015`. Contact with an angle limit adds `0.001`. The paper tears only when the pull exceeds `0.35`. Quitting returns 2 before movement and 1 after a partial pull. A torn paper returns 0 and marks puzzle flag 3.

The original 10-degree trigonometric lookup selects pair 113 at `0x020E272C`: sine 706 and cosine 4035. Using rounded mathematical sine and cosine changes the fixed-point grab position. The native projection uses the recovered pair.

The paper hit rectangle does not rotate with the drawn paper. It only follows the paper position. The controller can grab again during a continuous hold after losing contact.

The tear code increments its animation counter, compares it with zero and then resets it. This produces one movement update before the shared message and delay. The native controller retains this behaviour.

## Native boundaries

- `OriginalMemoPullProcess` owns drag state, pull limits, sounds, tear movement and results. Its touch contract contains the two world intersections.
- `OriginalMemoPullProjection` maps native page coordinates to the original fixed-point intersections.
- `OriginalMemoPullRenderer` draws the source models and paper textures from `trick/placedmemo`.
- `OriginalPlaySession` owns timing, fades, audio, pause handling and the return to the original room script.
- `OriginalMemoPullView` displays the image and forwards touches and Back.

## Checks and remaining limits

Targeted checks compare the initial state, held offset, repeated sideways movements, contact loss and pull threshold with original controller memory. The tear angle, translation and delay are also checked. All three story outcomes compare the complete 32,088-byte original game state.

The renderer uses source assets and transforms. Five sampled RGB5 colours differ from the original by at most three levels per channel. This is an approximate rendering comparison. The shared Metal model renderer does not reproduce DS colour modulation and rasterisation exactly.

The normal route check covers cabinet selection, process entry, native drag input, pause, tear, item acquisition and process-34 entry. It does not inject a puzzle result.

The final run passed 14 tests with no failures or skips. It included the full new-game route, the Chapter 2 route, seven memo checks and four office checks. `git diff --check` also passed. Native cabinet and memo snapshots were inspected.

```sh
SNAPSHOT_DIR=/tmp/hotel-memo-final \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter 'OriginalChapterTwoRouteTests|OriginalMemoPullTests|OriginalOfficeTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

Original process captions and the shared tear message remain in the unrendered-presentation trace. Their text layout and blocking timing are not reproduced. The original colour modulation, exact rasterisation and later game-over sequence remain open. Cabinet unlocking and red-box acquisition are connected. See [Cabinet combination](chapter-two-cabinet-combination.md). Crowbar lifting and joined-paper retrieval are connected. See [Crowbar recovery](chapter-two-crowbar-recovery.md).
