# Native implementation status

The architecture is Swift and SwiftUI, with Metal for the Duo book material. The original ROM is the comparison reference. No emulator integration is planned or included.

The native game remains incomplete. A fresh-game native-input test chain reaches the Chapter 10 ending through instant-save checkpoints. The Chapter 7 process-55 model does not match the original overlay, so the chain uses a synthetic puzzle success and does not prove a fully source-matched game route. Focused tests restore checkpoints between route sections. Original-device checks remain open for selected route triggers, puzzle gestures, bowling scores and audio. Game-over retries and original presentation also remain unfinished. See the [route tracing workbench](route-tracing-workbench.md) and [walkthrough route plan](walkthrough-route-plan.md) for the current boundaries.

## Playable opening slice

**Begin Chapter 1** starts a new game at the hotel arrival in `EP1_R102`. The slice runs these original events:

1. Event 0: Kyle's narration. The original dialogue text appears on the book pages. Tap to continue.
2. Event 1: process 56, the entrance. Tap the door handle on the right page.
3. Event 2: the lobby arrival. Hold the original floor plan to walk to the front desk. Face the counter, select **Inspect**, and use the slider to find the bell.

The normal route now reaches search area 2. The 3D picker selects the bell from original hit geometry (`obj02`). Confirm with **Look** or a second tap. `OriginalEventRunner.lookInSearchView(area:subarea:table:)` takes that result and continues:

4. Event 3: Kyle looks at the counter bell (mode 10 closeup).
5. Event 4: process 24, overlay 32. Tap the bell three times, or tap the quit button. The quit result runs event 5 and returns to the same counter view.
6. Events 7 to 12: Dunning's arrival and the suite offer. Opcode 10 kind 5 shows the original choice prompt (KIF labels). The answer is a mode-5 event; the saved frame then resumes event 12.
7. Event 16: process 25, overlay 1 (`CSign`). Drag right across each line of the registration card to sign it. The completed card returns 0; the quit button returns 1 or 2.
8. Events 19 to 27: the name, the room key and the brochure. Opcode 6 adds each item and shows its notice pages.
9. "Hold on" interrupts: on armed pages the touch page shows a pulsing icon. Pressing it plays the mode-6 event and its choice. The interrupted event then resumes and skips the `%!` lines.
10. Event 28: the question menu. The menu lists the `EP1_.ttk` topics that Dunning can be asked about. Answers are mode-1 events; "Leave" plays the mode-4 exit.

After the menu, the talk ends when the selector finds no event. The native session returns to lobby walking at the retained position. Face Dunning and select **Talk** to start mode 0 from his saved conversation block. The checked package-question route resumes at event 50 in block 6. Dunning's standing position blocks counter inspection, as the original table specifies. The connected exits lead through R103 to the Central Hallway, R117. Walking north starts event 15, then the stairway departure conversation.

Melissa’s stairway conversation reaches event 35 and keyword 8, “A puzzle, huh?”. Ask the question, use the interrupt, and choose “Let me help.” Event 48 requests process 26. The native process now supports the five loose pieces, rotation, snapping, idle hints and quit results. Completing it returns to event 51. The following story now requires two taps to collect the dropped piece, then enters R213. Walking west starts Jeff's conversation. Both the guide route and the missed-first-interrupt branch match the original saved state. Native play then opens Room 215 with the original key and answers Rachel’s telephone call. Suitcase inspection and item use now run process 37 through key insertion and breakage. The original dialogue replaces the key and records its retry checkpoint. See [Suitcase key](suitcase-key.md). The route now returns to the dresser, opens the brochure and collects its paperclip. Full state, image and hit-map comparisons pass. See [Brochure and paperclip](paperclip.md). The checked route already has the payment reminder flag, so it skips Dunning’s second call. See [Room 215](room215.md). See [Chapter 1 jigsaw](chapter-one-jigsaw.md) for evidence and rendering limits. Stair movement and transition fades are not drawn.

For simulator checks, a Debug build reads the environment variable `HOTEL_DUSK_FIXTURE`. `R102-bell-look` supplies the look result for area 2, subarea 2 at R102 exploration. `R102-sign` and `R102-event-N` play the original script with fixed inputs until process 25 or event N starts. These are isolated component inputs, like the reference runner's diagnostic writes. While one is set, a Debug build also ignores a closed hinge reading, because the iPhone Duo simulator can boot folded. Release builds ignore all of them, and the app shows no control for them.

`OriginalEventRunner` connects the recovered selector, conditions, state commands, dialogue packets and event exits. It marks a completed event at (current map, event key), as `0x0203D61C` does through `0x02097FC0`. Opcodes that change only controller or display state continue without a drawing: 3, 26, 27, 28, 43, 44 and the empty dispatcher cases. An unrecovered opcode, exit mode or process still halts that interaction with its program, event and source offset. The host then restores the last safe walking place, or starts Chapter 1 if it cannot restore a safe place.

These parts of the slice are approximations:

- Jigsaw projection and piece seams do not yet match DS rasterisation. The original portrait page, selected-piece glow and fades are absent. The following dropped-piece picture now requires selection and confirmation. Its original images and item acquisition are connected. See [Touch pictures](touch-pictures.md) for remaining presentation limits.

- The lobby supports search area 2 and walking after registration. R102/R103 return travel, the R103/R117 exit and R213 entry are connected. R205 dresser area 1, bed area 2 and suitcase area 3 are connected. Other search areas and room transitions remain unavailable. Camera smoothing uses native floating-point maths. Region 3 starts event 55 at the compared original position. R103 reminder events 0–2 and R117 event 15 also have original execution comparisons. The floor plan now shows the map artwork without native position, person or cursor overlays. Search close-ups use the visible object alpha masks with a two-pixel margin in transparent areas; the source masks and rendered artwork remain available for ROM comparisons. See [Lobby to bell](lobby-to-bell.md) for the covered comparisons.
- Inspection controls and the counter slider use native controls. The other counter page remains blank until Kyle's portrait compositor is recovered. Metal rendering does not reproduce every DS rasterisation detail.
- The opening cinematic does not run. Play starts at the arrival event that the reference runner reaches after the opening.
- The entrance shows the original `u01`–`u03` and `d01`–`d03` panels, not the 3D R101 scene. The handle target is invisible. Fades are counted for timing but not drawn.
- Text control `%m0NN` starts `SEQ_BGM_NN`. The meaning of the other mode values is not known.
- Text colours 1 and 2 use approximate ink tones. Portraits, talk backgrounds and character animation are not drawn.
- The bell page shows `bell02` with `bell01` on top. The bell target uses the sprite pixel mask with a two-pixel margin, excluded from the quit target. The bell swing angle, trick-button sprites and the talk background `R102_03` on the other screen are not drawn. Touch targets have no visible overlays.
- The registration card shows `signnote` and reveals `signnote02` per field as the strokes grow. The pen sprite and fades are not drawn.
- The choice prompt, the question menu and the interrupt icon use book typography, not the original menu graphics. The question menu now lists owned items. Melissa’s puzzle-piece return is checked. Showing an owned item with no chapter-specific response now tries the shared System event. If no shared event matches, the conversation menu returns without changing story state.
- The menu's `+0x6C = -1` branch (a mode-26 answer from the partner's scene) is not recovered. Topic answers use the mode-1 branch.
- The interrupt stays armed after a replay in the same way as `0x0203F57C`. When the original text window accepts a second press is not verified against the ROM.
- The original shows a Chapter 1 title card after the entrance; the native slice does not.
- The request stack at `0x021046B8` is kept in the runner. Bell quit/reload is connected to the retained counter state. Other map and search consumers remain incomplete.
- Screen 1 maps to the left page and screen 0 to the right page. Left-handed layout is not supported yet. The earlier demonstration was retired because it contained invented dialogue, arbitrary items, free room travel, chapter shortcuts and a procedural corridor. The white corridor rectangles were artifacts of that prototype, not original game graphics.

## Source-backed Swift modules

- `Engine/Original/OriginalData.swift`: bounded, strict CiNG dictionary decoder. Its 64 KiB ring handles initial zeroes, overlap and wraparound.
- `OriginalScript.swift`: hash-checked source catalog, indexed text, original debug labels and raw choice records. Control codes and empty strings survive unchanged.
- `OriginalBlockGraph.swift`: all four BLK tables and child spans. Known command fields come from the original ARM9 dispatch handlers. Unknown opcodes preserve their raw bytes.
- `OriginalControllerCore.swift`: isolated original flag and wait handlers. It deliberately does not advance events because the original animation lookahead and dialogue phases are not recovered.
- `OriginalConditions.swift`: original CHK lists and pure predicates. Successful original checks also commit selector context; that effect remains unimplemented. Unknown predicates and missing state return unresolved results.
- `OriginalInventory.swift`: native ordered inventory and separate acquisition state. Removal does not automatically erase acquisition state. IDs outside recovered storage fail explicitly.
- `OriginalMapExploration.swift`: R102/R103/R117/R213/R205 movement, entry markers, character and wall collision, fixed-point facing, nearby people, door selection, counter eligibility, camera and model picking. `OriginalMapRestrictions` reads original standing-position and room-permission tables. `OriginalRegionSelector` selects automatic map and departure events. `OriginalMapRenderer` supplies original textures and geometry to Metal. `OriginalMapBitmap` decodes the floor plan.
- `Renderer/OriginalAnimation.swift`: native ANM decoder with preserved index buffers, original palettes and loop restart indices. Checkpoints identify their original payload hash.
- `Renderer/MetalBookMaterial.swift` and `Metal/BookPaper.metal`: actual GPU rendering for paper stock, hinge-driven normals and binding shadows. Tests compile the shader and read rendered GPU textures.

These modules are recovery foundations, not a complete event interpreter. The Chapter 1 jigsaw now has recovered mechanics and story gating. The separate development preview retains its older placement assumptions and is not evidence that the Chapter 3 sequence is playable.

## Validation boundaries

Independent Python extraction and Swift decoding are compared using original payload, index-buffer, palette and RGBA hashes. Original command and condition fixtures are selected by exact program name and byte offset. Native handler tests check source behaviors such as preserving item acquisition state and the wait counter's extra update.

Passing these checks proves the covered transformations agree with recovered source evidence. It does not prove a chapter, puzzle sequence, ending or audio mix matches the running ROM. Full game comparisons, original audio cue timing and remaining handlers are outstanding. Continue now includes resumable interaction inputs and notebook reading state, with checksums and compatibility with existing walking checkpoints. Every input, active simulation step and writing update saves immediately. The app skips the original manual save prompts; older saves remain readable. Returning to title is blocked if saving fails. Legacy chapter slots remain readable for migration.

## Remaining native work

1. Recover startup and initial game state, event selection and all condition side effects.
2. Translate all dispatcher handlers, dialogue control codes and character scheduling.
3. Recover original scene geometry, textures, collision, camera and touch behavior.
4. Translate every original puzzle and its chapter prerequisites, including microphone and hinge interactions.
5. Restore original audio event selection, effects, envelope/modulation behavior and measured timing.
6. Recover notebook, original saves, failure states, all endings and chapter transitions.
7. Compare matching ROM/native input traces and screen/audio checkpoints throughout the complete game.

The supplied ROM and source artifacts are retained locally. Unverified data stays available for recovery; unverified gameplay stays unavailable in the app.

## Paperclip straightening

Process 28 now has checked native joint mechanics, drag projection, spring-back, success and quit outcomes. Its System story returns match complete original game state. The inventory table, native renderer, touch input and System return are connected. The normal route now quits, reopens and completes the puzzle to receive the thin wire. DS rasterisation, visual fades, rumble and physical-device behaviour remain unverified. See [Paperclip straightening](paperclip-straightening.md).

## Thin-wire lock attempt

Process 29 now runs from suitcase item use through insertion, all three pins and the original failure dialogue. Both quit branches match complete original state. The normal route also checks quit, re-entry and pause. Shared mode-16 System selection now restores the room runner. Original models and lock bitmaps are connected. Captions, rumble, visual fades, DS pixel matching and physical-device checks remain open. The delivery trigger requires completed Dunning questions 0–2, which the extended route below now covers. See [Thin-wire lock attempt](thin-wire-lock.md).

## Dunning questions and delivery knock

Both registration interrupts now preserve the brochure handover and match the complete original menu state. Replay cleanup no longer skips the handover or repeats an interrupt. The extended native route resolves the required questions, answers Dunning’s payment call and reaches the parcel knock. Opcode 16 now has original state comparisons before and after its child process. The ordinary clock process now completes through normal play, including pause/resume. Its morning branch remains open. The native route now takes the parcel, identifies Louie and completes his first conversation. Bed inspection then opens the wrong parcel and awards its notebook. Original object flags control rendering and touch selection. The route then exits Room 215 and completes Melissa’s notebook conversation, puzzle-piece return and departure. The notebook now displays her drawing and supports three writable pages, erasing and undo. Later grouped notes and the wider notebook menu remain unfinished. See [Original notebook](notebook.md). The extended route now meets Mila and Rosa and reaches the 5:20 time change. It then returns upstairs, inspects Room 213 and completes Jeff’s questions about Mila. Door inspection no longer requires a supported room interior. Jeff’s departure returns to corridor walking. Full-state comparisons pass at all recorded Room 213 checkpoints. See [Jeff at Room 213](jeff-room213.md). See [Mila and Rosa](mila-rosa.md). See [Melissa’s notebook and piece return](melissa-notebook.md). See [Wrong parcel and notebook](wrong-parcel.md). See [Louie’s delivery](louie-delivery.md). See [Time transition](time-transition.md). See [Dunning and delivery](dunning-delivery-route.md).

## Iris and Summer

The extended native route now completes Iris’s introduction and Summer’s visit. Kyle returns the brown notebook and takes his own parcel. Original comparisons cover the recorded choices, question menus, parcel hit mask and saved state. Map turning now preserves the exact full-turn boundary used by Summer’s knock checkpoint. See [Iris and Summer](iris-summer.md). The native route also collects the client list and order sheet, with full-state and image comparisons. See [Order documents](order-documents.md). Rachel’s next call and all five review answers now pass the native route check. All five menus and the first wrong-answer retry match the complete original game state. The Chapter 2 reset, automatic chapter transition, title and Room 215 opening are now connected. Instant saves retain progress throughout this transition. Complete state comparisons include the title-exit retry buffer and room arrival. Rosa’s Chapter 2 corridor conversation now passes the native route check, including the guide’s three interrupts and bracelet answer. The map checkpoint now retains the frame’s starting heading, matching the original corridor state and retry buffer. The native route now reaches the Linens Closet, completes Louie’s guide conversation and collects all three tools and the magazine. Nested close-ups retain their parent scene. The room renderer hides the original debug helpers. See [Chapter 2 Linens Closet](chapter-two-linens.md). Helen’s introduction, both Room 212 questions and the return to Room 215 now match the complete original saved state. The destination map now loads before arrival scripts can clear its entry context. See [Helen in Chapter 2](chapter-two-helen.md). Hanger inspection and cutting now run natively. The route uses the pliers, makes two cuts and receives the thick wire. Original comparisons cover cut geometry, controller state, quits, failures and the successful story return. See [Hanger recovery](chapter-two-hanger.md). The thick-wire suitcase puzzle now runs through insertion, latched pins, lock rotation and opening. Process 35 now renders the suitcase contents, moves objects, takes the cash and returns to inspection. Client-list storage is connected through the existing item-use script. See [Suitcase contents](chapter-two-suitcase-contents.md). See [Thick-wire suitcase lock](chapter-two-thick-wire.md). See [Rosa in Chapter 2](chapter-two-rosa.md). See [Chapter 2 transition and saves](chapter-two-transition.md). See [Chapter 1 review](chapter-one-review.md).

## Chapter 2 payment

The native route now returns downstairs after cash pickup and client-list storage. It knocks on the office door and follows the apology interrupt. Choice 21 and the returned lobby state have complete original game-state comparisons. The close-up decoder now accepts the lobby file’s unused trailing records while checking every declared record. The cash item remains available and the office lock clears, matching the original. R115 exploration is connected. The guest ledger, birthday card, supervisory log and calendar now run through native input. Trapped-memo pulling and torn-paper acquisition are connected. Chapter 2 process 34 opens the point-tie drawing scene; drawing, Clear, Back and inventory reopening have route checks. Chapter 9 process 64 starts the apple-painting overlay, but its full story route remains unverified. The route now places the crowbar, lifts the cabinet and receives the joined memo. Back returns to cabinet inspection. Process 31 now accepts the memo code, opens drawer 3 and returns to the red-box search. Item 14 acquisition and the office exit are connected. The returned lobby state has an original comparison. Louie’s Nile discussion and Rosa’s follow-up choices now have complete original state comparisons. Diagonal walking uses the original fixed-point lookup. See [Nile and Rosa](chapter-two-louie-office.md). See [Cabinet combination](chapter-two-cabinet-combination.md). See [Crowbar recovery](chapter-two-crowbar-recovery.md). See [Memo drawing](chapter-two-memo-drawing.md). See [Trapped memo](chapter-two-memo-pull.md). See [Office search](chapter-two-office.md). See [Chapter 2 payment](chapter-two-payment.md).


## Chapter 2 ending and Chapter 3

The native route completes Louie's confrontation, all required questions and the photo interaction. Scripted request 1 now moves Kyle into the corridor automatically. The Chapter 2 review checks all five answers and a wrong-answer retry. The next save, title artwork, clock and Room 215 arrival use Chapter 3 data. Rachel's phone call and the Kevin, Louie and Iris conversations run through native input. The route collects the rag doll, completes dinner and the Summer/Rosa questions, then talks to Louie to reach 6:20 PM.

Chapter titles and checkpoint validation now use the original tables for all ten chapters. This does not establish that the later chapters are playable. Rooms without a local chapter program retain System interactions. Present but damaged script files still fail validation. Walk-through exits use supported destination markers and retain original departure events.

See [Chapter 3 progress](chapter-three-progress.md) for the current route and remaining work.

## Chapter 4

The native route now plays Chapter 4 from the roof to the review through normal input. Opcode 34 and departure clock requests are recovered. Game-over pages (`%r`) still lack the original failure screen and retry behaviour. If one is reached, the app now returns to the last safe walking place, or starts Chapter 1 when no safe place is available. See [Chapter 4 progress](chapter-four-progress.md).
