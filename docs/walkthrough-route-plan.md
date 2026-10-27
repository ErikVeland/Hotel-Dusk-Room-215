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
| 8 | R102, R105, R113–R114, R118–R119, R124, R205–R206, R213, R401 | 45, 52, 76: partial native cassette handlers; 44: no native handler | No chapter route test found. Process 76 accepts the captured pencil swipe and returns to its parent. Process 45 returns through slot 5 after its delay and fade. Process 52 has an isolated scene handler, but the normal `R114` route and control selection remain unverified. The control selection capture injects an internal input phase; a tap after the native scene transition does not change the selector in the new source capture. Cassette previews have a known table-placement mismatch. The Chapter 8 route remains unverified, and process 44 needs a native handler. Check the cassette, bowling, rooftop meeting, brochure and Rosa's room. |
| 9 | R103, R105, R107, R112–R114, R116–R118, R123, R125, R205, R207, R213 | 63, 64 and 81: native handlers present | Process 63 waits for a full close and reopen. Process 64 resolves its embedded call context and map, renders the painting, checks its source region against the bitmap alpha mask, saves the found bit and returns result 2 after acknowledgement. Process 81 accepts five player taps in apple-count order and returns result 2 after J-E-N-N-Y. The CPR scene and physical hinge input need a DS comparison. Process 64 camera input, process 81 notebook presentation, source transition timing and the chapter route also need checks. |
| 10 | R102–R103, R108, R117–R118, R205, R210, R213, R301–R302, R304–R305, R401 | 59: native exit handler; 61, 62, 67, 74, 75, 79, 85, 86, 88, 90, 91: missing; 80: handler present | Process 59 displays a captured scene and returns through its source exit delay. Its pencil animation is not modelled. No Chapter 10 route test exists. Check the cellar, timed escape, wall and painting interactions, final conversations and endings. |

Chapter 9's apple-letter interaction uses overlay 38. Its five painting indices
come from the map-ID table at `0x02200370`, and the target word is `JENNY` at
`0x02200390`. The five map IDs, in painting order, are `11, 39, 17, 33, 31`.
The source stores the five found paintings in a bit mask at process offset
`+0x546`. Process initialisation queries its caller with key
`0x15` and selects the painting-search path only when the returned value is
`10`; another value enters the word-entry path. A process-ID RAM write does
not construct this caller context. Injecting process 64 from the walking
checkpoint therefore produces a blank scene, and that capture is not evidence
for normal apple-search input. `OriginalEventRunner` retains the embedded event
bytes, source offset and selection context for the active process.
`OriginalAlphabetProcessContext` now maps the five recovered process-64 call
sites to painting search and the process-81 call site to word entry. It returns
the source key `0x15` value 10 for search only; the word-entry caller value is
still unknown. Overlay initialisation at `0x021FCC60` takes the search path only
when that caller value is exactly 10. Every other value creates the shared
`0x2DC` text-entry object with `0x02028090` and `0x02028160`, then starts the
entry path. The recovered update at `0x021FFC80` waits for that control and
writes `6` to the overlay result field at `+0x59A`. The parent process then
returns manager value 2 after acknowledgement. The subsequent overlay state
(`0x021FD310`, state 8) lets the player move through the five word positions
and returns to the letter-search state when a position changes. These source
transitions identify the branch, but not its valid caller value, on-screen
layout, or exact input behaviour. Process 81 now has a native handler based on
the recovered five-slot selection flow and the `CHP913` guide: each tap selects
the next letter in apple-count order, and an incorrect tap clears the partial
entry. It requires all five found bits and returns result 2 after the full
sequence. This is a source-informed native interaction, not a matched DS
capture of the notebook controls. The apple images use `apple%d.bin` from the
alphabet archive. Process 64 has a partial native handler and an embedded-call
session test; no full Chapter 9 route test exists yet.

`EP9_R116` event 4 selects process 63. Its mode-15 record has selector 40 at
byte 16, and the source adds 23. The event sits between dialogue about helping
Mila and the next response. The `CHP914` walkthrough says the player performs CPR by
closing and reopening the DS. The native process waits for a closed hinge state,
then a fully open state, and returns success. This maps process 63 to the CPR
interaction from the script order and guide. A matching original process capture
is still needed. The simulator and Mac views offer a fold action through the
existing hinge simulator. The face images and physical Duo input remain
unverified.
For a recovered process-64 invocation, the context adapter now resolves the
active painting index from its preserved map ID. The source call sites are
verified from the bundled event tables; the test does not assume a fixed
call-site-to-map-ID pairing.
`OriginalApplePaintingSearch` now models the five source map IDs, their found
bits and the `JENNY` target word. Its tests cover map ordering, duplicate hits,
the five-bit completion state, and letter reveal from the active map ID.
`OriginalApplePaintingMask` reads the alpha representation from all five source
images. `OriginalApplePaintingRenderer` draws the selected 256×256 image into
the 192×256 page using the source three-to-one scale. Process 64 now uses the
saved map ID to select the painting, accepts its source hit region through that
mask, persists the found bit at game offset `0xD8`, and returns source result 2
after acknowledgement. Session tests cover all five map-selected bitmaps in
isolated process calls. The drag gesture changes the camera in 0.03-unit steps
and redraws the image. It uses a native mapping from drag distance to camera
steps. Held-input timing and source transition timing need a DS comparison. A
full Chapter 9 route test also remains open.

Overlay 38's selection check in `021fe830` transforms the active camera position
and touch point before testing the selected painting. `OriginalApplePaintingSearch`
now reproduces that transform and tests the 16×16 region
from `(anchorX - 32, anchorY)` to `(anchorX - 16, anchorY + 16)`. The five
anchor pairs, read from the interleaved tables at `0x0220037a` and `0x0220037c`,
are `(86,214)`, `(32,224)`, `(188,188)`, `(160,74)` and `(186,74)`. These are
camera-space values, not page coordinates. The source
also moves the camera with directional input and arrow hitboxes, and reveals
the selected letter only after the painting-selection transition. The renderer
and mask now use the same camera-space model as input. Drag movement updates
the camera fields and shows no hit-region overlay. The native mapping from drag
distance to camera steps needs a DS comparison. Treating anchor pairs as screen
hitboxes would select the wrong regions. The source selection also advances
through a five-step word list and stores recovered paintings in the `+0x546`
bit mask.

The alphabet assets are linear DS bitmaps. `apple1.bin` through `apple5.bin`
are 256×256; `answer.bin` is 256×192; and `word.bin`, `arrows1.bin` and
`arrows2.bin` are 32×128. Load them through the hash-checked
`OriginalBitmapLibrary.loadLinear` path. They are not covered by the tiled
bitmap decoder.

The recovered event tables call process 64 from `EP9_R117` event 1,
`EP9_R125` event 2, `EP9_R205` event 2, and event 1 in `EP9_R207` and
`EP9_R213`. Process 81 is called from `EP9_R125` event 5. These are embedded
mode-15 processes: their process selector is byte 16 plus 23. Preserve the
event/map context when adding the handlers; the event IDs alone do not
establish which painting or word-entry state is active.

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
deck, where side A or B can be selected. The native session now connects the
captured process-76 swipe and parent return. It does not establish the normal
`R114` inventory conditions, source-matched rendering, or audio. Process 45
now displays the ballpoint preview and returns through the captured slot 5
quit target. Its repeated-stroke behaviour does not establish a successful
ballpoint interaction.

A fresh modified-checkpoint capture of process 76 reaches overlay 25, variant 1,
interaction state 2 after its entrance animation. Its image shows the cassette
deck. The touch probe did not verify side selection or the process return, so
this capture remains scene-initialisation evidence only.

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

The source requests sound event `0x2B` during qualifying drag frames and sound
event `6` on success. The captured PCM has no confirmed cassette cue. Its
sound-manager fields report no active BGM and retain last-BGM value 17. Those
fields do not verify sound effects. Treat the PCM as runner output, not as a
cassette audio check. The RAM snapshots and hashes are in
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

The first isolated process-52 capture from the walking checkpoint stopped at
frame 300 and established neither interaction nor return. A later input trace
reaches the cassette controls and requests exit. The `R114` parent state is
absent from this workspace, so the Chapter 8 return has not been verified in
the story route.

The process factory maps process 52 to overlay 28 with variant 6
(`0200b334`, case `0x52`). Overlay 28 loads `/data/trick/cassette02.tbl` and
`/data/trick/cassette02.wpf`. Its resources include the `front`, `radio` and
`tape` models, plus play, stop, pause, rewind and fast-forward button images
(`021fcd14`). The update callback has timed states and input checks
(`021fde70`, `021ff360`). A normal-input process trace now touches the cassette
at `(76, 156)`, drags upward to `(76, 108)`, reaches input state 103, and starts
the playback sequence with A. A tap at the back control sets the source exit
flag. The audio log records BGM state only. It does not verify the cassette
sound.
The same fixture records the four fixed-point vectors copied into the source
camera object and the radio, front and tape model transforms at opening,
controls-ready, playback, exit-requested and after-exit frames. The vectors
change between opening and controls-ready, then change again on playback; the
captured model transforms remain fixed in these states. The new
`OriginalCassetteDeckCamera` helper maps the recovered position, up and target
vectors initialised in `021fcd14` and updated in `021fde70`. Camera setters
`02089254`, `02089270`, `0208928c` and `02089238` place them in the camera
object; `020895f4` uses the position, up and target fields for the view
transform. Projection values come from `02088fec`. `OriginalCassetteDeckRenderer`
renders the radio, front and tape models and builds invisible projected-mesh
masks with edge padding. Process 52 now starts this renderer in the native
session. Its controller follows the captured object hit, upward drag, 180-update
camera turn, control selection and 60-update back exit. The native Play
selection button maps to the DS A-button press, and Return to story maps to the
source back control. These touch adaptations, the model rotation order and the
rendered comparison against source frames are not verified. The native process
return is not yet verified through `R114`.

The recovered `EP8_R114` BLK record at offset 492 calls process 52. Its CHK
transition table maps return values 0, 1, 2 and 3 to events 16, 17, 17 and 18.
This defines the script return contract. The observed back-control path returns
2 and selects event 17. `OriginalEventCompletionTests` checks all four source
transitions; the Chapter 8 parent route is still unverified.

Overlay 28's control branch checks two source rectangles through
`FUN_0200985c` at input state 103. With orientation flag 0, the bounds are
`[192, 16, 224, 80]` and `[192, 112, 224, 176]` in transformed coordinates.
Independent taps at raw `(47, 47)` and `(47, 143)` advance input state 103 to
104 and set selector values 0 and 1. The capture writes state 103 directly.
It verifies the bounds only and does not identify the visible button masks.
After the native scene transition, a tap at `(47, 47)` leaves the selector at
0 and input state at 103. This normal-input probe does not verify the control
branch. Its RAM and command hashes are in
[`process-52-normal-control-tap.json`](../Tests/Fixtures/Cassette/process-52-normal-control-tap.json).
The native view does not draw the source bounds. Reproduce the injected-state
check with [`capture_cassette02_controls.py`](../tools/capture_cassette02_controls.py)
and the normal-input probe with
[`capture_cassette52_control_path.py`](../tools/capture_cassette52_control_path.py).

Overlay 28's update callback returns 2 when its exit flag reaches the timed
exit path (`021fd888`). The `EP8_R114` CHK table therefore selects event 17
for the observed back-control exit. This closes the source return-value
question for that path. Return values 0, 1 and 3 remain unverified.

The same script samples 42 raw touch points against overlay 28's 3D scene from
the initial view, with a release before each sample. Twenty-five points enter
input state 2. All sampled hits fall between X 60–92 and Y 108–156. This coarse
grid supports mask work, but it does not define the full silhouette or prove
that a native model projection matches the source. The runner reads the process
state and touch-active byte directly. It does not save a full RAM image for each
sample.

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
score recording, round status and the finish rule. `OriginalBowlingRenderer`
composes the recovered lane, ball and pin models and builds a projected mesh
mask for ball selection. The Metal rendering test skips on hosts without a Metal
device, so the scene is not yet compared with the source image or connected to
the native session. Process 44 still needs a session handler, drag-to-velocity
mapping, pin-pair response, turn progression and a verified final story return.

The `EP8_R119` process-44 event selects event 9 for process result 0, event 10
for result 1, and event 11 for result 2. A focused script test verifies all
three source transitions and their offsets. This identifies the return contract;
it does not establish which bowling outcome reaches each return in a normal run.

The overlay's normal completed-match path sets the process stage to 3, then
`021ff1b8` returns process result 2 after its audio cue finishes. The one-roll
probe also records the dialogue callback flag after the score dialogue begins.
That flag belongs to the dialogue controller; it is not the match result. The
isolated process still has no parent event, and all six score slots remain
unset. The source paths that produce results 0 and 1 are not yet tied to a
normal Chapter 8 interaction.

`tools/capture_bowling_component.py` now creates a reproducible process-start
trace from a valid walking checkpoint. It records the opening state at frame
120 and the ready state at frame 420, plus the initial camera matrix in
`Tests/Fixtures/Bowling/source-trace.json`. The checkpoint
injects process 44 through the original factory, so this confirms scene
initialisation only. It does not establish normal Chapter 8 route completion,
ball selection, a roll, or the story return.

The `--turn-phase-probe` capture adds one centre roll from that isolated
checkpoint. Its six toppled pins are visible in the source process data. The
ball stops by frame 30, and the captured screens then show the bowling
dialogue. An A press advances to Louie's reply. The isolated object remains in
its final state and its score slots remain unset, so this probe does not prove
the process-manager return or a complete turn. See
[`turn-phase-probe.json`](../Tests/Fixtures/Bowling/turn-phase-probe.json).
The fixture also records the dialogue request, callback flag and callback
delay. The callback flag at `+0xC58` belongs to the dialogue controller; it is
not the match result.

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
both formulas and the 256×192 input bounds. `dragAnchor` now requires a
lane-plane hit followed by a ball-plane hit and returns both world-space
intersections. Focused tests cover that order and reject a ball-plane hit
outside the lane mask. The component trace records the initial camera matrix
and both 24-word drag hit-test input blocks. Native input still needs the
per-frame camera basis, transformed lane vertices, and comparison against
original touch input before integration.
The decoded `2Frouka`, `boulball` and `boulpin` render groups do not include
hit triangles, so the renderer's mesh picker cannot stand in for this path.
Recover the overlay's live camera basis and transformed lane vertices before
mapping the native drag to a roll; the static model manifest alone does not
provide those values.

The decoded overlay image supplies two static six-vertex planes used by
`021FF914`: `0x02204B30` spans X/Z from −5 to +5 at Y=0, and `0x02204B78`
spans X/Y from −0.3 to +0.3 at Z=0. Both use 20.12 fixed-point coordinates.
They are copied to process offsets `+0x300` and `+0x348`. The process trace
shows temporary data at `+0x438`, `+0x498` and `+0x4F8`. The component capture
now records the 24 words copied from `+0x498` and `+0x4F8` immediately before
each hit-test call. The decompiler's fifth-argument layout does not establish
the vertex stride, so these raw words are evidence for follow-up analysis, not
transformed hit-test vertices. The source hit-test path still needs a clearer
account of its transformed triangles. `OriginalBowlingTouchRay` stores the two
static six-vertex plane templates and checks forward ray hits against their
triangles. Exact source segment clipping and the live camera transform remain
unverified, so this helper is not yet connected to bowling input.

While the player holds the ball, `021FDA10` stores the current and previous
drag deltas. On release, `021FEB08` averages those two deltas for each velocity
axis. It starts the roll only when the forward component passes the recovered
negative threshold (`−205` in 20.12 fixed point), then clamps that component
to the source minimum. `OriginalBowlingLaunch` now implements this conversion.
The roll score counts the ten pins with non-zero rotation (`021FE9D4`).
`OriginalBowlingPinField` records those rotation states and the four-row pin
centres recovered from `021FFDFC`. Its rotation values now use the source float
format at `+0x594`, which the captured roll records as π/2 for toppled pins.
Comparing its old centre formula with the
captured process state showed that its X spacing and Z positions were half the
source values. The component now uses the source formation, and the trace stores
each pin's 20.12 position and motion, rotation and active flag.
`OriginalBowlingPinField.Pin` now retains those fixed-point vectors, float
angles and update flags. A launch regression test now feeds in the
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
velocity under this rule. The helper still does not model pin collisions and is
not connected to process 44. The isolated ball-to-pin model is described below;
pin-pair response remains separate.
The reference checkpoint resolves the shared pin collision radius at
`0x02204D90` to `0.484848` (`02204BC0` initialises it). The pair routine squares
this radius before comparing it with the squared X/Z pin distance.
`OriginalBowlingPinField.overlappingMovingPinPairs` now implements that active,
moving-pair and distance gate. The ball-to-pin source uses radius fields
`0.2424242` and `0.7272727`, which sum to `0.9696969` world units.
`pin-pair-sweep.json` adds twelve isolated one-update captures across X, Z and
diagonal contacts, with motion along and across each contact axis. The original
changes both pins' positions and velocities, but the decompiled pair routine has
unreliable recovered branches. These captures narrow the response rules; they
do not support a complete native pair response yet.
`OriginalBowlingPinField.ballContactCandidates` checks active pins that are not
already updating against this strict X/Z distance limit. The isolated capture
sweep records contact at `0.9668` after seven substeps and no contact at
`0.9766`; this brackets the source limit. The moving-away case also changes
ball and pin state, so the source has no approach-direction gate.
`OriginalBowlingPinField.resolveBallContacts` now applies the captured
ball-to-pin linear and angular response. `OriginalBowlingBallPinSimulation`
combines it with ten fixed-point ball substeps and the outer positive-Z speed
rule. Its state matches every case in `ball-pin-collisions.json`. This verifies
the isolated source captures only; pin-pair response, process 44 rendering and
touch integration remain open. The simulation is not yet connected to the
normal Chapter 8 route.
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
one-frame pin update. The other cases record the source pair response for
axial, diagonal, approaching, separating and tangential motion. These captures
provide collision evidence, but the full pin response is not yet implemented
in the native process. Process update `022043c0` also applies a one-step X-axis
lane-edge correction of 410 fixed-point units at ±3.1 units. Seven isolated
source captures cover both edges and four pin rotations; the native pin field
now matches these positions. `02203db8` still applies a separate positional
correction during pair response.
The source update order in `021FDF64` is `021FEDA0`, `0220368C`,
`021FEF34`, `022043C0`, then `02203DB8`. The final routine processes every
active pin pair and applies positional and velocity corrections after the
individual pin update. The native model currently checks pair overlap but does
not reproduce this response. A full bowling turn and its score therefore remain
unverified.
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

The original factory maps process 44 to bowling, process 46 to label peeling,
process 55 to the search shed, process 59 to the pencil sharpener, process 61 to picture peeling,
process 62 and 67 to the code puzzle, process 63 to the Chapter 9 CPR interaction,
process 64 and 81 to the alphabet puzzle, process 74, 86, 90 and 91 to
the typewriter, process 75 and 79 to the brick/search-shed overlay, process 85
to the confession scene, and process 88 to an overlay with no recovered asset
strings. These mappings identify original code and assets. They do not prove
native input or route behaviour.

Process 59 has a repeatable isolated reference capture from the walking
checkpoint. A 20-frame touch at `(100, 100)` sets the held-pencil flag at
`+0x2ED`. Four frames at `(15, 172)` enter exit state 3. The overlay returns
result 2 after its exit callback. The native session now displays a captured
portrait scene, uses a hidden rounded mask for the exit icon, waits 60 updates,
and returns result 2. A focused session test runs `EP10_R301` event 14 through
the parent event runner. The pencil sharpening animation and the full Chapter
10 route remain unverified. See
[`source-trace.json`](../Tests/Fixtures/PencilSharpener/source-trace.json).

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
