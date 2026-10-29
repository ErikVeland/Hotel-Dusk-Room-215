# Chapter 10 brick-wall process

Process 75 selects overlay 40 in mode 0. The source event is `EP10_R304`,
source offset 672. The event maps process returns 0, 1 and 2 to events 25, 26
and 27. The native session now runs an isolated brick-wall interaction and
returns 0 when its doorway gate is clear, or 2 when the player leaves. Result 0
selects the source success event. The trigger for source result 1 remains
unverified. The session does not yet verify the normal Chapter 10 route or the
original DS hit map.

## Recovered interaction shape

Overlay initialisation creates 90 objects in a 15 by 6 arrangement. The
positions use the original random-number state. Mode 0 applies an additional
bit-mask layout to the initial board. The source loads `brick.tbl` and
`brick.wpf`, with bitmap resources under `trick/brick/`. The existing original
texture decoder reads all seven payloads: the background is 256×192 and each
brick-face image is 32×16. Native texture binding and procedural scene
geometry are still missing.

The update routine uses internal states 0–5 for selection and manipulation.
It casts the stylus ray against the board geometry to select an object, then
checks the selected object again while the stylus is held. Drag updates test
the moved geometry against the other board objects. The source also has a
separate validation path and a delayed reset/exit animation. These are
three-dimensional geometry operations; a two-dimensional cell hit test would
not preserve the original selection and collision behaviour.

Overlay 40 tests two faces on each brick: its front at local `z = +0.5` and
right side at `x = +0.5`, each made from two source triangles. The native mask
now tests all four triangles. Earlier code tested only the `x` face.

The source vertex table at `DAT_02200a3c` in overlay 40 decodes to those same
12 local vertices. `FUN_022004f8` scales and offsets them with each brick's
captured transform before testing the ray. This confirms the native front and
right-side mesh shape. The screen scan's 668 extra mask hits therefore remain
in the touch-ray mapping, transform state, or source hit-selection path; adding
more face triangles is not supported by this source table.

The player sequence is clearer in the walkthrough evidence: tapping the
exposed wall first triggers a response that calls for a stronger tool; after
using the hammer on the wall, the player taps bricks away until the door is
visible. This is secondary gameplay evidence. The native port still needs to
match the source state and return rules. See the [Chapter 10 walkthrough](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777).

The top-level overlay has two nonzero process returns. Its final callback
returns 1. Another completed path returns 2 before the final callback. Other
calls return 0 while the overlay is still running. The exact player actions
that reach each script branch still need original execution evidence.

The brick update helper checks inventory item `0x3b`, which is the Hammer
entry, and checks counts of one and two. It also compares each selected
object's vertical position with `-1.0` before it updates the object's
transform. This ties the Hammer to the brick interaction, but it does not by
itself identify which of the three script branches follows each player action.

The native engine builds the 90 source transforms from a deterministic seed.
It uses the recovered linear random generator, alternating row offsets, the
`row - 0.5` vertical positions, scale, and four fixed object indices. An
isolated Process 75 ROM run confirmed these transforms in main RAM. The nine
mode-0 mask bytes at `0x02111644` were all zero in that run. The connected
process now uses the CPU mask for full front and side faces, permits Hammer
drags, prevents brick overlap, and checks the 48-object doorway condition.
The board view draws the bricks without touch-region overlays. Its seed is
still fixed, its drawing is a native approximation, and the mask scan evidence
below shows it does not yet match the original touch map across the screen.

The native board view projects each source vertex with the inverse of the
recovered touch-ray equations. It uses the fixed eye, the 20-degree angle, the
1.33 aspect multiplier, and a 128-pixel divisor on both axes. This keeps the
drawn front and side faces in the same coordinate basis as the CPU hit mask.
It does not yet establish parity with the original render. ARM9 touch accessors
show that the overlay does not receive raw DS touch axes directly: one
accessor returns the vertical coordinate or its 191-pixel inverse, and the
other returns the horizontal coordinate or its 255-pixel inverse. A system
orientation flag selects each inversion. In the isolated walking fixture, the
shared flag byte at `0x021046f0` is zero, so the source accessors map raw DS
touch `(x, y)` to brick-view `(y, 255 - x)`. This is ROM-backed for the
fixture; normal-route and device settings still need checking.

A first 561-point scan tapped each location in one live Process 75 instance.
That scan changed process state between points, so its selection counts are
invalid and must not be used as mask evidence. A replacement scan restores the
same ready checkpoint before every tap. It sampled raw points from `(8, 24)`
through `(40, 40)`. The ROM selected no object at these points, while the
current floating-point CPU mask reports a hit at all 561 points. The corrected
fixture is `Tests/Fixtures/BrickWall/process-75-edge-scan.json`. This shows the
ray or hit calculation still differs from the ROM. The injected process does
not exercise normal Chapter 10 entry, dragging, collision, the Hammer,
completion, or a script return.

A restored-state coarse scan now covers the full 256×192 DS touch area at
eight-pixel intervals. The ROM selected a brick at 68 of 768 points. The
current Swift mask and test-only Q12 probe each predicted hits at 736 points,
with 668 false positives and no misses on this grid. At all 68 ROM-positive
points, the Q12 probe selected the same object index as the ROM. The ROM hits
cover 16 unique objects, all in board columns 2 and 3 (`objectIndex % 6`), so
the mismatch is strongly concentrated on the horizontal ray/projection axis.
These counts come from the checked Swift implementations against the saved
fixture. The capture is
`Tests/Fixtures/BrickWall/process-75-independent-screen-scan.json`. This is
screen-grid evidence only. The large false-positive count means neither
candidate establishes source-faithful masks. The current native process uses
the floating-point mask as a playable approximation; Chapter 10 completion
and hit parity remain unverified. The rejected points need source-level
diagnosis.

A second scan rebuilds Process 75 from the same Chapter 8 walking checkpoint
and records its ready RAM (`1f819b465774ea1057c7cec52878512d1cb6624f32c9f7d3cbfcdaf6f1a9a015`).
This run selected no objects on the 8-pixel grid. A 2-pixel scan near the
centre found 13 hits, all at raw Y 96, for objects 39 and 44. A raw-X sweep at
raw Y 96 found 108 hits across 13 objects. The Swift mask predicts 738
hits on the coarse grid. The new and earlier scans share the walking checkpoint
hash but have different ready-RAM hashes and different results; the selection
map is therefore not yet reproducible from the walking checkpoint alone.
Keep both captures separate until the RNG state and ready-process setup are
reconciled. See `Tests/Fixtures/BrickWall/process-75-reproducible-scan.json`.

A fresh isolated Process 75 run captures the live object transforms after a
tap at raw `(120, 96)`. The process structure is identified by its update
callback at `0x021FD920`; its camera fields at `+0x2B0`, `+0x2BC`, `+0x2C8` and
`+0x2D4` match the eye, target, right and up vectors used by the native ray.
The captured orientation flag is zero, and the process stores selected object
44. A focused test feeds all 90 captured positions and scales into the
diagnostic mask, which also selects object 44. The compact evidence fixture is
`Tests/Fixtures/BrickWall/process-75-one-tap.json`. This validates one fresh
tap and the camera basis only. It does not validate the full touch grid, drag
collision, hammer return, or story transition.

`OriginalBrickWallTouchRay` now builds the ray from the source camera position,
forward vector and crossed camera axes. It uses the source 20-degree angle,
aspect constant and 192×256 coordinate scaling. This replaces the
projected-face approximation for hit tests.

The source ray builder confirms the touch-ray scale directly. It uses a
192-pixel width, 256-pixel height, their `192 / 256` ratio for the horizontal
axis, an aspect multiplier of `1.33`, and a 20-degree angle. After the source
axis conversion, both ray offsets reduce to a 128-pixel divisor:
`horizontal = (x - 96) / 128 × 1.33 × tan(20°)` and
`vertical = (128 - y) / 128 × 1.33 × tan(20°)`. The native touch-ray formula
already matches this construction. The four shared-edge selection mismatches
therefore remain in Q12 conversion, segment intersection, or face selection.

The follow-up touch probes restored the same isolated save and tried bottom-
screen points `(36, 18)` and `(50, 50)`. The selection field at process offset
`0x448` remained `-1` in both captures. A full 2-pixel scan repeated exactly,
but it reads after one frame and may capture a stale selection. A fresh trace
showed that the input structure held the requested raw coordinates. Touches at
`(120, 96)` and `(128, 96)` selected object 44 on frame four. Touches at
`(136, 96)`, `(128, 88)` and `(128, 104)` did not select an object in four
frames. A per-point 8-pixel scan from a restored checkpoint found only 28
selections out of 768, all along one raw-Y row. These results do not match the
visible wall or the current mask. Resolve the source ray and hit geometry before
using either scan as mask calibration.

A frame-by-frame isolated trace from the same checkpoint gives one verified
selection: raw DS touch `(120, 96)` sets object 44 at process field `0x448` on
frame four. With orientation flag zero, this maps to overlay point `(96, 135)`.
The captured object transform is position `(3.874, 6.5, 0.5)` and scale
`(2, 1, 1)`. The CPU mask intersects that object's full front-face mask at this
point. A follow-up held touch at raw `(120, 110)` left the object transform
unchanged and the process in state 1. This validates one selection point only;
it does not validate drag initiation, movement, or neighbouring masks. The
walking checkpoint has a null inventory-list head at `0x021f7c98`, so it has no
Hammer and cannot exercise the hammer-enabled move path. Holding the touch for
60 frames also left the object unchanged. In this runner, the touch-valid flag
stays set for two frames after `release` and clears on the third. Wait for that
clear before injecting another tap, or the next touch has no fresh input edge.

The original overlay creates a valid item-list node for item `0x3b` after the
first hit. In an isolated run, changing that node's state from zero to one
enabled the Hammer path. After the touch reset, a second press on brick 44
lifted it. Moving the raw touch from `(120, 96)` through `(80, 96)` to `(40, 96)`
and releasing moved the brick to `y = -1.06` within 40 more frames. The source
render showed the cleared cell. This used a direct item-state write, so it is
evidence for the interaction mechanic, not the normal Chapter 10 route.

The completion gate checks inner columns 1–4 in rows 0–11. With Hammer state
one, a source diagnostic that moved all 48 of those objects below `y = -1`
entered process state 200, then state 205 after its delayed sequence; the
update callback returned 1. Leaving brick 44 at its starting height while
moving the other 47 left the process in state 1 after 200 frames. This confirms
the source gate and its one-brick boundary. The outer columns and bottom three
rows are outside this gate. The overlay manager's mapping from callback return
1 to the script's process result still needs to be verified. After 500 more
frames, the injected overlay had returned to the walking scene. Because this
diagnostic injection did not run inside `EP10_R304`, it did not exercise the
script's return table.

A fresh Process 75 injection from the walking checkpoint selected object 12 at
`(36, 18)` after a preceding `(34, 18)` touch and release. The selection field
must be read on the first update. A 4-pixel screen scan recorded 180 positive
samples across 47 object IDs in
`extracted/reference/component-brick-wall-hit-grid-repeat/selection-map.csv`.
This is useful calibration evidence, but it is still a diagnostic process
injection. It does not verify the normal story route or a full-resolution hit
mask. A later 2-pixel scan recorded 684 positive samples across 49 IDs. The
first projected-face comparison used the wrong coordinate basis and matched
none of them. The source ray now uses the recovered axis conversion. Against
all 90 positions and scales read from Process 75 memory, its four-triangle mask
made 677 hit predictions and matched 506 of 684 positive samples against the
one-frame scan. Because that scan may contain stale selections, this score is
not valid calibration. The native process now uses the mask, but that wiring
does not establish source parity. Keep the route marked incomplete until
per-point selection and drag checks match the source.

A new isolated scan reset touch before each tap. It sampled 3,072 raw touch
points at 4-pixel intervals. Each sample released touch, waited three frames,
pressed for four frames, and read the selected-object field. The source selected
a brick at 310 points on frame four. A second scan read the field on frame
five. Across both scans, the source selected a brick at 2,885 sampled points.
A temporary Swift comparison against the captured sweep found 2,885 source
selections. With a barycentric edge tolerance of `0.004`, the mask matched
2,880 selections. A tolerance of `0.016` matched 2,873, but it also matched
the four focused border taps at raw `(16, 32)`, `(28, 32)`, `(30, 28)`, and
`(30, 34)` to source objects 7, 7, 13, and 13. The narrower tolerance misses
the last two focused samples; the wider tolerance increases mismatches elsewhere.
The wider tolerance is retained for those known touch points, but neither result
is source-exact. The connected native mask still predicts hits at points where
the source scan reports none. Capture exact source intersection state around
overlapping edges before changing the selection rule.

A 1-pixel scan of the disputed border region sampled 561 points. The ROM
selected a brick at every point. The mask hit the same brick at 528 points. It
hit a different brick at the other 33 points, all on shared projected edges.
Every source selection still hit a mask triangle. Tested half-pixel and
one-pixel view offsets reduced the full-grid match count, so the ray remains
unchanged. The remaining difference needs the source fixed-point intersection
rules, not a broad screen offset.

Overlay 40 decompilation shows the exact selection order. It tests two triangle
faces for each of the 90 objects. When several faces intersect, it keeps the
hit with the greatest world-X coordinate. The triangle routine uses Q12
fixed-point arithmetic. A native trial with greatest-X ordering matched 2,862
of 2,885 sweep selections, below the nearest-hit approximation's 2,880 with a
`0.004` edge tolerance. The native ray and hit coordinates therefore still
differ from the source path. Keep the gameplay halt until the fixed-point ray
and intersection path matches captured taps.

A fresh reference-runner capture of the sweep's `ready.mln` checkpoint confirms
that the reconstructed seed produces the same object X positions as the live
process for objects 0, 6, 7, 13, 56 and 89. The remaining mismatch is in the
ray or hit-selection calculation, not the random board layout.

The PCM files from these scans are not per-tap audio. Each file contains output
from one runner that restores the same checkpoint for thousands of taps. Its
cue log records BGM state only and does not record effect requests. Do not use
these files to judge the sound for a brick tap. That needs a fresh, single-input
capture with effect-trigger evidence.

`OriginalEventCompletion` uses the process result as the transition-table
index. The decoded source text identifies the three outcomes:

| Process result | Event | Source response |
| --- | ---: | --- |
| 0 | 25 | “There's a door back there!” |
| 1 | 26 | Louie says, “Not all the bricks are out of…” |
| 2 | 27 | Louie asks why Hyde is not doing anything. Hyde replies that he is ready to start. |

This confirms that return `0` is the success route. The native process now
returns `0` after its doorway gate clears. It stays in the puzzle while the
doorway remains obstructed, and returns `2` when the player leaves. The trigger
for source return `1` still needs original execution evidence. The three-outcome
test checks the source transition table and dialogue records.

Do not confuse an update callback's `0` with the process result. The session
marks a puzzle complete when the final process result is `0`. Overlay 40's
final callback returns `1`, and its intermediate wait path returns `2`. A
native port must recover the overlay-manager transition around these callbacks
before it maps them to `EP10_R304` events 25–27.

## Remaining recovery work

- Bind the decoded brick background and face textures to the native scene.
- Reconstruct the procedural brick geometry and its original transforms.
- Match the remaining source ray selection results and drag collision results.
- Supply the normal mode-0 random seed and fixed-cell mask.
- Port the no-tool response, hammer-enabled brick removal, collision,
  validation, reset and exit state changes.
- Capture a normal overlay-40 mode-0 run to verify the interaction and all
  three `EP10_R304` transitions. No Chapter 10 reference checkpoint is
  currently available.

Until those steps are complete, the explicit process halt is safer than
returning a fabricated result. See [the route plan](walkthrough-route-plan.md)
for the chapter-level boundary.

## Source hit-test details

Overlay 40 visits all 90 objects in array order and tests both six-vertex
faces. For each face it keeps the first successful source triangle. Across
object hits, it retains the hit with the greatest source X coordinate
(`iStack_110`), not the nearest ray distance. A nearest-triangle rule can
therefore disagree on shared projected edges.

The face test is more than a ray-triangle barycentric check. The source builds
a fixed-point plane from the face and intersects a finite stylus ray segment
with it. `01ff817c` checks that the hit lies on the ray line, and `01ff8100`
checks the hit's position against the ray endpoints. It then forms vectors
from the hit to the three triangle vertices, normalises them, and checks the
edge-cross winding. A point on a triangle edge uses an additional collinearity
and endpoint-distance path. Vector cross products and dot products use Q12
rounding; length comparisons call the ARM9 square-root unit. Relevant routines
are `overlay_0040/022004f8.c`, `overlay_0040/02200fe4.c`, `arm9/01ff82dc.c`,
`arm9/01ff817c.c`, `arm9/01ff8100.c`, `arm9/020bd21c.c`,
`arm9/020bd2b8.c` and `arm9/020bd1b4.c`.

The source mesh is no longer uncertain: the 36 Q12 coordinate words at
`overlay_0040` address `0x02201adc` decode to the same 12 front-and-side
vertices used by the native candidates. The mismatch is in the ray segment,
fixed-point hit calculation, or validation path, not the local brick shape.

A Q12 plane-and-winding model was evaluated against the four focused raw
touches. With an approximate integer normaliser, it accepted brick 6 on the
first two touches and no hit on the last two. A test-only probe now follows the
source square-root and divider scaling path at `020bd074` and uses the source's
100-unit ray segment. It still predicts 6, 6, 6 and 7, while the ROM selects
7, 7, 13 and 13. A `0x10` allowance in
the winding dot products did not change those results. The probe quantises a
native floating-point ray, so its ray construction remains approximate.
Selecting the probe winner by X, Y or Z also failed to explain the mismatches.

The full-screen scan changes the next target: record the source result at the
plane, ray-line, segment-bound, and winding checks for both accepted and
rejected points. The probe selects the correct object at all 68 coarse-grid
ROM hits but accepts 668 additional points, while the focused border touches
still have four incorrect object IDs. This is evidence of a hit-validation or
Q12 ray-conversion mismatch; it does not isolate which check is wrong. The
float mask remains diagnostic and must stay disconnected from Process 75 until
the comparison matches. This evidence does not establish a normal Chapter 10
route or a completed end-to-end game.

A trial removed the aspect multiplier from the ray's vertical component,
following the renderer's conventional projection matrix. The four captured
border touches then selected bricks 13, 18, 18 and 19 instead of the ROM's
7, 7, 13 and 13. Restore the shared aspect multiplier in both ray axes; the
focused `OriginalBrickWallHitMaskTests` pass with that formula. This rejects
the projection-matrix shortcut but does not resolve the fixed-point mismatch.
