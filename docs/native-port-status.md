# Native implementation status

The architecture is Swift and SwiftUI, with Metal for the Duo book material. The original ROM is the comparison reference. No emulator integration is planned or included.

The native game remains incomplete. You can play only the recovered Chapter 1 opening. The app states that limit directly.

## Playable opening slice

**Begin Chapter 1** starts a new game at the hotel arrival in `EP1_R102`. The slice runs these original events:

1. Event 0: Kyle's narration. The original dialogue text appears on the book pages. Tap to continue.
2. Event 1: process 56, the entrance. Tap the door handle on the right page.
3. Event 2: the lobby arrival. Play stops when Kyle can explore, because exploration is not recovered.

The runner also plays the next story path, but normal play cannot reach it yet. The map walk to search area 2 and the 3D search view that picks the bell (node `obj02`) are not recovered. `OriginalEventRunner.lookInSearchView(area:subarea:table:)` takes that result and continues:

4. Event 3: Kyle looks at the counter bell (mode 10 closeup).
5. Event 4: process 24, overlay 32. Tap the bell three times, or tap the quit button. The quit result runs event 5, which asks the search view to reload, and play stops at exploration.
6. Events 7 to 12: Dunning's arrival and the suite offer. Opcode 10 kind 5 shows the original choice prompt (KIF labels). The answer is a mode-5 event; the saved frame then resumes event 12.
7. Event 16: process 25, overlay 1 (`CSign`). Drag right across each line of the registration card to sign it. The completed card returns 0; the quit button returns 1 or 2.
8. Events 19 to 27: the name, the room key and the brochure. Opcode 6 adds each item and shows its notice pages.
9. "Hold on" interrupts: on armed pages the touch page shows a pulsing icon. Pressing it plays the mode-6 event and its choice. The interrupted event then resumes and skips the `%!` lines.
10. Event 28: the question menu. The menu lists the `EP1_.ttk` topics that Dunning can be asked about. Answers are mode-1 events; "Leave" plays the mode-4 exit.

After the menu, the talk ends when the selector finds no event. Play then returns to exploration, which is not recovered. To ask the remaining topics, the original talks to Dunning again from exploration (mode 0).

For simulator checks, a Debug build reads the environment variable `HOTEL_DUSK_FIXTURE`. `R102-bell-look` supplies the look result for area 2, subarea 2 at R102 exploration. `R102-sign` and `R102-event-N` play the original script with fixed inputs until process 25 or event N starts. These are isolated component inputs, like the reference runner's diagnostic writes. While one is set, a Debug build also ignores a closed hinge reading, because the iPhone Duo simulator can boot folded. Release builds ignore all of them, and the app shows no control for them.

`OriginalEventRunner` connects the recovered selector, conditions, state commands, dialogue packets and event exits. It marks a completed event at (current map, event key), as `0x0203D61C` does through `0x02097FC0`. Opcodes that change only controller or display state continue without a drawing: 3, 26, 27, 28, 43, 44 and the empty dispatcher cases. All other unrecovered opcodes, exit modes and processes stop play and show the program, event and source offset.

These parts of the slice are approximations:

- The opening cinematic does not run. Play starts at the arrival event that the reference runner reaches after the opening.
- The entrance shows the original `u01`–`u03` and `d01`–`d03` panels, not the 3D R101 scene. An outline marks the original handle rectangle. Fades are counted for timing but not drawn.
- Text control `%m0NN` starts `SEQ_BGM_NN`. The meaning of the other mode values is not known.
- Text colours 1 and 2 use approximate ink tones. Portraits, talk backgrounds and character animation are not drawn.
- The bell page shows `bell02` with `bell01` on top. The bell swing angle, the trick-button sprites and the talk background `R102_03` on the other screen are not drawn. Outlines mark the original bell rectangle and quit button.
- The registration card shows `signnote` and reveals `signnote02` per field as the strokes grow. The pen sprite and fades are not drawn.
- The choice prompt, the question menu and the interrupt icon use book typography, not the original menu graphics. The question menu does not list items that Kyle can show.
- The menu's `+0x6C = -1` branch (a mode-26 answer from the partner's scene) is not recovered. Topic answers use the mode-1 branch.
- The interrupt stays armed after a replay in the same way as `0x0203F57C`. When the original text window accepts a second press is not verified against the ROM.
- The original shows a Chapter 1 title card after the entrance; the native slice does not.
- The request stack at `0x021046B8` is kept in the runner. The map and search processes that read it are not recovered.
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
