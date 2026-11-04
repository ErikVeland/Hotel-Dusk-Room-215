# Native implementation status

The native-input route covers Chapter 1 through the Chapter 10 ending, with
checkpoint restores between sections. The recorded 3 November 2026 run passed
all 80 ordered sections and validated both required handoff saves. Reproduce it
with `python3 tools/verify_full_route.py --output .build/verification/full-route-001`.
See [verification](verification.md) for the broader suite and fixture requirements.

This route result does not establish uninterrupted device play, every optional
branch or original-game fidelity. Static coverage finds handlers for all 47
chapter-script processes and 15 shared System processes. Handler presence alone
does not prove their behaviour. See [process coverage](story-process-coverage.md).

## Supported systems

- Original script decoding, event selection, conditions, inventory and state updates.
- Map movement, collision, doors, inspection, close-ups and conversations across the tested route.
- Native puzzle processes with original script returns and explicit recovery on unsupported behaviour.
- Resume saves, safe walking checkpoints, input replay and legacy chapter-save loading.
- Written dialogue, previous conversations, journey sketches and original notebook input.
- Original bitmap, animation, texture and model decoding with checked source hashes.
- Recovered music and sound effects, recorded soundtrack switching and supported iOS haptics.
- Two-page book presentation, handedness, hinge pause and fold actions.

The [architecture](../ARCHITECTURE.md) describes ownership and data flow.
Individual [recovery records](README.md) retain source addresses, checked inputs
and limits for each system.

## Remaining fidelity work

| Area | Open work |
| --- | --- |
| Story | Optional branches, cancel paths, alternate endings and uncertain condition side effects. |
| Opening | Connect the recovered 459-command cinematic queue to host scene and resource actions. Play currently starts at arrival. |
| Characters | Complete pose, scheduling, palette, compositor and animation-timing recovery. |
| Rendering | Compare DS rasterisation, jigsaw seams, selected masks, captions, sprites and screen effects. |
| Touch | Compare visible targets, drag planes and left-handed coordinate paths on a supported Duo. |
| Audio | Compare cue timing, envelopes, modulation, ambience, bowling and physical haptics against the original. |
| Saves | Verify every supported interaction branch and recover DS cartridge-save compatibility. |
| Artwork | Review enhanced images in motion, model mapping, visual consistency and device performance. |

Specific known differences need original-game comparisons:

- Chapter 7 process 55 uses recovered cube transforms, `soko.mdf` and the object-9
  blocker rule. CPU-projected route inputs do not verify visible touch mapping.
- Chapter 9 exposes a clue-gated **Search pantry wall** action. The original
  caller for the hidden pantry helper remains unresolved.
- Chapter 10 process 59 accepts back-and-forth pencil strokes. Its native
  completion threshold remains an approximation of the source gesture.
- Chapter 10 process 79 uses the recovered 90-slot board and five-hit rule.
  Its fixed seed and shared face rendering differ from the original variation.
- Bowling result branches continue the story, but scoring still needs comparison.
- Cassette Side A/B recording playback has no recovered payload or cue mapping.
- Game-over artwork and confirmed Retry/Title outcomes are checked. Reveal timing
  still needs comparison.
- Walking uses a longer far plane than the recovered camera to reduce pop-in.
  Camera smoothing uses native floating-point arithmetic.
- Native book typography and controls replace selected original menus and labels.

See [route tracing](route-tracing-workbench.md), [route dependencies](walkthrough-route-plan.md)
and [puzzle fidelity](puzzle-fidelity.md) for the supporting evidence.

## Release checks

Run the ordered route from an empty checkpoint directory after route changes.
Run the broader strict profiles separately and retain missing-fixture failures.
Build the iOS application with the required SDK. Check touch, hinge, lifecycle,
audio, haptics and restored progress on the target device.

Keep raw source records, hashes and offsets when improving a recovered system.
Unknown outcomes must remain explicit. Generated dialogue, guessed transitions
and fabricated puzzle success must not fill a recovery gap.
