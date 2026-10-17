# Chapter 2 cabinet combination recovery

The native office route reaches process 31 after crowbar lifting and joined-memo retrieval. Native wheel dragging, alignment, quit, retained digits and drawer opening are connected. The route now takes the red box from close-up 122.

The detailed walkthrough describes this puzzle in `CHP216`. The player reads three numbers from the memo, then turns the wheels above drawer 3. The code must come from saved game state.

## Original route evidence

Scripts under `tools/reference` use ordinary touch and button input:

| Script | Checkpoint |
| --- | --- |
| `chapter-two-memo-joined-return` | Back from the joined memo to cabinet inspection. |
| `chapter-two-cabinet-keypad` | Page point `(85,18)` opens cabinet close-up 116. |
| `chapter-two-cabinet-combination-entry` | Page point `(135,40)` opens the wheel process. |
| `chapter-two-cabinet-wheel-drag` | First-wheel press, three downward drag samples and release. |
| `chapter-two-cabinet-unlock` | Code 127 entry, drawer opening and story return. |
| `chapter-two-cabinet-success-motion` | Success delay, fade transition and drawer animation fields. |
| `chapter-two-cabinet-quit`, `chapter-two-cabinet-partial-quit` | Untouched and moved-wheel returns. |
| `chapter-two-cabinet-reopen` | Reopen after retaining the displayed number 199. |
| `chapter-two-office-after-box`, `chapter-two-office-exit-approach` | Return to walking and leave the office for the lobby. |
| `chapter-two-cabinet-drawer`, `chapter-two-red-box-closeup`, `chapter-two-red-box-take` | Drawer selection, close-up and red-box acquisition. |

The native Chapter 2 route compares all 32,088 game-state bytes at close-up and process entry. The full new-game check reaches the same process through ordinary native input.

## Source locations

The process factory at `0x0200B334` selects slot 9, which maps to overlay 10. The controller vtable is `0x02202104`. The current reference allocation is `0x02258710`. That address is capture data, not a native dependency.

| Function | Responsibility |
| --- | --- |
| `0x021FCD98` | Initialisation and target digits. Cabinet mode uses the memo value modulo 10, plus 127. |
| `0x021FCFB0` | Completion flag and retained wheel value on destruction. |
| `0x021FD544` | Phase dispatch and Back handling. |
| `0x021FD724` | Wheel selection, drag, release, alignment and success detection. |
| `0x021FDC64` | Convert wheel angle to a displayed digit. |
| `0x021FDD1C` | Compare all three digits with the target. |
| `0x021FDD90` | Later cabinet animation phase. |
| `0x021FE64C` | Fade transition and exit. |
| `0x021FE76C` | Camera setup. |
| `0x021FF68C` | Wheel geometry and initial state. |
| `0x02201B60`, `0x02201D74` | Touch ray and transformed intersection. |

Fields include mode at `+0x2A8`, phase at `+0x2AA`, stage at `+0x2AC`, held flag at `+0x2ED` and selected wheel at `+0x2EE`. Wheel angles start at `+0x4FC` with stride `0x2C`. Target digits occupy `+0x68C..+0x68E`.

The same overlay has a second mode with target 518. Keep that mode separate from the office cabinet until its story entry is recovered.

## Native boundaries

- `OriginalCabinetDialProcess` owns the three angles, selection, drag offsets, alignment, result and animation phases.
- `OriginalCabinetDialProjection` supplies the original fixed-point wheel and drag-plane intersections.
- `OriginalCabinetDialRenderer` draws the ten cylinder strips, translucent surround and original cabinet models.
- `OriginalPlaySession` owns touch sampling, pause, fades, audio commands and script return.
- `OriginalEventRunner.finishCabinetDial` records puzzle 7 completion on success and retains the displayed number.

The initial number is 999. Game offset `0x13D6` stores 999 minus the displayed number on quit. Success clears that field. Reopening reconstructs the three initial angles from the stored digits.

Dragging changes the selected angle using the original factor 0.16. Release wraps the angle into `[0,2)`, then moves it by 0.01 per update towards a multiple of 0.2. Alignment ends within the original squared tolerance. It does not snap the angle to an exact multiple. Captured emulator frames can contain different controller update counts, so motion checks align the recorded fields.

The target uses the saved memo random value modulo 10, plus 127. The tested reference code is 127. The normal new-game check reads the current target and turns the wheels through ordinary touch input.

Success starts the jingle, waits 121 updates, fades to the cabinet view, then opens the drawer. Drawer displacement increases by 0.001 until it exceeds 0.05. The source skips its unused camera-movement stage. A 61-update delay and 61-update exit stage follow.

The wheel surround uses the original A3I5 texture. The native renderer composites it after the opaque wheel faces so its partial alpha reveals the adjacent numbers. The drawer node translation follows the model rotation and scale, matching the source matrix order.

## Checks and limits

`OriginalCabinetDialTests` compares angles, drag offsets, wheel positions, target digits, held state, selected wheel, phases, timers and drawer displacement. All three script returns have complete 32,088-byte original game-state comparisons. Other checks cover quit and reconstructed digits.

Both normal story-route checks reach the cabinet through crowbar completion and the joined memo. They enter the code, resume the source script and inspect the red-box drawer. The Chapter 2 checkpoint route compares complete game state at the recorded checkpoints.

The milestone passed eight tests with no failures or skips: six dial checks, the Chapter 2 checkpoint route and the full new-game route. Both routes took the red box. A further seven-test run checked the original reopened wheel fields and return to walking. Both story routes then passed through the office exit, including the complete original lobby return state. `git diff --check` passed.

```sh
SNAPSHOT_DIR=/tmp/hotel-dial-final \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter 'OriginalCabinetDialTests|OriginalChapterTwoRouteTests.testChapterTwoRosaLinensAndHelenGuideRoute|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

Native dial and drawer snapshots have visual inspection. Exact rasterisation, original caption layout, the held-touch overlay, physical Duo input and acoustic fidelity remain unverified. Native Back uses the existing book control.

## Next work

- Continue Louie's Nile conversation using both walkthroughs. The office exit now has a complete state comparison. See [Louie route evidence](chapter-two-louie-office.md).
- Complete the remaining Chapter 2 conversations and review.
- Recover the shared process captions and held-touch presentation.
- Connect the overlay's separate 518 cashbox mode when its story route reaches it.

The decompiler does not preserve every floating-point condition. Assembly and captured fields support the implemented branches.
