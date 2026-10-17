# Chapter 2 Linens Closet

The detailed walkthrough identifies the room and toolbox route as `CHP202`–`CHP203`. The native route follows the original `EP2_R213`, `EP2_R211` and shared `System` scripts.

## Room and conversation

After Rosa leaves, walk east until the whistle event starts. Continue east to the Staff Only door at the corridor end. Read Kyle’s observation, then select the doorknob. Continue Louie’s arrival scene and approach him to talk.

The route uses map 37, resource name `R211`. The original collision member, room models, four search areas, floor plan and textures supply the room. Its map origin is `(0, 5)`, with 14 pixels per world unit. The source tables are at `0x020E02AC` and `0x020DFF60`.

| Stage | Original identifier |
| --- | --- |
| Corridor whistle | `EP2_R213` event 27, collision region 2 |
| Staff Only door | Door 27, search area 13, view 365, knob event 367 |
| Room arrival | `EP2_R211` event 0 |
| Louie’s opening | Person 4, event 2, answer 8 |
| Cleaning interrupt | Event 5, answer 10 |
| Stories and incident | Keywords 3, 4, 5, 6 and 7 |
| Bankruptcy interrupt | Event 20, answer 15 |
| Mila | Keyword 8, interrupt 24, answer 17 |
| Lost property and departure | Keyword 2, interrupt 32, answer 18 |

The normal native route reaches the room, completes Louie’s conversation and collects the three tools and magazine from a new game. A targeted route also restores the Chapter 2 checkpoint and completes Louie’s guide conversation. Original state comparisons cover the whistle, room arrival, all recorded choices, incident question menus and final departure. Each comparison checks all 32,088 game-state bytes.

## Rendering correction

The original draw function at `0x0208B6F0` omits nodes whose names start with `obj999`, unless its debug display is enabled. R211 contains two such helpers. Drawing them obscured the room with a black mesh.

Map rendering now applies this rule. The original model and hit geometry remain intact. The hit pass at `0x0208BAAC` retains these helpers.

## Nested close-ups

The locker opens view 295. Its toolbox component runs event 296, then opens child view 305. The layer field previously named `processID` contains the child view ID here. `0x02059E7C`, `0x02062038` and `0x02062F08` establish this sequence.

The session waits for the component response before opening the child. Request 6 cancels pending child entry, as in `0x02064530`. Back returns to the parent view. It retains the search area and subarea. Collected tool layers stay hidden after returning and reopening the toolbox. Detail-image layers remain unsupported.

The original shared responses award pliers (15), crowbar (10) and screwdriver (65). The opposite shelves use search area 3, subarea 4 and view 313. Collecting the magazine awards item 11 and hides object flag 5.

## Evidence and remaining work

Reference inputs are in `tools/reference/chapter-two-linens-*.txt` and `chapter-two-louie-*.txt`. These continue the existing modified delivery fixture without new memory writes. They do not establish a complete unmodified original playthrough.

Thirty-seven targeted checks pass. These include the full route from hotel arrival, complete original state comparisons, model visibility, doors and existing close-ups. Eight Linens Closet captures also match the original composed pixels and packed hit maps. The corrected room and final native route screenshots were visually inspected.

```sh
SNAPSHOT_DIR=/tmp/hotel-chapter-two-linens-final DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalChapterTwoRouteTests|OriginalSearchCloseupTests|OriginalModelTests|OriginalDoorTests|OriginalLobbyExplorationTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

Original portraits, camera cuts, character animation and audio timing remain incomplete. Detail-image close-ups, alternate conversation paths and physical Duo checks remain open. The route now returns to the corridor, completes Helen’s Room 212 conversation and returns to Room 215. See [Helen in Chapter 2](chapter-two-helen.md). The hanger and pliers mechanics remain unfinished. Later Chapter 2 routes and chapters remain unfinished.
