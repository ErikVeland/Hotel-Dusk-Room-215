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

The route now also completes `CHP214`: downstairs travel, the office-door knock, payment and apology choice 21. R115 entry and the `CHP215` guest-ledger, birthday-card, log and calendar searches are connected. The trapped memo now tears through native drag input and awards the torn paper. Chapter 2 process 34 opens the point-tie drawing overlay; the route covers drawing input, pause, Clear, Back and inventory reopening. Chapter 9 process 64 starts the apple-painting overlay; its full story route remains unverified. Crowbar placement, lifting and joined-memo retrieval now run through native input. The cabinet number wheels, drawer opening, red-box acquisition and office exit are connected. The route now follows Louie’s Nile discussion and Rosa’s questions. Ed's call, Louie's room confrontation, the photo and all Chapter 2 review answers now run through native input. The route continues into Chapter 3 through Rachel's call and the first restaurant conversations. See [Chapter 3 progress](chapter-three-progress.md). See [Louie route evidence](chapter-two-louie-office.md). See [Cabinet combination](chapter-two-cabinet-combination.md). See [Crowbar recovery](chapter-two-crowbar-recovery.md). See [Memo drawing](chapter-two-memo-drawing.md). See [Trapped memo](chapter-two-memo-pull.md). See [Office search](chapter-two-office.md). See [Chapter 2 payment](chapter-two-payment.md).

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

## Route dependency map, 26 October 2026

All chapter-script room IDs below have entries in `OriginalMapCatalog` and a
bundled `.col` collision file. This confirms map and collision data only. Search
scenes, object visibility, textures and route transitions still need checks
through normal play.

| Chapter | Script rooms | Story processes | Readiness |
| --- | --- | --- | --- |
| 5 | R102, R111, R113, R117–R119, R203–R205, R207, R212–R213 | 38, 60: handlers present | Three normal-input route tests cover Mila and the doll, evidence against Jeff, and the confession and review. Run them from the Chapter 4 save. |
| 6 | R104–R106, R126, R202, R205, R213 | 46, 51, 53, 54, 58: handlers present | A normal-input continuation from the Chapter 5 save reaches the Chapter 6 bar and answers the room-phone event. After Rosa's 9:20 topics, Dunning's history conversation and Rosa's favour, it advances to 10:00 PM. Process 53 is solved through normal input. The coin puzzle (process 51) now completes through touch input and follows its source result-0 event; its positions also match independent original captures. R106 object `obj06` identifies the red wine and `obj09` the white wine. R104 area 4 object `obj05` identifies the rosé. Room 215 area 2 object `obj03` opens Ed's package; close-up event 257 awards item 50, the adhesive remover. Knocking on Room 216 and Room 211 returns Iris's rosé and Summer's white-wine answers. Using the remover on the red wine starts process 46 through normal input. The native session completes both modeled process-46 stages, follows the source story return, and awards label item 66. Isolated ROM probes confirm the solvent threshold and that the peel handler tracks a downward drag, but they have not reproduced a successful peel return. The route then reaches R202 through R126, R117 and R213, completes Helen's story, collects Summer's pen, answers the five memory questions, and reaches map 31 at Chapter 7's time-zero state. The route now creates its own `chapter6-helen-room` checkpoint. The native peel threshold, touch path and timing still lack an original-run comparison. The bar jukebox starts process 58. Vending, ROM-matched label removal and audio playback remain unverified; route tests mute audio. |
| 7 | R102, R103, R105, R112, R117–R119, R122, R126, R205–R206, R213 | 43: native handler; 55: partial | Normal inputs from the Chapter 6 Helen handoff complete the storage/tree route, return to the lobby, and reach Dunning's room. At 10:40 PM the route asks Kevin about his drinking, follows Louie's questions about the duo and Gallery May, then leaves the bar for Iris's Room 216. It completes Iris's suitcase, envelope, Grace and Gallery May topics, Kevin's lobby conversation, and all five Chapter 7 review answers. The route reaches the normal Chapter 8 title and saves `chapter8-normal-entry`; event flag 3:9 is clear afterward. Chapter start resets both event-completion banks, so Chapter 7 flags do not carry into Chapter 8. The Chapter 8 R213 script records do not establish the source of the later flag state. The box target at origin and the tree's target-to-page fit remain inferred. Neither has original-run comparison. The Chapter 6 route now obtains wine-label item 66 through process 46 and generates the Helen handoff from normal input. Route tests use muted audio. Playback remains unverified. |
| 8 | R102, R105, R113–R114, R118–R119, R124, R205–R206, R212–R213, R401 | 44: partial native bowling handler; 45 and 76: partial cassette-rewind handlers; 52: Cassette02 deck handler | A normal-input continuation answers the 11:00 PM phone call, leaves Room 215, and reaches R213. It saves `chapter8-r213-entry`. The `in_r212` marker leads to the utility closet. From search area 4, the direct object hit mask selects `obj04`, which opens close-up 315. Normal clicks on components 316 and 319 recover inventory items 69 and 42; the route saves `chapter8-r212-items-recovered`. It returns through R213 to Room 215, then travels through R117, R105 and the bar map. Louie's “Someone else wanted it?” response resolves through normal input and sets game flag 29. The route returns through R126, R117 and R213 to Room 215, where flag 29 remains set. In search area 3, the real hit mask selects `obj04` on the open suitcase and awards pencil item 44. The route then returns through R119 to R114. Search area 3's `obj06` hit mask opens desk view 110; tapping component 112 runs `System.blk` event 651 and awards ballpoint item 74. Search area 1's `obj06` radio case opens view 107 with radio and tape components 108 and 109. Normal use of tape item 42 on component 108 consumes it and exposes the tape layer. Ballpoint item 74 selects process 76; its slot-5 exit follows the failed-attempt response. Pencil item 44 selects process 45; the successful input returns value 0 and adds repaired tape item 43. It then uses repaired tape item 43 on component 108, launches process 52, opens the deck with a held touch and swipe, selects Side B, and returns through the story CHK table. The route reaches R119 through the normal exit at time block 1. It then enters Room 216, presents items 69 and 43, and completes Iris's six Chapter 8 topics. This changes the time block to 2. The route returns to R119, knocks on Louie's door, enters R114 and talks to Louie. R114 event 22 sets event flag 14:22. The route then follows Louie back to R119 and starts bowling process 44 through event 8. A renderer seam lets this route reach the process without a Metal device. The route test now plays three modeled five-throw matches. Each reaches native result 2 and event 11, then starts process 44 again through event 8. A separate branch check injects return value 0 and follows the plant dialogue, normal picture input, travel from R119 through R117 and R213 to R401, and the rooftop meeting. After the empty topic menu is closed, the test saves `chapter8-after-rooftop-meeting` and returns to R213. This is post-process branch coverage only: process 44's original return value is still unknown, and the Chapter 8 clock remains at time block 2 after the rooftop scene. Rosa's room and the Chapter 8 review remain open. Route tests mute audio. Process 52 does not play cassette audio, so cassette sound remains unverified. The source capture scores `[6, 6, 6, 5, 5]`; normal route input still needs a matching bowling comparison. Searching `in_r210` was a wrong route (map 36 is Room 220). |
| 9 | R103, R105, R107, R112–R114, R116–R118, R123, R125, R205, R207, R213 | 63: CPR; 64: apple painting; 81: apple word entry | Factory cases map process 63 to overlay 37, process 64 to overlay 38, and process 81 to overlay 38. Isolated session tests now complete CPR through close-and-reopen input. A process-chain check visits all five recovered painting call sites, preserves the letter mask, and enters JENNY. It uses the accepted painting returns (2, except 1 at `EP9_R125:104`) and word-entry result 0. The normal walking/story route across these paintings and later Chapter 9 scenes remain unverified. |
| 10 | R102–R103, R108, R117–R118, R205, R210, R213, R301–R302, R304–R305, R401 | 59: pencil sharpener; 61: picture peel; 62 and 67: code notice; 74, 86, 90 and 91: typewriter; 75: incomplete brick-wall puzzle; 79: overlay 40 mode 1 search shed; 80: cashbox; 85: AfterConfess sequence; 88: VSScene sequence | The corrected audit passes the host process ID directly to the factory, then maps its loader slot through the original slot table. It places the typewriter at process 74, the overlay 40 variants at 75 and 79, the code notice at 62 and 67, and the cashbox at 80. Process 59 now completes its 60-frame exit animation through session input and selects the event from the source result-2 return table. Process 61 erases past the source threshold through session touch input; leaving with result 2 opens the source return dialogue at offset 4500. The source table maps returns 0, 1 and 2 to events 9, 10 and 11; the session currently verifies only the result-2 path. The focused test mutes audio and does not verify sound. Process 85 now plays three original image groups and returns result 2. Its frame timing and layer placement still need comparison with the original run. Process 75 now returns source result 0 when its doorway gate clears, and result 2 when the player leaves. Its screen-wide hit map disagrees with the ROM scan. The normal story entry, source result 1 trigger, and visuals remain unverified. Process 88 follows the normal touch path and returns 0, as the overlay handler specifies. The isolated native session follows its source transition, plays the next story dialogue, and returns to exploration. Process 79 now has a CPU-only session check through the found-box return path. A separate Metal test renders its source transforms and checks object-shaped mesh hits, including the target box. Its normal Chapter 10 placement and hit results remain unverified against original execution. Chapter 10 is not complete. |

The Chapter 9 mapping is now aligned with the recovered factory: process 63 is CPR, while 64 and 81 share the apple alphabet overlay for painting search and word entry. Isolated session tests verify that CPR returns to its source script. A process-chain test covers all five painting call sites, their saved letter bits, and the ordered word entry; it does not verify the normal walking route or later Chapter 9 scenes.

Chapter 7 process 43 maps to overlay 13 and loads `ChristmasTree.tbl` and
`ChristmasTree.wpf`. The 17 tree, ornament and hook textures decode through the
existing DTX reader: `tree` is 512×160, `tree_s` is 256×192, each of the 11
ornaments is 64×64, and each of the four hooks is 16×16. The process has
multiple drag and placement stages. Overlay state 2 (`021fd770`) prepares ten
draggable objects and reduces its remaining count when a source drop handler
returns 2. State 3 (`021fe320`) handles a separate draggable object. State 5
(`02200eac`) initialises eleven indexed positions, checks object placement,
and advances after all eleven placements. `02201830` supplies an order for
those positions, and `02200bd0` marks an object once it is within the recovered
distance threshold. `OriginalChristmasTreeLayout` now stores the eleven source
target points at `0x02201c40`, applies the target transform from overlay
initialisation at `0x021FCC5C`, and uses the squared-distance threshold from
`0x02200BD0`. It also decodes the saved ordering field at game-state offset
`0x13DA` (`0x0211148C + 0xDA`) using the swap bits and packed indices from
`02201830`. Focused tests cover the points,
threshold, saved-order encode/decode and touch transform. The session supplies
the saved value when process 43 starts. `OriginalChristmasTreeArrangement` now
records a decoration only when its model position is inside a recovered target
and encodes a completed order using the source format. The Chapter 7 process
model owns this arrangement and gates drops to its active scene phase. The
native view draws the `tree_s` background, the ten colour ornaments and placed
objects. Drag input selects visible ornament pixels from each sprite's alpha
mask. The star appears at the tray only after the ten ornaments are placed.
The target-to-page coordinates are a proportional fit to the
192×256 scene; they are not confirmed against the original camera projection.
Filling all eleven targets starts the source 60-frame completion fade and
returns 0. The session writes the completed order to the recovered save field
after that successful arrangement. Leaving through the menu returns 2 and does
not write an order. The normal route test completes the placements through
sprite masks, then follows the script success branch. The target-to-page fit
and item-to-colour mapping still lack original-run comparison.

The Chapter 5 route tests already exist in `OriginalChapterFiveRouteTests`,
although the earlier status notes do not record them. Run the three tests after
the Chapter 1–4 route chain creates its save. Use any route failure to update
this map with the specific missing dependency.

The original factory maps process 46 to overlay 22, which loads
`trick/LabelPeel` assets. The overlay binds a 0x5000-byte dynamic mask. It paints
a circular brush with a 10-pixel radius at three points per held update, then
accepts the peel at 99.5% clear. The native model now matches the brush radius
and sample count. Tests cover those rules and the threshold. Event 7 in
`EP6_R106` has four return branches to events 10, 8, 9 and 11. The native model
returns result 2 after the mask fade, displays event 9, and re-enters process 46.
The peel-stage model accepts a decreasing page-X drag until an authored distance
threshold, then returns result 0; this is not source-backed. The ROM trace in
[`source-transition.json`](../Tests/Fixtures/LabelPeel/source-transition.json)
starts from an injected follow-up state. Re-grabs move source progress from 1,475
to 792. A long diagonal pull enters substate 3 at frame 70 and phase 5 at frame
120. The trace does not capture a story return or prove the four branches in a
normal route. An isolated ROM process injection cleared the complete mask
and reached phase 2, substate 1. That state remained active after 120 frames
without input, which confirms that the next touch interaction is required. A
tap and short drag probe did not establish a successful exit. A walkthrough
specifies clicking the lifted label corner, then dragging downwards to remove
it ([Chapter 6 label walkthrough](https://www.justadventure.com/walkthrough/hotel-dusk-room-215-walkthrough/4/)). A fresh injected run confirmed the active process at
`0x02310020`, state 2, substate 1, with all 20,480 mask bytes clear. Touches in
a broad lower-right area selected hit object 0, but tap and downward-drag
probes from that area did not trigger the peel animation. This does not
establish the exact lifted-corner hit point or its raw-touch mapping. The
guide specifies a slow drag from the lifted upper-right corner diagonally
towards the lower-left, peeling about half the label
([label removal walkthrough](https://www.neoseeker.com/hotel-dusk-room-215/faqs/144909-hotel-dusk-b.html)). Isolated probes of that diagonal, including starts at both the
visible lower-right fold and the label's upper-right edge, still left the
process in phase 2, substate 1. A fresh 10-pixel touch grid around the fold
found eight valid selection points, including `(180, 150)` selecting object
0. A subsequent one-pixel grid found valid hits at raw X 161–199 on odd
coordinates and Y 132–171; all 800 selections targeted object 0. The original
handler kept selection active while the stylus moved down within that region,
and a five-pixel raw-Y drag changed its progress from 1,475 to 1,304. Selection
then cleared at the edge of the region; repeated short pulls stopped at 622
without changing phase. Moving diagonally out of the region also clears
selection. These probes use an injected process and cleared
mask; they do not prove a normal Chapter 6 route. A tap on the bottom-left
control moved the injected process to phase 4 briefly, then it returned to
phase 2, substate 1 after 360 frames. A longer central drag also left it in
phase 2, substate 1. The four event return paths remain unverified.

The process 46 runner uses raw DS coordinates (256×192), while the label view
uses 192×256 page coordinates. The source conversion is `pageX = rawY` and
`pageY = 255 − rawX`. Earlier touch grids used page bounds as raw coordinates
and did not clear the mask. A corrected two-pixel sweep cleared all 20,480 mask
pixels. On release it enters state 5 with return target 2, stays there through
the 60-frame animation, then returns to state 2, substate 1. This confirms the
follow-up interaction is a live process phase, not the label-clear result. Five
exploratory diagonal drags from raw `(180, 150)` to `(162, 132)` move the source
world-position field from 1,475 to 108 but do not change the phase. Five-stroke
axis probes show that raw-Y-decreasing strokes move the position to 620; raw-X
movement and raw-Y increase leave it at 1,475. None returns a process result.
The decompiled handler sets its follow-up flag at process start only when the
story-state word at `+0xdc` is nonzero. The isolated walking checkpoint starts
with that flag clear. The handler uses world-position threshold 737 for its
drag boundary, but these probes do not establish the story-state value or a
successful gesture for the normal Chapter 6 route. The process controller
checks animation event 5 during phase 2. When that event fires, it stores the
current drag position plus `0x1000` in the story-state word and starts the
fade. The isolated captures have not reached that event. The capture now
records the follow-up flag and both handler timers alongside the phase and drag
position.
The walkthrough describes this phase as peeling from the lifted top-right
corner towards the lower-left, with slow movement and re-grabs near the lifted
edge. A probe from raw `(195, 160)` selected object 0. Moving diagonally one
pixel per frame changed the world position from 1,475 to 1,304 by pixel two,
then cleared selection at pixel six. It did not reach animation event 5. The
capture fixture records this probe. After the partial pull and a 15-frame
release, a four-pixel scan across the full touch screen found no selectable
point. The run injected process 46 from a generic Room 215 checkpoint, which
lacks the Chapter 6 kitchen scene context. Do not use this scan to infer the
normal peel hit area or failure behaviour. The scan evidence is in
[`regrab-after-pull.json`](../Tests/Fixtures/LabelPeel/regrab-after-pull.json).
A successful peel and the label item return remain unverified.
The reproducible isolated capture is in
[`process-46-followup.json`](../Tests/Fixtures/LabelPeel/process-46-followup.json),
using [`capture_label_peel_component.py`](../tools/capture_label_peel_component.py).
The accepted action in this second phase remains unknown; a source result is
needed before wiring the route return.

The normal Chapter 6 route now reaches process 46 after collecting adhesive
remover from Ed's package, asking Iris about rosé, asking Summer about white
wine, and applying the remover to the red bottle. The test saves a checkpoint
before the bottle interaction. It mutes audio, so it provides no playback
evidence. The native process model does not yet receive the story-state word
that the original overlay reads at `+0xdc`; the normal-route test therefore
confirms the process entry only. The isolated injection used a generic Room
215 state with that word clear, so its follow-up gesture results cannot be
applied to this route. Next, capture or model the word from the normal process
entry, then validate the second drag and its event return before adding a
label item or continuing to Helen.

Several later processes share an original overlay. Keep one implementation
per overlay and check each chapter event that calls it:

| Processes | Chapters | Original interaction | Overlay |
| --- | --- | --- | --- |
| 45, 76 | 8 | Cassette rewind | 25 |
| 52 | 8 | Cassette playback deck | 28 |
| 64, 81 | 9 | Apple-word puzzle | 38 |
| 74, 86, 90, 91 | 10 | Typewriter | 41 |
| 75 | 10 | Lounge television | 27 |
| 79 | 10 | Search shed | 30 |

Chapter 8's `EP8_R114` event 9 invokes process 76 (source offset 372), and
event 13 invokes process 45 (offset 452). The event encoding stores the
process selector as byte 16 plus 23. Normal item use confirms the mapping:
ballpoint item 74 selects process 76, whose slot-5 return chooses the failed
attempt response; pencil item 44 selects process 45, whose successful return
value 0 chooses event 14 and awards repaired cassette item 43. The runtime now
renders process 76 with the ballpoint and process 45 with the pencil. Its route
test performs both inputs and checks item 43 in inventory. The test injects a
bitmap renderer because this environment has no Metal device, so it verifies
script transitions and process input, not cassette graphics or audio.

The `CHP802` walkthrough describes the ballpoint as too round, then uses the
pencil to rewind the tape before returning it to the deck. A separate source
capture associates a successful rewind gesture with process 76, which conflicts
with the normal script selectors above. That capture came from a modified
checkpoint and does not identify the selected inventory item. Keep its visual
and input observations separate from the verified normal-route mapping until a
matching source run resolves the mismatch.

A fresh modified-checkpoint capture of process 76 reaches overlay 25, variant 1,
interaction state 2 after its entrance animation. Its image shows the cassette
deck. The capture does not record the selected item, so it does not establish
whether that run matched the normal ballpoint or pencil branch. It remains
scene-initialisation evidence only.

Overlay 25's state-2 tap gate reads four bounds at `0x021FFF34` through
`FUN_0200985C`. The source values are `[108, 100, 120, 192]`; the helper checks
transformed X against 108–120 and transformed Y against 100–192.

A new isolated Process 45 tap sweep sampled raw X 135, 141 and 147 at raw Y 100
and 130. All six taps enter input phase 3, remain there while held, then return
to phase 2 on release. The drag-progress value stays 100 and the source counter
stays zero. This confirms the gate response at those sample points only; it
does not establish a visible-object mask or the normal `R114` item-use route.
The RAM snapshots and command hashes are in
[`process-45-gate-tap-sweep.json`](../Tests/Fixtures/Cassette/process-45-gate-tap-sweep.json).

The captured orientation flag at `0x021046B8` is zero. In that mode,
`FUN_02009920` returns raw Y and `FUN_02009960` returns `255 − raw X`. The
source gate therefore checks X 108–120 and Y 100–192. Raw touch `(141, 130)`
maps to `(114, 130)` and enters the gate; the earlier probe at `(114, 130)` maps
to `(141, 130)` and misses it. `tools/capture_cassette_component.py` records
process fields and touch deltas. Process 45 stays at input phase 3 during a
downward raw-Y swipe, and field `+0x4E4` stays at zero. Process 76 (variant
1) reaches its source success branch with a different path: tap `(141, 130)`,
move to raw X 135 (source X 120), then decrease raw Y from 130 to 100 one
pixel per frame. After 65 held frames, input phase 100 has a `+0x4E4` counter
value above five. The source increments this counter during qualifying touch
frames, so it is not a verified stroke count. After 245 held frames, input
phase 12. This matches the source `+0x4E4 > 5` branch. The guide describes a
downward stroke, so the
direction mapping still needs a display check. An A press and a touch release
do not leave phase 12 in this isolated run. Source phase 12 checks
`FUN_02081550(0x0210BC08, 0)`. This checks the screen-0 animation-manager job,
not touch or button input. The trace now records its active flag, timer and
mode. At phase 12 the job has mode 2 and a 28-frame timer; after 20 more frames
the job is idle, the cassette input phase resets, and the process main phase
advances. At 30 more frames, the process fields have reset. This verifies the
isolated completion path only; it does not establish the normal parent or
`R114` state.

The same source run now saves the bottom-screen image before input, after the
rewind drag and during its completion fade. It shows that the tool follows the
gesture and that the scene changes during the interaction. These source frames
are reference images for the renderer, not a replacement for its dynamic
scene. The source geometry dump contains 744 polygons; the tape, pencil and
ballpoint meshes contain 762 triangles combined. The dump is saved in
[`process-76-ready-geometry.txt`](../Tests/Fixtures/Cassette/ReferenceFrames/process-76-ready-geometry.txt).
Their counts are close, so
the dump does not indicate that most model geometry is missing. It does not
prove that the native transforms or composition match. The table surface still
appears in the wrong part of the native preview. Reproduce the captures with
[`component-cassette-rewind-visual.txt`](../tools/reference/component-cassette-rewind-visual.txt);
image hashes and checkpoint identity are in
[`process-76-source-visual-trace.json`](../Tests/Fixtures/Cassette/process-76-source-visual-trace.json).

The overlay sound calls need separate interpretation from the runner's event
labels. During the interaction, the source calls the sound manager with IDs 27
or 28, then stops ID 30. The bundled sound inventory resolves 27 to
`SE_EVENT_SCENE_PUZZLE_CHIRAKASU` and 28 to `SE_NAZOTOKI_CLIP_NOBASHI`; this
does not establish which call the modified-checkpoint capture reached. The
captured PCM has no confirmed cassette cue. Its sound-manager fields report no
active BGM and retain last-BGM value 17; those fields do not verify sound
effects. Treat the PCM as runner output, not as a cassette audio check. The RAM
snapshots and hashes are in
[`held-touch-trace.json`](../Tests/Fixtures/Cassette/held-touch-trace.json).
Reproduce the input with
[`component-cassette-rewind.txt`](../tools/reference/component-cassette-rewind.txt)
and [`component-cassette-45-repeated-matched-strokes.txt`](../tools/reference/component-cassette-45-repeated-matched-strokes.txt).
The deck probe remains in
[`component-cassette-deck.txt`](../tools/reference/component-cassette-deck.txt).
`OriginalCassetteTouchRegion` records the invisible source tap region and draws
no touch overlay. Overlay 25 checks this gate with explicit rectangular
bounds; no separate source mask check appears in the recovered handler. The
cassette, pencil and ballpoint MDFs have render geometry but no recovered hit
geometry. `OriginalModelProjectedMask` now projects those render triangles into
screen-space masks. The cassette preview can make tape and tool masks from the
same camera and transforms as its rendered meshes. Callers can add edge padding
without drawing overlays. Tests cover all three model silhouettes. The masks
are not connected to gameplay, and the preview still does not match the source
scene. A matched raw-Y-decreasing
gesture on process 45 reaches input phase 5 and changes field `+0x4E4` from 0
to 1, but remains in phase 5 after release and a 40-frame wait. Repeating that
path six times leaves the process in phase 5 and the field reaches 380. The
field is not established as a completed-stroke count or success condition.
The capture is in
[`process-45-matched-path.json`](../Tests/Fixtures/Cassette/process-45-matched-path.json);
it does not identify the normal item-selection condition. A separate quit
probe confirms the overlay's slot-5 return path: without input, variant 0 stays
at main phase 1 and input phase 5; a tap at raw `(15, 170)` sets the main
return gate, and the process fields reset after the 60-frame exit fade. This
is modified-checkpoint evidence only. The session uses this slot 5 target and a
60-update fade before it returns. See
[`process-45-quit-path.json`](../Tests/Fixtures/Cassette/process-45-quit-path.json).

Overlay 25 loads `bg.bin` and `table.bin` as textures, then loads `pencil.mdf`,
`ballpen.mdf` and `tape.mdf` with their matching source textures. The bundled
model report decodes the pencil and ballpoint as cylinder meshes and the tape
as a cube mesh with side-A and side-B materials. The source draws `table.bin`
as a four-vertex textured quad in `021FF614`, with dimensions from the texture
record and a transform at `021FFC50`. The current preview uses that transform,
including Z −90°, X 4° and Y −50° rotations and translation
`(−4, 0.5, −26)`,
but its tabletop still covers the wrong part of the frame. The source camera
uses a 20-degree field of view, 4:3 aspect, eye `(0, 0, 4)`, up `(0, −1, 0)`,
target `(0, 0, 0)`, near plane `0.1` and far plane `60`. The renderer now uses
these values. Texture coordinates or matrix conventions may still differ.
The session displays this renderer during processes 45 and 76. Its table
placement still does not match the source capture, so neither process is
visually verified for normal play. The quit path has no confirmed cassette
sound cue. Do not treat the visible scene or its audio as source-matched
evidence.

`EP8_R114` event 15 embeds process 52, and its CHK table maps returns 0–3 to events 16–18. The factory audit maps process 52 to case `0x34`, overlay slot 27, and Cassette02 resource group 28. The session now starts the cassette deck for this process and preserves process 44 as bowling. The normal route test reaches process 52, uses its scene and controls, and returns through the CHK table with result 2. Its injected bitmap renderer and muted audio mean that it does not verify graphics or sound. Native process initialisation passes `0x34` for Side A and `0x59` for Side B to the audio context. Those values are outside the recovered BGM sequence range (0–35), so they must not be sent through the current music player as sequence IDs. Cassette audio playback and the source fidelity of the deck sequence remain open.

Chapter 7's `EP7_R122` calls process 55 at event 3, then process 43 at event 7.
The supplied guide places the tree-box search before tree decoration. The
factory maps process 55 to overlay 3 and the `bag.tbl` and `bag.wpf` assets.
Overlay 3 creates 20 3D objects and supports touch selection and dragging on a
horizontal plane (`021fd110`, `021fd794`). On release, it sets its found state
when a type-3 object matches controller coordinates at `+0x88c` and `+0x894`
(`021ff2e0`). The recovered initialisation function does not set those target
coordinates. The native process restores the source's object types,
fixed-point positions and drag scaling. It uses decoded MDF geometry to build
object-shaped touch masks. A normal-input route test reaches storage area 3 and
selects visible node `obj01_08` through the original model hit mask. It starts
process 55, moves the type-3 object to the native origin target, and follows
the success return into the Chapter 7 script. This test requires Metal and
skips when no Metal device is available. The source setup does not initialise
the target fields at `+0x88c` and `+0x894`, so the native origin target is an
inference; the original target, model-to-type assignment and camera still need
an original-run comparison. Search-shed assets belong to process 79, not
process 55. The normal route continues through process 43, eleven ornament
placements, and the post-tree talks with Louie and Mila. Process 43 returns
zero on success and two when the menu exits early. Its target-to-page fit
remains inferred. The route returns from storage to R118, but the Dunning room
and later Chapter 7 scenes remain open. These checks establish partial native
handlers, not Chapter 7 completion.

Chapter 8 process 44 is the bowling interaction in overlay 11. Its original
model archive contains decoded `2Frouka`, `boulball` and `boulpin` models. The
process reads held touch input while the ball is selected. Its 0-based counter
alternates the players' turns, but it writes scores into two player rows:
player 0's three rounds at offsets 0, 4 and 8, then player 1's rounds at
offsets 12, 16 and 20 (`021fdf64`). The decompiled result check
uses player 0's three scores and three round-status values (`021fea90`). This
agrees with the guide's three rounds and Louie's final roll into a potted plant.
`OriginalBowlingResult` now records the player-row layout and the recovered
round comparisons and final-check predicate; focused tests cover slot order,
score recording, round status and the finish rule. `OriginalBowlingRenderer`
composes the recovered lane, ball and pin models and builds a projected mesh
mask for ball selection. The Metal rendering test skips on hosts without a Metal
device, so the scene has no source-image comparison. A CPU-only session test
injects a drawing stub and runs the native held-touch path through process
completion and event 11. This verifies session input and timing without
verifying model rendering. The native session loads process 44, forwards held
page touches and runs the match model. The session stays ready on the initial
press and begins the drag when the touch moves, matching the captured
press-and-drag transition. The isolated turn model
covers source drag selection, automatic roll start, and pin scoring after motion
stops. `OriginalBowlingMatchProcess` sequences alternating throws, applies the
recovered early-finish predicate, plays the recovered broken-pot effect for an
early win, waits through its 221-frame result display, then waits for the
source's 60-frame result action before returning 2.
A repeated replay of the drag-update helper scores four pins per throw, while
the separate five-throw source capture records `[6, 6, 6, 5, 5]`; these are not
the same touch path and do not establish score parity. The session uses the
captured initial camera matrix and does not model the result action's graphics.
The early-win path starts archive 60 entry 0, `SE_EVENT_BROKE_UEKIBACHI`, then
holds its result display for 221 frames. The source later calls
`FUN_0200a2f0` with `(-1, 10, 8)`; the `-1` branch fades active effect players
and does not start an effect. `FUN_02026c20` schedules a 60-frame scene action,
and `FUN_02081550` waits for its active flag to clear. The native session starts
the recovered effect, fades active effects over 10 frames at the callback, and
models both waits. A focused session test mutes output and checks the recorded
effect symbol and return to event 11; it provides no playback evidence. It
records four pins per throw, so it does not establish source score parity or the
full Chapter 8 route.

The `EP8_R119` process-44 event selects event 9 for process result 0, event 10
for result 1, and event 11 for result 2. A focused script test verifies all
three source transitions and their offsets. This identifies the return contract;
it does not establish which bowling outcome reaches each return in a normal run.

The early-win path schedules a 221-frame result display with the broken-pot
effect. The overlay then sets process stage 3. `021ff1b8` starts a 60-frame
scene action, fades active effects, then returns 2 when the action flag clears.
The five-throw probe records scores
`[6, 6, 6, 5, 5, -1]`, round statuses `[1, 1, 0]`, and bowling state 10. The
source checks player 0's three scores. It finishes when fewer than two rounds
have status 2. The native result model matches this early-finish rule.

A separate low-score capture follows six throws. It records scores
`[4, 4, 4, 5, 5, 5]`, round statuses `[2, 2, 2]`, and process stage 3. This
shows that a completed loss reaches the completion stage. The native match
model now completes this path after the 60-frame result action without the
221-frame early-win display. The capture does not include the terminal callback
or story caller result. See
[`loss-finish-probe.json`](../Tests/Fixtures/Bowling/loss-finish-probe.json).
A native route test repeats three five-throw matches through events 11 and 8.
It does not reach the plant scene. Results 0 and 1 still lack verified
interactions.

The remaining return is in the System-response handoff. Overlay 11 queues a
System mode-20 response with pair A `0x15` and pair B equal to the commentary
request ID (`02204744`, `020282a4`). In an isolated ROM trace, the status method
`021fd74c` ran twice while `+0xc58` was 1; both captures had request ID 0
because the overlay clears it before the following update. The trace shows
that the response status path runs, but it does not reveal the terminal
process return. A trace of ARM9 method `0206d28c` did not catch that method
during the same injected interaction, so its return mapping is not evidence
for the bowling handoff. The native session resumes the parent after the
System event, while the story return still needs a normal `EP8_R119` execution
or a source-backed isolated parent context. The route tests' injected 0/1
branches are not yet tied to ordinary play. The frame and state evidence is in
[`parent-status-probe.json`](../Tests/Fixtures/Bowling/parent-status-probe.json).

`tools/capture_bowling_component.py` now creates a reproducible process-start
trace from a valid walking checkpoint. It records the opening state at frame
120 and the ready state at frame 420, plus the initial camera matrix in
`Tests/Fixtures/Bowling/source-trace.json`. The checkpoint
injects process 44 through the original factory, so this confirms scene
initialisation only. It does not establish normal Chapter 8 route completion,
ball selection, a roll, or the story return.

The `--turn-phase-probe` capture now follows five source rolls from that
isolated checkpoint. The repeated touch path records alternating turns in the
two player rows. After player 0's third score, the source enters bowling
state 10 with two completed round wins. It then reaches process stage 3 and
resets the bowling fields. `OriginalBowlingResult` now reaches the same finish
decision before player 1's last score. The test compares the native model with
the captured scores and statuses. The overlay result callback returns 2 after
its scene action. The trace does not capture the final return or verify the
normal Chapter 8 route. See
[`turn-phase-probe.json`](../Tests/Fixtures/Bowling/turn-phase-probe.json).
The fixture records the dialogue callback flag separately from the match
result. That flag is at `+0xC58`.

Overlay 11's touch path runs through `02202D74` and `02202F88`.
`02202D74` builds a ray from the live camera basis and raw touch point. It uses
the 192×256 viewport, a 1.33 scale and the recovered 30-degree projection
angle. The raw touch conversion from `02009920` and `02009960` is represented
for both screen orientations: the resulting page point is
`(191 - y, x)` when rotated and `(y, 255 - x)` otherwise. Focused tests cover
both formulas and the 256×192 input bounds. `dragAnchor` now requires a
ball-plane selection hit followed by a lane-plane anchor hit and returns both
world-space intersections. Focused tests cover the ordering contract and reject
a lane-plane miss even when the ball plane hits. The component trace records
the raw touch point, per-frame camera matrix, live plane translations and both
24-word transform blocks. At drag frames 47 and 79, the native ray
intersects the translated lane within 0.1 world units of the source X/Z hit.
This validates two plane-hit samples only; complete gesture input and launch
parity remain open.
`drag-delta-probe.json` captures each eight-pixel step of that same modified-
checkpoint gesture. The stored touch point and drag delta update through raw
X=79; from X=87 onward they stay fixed while the ball transform continues to
move. This captures the source's held-input boundary, but not a normal route
entry.
The first `projection-sweep.json` used one cumulative touch path. It entered
the roll substage at X=80, so later samples did not show held-touch projection.
The touch point stayed fixed because the process had left the drag substage.
The reference trace of `FUN_02025888` shows bounds of `-9719...9719` in 20.12
fixed point. Those bounds are wider than the captured target values.
`projection-sweep.json` now reloads the ready checkpoint for each sample and
replays the eight-frame steps from X=15. It records the live camera, stage,
touch flags, ball and lane transforms, drag deltas and projected target through
X=79, then captures X=87 to record the roll state. The process enters its roll
substage at X=79 in this input path, so the unchanged target at X=87 is not a
lane hit boundary. The native ray now matches the source lane X/Z points at
each eight-pixel step from X=23 through X=71 within 0.1 world units. Regenerate
the trace with
`python3 tools/capture_bowling_component.py --projection-sweep`.
The decoded `2Frouka`, `boulball` and `boulpin` render groups do not include
hit triangles, so the renderer's mesh picker cannot stand in for this path.
`02202F88` tests two triangles from six 12-byte vertices, adding the supplied
20.12 translation to each vertex. The caller first tests the ball plane using
the template at `+0x348` and transform at `+0x4F8`, then tests the lane using
the template at `+0x300` and transform at `+0x498`. `OriginalBowlingTouchRay`
applies those translations and follows that selection order. The raw touch
conversion from `02009920` and `02009960` is represented for both screen
orientations.

The held-touch handler tests the live lane plane, adjusts its hit point through
the source projection and clamp functions, then calls `01FF8920` with that point
at `r1` and the ball transform at `+0x4F8` in `r2`. The helper writes `r1 - r2`
component by component to the temporary vector at `r0`; the handler stores the
result as the current drag delta at `+0x504` and shifts the old value to
`+0x510`. The ball then moves one quarter of the way toward the previous touch
point and clamps its forward position to `0x2e66`; release averages the two
latest deltas and applies the recovered launch threshold. Focused isolated
traces and the decompilation confirm this order. `OriginalBowlingTouchRay`
mirrors the wrapping vector subtraction, and `OriginalBowlingDrag` models the
per-frame update and release rule. The stored touch and drag values stop
updating at raw X=87 even as the ball moves. Lane-point projection, clamp and
the full gesture remain to be connected and checked in the native session;
normal Chapter 8 entry also remains open.

While the player holds the ball, the source stores the current and previous
drag deltas. On release, the source averages those two deltas for each velocity
axis. It starts the roll only when the forward component passes the recovered
negative threshold (`−205` in 20.12 fixed point), then clamps that component
to the source minimum. `OriginalBowlingLaunch` now implements this conversion.
The centre-roll source capture writes zero to the ball's vertical velocity
after averaging a non-zero vertical drag delta; the native launch model now
matches that ground-plane constraint.
The roll score counts the ten pins with non-zero rotation (`021FE9D4`).
`OriginalBowlingPinField` records those rotation states and the four-row pin
centres recovered from `021FFDFC`. Its rotation values now use the source float
format at `+0x594`, which the captured roll records as π/2 for toppled pins.
Comparing its old centre formula with the
captured process state showed that its X spacing and Z positions were half the
source values. The component now uses the source formation, and the trace stores
each pin's 20.12 position and motion, rotation and active flag.
`OriginalBowlingPinField.Pin` now retains those fixed-point vectors, float
angles and update flags. The launch and turn models now replay the captured
drag, roll start and pin scoring behaviour. A process-44 scene and native
session input handler remain open, as does the verified story return.

`OriginalBowlingDrag` now replays all 56 captured held updates from the
modified-checkpoint trace, including the source ball easing and forward
position clamp. The same replay checks release against the last two captured
deltas and gets velocity `(-71, 0, -819)`. The earlier turn-process draft was
removed because it derived drag from the difference between the lane and ball
plane hits. The source instead subtracts the ball transform from the projected
lane point. `OriginalBowlingTurnProcess` now connects the recovered drag to the
automatic roll threshold, then advances the existing ball and pin simulation
until the score is available. Its focused fixture test replays the captured
held updates and checks the source velocity. The native session now uses the
captured camera, translated ball and lane hit planes, and held lane projections.
The source touch replay reaches process stage 3 and resets the bowling fields,
but it does not capture a terminal return. Its scores also differ from the
native replay. These checks do not establish Chapter 8 playability.

A second modified-checkpoint reference run now captures a successful centred
roll in `Tests/Fixtures/Bowling/centre-roll.json`. From the ready state, it
holds at raw touch `(15, 90)`, moves right in eight-pixel steps through
`(119, 90)`, then moves to `(125, 90)`, holding each point for eight frames
before release. After 180 frames, six pin rotation fields are non-zero,
which confirms the score check returns 6 for this input. The same path at raw
Y=105 selects the ball and topples four pins. At raw Y=40, 60, 75, 120 and 140,
the ball is not selected and no drag deltas are recorded. These samples are in
`Tests/Fixtures/Bowling/touch-sweep.json`. The traces record useful original
inputs and numeric scores, but they do not verify normal Chapter 8 entry, later
turns, or the process return transition. This is emulator reference evidence
from a modified checkpoint, not a hardware run.

`Tests/Fixtures/Bowling/camera-input-trace.json` replays the same centred roll
and records the camera matrix, drag deltas, launch velocity and pin rotations
at selected points. It now records each pin's angular velocity and update flag,
plus states after each of the first 40 post-release runner frames. The first
moving pin appears at sample 24. Its motion changes again with later pin
collisions, so the per-pin movement routine alone cannot reproduce this trace.
The camera matrix stays unchanged from ready through drag
and release. It switches to a second fixed matrix by the first captured point
10 frames into the roll, then stays there through frame 180. This supports two
source camera modes. `OriginalBowlingCameraBasis` now has a focused comparison
for both captured matrices. This verifies the basis conversion only. It does
not establish the renderer or pin motion between captures. The decompiled
movement routine uses a 0.9 motion factor, a 0.0001 motion threshold, a 0.05
angular step and angle bounds from π/2 and 3π/2. `OriginalBowlingPinField` now
implements per-pin X/Z position, Y-motion reset, 0.9 linear damping and the
per-axis stationary threshold. It also advances rotation by angular velocity,
adds the source's 0.05 angular step and clamps at either rotation limit. The
captured pin 0 state at roll 24 advances to its roll 27 rotation and angular
velocity under this rule. The helper now models the captured pin-pair velocity,
spin and positional response, but it is not connected to process 44. The
isolated ball-to-pin model is described below.
The reference checkpoint resolves the shared pin collision radius at
`0x02204D90` to `0.484848` (`02204BC0` initialises it). The pair routine squares
this radius before comparing it with the squared X/Z pin distance.
`OriginalBowlingPinField.overlappingMovingPinPairs` now implements that active,
moving-pair and distance gate. The ball-to-pin source uses radius fields
`0.2424242` and `0.7272727`, which sum to `0.9696969` world units.
`pin-pair-sweep.json` records twelve isolated one-update captures across X, Z
and diagonal contacts, with motion along and across each contact axis. The
native pair response matches their fixed-point motion and angular states.
`OriginalBowlingPinField.ballContactCandidates` checks active pins that are not
already updating against this strict X/Z distance limit. The isolated capture
sweep records contact at `0.9668` after seven substeps and no contact at
`0.9766`; this brackets the source limit. The moving-away case also changes
ball and pin state, so the source has no approach-direction gate.
`OriginalBowlingPinField.resolveBallContacts` now applies the captured
ball-to-pin linear and angular response. `OriginalBowlingBallPinSimulation`
combines it with ten fixed-point ball substeps and the outer positive-Z speed
rule. Its state matches every case in `ball-pin-collisions.json`. Process 44 now
uses this simulation in the native session. These checks verify isolated source
captures and partial handler integration. They do not establish normal Chapter
8 route behaviour.
`OriginalBowlingBallMotion` clears vertical velocity during a normal substep,
applies the recovered lateral X stop boundary and continues longitudinal Z
motion. The isolated original-runner fixture checks both behaviours with all
pin records disabled.
An earlier pin-state write trace was exploratory, not isolated collision
evidence. It loaded roll frame 23, modified pin fields, and advanced one frame.
It left the ball moving and placed inactive test pins at the same position.
Those conditions could produce ball-to-pin and pin-to-pin collisions, so the
trace cannot isolate either response. The renamed
[`pin-state-write-probes.json`](../Tests/Fixtures/Bowling/pin-state-write-probes.json)
preserves these exploratory captures. The roll process uses `+0x4F8` and
`+0x500` for ball X/Z position and `+0x51C` and `+0x524` for X/Z velocity.
The new
[`isolated-pin-interactions.json`](../Tests/Fixtures/Bowling/isolated-pin-interactions.json)
parks the ball at a distant position, sets zero velocity, spaces unused pins
apart, and records one update for seven pin configurations. The separated-pin
case confirms 20.12 position integration, 0.9 velocity damping, and the 0.05
angular-velocity step from rest. `OriginalBowlingPinField` now matches that
one-frame pin update. The other cases record axial, diagonal, approaching,
separating and tangential pair response. `pin-separation-sweep.json` adds 16
isolated one-update captures across both axes and separations from 100 to 1,500
fixed-point units. `OriginalBowlingPinField` reproduces the source's seven by
seven tilted-pin samples and per-contact 0.01 positional correction; all
separation captures pass. Process update `022043c0` also applies a one-step
X-axis lane-edge correction of 410 fixed-point units at ±3.1 units. Seven
isolated source captures cover both edges and four pin rotations; the native
pin field matches these positions.
The source update order in `021FDF64` is `021FEDA0`, `0220368C`,
`021FEF34`, `022043C0`, then `02203DB8`. `OriginalBowlingPinField` now applies
the captured pin-pair velocity and angular response before the individual pin
step, then applies positional correction. This verifies isolated process
updates only. Full touch projection, native turn progression and the final story
return remain unverified.
The new
[`ball-pin-collisions.json`](../Tests/Fixtures/Bowling/ball-pin-collisions.json)
adds isolated captures for head-on, diagonal, near-edge, outer-edge, stationary
overlap, moving-away overlap and axial contact-limit inputs. These captures
span a complete process update, not individual substeps. The isolated model
matches these states, but does not establish full pin-to-pin response or normal
route behaviour.
Overlay 11's draw routines build model transforms from process values at
`+0x468` and `+0x4A0`. The trace records both inputs, but they stay fixed during
the sampled roll. The draw parameter blocks at `+0x448` and `+0x480` are mostly
zero in these states. The captures still do not identify the rendered ball
transform or the object masks.

A follow-up trace waited 1,200 frames after the centred roll. The six pin
rotation fields remained set, while the process stayed at scene state 2,
substate 2, internal state 5, round index 0, with all six result slots at −1.
The callback also set `+0xC58` to 1 and cleared `+0xC56`. Source function
`02204744` sets those fields when it queues a parent process response and
returns 1. This is consistent with the modified-checkpoint process completing
without its normal parent event to consume the response. An A press, another
touch and a forced internal-state write did not restore the parent call loop.
This trace does not show how a normal game turn records or returns its result.
There is no normal Chapter 8 checkpoint in the current reference captures, so
the process return still needs verification in the `EP8_R119` story context.
The callback queues System mode 20 with pair A 21 and a commentary request ID.
The match model now queues the recovered throw and round commentary IDs, and
the live session runs each System dialogue before continuing the match. A
focused native test covers the input path through event 11. An isolated ROM
trace confirms the overlay calls its status method during a request, but does
not capture the process return. Verification still needs the normal
`EP8_R119` route context.

The original factory receives the process byte stored at event offset 16. The host process ID is that byte plus 23. `tools/audit_story_factory.py` uses each host process ID directly as the factory case, then maps the loader slot through the original slot table. Current Chapter 10 mappings include process 59 to pencil sharpener, 61 to picture peel, 62 and 67 to code notice, 74/86/90/91 to typewriter, 75/79 to overlay 40 resources, 80 to cashbox, 85 to overlay 42, and 88 to overlay 44. These mappings identify factory resources. They do not prove full process behaviour or route transitions.

Processes 75 and 79 load overlay 40 in different modes. Process 75 uses mode 0 for the brick-wall puzzle. Its event has three returns to events 25, 26 and 27. The native process supports full front and side masks, Hammer-gated drags, collision checks, the doorway-clear result and the leave result. Its mask still disagrees with the ROM scan, and the normal Chapter 10 route remains unverified. See [Chapter 10 brick-wall process](chapter-ten-brick-wall.md). Process 79 uses mode 1 and starts the search-shed model. Its model returns zero, the only result accepted by EP10_R304. A CPU-only native event check exercises its found-box return path with an injected renderer. A separate Metal test checks rendering and mesh-hit selection, including the target box. The normal Chapter 10 route remains unverified.

The corrected mapping places process 59 at the pencil sharpener and process 58 at the jukebox. Old isolated captures that labelled process 59 as a sharpener do not establish that mapping. Chapter 10 processes 74, 86, 90 and 91 load typewriter resources. Session tests now verify process 74's first answer, process 90's memento answer and process 91's final answer through normal page input and their story returns. Overlay 41's answer check has no success branch for process 86's opening variant. Its session test enters a valid first-answer cipher, confirms that the process stays open, then checks the source exit result returns to exploration. These are isolated event tests, not a normal Chapter 10 route. Process 85 now loads the eight `AfterConfess` images, plays three grouped screens and returns 2. Its timing and image placement remain unverified against the original overlay. Process 88 loads `VSScene.tbl` and `VSScene.wpf`; its ARM9 handler selects either a custom interaction or a key-5 wait, then waits for an animation and a 100-frame completion delay. The overlay's normal path returns 0, while its alternate `+0x2ae == -1` path returns 2. The 23 named image resources pass a focused DTX decode test. A geometry capture of the active process screen matched its texture memory to `ED_A_01L2.bin`. An isolated process injection reached the custom interaction state. A centre tap moved it through inner state 4 into inner state 5; by 160 frames after release it had reached outer state 5, and at 240 frames its completion counter was 99. The process object was gone by 280 frames. The native handler now uses the normal return value. Its focused session test follows the transition at `EP10_R102` offset 208, plays the ending event, and returns to exploration. Layer placement and animation remain unverified against the original. The alternate key-5 path remains open. The full Chapter 10 route remains unverified.

The 26 October verification attempt skipped all three Chapter 5 route tests
because the Chapter 4 save was absent. The reference profile also failed in
tests that need Metal or CoreAudio services. Its process-coverage audit passed.
The fast profile passes the five Chapter 6 label-texture checks and the label
process tests. These results do not establish Chapter 5 route completion or
Chapter 6 presentation and route fidelity.

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
