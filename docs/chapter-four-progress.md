# Chapter 4 progress

The fresh-game normal-input checkpoint chain reaches Chapter 4 from the Chapter 3 finale, completes the Chapter 4 review, and continues through the Chapter 10 ending. Focused tests restore instant-save checkpoints between route sections. Selected original-device fidelity checks remain open.

## Checked story path

`OriginalChapterFourRouteTests` continues from the Chapter 3 save. Each test restores the checkpoint that the previous test wrote and uses only normal game input:

1. `testChapterFourReturnsFromRoofToRoom215`: Kyle walks from the roof to Room 215.
2. `testChapterFourRoom217AndTankCash`: Rachel's call, Louie's Room 217 key, the photo behind the painting, Bradley's lighter, Dunning's confrontation, Jeff, the wet floor, the toilet tank and Rachel's second call. Saves `chapter4-cash`.
3. `testChapterFourTheftReportAndNewspaper`: Jeff in the lobby, Rosa's novel, the theft report, Dunning's questions, Summer and the three newspaper articles. Saves `chapter4-lobby`.
4. `testChapterFourSummerPenAndNotebook`: Rosa's back-stairs clue, Dunning at the utility closet, the knock on Room 211, the fountain pen, the autograph and Summer's notebook. Saves `chapter4-summer`.
5. `testChapterFourConfrontationAndReview`: Kyle stores the cash, memo, red box and Room 217 key in his suitcase. He returns the pliers, crowbar and screwdriver to the Linens Closet toolbox. Dunning's search then finds nothing. Rosa gets her autograph. The confrontation uses the signature comparison (process 73), and the review accepts all five answers. The test continues through the title and writes the `chapter5-normal-entry` instant checkpoint.

Run the chain with `HOTEL_DUSK_ROUTE_CHECKPOINTS` set, in the order above, after the Chapter 3 continuation tests.

## Engine changes

- Opcode 34 (`0x0203C51C`) pushes a request with the record's kind and value. It then commits scene 1, mode 29 and block 0, with the value in session `+0x3A` (`0x02028240`, `0x020282EC`). Mode-29 events select on this value. Dunning's Room 217 scene and the R117 search use it.
- A departure script's clock request (kind 3) now changes the time before the destination map selects its arrival events. Before this change, the request was lost when the runner moved to the new map.
- Text control `%r` with four digits is decoded. It starts every game-over sequence in the original scripts (69 files). The game-over screen and retry restore are not recovered, so the runner now stops at such a page with an explicit message. It no longer continues as if the player had not failed.

## Route helpers

`OriginalChapterThreeRouteChecks` now includes route helpers that later chapters can use:

- `navigate` finds a path over cells that the original wall probes leave unchanged. It only selects walking targets; normal movement and collision still move Kyle.
- `exit` walks to a door marker and uses the door, or walks into a walk-through exit.
- `talk`, `search`, `closeupLayer`, `useItem`, `doorComponent`, `picture`, `openToiletTank` and `compareSignatures` drive the matching native input.
- `conversation` can show inventory items from the question menu.
- `printMap` prints walls, event regions, search regions and exits for route planning.

## Limits

- Game over and retry are not implemented. A wrong answer or a failed search stops play.
- Request kind 7 from opcode 34 is recorded but not drawn. Its original presentation effect is not recovered.
- The route uses one set of answers. Other branches are not checked.
- These are native playability checks. They are not byte-for-byte comparisons with a matching original run.
