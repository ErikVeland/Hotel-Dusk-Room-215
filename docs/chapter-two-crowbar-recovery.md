# Chapter 2 crowbar recovery

Process 30 now runs through ordinary inventory use on cabinet close-up 124. Native placement, lifting, paper retrieval and story return are connected. The route opens the joined memo and continues to the cabinet combination.

The supplied walkthroughs describe cabinet lifting in `CHP216` and the spoiler-free Chapter 2 route. The source also permits retrieving the whole memo before tearing it. This document records the implementation and original evidence.

## Reproducible original input

Scripts are under `tools/reference`. Captures remain local under `extracted/reference`.

| Script prefix | Evidence |
| --- | --- |
| `chapter-two-crowbar-closeup` | Select the torn paper and open view 124. |
| `chapter-two-crowbar-entry` | Use item 10 on component event 125, then enter process 30. |
| `chapter-two-crowbar-place` | Grab the handle, lower it to the cabinet base and wait for placement. |
| `chapter-two-crowbar-lift` | Hold the placed handle and drag through the successful lift. |
| `chapter-two-crowbar-drop` | Release during lifting and follow the failure response. |
| `chapter-two-crowbar-quit` | Quit before grabbing the crowbar. |
| `chapter-two-crowbar-partial-quit` | Quit after placement. |
| `chapter-two-crowbar-regrab-quit` | Release and grab again before quitting, which selects result 1. |
| `chapter-two-crowbar-drop-motion`, `chapter-two-crowbar-low-drop` | Drop motion, camera shake and a low release that permits another attempt. |
| `chapter-two-crowbar-success-motion` | Completion delay, paper animation and exit phases. |
| `chapter-two-memo-joined-return` | Back from the joined memo to cabinet inspection. |
| `chapter-two-cabinet-keypad`, `chapter-two-cabinet-combination-entry` | Close-up 116 and process 31 entry. |
| `chapter-two-crowbar-whole-memo` | Follow the alternative route without tearing the paper first. |

These scripts use touch and button input. They do not change original memory.

For the torn-paper route, the native route selects page point `(85,222)`, opens close-up 124 and uses item 10 at `(70,145)`. The resulting complete game state matches `chapter-two-crowbar-entry/ready`.

## Controller source

The factory selects overlay 5. The controller vtable is `0x02201530`. The current reference run allocates the object at `0x0221F410`. Allocation addresses must not become native dependencies.

| Function | Responsibility |
| --- | --- |
| `0x021FCD0C` | Assets, caption, initial return value and camera. |
| `0x021FD2A4` | Main phase dispatch and Back handling. |
| `0x021FD4C0` | Placement, lifting, release, dropping and completion delay. |
| `0x021FE37C` | Post-success camera and paper animation. |
| `0x021FE944` | Exit fade. |
| `0x021FE9C8` | Camera setup. |
| `0x02200BAC` | Original touch ray. |
| `0x02200D9C`, `0x02200EA0` | Handle hit geometry and drag plane. |
| `0x02200F8C` | Start a dropped-cabinet response. |
| `0x022010E8` | Detect placement at the cabinet base. |
| `0x022011C0` | Clamp lifting angle and calculate drop severity. |
| `0x022010A4` | Detect the completed lift. |

The controller starts in phase 1, substage 10. Camera eye is `(-42,7332,-2608)` and target is `(0,-294,-2621)`. The up vector is `(-4096,4096,0)`. Its initial handle position is `(819,532,-4096)`.

Placement moves to substage 2, then 5, then 3. The placed handle rotates around the cabinet base. The initial angle is approximately `0.157079637`. Successful lifting clamps it to `0.785398185`. Original captures retain intermediate angles and touch-held flags.

The lift capture reaches substage 6, then receives the remaining memo and opens the joined-paper drawing process. The drop capture releases from an intermediate lift checkpoint and enters the original failure dialogue. The later game-over presentation still needs recovery and a complete route check.

The original default return value is 2. The first grab leaves it unchanged. Releasing and grabbing again during placement changes it to 1. Success changes it to 0. A loud cabinet drop uses result 3. A low release returns to the lifting stage.

## Native boundaries

- `OriginalCrowbarProcess` owns placement, lifting, release, drop severity, animation and result selection.
- `OriginalCrowbarProjection` provides typed handle and drag-plane intersections. It preserves the original fixed-point triangle checks.
- `OriginalCrowbarRenderer` draws the original cabinet, wall, crowbar and paper assets.
- `OriginalPlaySession` owns touch sampling, pause, fades, audio commands and the process lifetime.
- `OriginalEventRunner.finishCrowbar` marks puzzle 6 complete only for result 0, then resumes the source script.

The handle rectangle follows its position without rotating. The placed handle retains its pre-clamp overshoot position. These details affect subsequent touch input.

The original triangle test checks three-dimensional edge cross products after fixed-point interpolation. A rectangle bounds test accepts a captured drag point that the original rejects. The native projection preserves that rejection.

Capture frame counts can differ from controller update counts. Tests align the original phase, timer and animation fields. They do not assume one controller update per emulator frame.

## Checks

`OriginalCrowbarTests` compares positions, angles, held flags, drag offsets, speed, drop severity, paper movement, timers and phases. It covers placement, lifting, low release, loud drop, success animation and quit results. Story-return checks compare all 32,088 original game-state bytes.

`OriginalOfficeRouteChecks` exercises the process through normal session input. It also checks pause, joined-paper acquisition, drawing exit and cabinet combination entry. Both the Chapter 2 checkpoint route and the full new-game route use this helper.

The milestone passed 10 tests with no failures or skips: eight crowbar checks and both story routes. A subsequent crowbar run passed all eight checks after adding marker fields, audio timers and result-1 story comparison. `git diff --check` passed.

```sh
SNAPSHOT_DIR=/tmp/hotel-crowbar-final \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter 'OriginalCrowbarTests|OriginalChapterTwoRouteTests.testChapterTwoRosaLinensAndHelenGuideRoute|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

The renderer loads original model and texture payloads. Native entry, placement and lift snapshots have visual inspection. Exact rasterisation and colour matching are not established.

## Remaining work

- Recover the shared animated touch marker and caption presentation.
- Check sound output against the original envelopes and mixing. The native host sends the recovered sound and volume commands.
- Complete the dropped-cabinet game-over sequence and its presentation. The process result and first returned story state have comparisons.
- Check the alternative whole-memo route through the native session. Original captures and memo-image checks cover its assets.
- Continue the office and Chapter 2 route. Process 31 and red-box acquisition are now connected. See [Combination recovery](chapter-two-cabinet-combination.md).

Decompiler carry flags are not reliable high-level comparisons. Assembly and captured controller fields support the implemented branches.
