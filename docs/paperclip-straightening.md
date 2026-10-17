# Paperclip straightening

Process 28 now runs through normal native play. Search and close-up inventory launch it, and its original System response awards the thin wire.

The supplied walkthrough identifies this dependency in `CHP107`. Original execution shows that selecting **Paper Clip → Use** starts the puzzle directly. The player does not select a suitcase target first.

## Recovered mechanics

`OriginalPaperclipProcess` transcribes physical overlay 9. `OriginalPaperclipProjection` supplies the fixed-point touch-plane intersection.

| Behaviour | Original evidence |
| --- | --- |
| Initial 16 vertices | Table at `0x02201D08` |
| Segment lengths and signed joint angles | `0x021FCBEC`, `0x02025464` |
| Initial adjustment | Twenty straightening steps on joints 0–3, then retained angle limits |
| Active sections | Joints 0–3, 4–7 and 8–13, with handles at vertices 0, 4 and 15 |
| Drag direction | `0x021FDDE8` compares the current endpoint distance with one step in each direction |
| Joint step | `0x02200994` and `0x02200A5C`, step 0.015 radians |
| Straightening | The middle joint stays fixed. The other joints move towards the next threshold. |
| Spring-back | `0x021FE10C` alternates bend direction with a decreasing step count |
| Shape reconstruction | `0x02200528` retains vertices 8 and 9 and rebuilds the two chains |
| Touch ray and hit planes | `0x021FF824`, `0x021FF9F0`, `0x021FFAF4` |
| Successful exit | Result 0 and puzzle flag 4 through `0x02026DD4` |
| Quit after grabbing | Result 1 |
| Quit before grabbing | Result 2 |

The touch ray uses an eye at `(0,32768,0)` and a target at `(0,410,0)`. Grab rectangles extend 2048 fixed-point units around the handle. The drag plane extends 20480 units around the origin. A held touch outside the plane must remain held until release.

The checked large-drag sequence triggers spring-back, then advances to the second section when its angles meet the threshold. The native model reproduces this original behaviour.

## Story return

The inventory table `data/system/trickitem.bin` maps item 8 to trick 5 at row 0. Search and close-up hosts start process `5 + 23`.

On return, `0x0202830C` selects mode 30 with the table row and result. System events 1, 2 and 3 handle success, a touched quit and an untouched quit. Event 1 supplies the original dialogue, adds thin wire item 9 and replaces paperclip item 8. Mode 30 completion clears the dialogue presentation without a further story transition.

The event-runner checks launch through the decoded inventory table and compare all 32,088 game-state bytes after each outcome. The session route separately reaches this puzzle from arrival through normal input. It checks quit, re-entry, all three drag stages, wire replacement and return to the brochure.

## Native host and rendering

`OriginalInventoryProcessTable` decodes the six original rows and verifies the bundled hash. It checks item possession, required items, game flag 26 and chapter restrictions. Other item processes still stop explicitly when their native implementation is missing.

The runner keeps inventory processes separate from embedded script processes. The session forwards held page touches, clears them on pause, advances fade timers and plays archive-0 sound cues. The original System event owns the inventory change.

`OriginalPaperclipRenderer` transcribes the segment construction at `0x02200B98` and quad joins at `0x021FFBE0`. Each segment has eight fixed-point vertices. Its endpoints move 20% towards the midpoint before the faces join adjacent segments. The renderer applies the process translation and Y rotation during the completed-wire animation.

The desk uses the original quad, rotation and BIN texture. The active handle uses `PointLight.bin`, the original half-unit quad, scale ramp and 31-step pulse counter. The camera uses the original 30-degree half-angle, aspect ratio, near plane and far plane. Native snapshots confirm that the puzzle draws, but do not prove DS pixel equivalence.

## Reference captures

The scripts under `tools/reference/room215-paperclip-*.txt` use ordinary inputs without RAM writes.

| Checkpoint | Save-state SHA-256 |
| --- | --- |
| `room215-paperclip-puzzle/puzzle` | `02e27beea47078b76be86002cb7eb2ad50803430b7545b07524201dd6cedfe2f` |
| `room215-paperclip-straighten/stage0` | `88c8d9d78562d449dec47aeeb557e52fb6262da7a8bc5179f866291e5a5e0f58` |
| `room215-paperclip-straighten/stage2` | `7141eca31f66a7043058cc409e32b8825e2a3c24579fa2990b6d0a2122fee80c` |
| `room215-paperclip-straighten/stage4` | `e0c9a6f8a6b0c1166032cd23f68ebc69b2ef355222aa48cb4e186e36d5e76cb2` |
| `room215-paperclip-aftermath/step10` | `d12fde9a8684904b32054cbb32748d5c3f6799b7a8002bd4ee84ce16b268a4d9` |
| `room215-paperclip-quit-untouched/step4` | `9d953e5300eb8082d1a6ee018aa20730f27cdf961b9cb33882a5beb03a7c2602` |
| `room215-paperclip-quit-touched/step4` | `a049528dd7d7b8a5938b68033a42d5c546424b6fc2230b79046a32450419b03a` |

The live process is at RAM offset `0x21F410` in these captures. Its phase and stage are at `+0x2A8` and `+0x2AA`. Vertices start at `+0x4D8`, lengths at `+0x658`, angles at `+0x790`, and limits at `+0x800`.

## Validation and remaining work

On 17 October 2026, 21 targeted Swift checks passed together with no failures or skips. These cover the paperclip, event runner, event completion, close-up and normal session route. The route check includes pause/resume, quit, re-entry and wire acquisition. `git diff --check` also passed.

The initial vertices and joint angles match within 0.00001. The captured drag sequence reaches all three original stages. Joint angles match within 0.00001 radians at the stage checkpoints and after the checked spring-back.

Remaining work:

- Draw the visual fades. Their timers already control the process return.
- Compare DS brightness, lighting, marker blending and rasterisation. Native rendering currently looks brighter than the reference capture.
- Implement the original spring-back rumble. The host records this missing effect in its presentation trace.
- Draw the original item notice image and check sound timing. The System text and inventory replacement already run.
- Compare continuous touch positions, animation timing and rendered pixels. Checkpoint tolerances do not prove complete per-frame equivalence.
- Continue thin-wire lock picking and the delivery route.
- Check iOS, physical Duo, accessibility and left-handed input.
