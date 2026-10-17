# Walkthrough route plan

The two locally supplied guides help identify routes, puzzle dependencies, optional actions and failure paths:

- `Source/Walkthrough/spoiler-free.txt`: strawhat, version 1.01, dated 1/6/08 as printed.
- `Source/Walkthrough/spoilers.txt`: neeker, FAQ/walkthrough version 1.1. Its section codes provide stable search anchors.

Both guides cover ten chapters. These files remain local source material. This document records implementation priorities in our own words.

## Evidence rules

Use the guides to choose player actions for original reference runs. Use the recovered scripts, native code and matching captures to establish implementation behaviour.

A guide description does not establish process IDs, state offsets, collision bounds, timing, randomisation or exact choice conditions. Record these separately.

The detailed guide's first-jigsaw description mentions three pieces. Our normal-play ROM capture has five loose pieces, matching the original default mask `0x668`. The capture and code determine the native model.

The Chapter 1 jigsaw and Chapter 3 jigsaw have different story requirements. The later puzzle includes a full assembly and a lid-close/reopen action. Do not expose the later action during the first puzzle.

## Immediate route

| Step | Guide anchors | Native state and next check |
| --- | --- | --- |
| Arrival, bell and registration | Spoiler-free `{3.1}`, detailed `CHP101` | Normal session input reaches registration and the package question. |
| Central Hallway and Melissa | `{3.1}`, `CHP105` | Normal play reaches and completes process 26. Initial pieces, placement, hints and quit results have original comparisons. |
| First jigsaw and its aftermath | `CHP105` | Completion and both quit branches are checked. The dropped piece now requires two taps before item acquisition. The route then enters R213. |
| Upstairs corridor and Jeff | `CHP106` | The guide route and missed-first-interrupt branch match the original state. Normal native input completes his conversation. |
| Room 215 door and telephone | `CHP107` | The door, key, room entry and Rachel’s call have normal-input checks and original state comparisons. Check the alternate route that receives Dunning’s second call. |
| Suitcase and paperclip | `{3.1}`, `CHP107` | Suitcase inspection, key insertion and the broken-key outcome now pass the normal route check. Brochure entry and paperclip acquisition also pass the normal route and original state checks. Paperclip straightening now passes the normal route, quit/re-entry and wire-award checks. Thin-wire insertion and all three pins now reach the original failure dialogue. The extended route now completes Dunning’s early questions and reaches the delivery knock. See [Thin-wire lock attempt](thin-wire-lock.md). See [Suitcase key](suitcase-key.md) and [Brochure and paperclip](paperclip.md). |
| Delivery and Louie | `CHP111`–`CHP112` | Event 28 requires completed keywords 0–2 and event flag 25. Both registration interrupts and the native route to the knock are now checked. Opcode 16 state effects now match an isolated original component run. The ordinary clock process now returns to the room. Native input now takes the parcel, identifies Louie and completes his first conversation. Bed inspection and notebook acquisition now pass the native route and original component comparisons. Next: a matching complete ROM route and alternate answers. See [Wrong parcel and notebook](wrong-parcel.md). See [Louie’s delivery](louie-delivery.md). |
| Melissa, Mila and Rosa | `CHP113`–`CHP114` | Melissa’s notebook picture, item return and departure now pass native route and original state checks. The notebook now displays her drawing and supports three writable pages. Mila’s shoulder picture, Rosa’s conversation and the ordinary 5:20 time change now pass the native route check. Jeff’s Room 213 conversation now passes the native route and original full-state checks. Iris and Summer’s parcel handover now also pass the native route check. See [Jeff at Room 213](jeff-room213.md). See [Mila and Rosa](mila-rosa.md). See [Original notebook](notebook.md). See [Melissa’s notebook and piece return](melissa-notebook.md). |
| Jeff, Iris, Summer and the order | `CHP121`–`CHP124` | Jeff’s door inspection, knock, interrupt, two questions and departure are connected and compared. Iris’s introduction and Summer’s visit now pass native input and complete original game-state comparisons. Kyle returns the notebook and takes his parcel. Bed inspection now collects the client list and order sheet, with complete original state and image comparisons. Rachel’s call now reaches the Chapter 1 review. See [Order documents](order-documents.md). See [Iris and Summer](iris-summer.md). |
| Chapter review | `CHP1QZ` | The five review questions, correct answers and wrong-answer retries now run natively. All original menu checkpoints match. The Chapter 2 reset, save decision, native checkpoint restore and room arrival now pass checks. Rosa’s Chapter 2 conversation (`CHP201`) now passes the native route check. The Linens Closet, Louie’s guide conversation, all three tools and the magazine (`CHP202`–`CHP203`) now run natively. Helen’s introduction, both Room 212 questions and the return to Room 215 (`CHP210`–`CHP211`) now pass the native route check and complete original state comparisons. Hanger inspection and cutting now run natively. Cut geometry, camera movement, pliers placement and story outcomes have original comparisons. See [Hanger recovery](chapter-two-hanger.md). The thick-wire puzzle (`CHP212`) now opens the suitcase through native input. The contents process (`CHP213`) now supports native cash collection and return to inspection. Client-list storage is connected through the existing item-use script. See [Suitcase contents](chapter-two-suitcase-contents.md). See [Thick-wire suitcase lock](chapter-two-thick-wire.md). See [Helen in Chapter 2](chapter-two-helen.md). See [Chapter 2 Linens Closet](chapter-two-linens.md). See [Rosa in Chapter 2](chapter-two-rosa.md). See [Chapter 2 transition and saves](chapter-two-transition.md). See [Chapter 1 review](chapter-one-review.md). |

The route now also completes `CHP214`: downstairs travel, the office-door knock, payment and apology choice 21. R115 entry and the `CHP215` guest-ledger, birthday-card, log and calendar searches are connected. The trapped memo now tears through native drag input and awards the torn paper. Memo drawing and inventory reopening are connected. Crowbar placement, lifting and joined-memo retrieval now run through native input. The cabinet number wheels, drawer opening, red-box acquisition and office exit are connected. The route now follows Louie’s Nile discussion and Rosa’s questions. The next target is the return to Room 215 for Ed’s call. See [Louie route evidence](chapter-two-louie-office.md). See [Cabinet combination](chapter-two-cabinet-combination.md). See [Crowbar recovery](chapter-two-crowbar-recovery.md). See [Memo drawing](chapter-two-memo-drawing.md). See [Trapped memo](chapter-two-memo-pull.md). See [Office search](chapter-two-office.md). See [Chapter 2 payment](chapter-two-payment.md).

## Later chapter checkpoints

These are planning targets from the guide contents. They are not implemented-route claims or complete branch coverage.

| Chapter | Principal route and interaction targets | Detailed guide anchors |
| --- | --- | --- |
| 2 | Toolbox, suitcase opening, payment, office access and memo puzzles | `CHP203`, `CHP212`–`CHP218`, `CHP2QZ` |
| 3 | Bookmark, piano, fountain pen, full jigsaw, lid action and locked-room escape | `CHP304`–`CHP306`, `CHP312`–`CHP325`, `CHP3QZ` |
| 4 | Room 217, theft investigation, newspapers, autograph and pen evidence | `CHP401`–`CHP425`, `CHP4QZ` |
| 5 | Painting inquiry, rag doll, distraction and Room 213 search | `CHP500`–`CHP524`, `CHP5QZ` |
| 6 | Vending prize, coins, matchsticks, bottles and wine label | `CHP602`–`CHP605`, `CHP613`–`CHP623`, `CHP6QZ` |
| 7 | Christmas tree box, decoration, Dunning's room and Kevin's account | `CHP711`–`CHP723`, `CHP7QZ` |
| 8 | Cassette, bowling, rooftop meeting, brochure and Rosa's room | `CHP801`–`CHP823`, `CHP8QZ` |
| 9 | Apple paintings, Room 111, CPR, birthday cards and secret door | `CHP901`–`CHP923`, `CHP9QZ` |
| 10 | Cellar, timed escape, wall and painting interactions, final conversations and endings | `CHP001`–`CHP022` |

## Checkpoint procedure

1. Read the relevant guide section and original event records.
2. Reach the interaction with ordinary inputs in the ROM reference runner.
3. Save the input sequence, checkpoint, relevant state and both screens.
4. Recover the required state machine and its native dependency boundaries.
5. Add targeted checks for entry, completion, cancellation and relevant failure paths.
6. Run the same route through the native session input methods.
7. Record presentation differences and unresolved dependencies before extending the route.

Use the spoiler-free guide's ending variations and the detailed guide's failure warnings to expand branch coverage after each main route works. Neither guide replaces original execution evidence.

The checked Room 215 route already has game flag 9 from the earlier Dunning conversation. The original therefore skips his payment reminder call. The guide sequence is conditional.
