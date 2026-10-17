# Thin-wire lock attempt

Process 29 now runs from normal Chapter 1 play. Use the thin wire on the suitcase, insert it, then press all three lock pins. The original failure dialogue follows. The suitcase stays closed and the player keeps the wire.

The supplied detailed walkthrough describes this dependency in `CHP107`. The guide gives the route. Overlay 12 and matching ROM captures establish the mechanics and state changes.

## Recovered mechanics

| Behaviour | Original evidence |
| --- | --- |
| Process 29 uses variant 0 | ARM9 factory `0x0200B334`, overlay constructor `0x021FCB54` |
| Wire insertion and touch plane | `0x021FD78C`, shared suitcase projection |
| Alignment and camera movement | `0x021FDBB0` |
| Lock coordinates and contours | `0x02205AF4`, `0x02203E9C`, `0x02203EC0`, `0x02203EE8` |
| Cursor contact | `0x02203F74`, `0x02204214` |
| Pin pressure and spring return | `0x022045BC`, `0x02204850` |
| Completion after all three retained flags | `0x02204D50`, `0x021FDB3C` |
| Scrape volume | `0x02207874` |
| Model and bitmap drawing | `0x021FFB3C`, `0x02202950`, `0x022056BC`, `0x02201B7C` |

Each pin springs back after release. Its reached flag remains set once its depth reaches eight steps. All three flags complete the attempt. The native model retains this distinction.

The cursor moves in fixed-point steps and checks the original pin contour vertices and midpoints. Captured pin checkpoints match cursor position, pin positions, depths, retained flags, process phase and stage exactly. The reference replay accounts for the DS input sampler's one-frame delay.

## Story and session boundaries

The room script has no matching mode-16 event for item 9 at area 3, component 4. The original dispatcher `0x0203A444` then selects the shared System event. `OriginalEventRunner.searchFallback` now supports that selection. The session retains and restores the room runner.

| Outcome | Process result | Persistent changes |
| --- | --- | --- |
| All three pins reached | 0 | Puzzle flag 5, then game flag 5 through the System dialogue |
| Quit after insertion | 1 | No game-state changes |
| Quit before insertion | 2 | No game-state changes |

All 32,088 bytes match the original after each outcome. The model owns puzzle completion. The original script owns the story flag.

The normal session route uses ordinary movement, item selection and held touches. It covers wire acquisition, puzzle entry, quit and re-entry, pause and resume, insertion, all three pins and return to Room 215.

## Rendering and audio

`OriginalThinWireRenderer` loads the original suitcase and wire models. It applies the original position, scale and Euler rotations. The lock uses `hole.bin`, `01.bin`, `02.bin`, `03.bin` and `bg.bin`, with the recovered quad sizes and layer order. The cursor uses the original ten fixed-point vertices.

The session sends archive-0 effect 33 and its movement-dependent volume to the native audio adapter. Puzzle completion and quit stop this effect. Exact acoustic matching remains unverified.

Native page snapshots show the insertion and pin stages. DS pixel equivalence is not established. The common puzzle caption and rumble remain recorded presentation gaps. Fade timers advance, but the visual fades are not drawn. Physical Duo touch, hinge and lifecycle behaviour remain unverified.

## Reference inputs

The `tools/reference/room215-thin-wire-*.txt` scripts use ordinary input. They do not modify RAM. Local captures remain under `extracted/reference/room215-thin-wire-*`.

`OriginalThinWireProcessTests` covers insertion, pin checkpoints, both quit results, invalid input and full story-state comparisons. The normal route check is `LayoutSnapshotTests.testRenderPlayableLobbyAndRingBellThroughSession`.

## Next route prerequisite

The captured route does not yet trigger the parcel delivery. `EP1_R205` event 28 requires completed keywords 0, 1 and 2, plus event flag 25. The current reference has only keyword 0 completed. Walking to the door therefore does not prove delivery progression.

The extended native route now resolves these questions and reaches the knock. Registration has a complete original state comparison. The full original delivery route still needs recording. See [Dunning and delivery](dunning-delivery-route.md). The exploratory `room215-delivery-*` references record movement only. They do not establish a completed delivery route. The thin-wire game flag is not among event 28's conditions.

## Validation recorded on 17 October 2026

The targeted Swift run passed 29 tests with no failures or skips. It covered thin-wire mechanics and story returns, suitcase and paperclip regressions, search fallback, event execution, completion rules and the normal session route. The route included quit/re-entry and pause/resume checks. Native page snapshots were saved locally for visual inspection. `git diff --check` also passed.

These checks establish the covered route and state outcomes. They do not establish full-game playability or device fidelity.
