# Chapter 5 component recovery

Processes 38 and 60 have independent component checks against the supplied ROM.
These checks use modified walking checkpoints to request each original process
through its own factory. They do not establish a normal Chapter 5 playthrough.
No puzzle result, item, flag or puzzle-instance field is patched by the capture
script. The native game does not execute the ROM runner.

## Doll repair, process 38

Factory 0x0200B334 loads slot 15, overlay 16, and allocates 0x748 bytes. The
shared native host already provides the doll process and renderer. The independent
capture confirms that the zigzag input records ten stitches and produces seam
mask 0x3F, entering success stage 3. Recognition comes from 0x021FE350 and
0x021FECCC. This is a component recognition comparison, not a frame-exact
comparison of the complete success animation or its story return.

The independent check corrected two sound arguments. 0x0200A060 takes entry
before archive. The stitch call at 0x021FECCC uses archive 35, entry 0. The shared
completion helper at 0x02064DC4 uses archive 1, entry 0. Both cues now resolve
through the original sound archive and have a regression check.

## Linen wagon, process 60

Factory 0x0200B334 loads slot 33, overlay 33, and allocates 0x704 bytes. The new
`OriginalLinenWagonProcess` is a standalone, deterministic module, ready for host
and renderer integration. It does not yet provide a playable linen-wagon screen.

| Behaviour | Original function |
| --- | --- |
| Outer startup, 31-update delay and exit | 0x021FD194 |
| Touch capture, release, reveal and completion | 0x021FD360 |
| Original sheet placement, depths and RNG rotations | 0x021FE010 |
| Circular hit test, lowest Z wins overlap | 0x021FDEF8 |
| Drop direction and exact cart boundaries | 0x021FF970 |
| Throw movement and offscreen removal | 0x021FF868 |
| All six sheets removed | 0x021FDFE0 |
| Touch rectangles initialized in overlay BSS | 0x021FFC18 |

The module retains original 20.12 coordinates. Its page coordinates are 192×256;
world X is `(pageX - 96) / 96` and world Y is `(128 - pageY) / 96`. The source
hit radius is 40 page pixels. The original cart rectangle includes its left/top
edge and excludes its right/bottom edge: X [42,158), Y [69,208).

Release outside the cart chooses one of eight throw directions. Sheets move by
171 fixed-point units on each selected axis until either world coordinate exceeds
two units in magnitude, then retain removal marker 10. Releasing a sheet inside
the cart keeps it available. Return values are 2 before a successful throw, 1
after a throw, and 0 after taking the revealed gun.

The committed compact fixture records original initial positions, depths,
rotations, held positions, throw directions, removed positions, cover/gun alpha
and the take return value. It includes ROM, overlay, checkpoint and command hashes.
Five tests cover source comparisons, source rectangle boundaries, cancellation
results and the independent doll recognition check.

For integration, advance `update` once per original update with held page touch.
Apply returned sound/fade effects, provide actual animation/fade completion, draw
the source wagon and sheet artwork at the exposed positions, and pass `completed`
to `runner.completeProcess`. Resource loading and rendering have their own timing
in the original engine; the component tests do not establish presentation timing.
The original script must award items and choose the next event from the returned
value. Do not replace that route with an unconditional success.

## Reproduce

Build the pinned reference runner as described in `tools/reference/README.md`, then:

```sh
python3 tools/capture_chapter_five_components.py
python3 tools/verify.py --profile fast --strict
```

The capture starts from `extracted/reference/entrance/entrance.mln`, whose input
script is `tools/reference/entrance.txt`. `--reuse-walking-base` skips rebuilding
the derived walking checkpoint. Full RAM, images and command logs stay under
`extracted/reference/component-*`. Compact source values are written to
`Tests/Fixtures/ChapterFiveComponents/source-trace.json`.

## Native integration, 26 October 2026

Process 60 now has a session host, touch view and original-artwork renderer.
`OriginalLinenWagonIntegrationTests` enters the Chapter 5 source event at time block
2, removes all six sheets through touch input, opens the cover, reveals and takes
the gun, and verifies completion flag 36. This test passed with Metal access in
1.1 seconds. Pause releases an active drag. The source script retains responsibility
for awarding the item and continuing the conversation.

The renderer uses the original fixed-point quads and transforms for the cart,
cover and gun, plus the four sheet images selected by highlight state. The source
`020A63E0` step waits for image upload; the host completes that step after loading
`bg2.bin`. Ready and revealed native images were inspected. The isolated original
capture has corrupted background textures, so it is not a complete pixel baseline.
Supporting effects and full presentation timing remain to be compared. The earlier
standalone-only status above describes the component before this integration.
