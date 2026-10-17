# Jeff at Room 213

The native Chapter 1 route now returns upstairs after Rosa’s 5:20 departure. Kyle can inspect Room 213, knock, question Jeff about Mila and return to corridor walking.

Both supplied walkthroughs place this visit after Rosa. The detailed guide uses `CHP121`. Original scripts and reference captures determine the mechanics and state changes.

## Connected route

1. Return through R103 and R117 to the upstairs corridor, R213.
2. Walk west and finish Kyle’s reminder about speaking to Jeff.
3. Approach Room 213 and select **Door**.
4. Select the door panel, then confirm it to knock.
5. Ask about Mila’s name.
6. Use the interrupt and select **She ASKED?**
7. Ask whether Mila knew about the hotel.
8. Finish Jeff’s response and departure.

| Checkpoint | Original identifier |
| --- | --- |
| Upstairs reminder | Event 62, map region 2 |
| Room 213 interior identifier | R203, map 29 |
| Corridor door connection | Door 30, search area 5 |
| Door view and knock | View 333, component event 334 |
| Knock response | Event 76 |
| Jeff’s return conversation | Event 87, person 6 |
| Initial question | Keyword 26, event 91 |
| Request interrupt | Event 92, choice 36 |
| Correct answer | Event 93, enables keyword 27 |
| Brochure question | Keyword 27, event 95 |
| Departure | Event 105 |

## Implementation boundary

Door inspection now uses the corridor’s original search table, close-up table and bitmaps. It no longer requires the destination interior to support exploration. Room entry retains its separate supported-map check. This permits the original corridor conversation while keeping unavailable interiors explicit.

The door close-up now closes when its script transitions to a person’s normal event. This follows the transition path at `0x0203E7C8`. The original departure capture returns to corridor walking. The native session must not retain a door view after the conversation.

The knock, questions, interrupt and departure use existing event handlers. The native session check starts at hotel arrival and uses ordinary input throughout. It does not inject inventory, puzzle outcomes or event completion flags.

Reference input files are under `tools/reference/jeff-room213-*.txt`. They continue the modified delivery fixture through the recorded Rosa route. They add no memory writes. A complete matching original playthrough from a new game remains outstanding.

## Original checkpoints

The component comparison checks all 32,088 game-state bytes at door inspection, the initial question menu, the interrupt choice, the brochure question and departure.

On 18 October 2026, 18 targeted checks passed, including the normal-input arrival-to-Jeff route, the full-state comparisons and the affected door and Rosa checks. The earlier normal-input Room 215 route also passed separately, giving 19 passing checks. Native captures of Room 213 and the return to corridor walking were visually checked under `/tmp/hotel-jeff213-final`.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SNAPSHOT_DIR=/tmp/hotel-jeff213-final \
swift test --filter 'OriginalJeffReturnRouteTests|OriginalDoorTests|OriginalRosaRouteTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter LayoutSnapshotTests.testRenderPlayableLobbyAndRingBellThroughSession
```

| Local save checkpoint | SHA-256 |
| --- | --- |
| `jeff-room213-inspect/door.mln` | `a2dcd55957602f20896a2276f7bcdf9faca9c68f2c0e492f98de2dada4c0ac40` |
| `jeff-room213-knock/page16.mln` | `599aa24d8db5eb2c5382be2c01ec1b3390240b896ba759b6e711e293f1a5a2f8` |
| `jeff-room213-request-confirmed/page1.mln` | `9a8c94c26fcb670f88edab5ab1e983d77550fe5c956a4de6fdb33f2368fd9564` |
| `jeff-room213-request-answer-correct/page16.mln` | `ea4860d521ef40e34b4a1445ff24b52cc9c2c83ebe06235f76e0fb4a750f0d56` |
| `jeff-room213-brochure-answer/page24.mln` | `6ed39ced5b34920847972cf643e14cc4fbee1f3d3be3069a9b7517459f827a85` |

`tools/reference/iris-entrance.txt` continues from the departure capture with ordinary corridor movement. Its `extracted/reference/iris-entrance/entrance.mln` checkpoint is ready for the next conversation comparison.

## Remaining work

- Continue towards Room 215 to meet Iris, then complete Summer’s visit and the order documents.
- Compare alternate answers, the missed interrupt and later repeat knocks.
- Connect the original portraits, character animation, fades and scene audio.
- Complete Chapter 1’s review and chapter transition.
- Verify physical Duo input and presentation.

The full game remains unfinished.
