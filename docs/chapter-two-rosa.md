# Rosa’s Chapter 2 corridor conversation

The native route now leaves Room 215, approaches Rosa and completes the guide’s recommended conversation. It returns to corridor walking after Rosa leaves. This extends the normal-input route from hotel arrival through the Chapter 2 transition.

The detailed walkthrough identifies this route as `CHP201`. The original `EP2_R213` script supplies the dialogue, options and state changes. No new dialogue or story flags were invented for this route.

## Connected route

1. Leave Room 215 and walk east along the corridor.
2. Continue Kyle’s observation, approach Rosa and select **Talk**.
3. Ask about Louie.
4. Use the three interrupts and select the stories, cannot-talk and relent answers.
5. Ask about Mila and select the bracelet answer.
6. Continue until Rosa leaves.

| Stage | Original identifier |
| --- | --- |
| Corridor observation | Event 0 |
| Rosa’s opening | Event 1, person 3 at marker 3903 |
| Louie question | Keyword 0, event 3 |
| Stories interrupt and answer | Event 4, option 1, response 6 |
| Cannot-talk interrupt and answer | Event 7, option 3, response 9 |
| Relent interrupt and answer | Event 10, option 4, response 11 |
| Mila question | Keyword 1, event 14 on this route |
| Bracelet answer | Option 7, response 16 |
| Departure | Event 22, shared event key 21 |

The more aggressive answer remains a separate branch. This route check does not establish its game-over behaviour.

## Recovered checkpoint heading

`0x0202CE5C` copies the current heading into map-controller field `0x14600` before it moves and turns Kyle. Map request 8 stores that retained heading. The native map previously used the heading after the turn.

Rosa’s corridor observation interrupts movement while Kyle is still turning. The comparison exposed a difference of 0.0425 radians in both the live saved state and retry buffer. `OriginalMapExploration.checkpointFacing` now retains the starting heading. An idle walking update refreshes it. The session uses it for map checkpoints and the chapter transition.

The original corridor checkpoint now matches all 32,088 bytes, including the retry buffer. The first question menu, all three interrupt choices, the bracelet choice and final departure also use complete state, without excluding pose fields.

## Validation and limits

`OriginalChapterTwoRouteTests` restores the captured Chapter 2 checkpoint, walks to Rosa and follows ordinary conversation inputs. `LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock` reaches the same departure from a new native game at the hotel entrance. It does not inject chapter flags or puzzle outcomes.

Twenty-one checks pass across the full native route, Chapter 2 saves, the chapter review, movement and the earlier Rosa route. The native departure screenshot was visually inspected. Additional original answer comparisons are recorded in the route test.

Reference inputs are in `tools/reference/chapter-two-rosa-*.txt`. They continue the existing modified delivery fixture without new memory writes. Files marked exploratory did not reach their intended checkpoint. A complete unmodified original playthrough, alternate answer orders, original portraits and animations, and physical Duo checks remain outstanding.

```sh
SNAPSHOT_DIR=/tmp/hotel-chapter-two-rosa DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalChapterTwoRouteTests|OriginalChapterSaveTests|OriginalChapterReviewTests|OriginalLobbyExplorationTests|OriginalRosaRouteTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

The route now continues into the [Linens Closet](chapter-two-linens.md) (`CHP202`–`CHP203`). The full game remains unfinished.
