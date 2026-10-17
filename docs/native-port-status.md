# Native implementation status

The architecture is Swift and SwiftUI, with Metal for the Duo book material. The original ROM is the comparison reference. No emulator integration is planned or included.

The native game remains incomplete. You can play only the recovered Chapter 1 opening. The app states that limit directly.

## Playable opening slice

**Begin Chapter 1** starts a new game at the hotel arrival in `EP1_R102`. The slice runs these original events:

1. Event 0: Kyle's narration. The original dialogue text appears on the book pages. Tap to continue.
2. Event 1: process 56, the entrance. Tap the door handle on the right page.
3. Event 2: the lobby arrival. Play stops when Kyle can explore, because exploration is not recovered.

`OriginalEventRunner` connects the recovered selector, conditions, state commands, dialogue packets and event exits. It marks a completed event at (current map, event key), as `0x0203D61C` does through `0x02097FC0`. Opcodes that change only controller or display state continue without a drawing: 3, 26, 27, 28, 43, 44 and the empty dispatcher cases. All other unrecovered opcodes, exit modes and processes stop play and show the program, event and source offset.

These parts of the slice are approximations:

- The opening cinematic does not run. Play starts at the arrival event that the reference runner reaches after the opening.
- The entrance shows the original `u01`–`u03` and `d01`–`d03` panels, not the 3D R101 scene. An outline marks the original handle rectangle. Fades are counted for timing but not drawn.
- Text control `%m0NN` starts `SEQ_BGM_NN`. The meaning of the other mode values is not known.
- Text colours 1 and 2 use approximate ink tones. Portraits, talk backgrounds and character animation are not drawn.
- Screen 1 maps to the left page and screen 0 to the right page. Left-handed layout is not supported yet. The earlier demonstration was retired because it contained invented dialogue, arbitrary items, free room travel, chapter shortcuts and a procedural corridor. The white corridor rectangles were artifacts of that prototype, not original game graphics.

## Source-backed Swift modules

- `Engine/Original/OriginalData.swift`: bounded, strict CiNG dictionary decoder. Its 64 KiB ring handles initial zeroes, overlap and wraparound.
- `OriginalScript.swift`: hash-checked source catalog, indexed text, original debug labels and raw choice records. Control codes and empty strings survive unchanged.
- `OriginalBlockGraph.swift`: all four BLK tables and child spans. Known command fields come from the original ARM9 dispatch handlers. Unknown opcodes preserve their raw bytes.
- `OriginalControllerCore.swift`: isolated original flag and wait handlers. It deliberately does not advance events because the original animation lookahead and dialogue phases are not recovered.
- `OriginalConditions.swift`: original CHK lists and pure predicates. Successful original checks also commit selector context; that effect remains unimplemented. Unknown predicates and missing state return unresolved results.
- `OriginalInventory.swift`: native ordered inventory and separate acquisition state. Removal does not automatically erase acquisition state. IDs outside recovered storage fail explicitly.
- `Renderer/OriginalAnimation.swift`: native ANM decoder with preserved index buffers, original palettes and loop restart indices. Checkpoints identify their original payload hash.
- `Renderer/MetalBookMaterial.swift` and `Metal/BookPaper.metal`: actual GPU rendering for paper stock, hinge-driven normals and binding shadows. Tests compile the shader and read rendered GPU textures.

These modules are recovery foundations, not a complete event interpreter. The development jigsaw also retains unverified placement tolerances and has no original story gating yet. It must not be treated as proof that all original puzzles have been ported.

## Validation boundaries

Independent Python extraction and Swift decoding are compared using original payload, index-buffer, palette and RGBA hashes. Original command and condition fixtures are selected by exact program name and byte offset. Native handler tests check source behaviors such as preserving item acquisition state and the wait counter's extra update.

Passing these checks proves the covered transformations agree with recovered source evidence. It does not prove a chapter, puzzle sequence, ending or audio mix matches the running ROM. Full game comparisons, save persistence, original audio cue timing and remaining handlers are outstanding.

## Remaining native work

1. Recover startup and initial game state, event selection and all condition side effects.
2. Translate all dispatcher handlers, dialogue control codes and character scheduling.
3. Recover original scene geometry, textures, collision, camera and touch behavior.
4. Translate every original puzzle and its chapter prerequisites, including microphone and hinge interactions.
5. Restore original audio event selection, effects, envelope/modulation behavior and measured timing.
6. Recover notebook, original saves, failure states, all endings and chapter transitions.
7. Compare matching ROM/native input traces and screen/audio checkpoints throughout the complete game.

The supplied ROM and source artifacts are retained locally. Unverified data stays available for recovery; unverified gameplay stays unavailable in the app.
