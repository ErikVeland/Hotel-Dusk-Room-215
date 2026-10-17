# Chapter 2 Helen and the return to Room 215

The supplied detailed walkthrough identifies this route as `CHP210`–`CHP211`. After collecting the tools, leave the Linens Closet. The clock advances to 5:40 PM. Walk west to meet Helen, then knock on Room 212. Ask why she stays here, then ask about her memories. The conversation ends automatically. Return to Room 215.

## Original route

| Stage | Original identifier |
| --- | --- |
| Leave the Linens Closet | `EP2_R213` event 32, arrival from map 37 |
| Meet Helen | Collision region 3, events 33 and 34 |
| Knock on Room 212 | Destination map 28 (`R202`), view 329, component event 330 |
| Door response | Events 35 and 36 |
| Why stay here? | Keyword 9, event 38 |
| What kind of memories? | Keyword 10, event 39 |
| Return to Room 215 | Destination map 31 (`R205`) |

Resource names differ from the displayed room numbers. `R201` is Room 211. Helen's Room 212 uses `R202`.

## Map arrival correction

The original map controller loads before its arrival script runs (`0x02029B78`). The native session previously waited until that script finished. The 5:40 clock command clears the previous-map field, so the delayed map load lost its entry marker.

The session now constructs the destination map before running the arrival script. The entry marker sets Kyle's position and live heading. The checkpoint heading starts at zero, as observed in the original corridor arrival. The first walking update copies the live heading into it (`0x0202CE5C`). Explicit marker relocation still sets both headings (`0x0202C264`, request 9).

## Comparisons and limits

The targeted route compares all 32,088 saved-state bytes at the corridor transition, Helen's introduction, both question menus, her departure and Room 215 arrival. No pose bytes are excluded. The new-game route also reaches these scenes through ordinary native inputs.

On 18 October 2026, all 26 targeted route, door and movement checks passed without skips. The native Room 215 return screenshot was visually inspected. `git diff --check` also passed.

Reference inputs are in `tools/reference/chapter-two-linens-exit.txt`, `chapter-two-helen-*.txt`, `chapter-two-room215-return.txt` and `chapter-two-room215-enter.txt`. They continue the existing modified delivery fixture without new memory writes. `chapter-two-room211-door.txt` records an exploratory knock at the neighbouring door.

Original portraits, character animation, cinematic camera movement and audio timing remain incomplete. Alternate answers, physical Duo input and a complete unmodified original playthrough remain unverified.

The next route is `CHP212`: use the pliers on the hanger, obtain the thick wire and open the suitcase. Hanger inspection and the recovered cutting controller now have original comparisons. Rendering and session integration remain unfinished. See [Hanger recovery](chapter-two-hanger.md). The successful thick-wire variant remains unfinished. Chapter 1's thin-wire failure does not implement this success path.

```sh
SNAPSHOT_DIR=/tmp/hotel-chapter-two-helen-final DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalChapterTwoRouteTests|OriginalLobbyExplorationTests|OriginalDoorTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```
