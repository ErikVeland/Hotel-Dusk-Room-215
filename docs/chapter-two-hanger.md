# Chapter 2 hanger recovery

The walkthrough identifies the hanger and thick-wire route as `CHP212`. Native play now reaches the hanger close-up, uses the pliers and cuts the hanger. The original System script awards the thick wire after two valid cuts. The successful native route matches all 32,088 original game-state bytes. The [thick-wire suitcase puzzle](chapter-two-thick-wire.md) now opens the suitcase. Its contents remain unfinished.

## Room interaction

Room 215 uses map `R205`. Search area 4 contains the hanger (`obj02`, subarea 2). Selecting it runs the room response and opens view 258. Its hanger layer uses event 259. The native route reaches this close-up from the hotel entrance through ordinary inputs. The checkpoint route compares all 32,088 game-state bytes. The close-up also has an original pixel and hit-map comparison.

Using the pliers (item 15) selects shared `System` event 994 from the close-up, or event 995 from the model search. Both lead to event 996 and process 32. The factory at `0x0200B334` loads overlay 4 through overlay selector 3.

Close-up item selection and cancellation now use the session input path. Confirmation passes the selected layer's event as the mode-16 subarea, with area `FFFF`. This follows state 11 at `0x02063BDC`. The item must be in inventory. Selection and cancellation are disabled while play is paused. Inventory tricks, such as paperclip straightening, retain their existing path.

`OriginalPlaySession` owns process 32, its renderer, held touch and screen effects. `OriginalHangerView` forwards page touches and Back. The session clears held input when paused or stopped. Process completion closes the close-up and restores the surrounding model search. The original object flag hides the hanger after success.

## Recovered cutting rules

`OriginalHangerCuts` owns the accepted cuts. `OriginalHangerProcess` owns controller phases, animation update counts, camera bounds, pliers placement and opening, sound and fade requests, exit results and completion requests.

| Behaviour | Original evidence |
| --- | --- |
| Four fixed-point hit regions | `0x022005FC`, original controller offset `0x2F8` |
| Press acceptance and 16-pixel separation | `0x021FD644` |
| Polygon edge tests | `0x02202B2C` |
| Projection onto the wire centre line | `0x02202C74`, six source floats at `0x02203F60` |
| Cut count | `0x021FD7EC` |
| Usable wire check | `0x022030C8` |
| Camera and cutting stages | `0x021FD95C` |
| Orthographic camera bounds | `0x021FE51C` |
| Pliers placement and angle | `0x02203C5C`, `0x02025464` |
| Exit fade and 30-update delay | `0x021FE3C0` |

The controller clamps the page's vertical touch coordinate to 31–223. A press must be more than 16 pixels from the last accepted cut. Each accepted touch projects onto the wire centre line. Conversion to fixed point rounds halfway values away from zero.

Two cuts complete an attempt. Both must lie low enough on the hanger, and their horizontal separation must be at least half a world unit. The native rule preserves the original floating-point threshold and rounding. Upper cuts and short pieces fail. Repeated cuts within the exclusion radius do not count.

The first cut uses 61 camera-in updates, a setup update, 61 cutting updates, another setup update and 61 camera-out updates. A successful second cut shortens the cutting stage to 31 updates. The second camera-out stage uses 121 updates. The sound starts at cutting counter 30. Initialisation stages and exit fades add their own updates.

Camera interpolation rounds its fraction to fixed point before multiplying the movement vector. Camera bounds then round halfway values away from zero. The return movement retains its frame-59 camera, including the slight remaining zoom. These bounds match the captured original values exactly. The pliers position is offset by 0.08 units along the selected wire's normal. Position and opening match the captures exactly. Rotation comparisons allow a tolerance of `0.000001` because native inverse trigonometry can differ from the DS library.

## Outcomes and evidence

| Outcome | Return value | Story effect |
| --- | --- | --- |
| Usable wire | 0 | Puzzle flag 8, hidden hanger object flag 3, thick wire item 16 |
| Invalid pair of cuts or quit after a cut | 1 | No thick wire |
| Quit before cutting | 2 | No thick wire |

`finishHanger` marks process 32 complete only for result 0. The original System script owns the item and object changes. Success, short-wire failure, upper-cut failure and both quit outcomes match all 32,088 original game-state bytes in runner tests. Each outcome is checked through both item-use entry paths. These tests return the process result directly. They do not prove a playable native cutting UI.

The separate native route now supplies ordinary session input for both cuts. It pauses and resumes during the first cutting animation, then completes the second cut and receives item 16. This route supplies no process result. The session also marks puzzle completion when the successful cut occurs, before the process returns.

## Rendering

`OriginalHangerRenderer` draws the supplied `Hanga` and `penchi` models, the `gabe` wall texture and both hook layers. The original hanger material has an unbound texture slot. Its native draw therefore uses vertex colour, despite the model naming a `hang` texture. The pliers halves rotate separately about Y. The camera uses recovered fixed-point bounds in the rotated page orientation.

The game conceals each cut with a small wall-textured quad at depth 1. `0x02203178` extends this quad 0.05 units across the wire and 0.025 units along it. Native vertices match captures for lower, upper-left and upper-right cuts. `0x02203700` derives the patch texture coordinates from the wire position.

The wall and hook panels use polygon alpha 30 over an opaque black clear colour. Cut covers use alpha 31. The native panel shader preserves this blend and the original five-bit display capture. Five sampled wall pixels now match the original RGB values exactly. This does not establish complete image equivalence. `chapter-two-hanger-geometry` records the original polygon attributes, display registers and uploaded texture and palette bytes.

The session uses `OriginalScreenEffects` for the entrance fade, white completion flash and exit fade. Sound entry 32 plays at the recovered cutting counter. Native image controls remain outside the original bitmap UI. Exact DS rasterisation, all lighting and edge pixels, caption presentation, left-handed play and wall-clock timing remain unverified.

Reference inputs are in `tools/reference/chapter-two-hanger-*.txt`. They continue the existing modified delivery fixture without new memory writes. The original controller is at `0x02258850` in these puzzle captures. The four hit regions, accepted cut points, selected regions and last-touch coordinates match the recorded controller bytes.

The DS sometimes runs zero or two controller updates between video captures. Timing comparisons therefore align by the original animation counter. They then compare the controller phase, severed-cut flags, camera bounds and pliers state. Separate checks enforce the recovered update counts. Wall-clock animation equivalence remains unverified.

## Remaining work

The connected hanger route passed six checks on 18 October 2026. These covered the new-game route, Chapter 2 retries and success, the shared Metal renderer, and hanger rendering. The Chapter 2 route covered untouched quit, quit after one cut, short-wire failure and upper-cut failure before successful re-entry. Every returned game-state byte matched the corresponding original capture. The final hanger-removed page was visually inspected.

The first precise wall-pixel check exposed the missing polygon blend and display-capture quantisation. After correcting those steps, all 16 focused hanger checks passed without skips. These cover cut geometry, process behaviour, cut-cover vertices, rendering stages and exact sampled wall RGB values. Hook overlap, model edges and full-frame pixel equivalence remain unverified.

On 18 October 2026, all 24 targeted checks passed without skips. These cover the new-game route, Chapter 2 checkpoint route, close-up pixels and hit maps, cut geometry and controller behaviour. A subsequent five-check run passed after adding both original quit-state comparisons. The native close-up screenshot was visually inspected. `git diff --check` passed.

The camera and item-selection extension adds an upper-wire pliers check. Its 25-check run passed both native routes and all cut-geometry and close-up checks. The runner assertion initially expected the intermediate selection event. The runner had already advanced to process event 996. After correcting that assertion, all six hanger process checks passed without skips. The other 19 checks were unchanged and were not repeated. The updated close-up screenshot was visually inspected. `git diff --check` passed.

```sh
SNAPSHOT_DIR=/tmp/hotel-chapter-two-hanger-final DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalHangerCutsTests|OriginalHangerProcessTests|OriginalChapterTwoRouteTests|OriginalSearchCloseupTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```

- Compare remaining edge pixels, brightness masks and caption presentation with the original.
- Check left-handed play and physical touch behaviour on the Duo device.
- Continue with the suitcase contents. The [thick-wire suitcase process](chapter-two-thick-wire.md) now reaches that boundary.

The original reference entry is `chapter-two-hanger-use/puzzle`. Successful cuts use page coordinates `(45,148)` and `(145,148)`. The reference input files use the rotated DS coordinates `(107,45)` and `(107,145)`.
