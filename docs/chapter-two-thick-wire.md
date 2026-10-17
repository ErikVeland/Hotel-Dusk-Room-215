# Chapter 2 thick-wire suitcase lock

The native overlay-12 controller now supports process 33, the thick-wire variant. It inserts the wire, latches all three pins, turns the lock and opens the suitcase. The original script then starts process 35 for the suitcase contents. That process remains unrecovered. Cash collection and client-list storage are not yet playable.

## Route evidence

Both supplied walkthroughs place this puzzle after cutting the hanger in Room 215. The detailed guide uses `CHP212` for the wire and `CHP213` for the contents. The spoiler-free guide places both after Helen's 5:40 conversation.

The detailed guide says an earlier pin can pop out. Overlay 12 retains reached pins in variant 1. Its timed reset belongs to variant 3. Native behaviour follows the original controller and matching captures.

## Controller differences

`OriginalThinWireProcess` retains its existing name and default thin-wire behaviour. Its explicit `.thick` variant uses the same recovered insertion and pin-contact code.

| Behaviour | Original evidence |
| --- | --- |
| Process 33 selects overlay 12, variant 1 | ARM9 factory `0x0200B334` |
| Contact radius 0.1, wire scale 0.06 | `0x021FCD7C` |
| Sixteen pin steps latch a pin, with at most eighteen steps of travel | `0x022045BC` |
| Latched pins retain their positions | `0x02204850` |
| All three pins complete the puzzle | `0x021FDB3C`, `0x02204D50` |
| Lock waits 191 updates, then eases towards a half-turn parameter for 51 updates | `0x02204D50` |
| Camera moves over 45 updates and holds through update 60 | `0x021FE1DC` |
| Lid acceleration, target-height movement and final hold | `0x021FE1DC` |
| Both quit outcomes and the success return | `0x021FF780`, shared System script |

The native process records puzzle flag 9 when the pins complete. The System script sets the suitcase story flag and starts process 35. Successful completion must not skip the contents process or award its items early.

## Presentation

`OriginalThinWireRenderer` uses `trick/hanger/kitasen.mdf` and its original texture for the thick wire. Thin wire retains `trick/bag/harigane.mdf`. The lock uses the existing source bitmap layers and a larger cursor. The opening draw rotates suitcase nodes 1–4 about X, following `0x02203014`.

The session plays the original pin-latch effect from archive 1, entry 33. Opening uses archive 0, entry 55. Scrape playback keeps the existing movement-dependent volume.

Pixel inspection confirms that the thin source model remains visible during insertion. Its shading and edge coverage differ from the original. The `geometry` reference records the original submitted wire geometry and textures for further comparison.

Exact model rasterisation, acoustic matching, visual fades, caption presentation and physical-device interaction remain unverified. The recovered fade durations control process transitions, but the wire view does not yet draw those fades.

## Captures and checks

The `tools/reference/chapter-two-thick-wire-*.txt` files use ordinary input and existing original checkpoints. They do not write game memory. Local output is under matching `extracted/reference` directories.

- `approach`, `items`, `select` and `use` record item selection and puzzle entry.
- `insert` and `pins` record insertion, all three pins and release behaviour.
- `opening` records the lock turn, camera, lid and process-35 boundary.
- `quit-untouched` and `quit-inserted` record the two quit outcomes.

`OriginalThickWireProcessTests` compares pin coordinates, depths, reached flags, camera coordinates, lid rotation and lock rotation. It compares every original game-state byte for both quits and the successful process-35 boundary. The session route helper exercises real movement, item use, insertion, pin input and pause/resume.

## Next work

Process 35 now connects object selection, dragging, cash acquisition, presentation and session return. See [Suitcase contents recovery](chapter-two-suitcase-contents.md).

Process 35 uses overlay 24, selected by factory overlay index 23. Its object positions, hit regions, item animation and cash-return state now have comparisons. Extend the route downstairs after client-list storage.

## Verification on 18 October 2026

The Chapter 2 route and five focused controller checks passed without failures or skips. A subsequent 11-check run passed the new-game route, thin-wire regressions and shared Metal rendering. The final 13-check run passed both wire controllers, wire visibility and hanger rendering, including the exact sampled wall colours. `git diff --check` passed.

The opening and insertion images were visually inspected. At that verification run, the route checks expected a halt at process 35. The newer contents route removes that halt. They establish suitcase unlocking and the correct next process, not playable suitcase contents or full-game completion.

```sh
SNAPSHOT_DIR=/tmp/hotel-thick-wire-final DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalThinWireProcessTests|OriginalThickWireProcessTests|OriginalModelMetalTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock'
```
