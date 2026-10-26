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

The route now also completes `CHP214`: downstairs travel, the office-door knock, payment and apology choice 21. R115 entry and the `CHP215` guest-ledger, birthday-card, log and calendar searches are connected. The trapped memo now tears through native drag input and awards the torn paper. Memo drawing and inventory reopening are connected. Crowbar placement, lifting and joined-memo retrieval now run through native input. The cabinet number wheels, drawer opening, red-box acquisition and office exit are connected. The route now follows Louie’s Nile discussion and Rosa’s questions. Ed's call, Louie's room confrontation, the photo and all Chapter 2 review answers now run through native input. The route continues into Chapter 3 through Rachel's call and the first restaurant conversations. See [Chapter 3 progress](chapter-three-progress.md). See [Louie route evidence](chapter-two-louie-office.md). See [Cabinet combination](chapter-two-cabinet-combination.md). See [Crowbar recovery](chapter-two-crowbar-recovery.md). See [Memo drawing](chapter-two-memo-drawing.md). See [Trapped memo](chapter-two-memo-pull.md). See [Office search](chapter-two-office.md). See [Chapter 2 payment](chapter-two-payment.md).

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
| 6 | R104–R106, R126, R202, R205, R213 | 46, 51, 53, 54, 58: handlers present | A normal-input test now starts from the Chapter 5 save and follows R205 → R213 → R117 → R126 → R104. It saves a bar checkpoint for the next route segment. The test skips until the Chapter 5 route creates its save. No full Chapter 6 route test exists. Process 46 uses the original label mask, drag reveal and 99.5% completion threshold. Its native placement and route still need reference confirmation. Check the vending prize, coins, matchsticks, bottles and wine label. |
| 7 | R102, R103, R105, R112, R117, R118, R122, R126, R205–R206, R213 | 55 and 43: native handlers added | No chapter route test found. Process 55 loads the source cube at the 26 recovered transforms and opens the tree-box selection. Process 43 now renders ornaments and accepts drag-and-drop through their alpha masks. Its native target-to-page fit is inferred and has no original-run comparison. The other tree interaction stages and the chapter route remain incomplete. |
| 8 | R102, R105, R113–R114, R118–R119, R124, R205–R206, R213, R401 | 44, 45, 52, 76: no native handlers | No chapter route test found. An isolated trace reaches process 76's source stroke threshold, but has no native handler or parent return. Process 44, 45 and 52 remain unverified. Check the cassette, bowling, rooftop meeting, brochure and Rosa's room. |
| 9 | R103, R105, R107, R112–R114, R116–R118, R123, R125, R205, R207, R213 | 63, 64, 81: missing | No chapter route test found. Check the apple paintings, Room 111, CPR, birthday cards and secret door. |
| 10 | R102–R103, R108, R117–R118, R205, R210, R213, R301–R302, R304–R305, R401 | 59, 61, 62, 67, 74, 75, 79, 85, 86, 88, 90, 91: missing; 80: handler present | No chapter route test found. Check the cellar, timed escape, wall and painting interactions, final conversations and endings. |

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
returns 0 and writes the completed order to the recovered save field. The menu
path returns 2. The separate source drag stages, item-to-colour mapping and
Chapter 7 route still need implementation and original-run comparison.

The Chapter 5 route tests already exist in `OriginalChapterFiveRouteTests`,
although the earlier status notes do not record them. Run the three tests after
the Chapter 1–4 route chain creates its save. Use any route failure to update
this map with the specific missing dependency.

The original factory maps process 46 to overlay 22, which loads
`trick/LabelPeel` assets. The original overlay binds a 0x5000-byte dynamic mask,
marks pixels during a drag and accepts the result at 99.5% clear. The native
model and renderer now use this threshold and the original bottle and label
textures. Process tests cover the threshold and a full drag. Compare the native
image placement and route with the original game before marking Chapter 6
complete.

Several later processes share an original overlay. Keep one implementation
per overlay and check each chapter event that calls it:

| Processes | Chapters | Original interaction | Overlay |
| --- | --- | --- | --- |
| 45, 76 | 8 | Cassette | 25 |
| 64, 81 | 9 | Apple-word puzzle | 38 |
| 74, 86, 90, 91 | 10 | Typewriter | 41 |
| 75, 79 | 10 | Brick and search-shed interaction | 40 |

Chapter 8's `EP8_R114` event 9 invokes process 76 (source offset 372), and
event 13 invokes process 45 (offset 452). The event encoding stores the
process selector as byte 16 plus 23. The recovered dialogue and `CHP802`
walkthrough establish the required item sequence: the ballpoint pen fails
because it is round; the pencil rewinds the tape after repeated downward
strokes; the rewound tape returns to inventory and is then used on Louie's
deck, where side A or B can be selected. Isolated process injections render
the cassette scene for both IDs, but they do not establish the normal `R114`
inventory and story-state conditions or the native gesture thresholds. Both
process handlers remain missing.

A fresh modified-checkpoint capture of process 76 reaches overlay 25, variant 1,
interaction state 2 after its entrance animation. Its image shows the cassette
deck. The touch probe did not verify side selection or the process return, so
this capture remains scene-initialisation evidence only.

Overlay 25's state-2 tap gate reads four bounds at `0x021FFF34` through
`FUN_0200985C`. The source values are `[108, 100, 120, 192]`; the helper checks
transformed X against 108–120 and transformed Y against 100–192.

The captured orientation flag at `0x021046B8` is zero. In that mode,
`FUN_02009920` returns raw Y and `FUN_02009960` returns `255 − raw X`. The
source gate therefore checks X 108–120 and Y 100–192. Raw touch `(141, 130)`
maps to `(114, 130)` and enters the gate; the earlier probe at `(114, 130)` maps
to `(141, 130)` and misses it. `tools/capture_cassette_component.py` records
process fields and touch deltas. Process 45 stays at input phase 3 during a
downward raw-Y swipe, and its stroke counter stays at zero. Process 76 (variant
1) reaches its source success branch with a different path: tap `(141, 130)`,
move to raw X 135 (source X 120), then decrease raw Y from 130 to 100 one
pixel per frame. After 65 held frames, it reaches input phase 100 with six
strokes. After 245 held frames, it reaches input phase 12. This matches the
source `strokeCounter > 5` branch. The guide describes a downward stroke, so
the direction mapping still needs a display check. An A press and a touch
release do not leave phase 12 in this isolated run. The handler polls byte
`0x0210BDA4` before it leaves phase 12. The isolated checkpoint keeps this byte
at 1, while an unrelated dialogue capture has 0. This comparison does not
establish the required `R114` value. The normal parent state and process return
remain unverified. The RAM snapshots and hashes are in
[`held-touch-trace.json`](../Tests/Fixtures/Cassette/held-touch-trace.json).
Reproduce the input with
[`component-cassette-rewind.txt`](../tools/reference/component-cassette-rewind.txt)
and [`component-cassette-repeated-swipes.txt`](../tools/reference/component-cassette-repeated-swipes.txt).
The deck probe remains in
[`component-cassette-deck.txt`](../tools/reference/component-cassette-deck.txt).
`OriginalCassetteTouchRegion` records the invisible source tap region and draws
no touch overlay.

An isolated process-52 injection from the walking checkpoint is also
inconclusive: its frame-300 capture establishes neither a verified interaction
nor a process return. The normal `R114` parent state is absent from that run.

Chapter 7's `EP7_R122` calls process 55 at event 3, then process 43 at event 7.
The supplied guide places the tree-box search before tree decoration. The
process-55 factory mapping loads overlay 30's `searchshed.tbl` and
`searchshed.wpf`. `OriginalSearchShedLayout` records the 26 initial object
positions and scales from overlay 30 at `0x02201488`. Process 55 now draws the
source cube at those transforms, tests touches against its projected hit
triangles, and moves objects on the source horizontal plane. It accepts object
9 only when that object is the nearest hit. Confirming object 9 now returns
process result 2 through the session. Four process tests pass for drag handling,
object selection and exit results. The focused tree and search-shed test run
passes 25 tests on this host, including both renderers and the ornament alpha
mask picker. No Chapter 7 route or original-run comparison exists yet. The
source box reveal animation is not drawn. Process 43 supports ten ornament
placements and reveals the star after those placements. Its terminal fade now
returns source process value 2, as the overlay state machine does. The target-to-page fit remains inferred, and the separate source drag stages and route still need implementation and original-run comparison.
Its target-to-page fit remains inferred, with no original-run comparison. These
checks establish partial native handlers, not Chapter 7 completion.

Chapter 8 process 44 is the bowling interaction in overlay 11. Its original
model archive contains decoded `2Frouka`, `boulball` and `boulpin` models. The
process reads held touch input while the ball is selected. Its 0-based counter
writes six interleaved result slots: player 0/1 at round 0, then player 0/1 at
round 1, then player 0/1 at round 2 (`021fdf64`). The decompiled result check
uses player 0's three scores and three round-status values (`021fea90`). This
agrees with the guide's three rounds and Louie's final roll into a potted plant.
`OriginalBowlingResult` now records this interleaved layout and the recovered
round comparisons and final-check predicate; focused tests cover slot order,
score recording, round status and the finish rule. The current native session has
no process-44 handler, scene renderer or input path. Ball hit geometry,
drag-to-velocity mapping, pin outcomes and the final story return still need
implementation and comparison.

The `EP8_R119` process-44 event selects event 9 for process result 0, event 10
for result 1, and event 11 for result 2. A focused script test verifies all
three source transitions and their offsets. This identifies the return contract;
it does not establish which bowling outcome reaches each return in a normal run.

`tools/capture_bowling_component.py` now creates a reproducible process-start
trace from a valid walking checkpoint. It records the opening state at frame
120 and the ready state at frame 420, plus the initial camera matrix in
`Tests/Fixtures/Bowling/source-trace.json`. The checkpoint
injects process 44 through the original factory, so this confirms scene
initialisation only. It does not establish normal Chapter 8 route completion,
ball selection, a roll, or the story return.

Overlay 11's touch path is now traced through `02202D74` and `02202F88`.
`02202D74` builds a camera ray from the current camera basis and touch point.
It uses the 192×256 viewport, the 1.33 scale, and the tangent of the recovered
30-degree projection angle. `OriginalBowlingTouchRay` records these constants
and the source's per-axis operations in a normalised basis-relative ray
calculation. Its `firstHit` method checks two triangles in the order used by
`02202F88`. The intersection is a native ray-triangle calculation; exact
source segment clipping remains unverified. These are geometry components only;
the native process does not yet supply the source camera basis or live lane
vertices for hit tests. The raw touch conversion from `02009920` and `02009960`
is now represented for both screen orientations: the resulting page point is
`(191 - y, x)` when rotated and `(y, 255 - x)` otherwise. Focused tests cover
both formulas and the 256×192 input bounds. The new component trace records
the initial camera matrix. Native input still needs the per-frame camera
basis, transformed lane vertices, and comparison against original touch input
before integration.
The decoded `2Frouka`, `boulball` and `boulpin` render groups do not include
hit triangles, so the renderer's mesh picker cannot stand in for this path.
Recover the overlay's live camera basis and transformed lane vertices before
mapping the native drag to a roll; the static model manifest alone does not
provide those values.

The decoded overlay image supplies two static six-vertex planes used by
`021FF914`: `0x02204B30` spans X/Z from −5 to +5 at Y=0, and `0x02204B78`
spans X/Y from −0.3 to +0.3 at Z=0. Both use 20.12 fixed-point coordinates.
They are copied to process offsets `+0x300` and `+0x348`. The 96-byte
structures at `+0x438`, `+0x498` and `+0x4F8` copy the same six 3D vectors from
the process template at `+0x3D8` (`022044F4`). The touch test transforms the
six vectors from `+0x4F8` before ray intersection. This is transform data, not
the model's missing hit triangles. `OriginalBowlingTouchRay` now stores the
two source six-vertex plane templates and checks forward ray hits against their
two triangles. Exact source segment clipping and the live camera transform
remain unverified, so this helper is not yet connected to bowling input.

While the player holds the ball, `021FDA10` stores the current and previous
drag deltas. On release, `021FEB08` averages those two deltas for each velocity
axis. It starts the roll only when the forward component passes the recovered
negative threshold (`−205` in 20.12 fixed point), then clamps that component
to the source minimum. `OriginalBowlingLaunch` now implements this conversion.
The roll score counts the ten pins with non-zero rotation (`021FE9D4`).
`OriginalBowlingPinField` records those rotation states and the four-row pin
centres recovered from `021FFDFC`. A launch regression test now feeds in the
captured final drag deltas and confirms the source threshold accepts the roll
and clamps its forward speed. The pin simulation and process-44 scene, input
and return path still need implementation.

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

The original factory maps process 44 to bowling, process 46 to label peeling,
process 55 to the search shed, process 59 to the pencil sharpener, process 61 to picture peeling,
process 62 and 67 to the code puzzle, process 63 to the Chapter 9 character
lookup, process 64 and 81 to the alphabet puzzle, process 74, 86, 90 and 91 to
the typewriter, process 75 and 79 to the brick/search-shed overlay, process 85
to the confession scene, and process 88 to an overlay with no recovered asset
strings. These mappings identify original code and assets. They do not prove
native input or route behaviour.

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
