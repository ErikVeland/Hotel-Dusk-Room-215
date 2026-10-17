# Iris and Summer’s delivery

The Chapter 1 route continues from Jeff at Room 213 towards Room 215. Iris introduces herself, asks about Kyle’s work and leaves after Louie joins them. Kyle can then return to his room, answer Summer’s knock, return the notebook and take his own parcel.

Both supplied walkthroughs identify this route. The detailed guide uses `CHP122` for Iris and `CHP123` for Summer. Original scripts and captures determine the exact state changes.

## Iris

| Checkpoint | Original identifier |
| --- | --- |
| Corridor entrance | R213 region 1, event 63 |
| Introduction | Person 9, event 64 |
| Question menu | Event 66, keyword 24 |
| Work question | Event 67, choices 34 and 35 |
| Salesman answer | Choice 34, event 68 |
| Louie arrival and departure | Event 74 on the checked route |
| Later question about Iris’s stay | Keyword 25 |

`OriginalIrisRouteTests` compares all 32,088 game-state bytes at the question menu, work choice and departure. These comparisons pass. The native session route also reaches the same departure with ordinary input.

The checked route previously kept Kyle’s police history private from Louie. The alternate departure event 75 reveals it and sets game flag 21. That branch changes the later room visit and still needs a separate comparison.

## Summer’s knock

R205 event 78 requires the completed Jeff brochure question, keyword 27, and Iris’s work question, keyword 24. Walking into map region 1 starts the knock. Its request 8 saves Kyle’s current pose and retry checkpoint.

The original captures preserve facing `6.2831854820251465` at this checkpoint. Map turning now keeps that exact full-turn value. The source at `0x0202CE5C` wraps values greater than a full turn. It does not wrap equality. The native pose `(317,12288,119)` and complete saved state now match the original after the knock.

## Summer’s conversation and parcel

| Checkpoint | Original identifier |
| --- | --- |
| Door departure intercepted | Event 79, then event 80 and introduction 88 |
| Privacy interrupt | Event 89, choice 52 |
| Apology interrupt | Event 92, choice 55 |
| Name and writing questions | Keywords 29 and 30 |
| Reading answer | Choice 57 |
| The Angel Whispers | Choice 58 |
| Notebook return | Events 109–110, inventory item 5 removed |
| Parcel handover and departure | Event 111, touch picture 6 |

The native route presses each recorded interrupt once. It takes the parcel with two presses at page coordinate `(30,100)`, which maps to DS touch coordinate `(155,30)`. The complete packed hit mask matches the original picture process. The parcel is placed on the bed through a script flag; it is not an inventory item.

`OriginalSummerRouteTests` compares all game-state bytes at both interrupt choices, both question menus, both book choices, the parcel picture and departure. These checkpoints use the same answers as the native route. Repeated interrupts and other answers still need separate comparisons.

## Evidence boundary

Reference input files are under `tools/reference/iris-*.txt` and `tools/reference/summer-*.txt`. Captures remain local under `extracted/reference`. They continue the modified delivery fixture through Rosa and Jeff and add no memory writes. A matching original playthrough from a new game remains outstanding.

The native session route starts at hotel arrival and uses ordinary player inputs. It does not inject items, puzzle results or event completion flags. Original character portraits, animation, fades and full scene audio remain unfinished.

## Local validation

The targeted run passed 26 checks with no failures. It includes both native session routes, the Iris and Summer state comparisons, Jeff and Rosa regressions, movement and touch-picture checks.

```sh
SNAPSHOT_DIR=/tmp/hotel-iris-summer-regression DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalSummerRouteTests|OriginalIrisRouteTests|OriginalJeffReturnRouteTests|OriginalRosaRouteTests|OriginalLobbyExplorationTests|OriginalTouchPictureTests|LayoutSnapshotTests.testRenderPlayableLobbyAndRingBellThroughSession|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

| Local original checkpoint | SHA-256 |
| --- | --- |
| `iris-introduction/page30.mln` | `f8c2801c9b7d2c0c4b4e866369878a97668ecd8c2b5901d516e5ccadba996b9b` |
| `iris-confirm-question/page14.mln` | `3a66f3d853ee862c587d28d763ed5137fff28ca679d08a88a4c057474bc87619` |
| `iris-salesman-departure/page55.mln` | `3ad81fb2176bb7619dfcc483df335313b52cb07b00a9ff6a9b45316acbe47d4b` |
| `summer-delivery-knock/page4.mln` | `ac4c78bd31ff58009808843c6c6d2e17aa25895381ce65cd443edb8115a0b1dd` |
| `summer-book-answer/page22.mln` | `e773870fa6dc7076623628140d5a24b177085199210657dd737c2373d79f8b30` |
| `summer-parcel-departure/page15.mln` | `3a55df3de98acccde026cd0000653801283baa2db248a6d956ad88aa026598a5` |

## Remaining work

- Continue from the completed [order documents](order-documents.md) to Rachel’s telephone call and Chapter 1 review.
- Compare alternate answers, repeated interrupts and the police-history branch.
- Check physical Duo input and presentation.

The full game remains unfinished.
