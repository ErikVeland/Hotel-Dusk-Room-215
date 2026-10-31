# Architecture

Hotel Dusk: Room 215 is an unfinished native Swift and SwiftUI port for a two-page Duo presentation. Metal renders the book material and recovered model previews. AVFoundation supports native audio playback.

The app reads recovered game data and runs Swift implementations of recovered behaviour. It does not execute Nintendo DS ARM code or embed an emulator. The separate reference runner executes the ROM for comparison.

This document describes the working tree on 31 October 2026. The macOS debug app builds. The native-input test chain reaches the Chapter 10 ending through instant-save checkpoints, but it does not prove a fully source-matched game route. Chapter 7 process 55 uses overlay 30's recovered cube transforms, model and blocker rule. Checkpointed normal-input tests complete processes 55 and 43 with CPU-projected touch points. Original touch mapping and Metal rendering still need device verification. Chapter 10 process 79 uses overlay 40's 90-slot layout, accepted hit indices, five-hit rule and confirmation return. Its deterministic seed and shared face rendering differ from the original time-seeded, varied board. Metal rendering and device-level touch behaviour remain unverified. Runtime interaction errors return to the last safe walking place. Original-device fidelity remains open for selected interactions and audio. See the [route tracing workbench](docs/route-tracing-workbench.md) for current evidence.

The map controller uses the recovered trigonometric lookup and rounded fixed-point product for walking steps. Original frame captures cover the diagonal approach to Louie and character collision. The existing event runner handles the Nile and Rosa branches through ordinary choices, interrupts and questions. See [Nile route and movement evidence](docs/chapter-two-louie-office.md).

## Targets and directories

[`Package.swift`](Package.swift) declares iOS 17 and macOS 14 deployment targets. The iOS app project also uses [`project.yml`](project.yml). Deployment targets do not establish the minimum SDK needed to compile every API reference.

| Location | Responsibility |
| --- | --- |
| `Sources/HotelDuskDuoApp` | App entry point and session ownership above the display windows. |
| `Sources/HotelDuskDuoKit/Engine` | Session coordination, hinge state, asset loading, puzzle previews, and audio. |
| `Sources/HotelDuskDuoKit/Engine/Original` | Script decoding, event selection, conditions, game state, dialogue, cinematic queues, and recovered processes. |
| `Sources/HotelDuskDuoKit/Models` | Native book layout, shared model types, and notebook drafts. |
| `Sources/HotelDuskDuoKit/Views` | SwiftUI pages, controls, input forwarding, and UIKit hinge integration. |
| `Sources/HotelDuskDuoKit/Renderer` | Original graphics decoders, animation state, screen effects, model previews, and book material integration. |
| `Sources/HotelDuskDuoKit/Metal` | Book paper, lighting, and binding shaders. |
| `Sources/HotelDuskDuoKit/Resources` | Bundled original payloads, manifests, derived assets, images, and text. |
| `Tests/HotelDuskDuoTests` | Native state, decoder, process, rendering, audio, and layout checks. Some checks need external captures or platform services. |
| `tools` | Extraction, decoding, recovery, Ghidra scripts, and the separate ROM reference runner. |
| `docs` | Recovery findings, format reports, previews, and implementation limits. |
| `archive/retired-prototype` | Former demonstration code outside the active build. It contains invented content and is not gameplay evidence. |

## Session ownership and runtime flow

```text
HotelDuskDuoApp
  owns GameSession
    owns DuoHingeManager, AudioController, MemoDraft, JigsawPuzzleManager
    owns OriginalPlaySession while a game is active
      owns OriginalEventRunner and active recovered process state
      owns OriginalMapExploration and its renderer while R102, R103, R117, R213, R205, R211 or R115 exploration is available

DuoBookContainerView
  observes GameSession
  lays out LeftPageView, RightPageView, cover, and preview overlays
  forwards player input to session methods

Bundled data -> decoders -> event runner -> published play state -> views
Player input -> play session -> event runner or active process
Hinge input -> hinge manager -> session -> pause/resume and puzzle fold events
```

`HotelDuskDuoApp` creates one `GameSession` above its `WindowGroup`. Replacing a display window therefore does not create a new game session.

`GameSession` owns the script catalogue, notebook drafts, preview state, audio controller, hinge manager, and active play session. `DuoBookContainerView` keeps the inner pages mounted while the cover or jigsaw hides them.

`GameSession` stores the latest walking checkpoint separately from the exact resume save. Engine halts restore the walking checkpoint automatically. An embedded process without a native handler, or one that loses its native state, returns the player to that checkpoint. The player may need to repeat the interaction. The pause menu also offers **Return to last safe place** for interactions that remain active without making progress.

This ownership preserves state during the running process. Native Chapter 2 checkpoints now survive process termination through an injected save store. General midgame save and restore remains unfinished.

## Original game runtime

The original runtime uses several separate layers:

1. `OriginalData` decodes CiNG data and provides bounded byte access.
2. `OriginalScript` loads the bundled catalogue and checks source hashes. `OriginalBlockGraph` exposes BLK records and their source offsets.
3. `OriginalConditions`, `OriginalEventSelector`, and `OriginalEventSession` evaluate recovered conditions and maintain selection context.
4. `OriginalGameState`, `OriginalInventory`, and `OriginalStateCommand` hold and update recovered state fields.
5. `OriginalEventRunner` coordinates event execution, dialogue, choices, item notices, question menus, interrupts, and completion.
6. `OriginalPlaySession` connects the runner to native timing, audio, map exploration, and the entrance, bell, registration, Chapter 1 jigsaw and suitcase-key processes.
7. `OriginalMapExploration` owns the supported map position, entry marker, wall collision, search eligibility, nearby-person selection, counter camera and object selection. Its constructor receives decoded models, collision data, `OriginalMapRestrictions` and `OriginalObjectVisibility`.
8. `OriginalRegionSelector` evaluates the original region and departure events. The session checks collision regions during movement and retains the entry position while an event runs. Departure cancellation restores the previous movement position. Successful departure loads the destination program with the retained game state.

The dialogue runner now checks both registration interrupts and the brochure handover against a complete original state snapshot. Skipped replay pages still clear their replay marker and disarm completed interrupt windows. See [Dunning and delivery](docs/dunning-delivery-route.md).

`OriginalEventRunner` is a value type with explicit phases. These include dialogue, process, waiting, exploration, choice, item notice, touch picture, questions, and halted. A halt records the reason, program, event, and source offset where available.

Unknown required event behaviour returns the player to the latest walking checkpoint. Unknown embedded processes use the same recovery path and do not mark the interaction successful. A required event that reaches an unknown process will repeat until a native handler is recovered. Recognised presentation operations can advance without drawing their original output; the runner records these in `unrenderedPresentation`. An event trace alone therefore does not establish presentation fidelity. Choice menus mark every offered option before the player answers, as the original opcode-10 handler does. Question menus retain unanswered entries and append new questions. The runner clears that order when a new conversation starts from exploration.

Map request 9 relocates Kyle to an original `hyde_pointNN` marker and stores his position and facing. The session consumes new map requests in their original stack order. Map construction also marks the destination as visited. The map retains the heading from the start of each update, following controller field `0x14600`. Map checkpoints use this heading when an event interrupts a turn. See [Rosa in Chapter 2](docs/chapter-two-rosa.md).

Opcode 16 queues a request and enters clock process 126 unless its label is `NONE`. It clears the previous map and stores the child's time label before the numeric time changes. Map request 3 later changes the numeric time and clears saved conversation blocks. These state effects have full original comparisons. `OriginalClockProcess` now runs the ordinary clock and label animation, and `OriginalClockRenderer` draws its original bitmaps. The special morning transition remains unsupported. See [Time transition](docs/time-transition.md).

The runner also retains process requests whose map or search consumers remain unrecovered. Completing an event does not imply that its destination system is playable.

`OriginalJigsawProcess` owns Chapter 1 piece state, randomisation, rotation, snapping, hints and process outcomes. The session supplies its random seed. A System hint temporarily replaces the active runner while the parent retains its script position. System hint completion does not mark a normal map event. The process saves its loose-piece mask before returning to the parent script.

`OriginalSuitcaseKeyProcess` owns process 37 from overlay 12, variant 2. `OriginalSuitcaseProjection` supplies its fixed-point touch segment and rotated camera. `OriginalSuitcaseRenderer` draws the original bag and key models with BIN textures in a shared Metal pass. Views forward touches to the session. Success sets puzzle flag 13. The original script replaces the key and requests a retry checkpoint. Search request 8 copies the live state into the in-memory retry buffer. General midgame saves remain unfinished. The Chapter 2 starting checkpoint preserves this state in native saves. See [Suitcase key](docs/suitcase-key.md) for comparisons and presentation limits.

`OriginalMemoPullProcess` owns process 27 from overlay 6. Its typed touch input carries the paper and drag-plane intersections from `OriginalMemoPullProjection`. The native renderer uses the source cabinet, wall and paper assets. The session owns fades, audio, pause and story return. Drag state and all three outcomes have original comparisons. The office route reaches torn-paper acquisition and memo drawing. Exact presentation and later Chapter 2 routes remain unfinished. See [Trapped memo](docs/chapter-two-memo-pull.md).

`OriginalCrowbarProcess` owns process 30 from overlay 5. Its projection supplies fixed-point handle and drag-plane intersections. The renderer draws the original cabinet, wall, crowbar and paper. The session owns touch sampling, pause, fades and audio commands. Success marks puzzle 6 complete before script return. The normal route retrieves the joined memo and continues through cabinet unlocking. Controller fields and returned game bytes have original comparisons. Captions, the animated touch marker and later game-over presentation remain unfinished. See [Crowbar recovery](docs/chapter-two-crowbar-recovery.md).

`OriginalCabinetDialProcess` owns cabinet-mode process 31 from overlay 10. The projection preserves the original fixed-point wheel and drag-plane intersections. The renderer uses the original cylinder strips, translucent surround and cabinet models. The session forwards touches and handles fades, pause, audio commands and return. Game offset `0x13D6` retains the displayed number on quit. Success clears that value and records puzzle 7 completion. The normal route opens drawer 3, takes item 14, the red box, and returns to the lobby. The separate cashbox mode, captions and held-touch presentation remain unfinished. See [Cabinet combination](docs/chapter-two-cabinet-combination.md).

`OriginalPaperclipProcess` now owns the three-stage joint model for process 28. `OriginalPaperclipProjection` supplies its touch-plane intersection. Original drag, spring-back, success and quit captures support targeted checks. Mode-30 System responses reproduce the wire replacement and both quit states. `OriginalInventoryProcessTable` selects the process from `trickitem.bin`. The session starts it from search or close-up inventory and restores the room runner after its mode-30 System response. `OriginalPaperclipRenderer` draws the recovered segment mesh, desk quad and point-light texture. The normal route reaches thin-wire acquisition, including quit and re-entry. See [Paperclip straightening](docs/paperclip-straightening.md).

`OriginalHangerCuts` and `OriginalHangerProcess` implement process 32 cut acceptance, wire checks and controller update counts. Original comparisons cover cut coordinates and success/failure story returns. The hanger search area is available. Rendering and session integration remain unfinished. See [Hanger recovery](docs/chapter-two-hanger.md).

`OriginalThinWireProcess` owns process 29, including insertion, fixed-point cursor contact, pin spring return and retained completion flags. `OriginalThinWireRenderer` draws the original models and lock bitmap layers. Mode-16 System fallback starts the puzzle and preserves the room runner. All three outcomes match full original game state. The normal route reaches the failed attempt.

`OriginalDoorTable` decodes the original connection IDs, initial lock states and fields for each side. `OriginalStateDefaults` uses this decoder for new-game door state. `OriginalMapExploration` selects a nearby door from model markers. Collision records and `OriginalMapRestrictions` control its availability. `OriginalSearchTable` supplies the door area and up-view record. `OriginalDoorScene` holds component and item selection. `OriginalUpViewTable` supplies the layers, and `OriginalUpViewImage` composes their pixels and packed hit map. The session runs door entry, key use and opening events before departure selection. The checked Room 215 route uses modes 13, 16 and 14. Unlocked sides can depart directly, following `0x0202DEC4` and the original side flags. This corrects room exit and Louie’s arrival. The lobby office-door payment route is connected. Its close-up decoder accepts unused trailing records, as the original reader does. R115 office entry is connected. Other door responses remain incomplete. See [Chapter 2 payment](docs/chapter-two-payment.md).

`OriginalSearchCloseup` retains search area, component selection and item-layer visibility for process 98. The session runs the mode-10 entry before opening the image, then runs its mode-11 background response. Mode-11 confirmation tries the room script, then its System response. The room runner resumes with the returned game state. The brochure, paperclip, wrong parcel and notebook have complete state and bitmap comparisons. See [Brochure and paperclip](docs/paperclip.md). Nested close-ups now retain their parent scene and return after Back. The component response runs before child entry. Request 6 can cancel that entry. Detail-image layers now run mode 11, show the source bitmap, run mode 12 and restore the close-up. Guest-ledger, supervisory-log and calendar responses have original state comparisons. Detail fades and wider branch coverage remain unfinished. See [Office search](docs/chapter-two-office.md). See [Chapter 2 Linens Closet](docs/chapter-two-linens.md).

`OriginalObjectVisibility` reads `onoffobjs.dat` and applies the original state flags to room and search model nodes. `OriginalMapRenderer` requires the current game state. The search picker receives the same visible-node set. Dynamic floor-plan sprites from this table remain unfinished.

`OriginalNotebook` owns three writable pages, acquired drawings, ink, undo state and page navigation. It receives a loader for original packed drawing bytes. The session retains the parent conversation or map, samples held ink, and stores writable pages in original game state. `OriginalNotebookImage` converts the original tiles to upright page pixels. Acquired drawings remain read-only. Overlay 38 and the notebook renderer share the five apple-painting bits at state offset `0x13D8`; the notebook clears uncollected regions from the overview image. Later grouped-note combinations still need original captures. Notebook state survives close and reopen within the running session. General midgame saves remain unfinished. The Chapter 2 starting checkpoint preserves this state in native saves.

`OriginalShownItemSelector` scans the current person's blocks at the current time for modes 16 and 27. If no chapter response matches, the runner checks the System script for the same person and item. `OriginalPlaySession` keeps the conversation runner while the shared response runs, then restores the question menu. If no chapter or System response matches, the question menu remains open and game state does not change. Melissa's item-3 response has full original-state comparisons. Other shown-item paths need route checks.

`OriginalTouchPicture` handles opcode 8 as a blocking process. The session loads its original table and images, then forwards presses and releases. The model builds the original packed hit mask and requires a second press to confirm a selection. The following opcode owns item acquisition. Unsupported picture modes stop explicitly. The selection overlay uses the original polygon alpha 15, equivalent to 50% blending. Image loading and selection rendering remain separate from the model.

`OriginalCinematicProgram` and `OriginalCinematicQueue` provide separate cinematic data and scheduling support. The host must supply the remaining handlers. The complete opening cinematic is not connected to normal play.

## Current playable boundary

Normal play starts at the recovered Chapter 1 arrival in `EP1_R102`. It runs the narration and entrance, then enables the lobby floor plan. Held touches move Kyle using the original speed table and direction steps. Original collision triangles constrain the route to the counter.

The `search02` polygon and facing cone enable counter inspection. The counter camera uses the original model markers. Ray intersection with original hit geometry selects `obj02`, which resolves to search subarea 2. A confirmed selection enters event 3, then process 24. Quitting the bell returns to the same counter view. Three rings continue to Dunning's existing conversation and registration path.

The native session check covers arrival, walking, inspection, bell quit/re-entry, three rings, registration, the package question and a second conversation with Dunning. It uses ordinary session input without a debug fixture or injected process result. The checked route continues through R103 and R117, completes Melissa’s first jigsaw, collects the dropped piece, completes Jeff's conversation and walks to the Room 215 door in R213. The route now opens the door with its original key, enters R205 and answers Rachel’s telephone call through dresser area 1. See [Room 215](docs/room215.md) for state comparisons and branch limits. Suitcase area 3 is also connected, including inventory use and process 37. Bed area 2 now supports the wrong parcel and notebook. Other room search areas remain unavailable. See [Lobby to bell](docs/lobby-to-bell.md) for original execution evidence and rendering limits.

Each selected normal event saves its block in the original map/person table. Returning to exploration retains Kyle's position and returns the view to walking. The Talk action selects a nearby person using the original distance and facing rules. It starts mode 0 from that person's saved block. Original standing-position records and room permissions control inspection availability. Native circles mark people on the floor plan until original character graphics are connected.

Debug builds accept `HOTEL_DUSK_FIXTURE` values such as `R102-bell-look`, `R102-sign`, and `R102-event-N`. `OriginalFrontierProbe` also supplies process outcomes and a search result. Its output describes the diagnostic route only.

See [Native implementation status](docs/native-port-status.md) for the recorded slice and its approximations. Reconcile older status statements with the implementation before using them as a delivery claim.

## Presentation, input, and hinge state

`DuoBookLayout` splits the physical display before applying content safe areas. `PaperbackPageSurface`, `MetalBookMaterial`, and `BookPaper.metal` render the paper and binding independently of game logic.

The container supports swapping page roles. Some original gameplay coordinate paths still assume right-handed orientation, so page swapping alone does not establish complete left-handed support.

Views convert native touches into original page coordinates and forward them to `OriginalPlaySession`. Recovered process types hold the interaction rules. New story rules and state transitions belong in the engine, not in views.

`HingeObserverView` forwards UIKit hinge readings to `DuoHingeManager` through an availability-guarded integration. Debug controls can simulate hinge events. The manager distinguishes closed, partially open, and fully open states.

`GameSession` pauses active play when the book closes and resumes it when the book opens. It forwards fold events to the jigsaw only while that preview is active. The jigsaw handles the first explicit reopening without requiring a flat posture.

`OriginalMemoDrawing` owns process 34's symbol geometry and masked ink. Its process controller owns toolbar timing and exit. The image composer uses original paper and glyph assets. `OriginalGameState` retains the random value, with an injected seed supplied by the session. Story and inventory entry share the controller and return through their original script boundaries. See [Memo drawing](docs/chapter-two-memo-drawing.md).

## Graphics and audio

Graphics libraries load original bitmaps, tile animations, ANM animations, textures, and models. Manifests retain provenance, hashes, decoder coverage, and unresolved entries.

`OriginalAnimationDecoder` preserves delta-frame buffers and supports checkpoints tied to the source payload. Frame decoding does not determine the original story animation clock.

`OriginalModelMetalPreview` renders recovered geometry and textures. `OriginalMapRenderer` reuses it with the recovered lobby and counter cameras. `OriginalMapBitmap` decodes the original floor-plan tile dictionary and screen map. R102, R103, R115, R117, R213, R205 and R211 are connected. The map uses each room’s original scale. The 256×256 room maps use separate scrolling rules. Other maps and DS rasterisation equivalence remain unverified.

`AudioController` coordinates native playback. Music uses recovered sequence and sample data. Effect playback uses `OriginalSoundArchive`, `OriginalSequenceMachine`, `OriginalSoundDriver`, and `OriginalEffectRenderer`, with an AVFoundation adapter in `OriginalEffectPlayback`.

Playback support does not establish complete scene cue selection or acoustic fidelity. Original recordings and matching execution traces are still needed for those comparisons.

## Resource and tool boundaries

The package copies the script, audio, game-data, animation, texture, model, and bitmap directories into its resource bundle. Loaders access these through `Bundle.module`. They do not require the original ROM for ordinary bundled-data access.

| Resource | State in this checkout | Effect |
| --- | --- | --- |
| Native Swift code, tests, and `tools/` files | Committed | Supports native implementation and work on the recovery tools. |
| Bundled payloads and manifests | Committed | Supports decoding, native playback, and checks against recorded hashes. |
| `Source/` | Present locally and ignored | Contains the original ROM and supplied source exports. The ROM hash matches the bundled script manifest. |
| `extracted/` | Present locally and ignored | Contains extracted binaries, recovery outputs, decompilation, RAM captures, and reference traces. |
| `.tools/` | Present locally and ignored | Contains Ghidra and the melonDS source at the revision pinned by the reference runner. |

These directories were restored locally on 17 October 2026. They remain outside Git, so a fresh clone still needs a separate resource setup. Several Python tools use `extracted/` as their default input directory.

The restored tree includes the 1,031,352-byte decompressed ARM9 image, ARM9 and overlay decompilation, and reference captures. Decompiler output supports investigation but still needs interpretation and comparison with original execution.

The [reference runner](tools/reference/README.md) builds separately through CMake. It needs the ROM and pinned melonDS source, and writes screen, audio, input, and memory captures. It is never linked into the native app. Its microphone currently supplies silence.

Local CMake is installed under `.tools/python/cmake/data/bin`. The reference runner builds with `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`. Xcode 26.6 builds the macOS target when `DEVELOPER_DIR` selects `/Applications/Xcode.app/Contents/Developer`. The default selection remains Command Line Tools. iOS SDK compatibility and device behaviour remain unverified. New Ghidra analysis still needs Java. Existing decompilation can be read without launching Ghidra.

## Verification boundaries

Use the build and verification commands in [README.md](README.md). Record these results separately:

| Check | What it can establish |
| --- | --- |
| Manifest and hash checks | Bundled bytes match the recorded expected data. |
| Decoder checks | Covered decoded outputs agree with the stored reference values. |
| Native state and process tests | The covered Swift behaviour matches the asserted rules. |
| GPU, audio, and layout checks | Covered native rendering or playback works on the test host. |
| Matching ROM/native traces | Covered behaviour agrees at the same original state and input sequence. |
| Device interaction checks | Touch, hinge, display, and lifecycle behaviour works on the checked device. |

Missing external evidence must remain visible. `OriginalGameStateTests` skips its boot-memory comparison without the capture. `OriginalEntranceProcessTests` omits additional RAM comparisons when its capture is absent.

Both capture files are now present. The seven Python checks in `tools/tests/test_original_recovery.py` pass. They cover selected original script payloads, malformed data, and ARM9 decompression. The lobby work also builds the native macOS target and checks Swift state, models, textures, bell transitions and page snapshots. GPU and window-server checks require access outside the filesystem sandbox.

Passing native tests does not replace original execution comparisons. Historical reports are evidence of their recorded runs, not a current checkout validation result.

## Extension rules and remaining work

- Keep event rules, conditions, inventory changes, and process state in the engine. Views present state and forward input.
- Pass external dependencies through explicit boundaries. `OriginalPlaySession` currently receives a concrete `AudioController`; smaller contracts can improve isolated testing when this boundary changes.
- Preserve original identifiers, raw records, hashes, and source offsets where available.
- Keep unsupported behaviour explicit. Do not invent story transitions, timings, assets, or puzzle solutions to bridge recovery gaps.
- Keep diagnostic fixtures separate from claims about normal play.
- Keep reference execution and recovery tooling outside the shipped app.

Work can proceed now on resource audits, reproducible native checks, deterministic event traces, supported presentation details, session handling, and diagnostic scene inspection.

The restored resources support new reference runs. Arrival, the bell, registration, R103, the Central Hallway and Melissa's first jigsaw are connected. The checked native route completes the puzzle, collects the dropped piece and enters R213. Walking west starts Jeff's entrance at the captured original position. Jeff’s guide route and missed first interrupt now have state comparisons. The connected route continues through the Room 215 key and Rachel’s call. The suitcase key now runs through insertion, breakage, inventory replacement and the retry checkpoint. Brochure inspection and paperclip acquisition now pass the normal route check. Paperclip straightening now returns the thin wire through normal play. The thin-wire attempt now runs through insertion, pin interaction and its original failure dialogue. The extended route now resolves Dunning’s early questions, answers his payment-reminder call and reaches the delivery knock. Opcode 16 now queues the time change and enters clock process 126. Its state changes match the original before and after the clock, including the conversation-block reset. The ordinary clock process now runs through pause/resume and returns to Room 215. Selecting Door then reaches Louie's arrival at event 32. Native input now takes the parcel, identifies Louie, resolves his questions and returns to Room 215. Bed inspection now opens the wrong parcel and awards its notebook through normal input. Object flags control both rendering and touch selection. The route now continues through Melissa’s two interrupts, notebook picture, puzzle-piece return and departure with Kevin. All recorded conversation checkpoints match the complete original game state. See [Melissa’s notebook and piece return](docs/melissa-notebook.md). The native notebook now displays her original drawing and supports three writable pages, erasing and undo. Later grouped notes, the wider notebook menu and persistent saves remain unfinished. See [Original notebook](docs/notebook.md). See [Wrong parcel and notebook](docs/wrong-parcel.md). The special morning transition is unfinished. See [Louie's delivery](docs/louie-delivery.md). See [Time transition](docs/time-transition.md). See [Dunning and delivery](docs/dunning-delivery-route.md). See [Thin-wire lock attempt](docs/thin-wire-lock.md). See [Chapter 1 jigsaw](docs/chapter-one-jigsaw.md). Character presentation and exact movement timing remain separate fidelity work.

Two local walkthroughs now guide route selection and puzzle dependencies. The [walkthrough route plan](docs/walkthrough-route-plan.md) records Chapter 1 checkpoints and later chapter targets. Original code and matching ROM captures determine exact mechanics when a guide differs.

The extended native route now returns from Melissa through R117 and R103 to the lobby. Mila’s shoulder picture, Rosa’s conversation and the ordinary 5:20 time change run through existing recovered handlers. Map movement now resolves visible character radii before walls and uses recovered fixed-point facing calculations. The full game state matches the original after Rosa’s departure, including the saved pose and retry checkpoint. The route then returns upstairs and completes Jeff’s Room 213 conversation. Door inspection uses the corridor’s resources independently of interior exploration support. A transition to a person’s normal event closes the door view, so departure returns to walking. See [Jeff at Room 213](docs/jeff-room213.md) and [Mila and Rosa](docs/mila-rosa.md). The route now completes Iris’s introduction and Summer’s visit, returns the notebook and takes Kyle’s parcel. Full-state comparisons cover the recorded dialogue choices and parcel departure. Turning preserves the original full-turn boundary value, including the saved facing at Summer’s knock. See [Iris and Summer](docs/iris-summer.md). Bed inspection then opens Kyle’s parcel and collects the client list and order sheet through the existing close-up and shared-response handlers. Complete state, hit-map and pixel comparisons pass. See [Order documents](docs/order-documents.md). Rachel’s next call and all five review answers are now connected. `OriginalChapterReview` decodes the chapter SPN table supplied by `OriginalScriptCatalog`; the event runner handles mode 24 menus and mode 17 answer completion. Correct answers advance and wrong answers replay the current prompt. The final answer queues kind 4 with the next chapter number. The host now applies the Chapter 2 reset, offers three native save slots and presents the title. Its completion saves the retry checkpoint, loads the new script and keyword table, and runs the Room 215 arrival. `OriginalChapterSaveStore` separates storage from the session. Native files preserve all original state bytes and are validated before restore. The initial menu can load this checkpoint in a fresh session. The normal-input route then completes Rosa’s Chapter 2 corridor conversation, including the three guide interrupts and bracelet answer. It continues into R211, completes Louie’s guide conversation and collects the three tools and magazine. Map rendering excludes `obj999` debug helpers, following `0x0208B6F0`. Their hit geometry remains available. See [Chapter 2 Linens Closet](docs/chapter-two-linens.md). See [Chapter 2 transition and saves](docs/chapter-two-transition.md). See [Chapter 1 review](docs/chapter-one-review.md).

Further gaps include unknown event handlers, complete cinematics, character scheduling, unresolved graphics, remaining puzzle mechanics, scene audio cues, DS save compatibility, general midgame saves, and later chapter transitions. Restoring the resources enables this work but does not implement or validate these systems.

The Chapter 2 hanger controller now includes original camera interpolation and pliers placement and opening. Close-up item use passes the selected component event through the existing mode-16 selection boundary. `OriginalPlaySession` connects process 32 to touch input, original screen effects, sound and the script return. `OriginalHangerRenderer` draws the source models, hook layers and wall-textured cut covers. The native route now cuts the hanger and receives the thick wire. The shared wire-lock controller now supports process 33. The session route inserts the thick wire, latches the pins and opens the suitcase. Original comparisons cover the pin states, lock rotation, opening camera, lid motion and complete story state. Process 35 now opens the contents, handles object selection and dragging, takes the cash and returns to inspection. See [Thick-wire suitcase lock](docs/chapter-two-thick-wire.md). See [Hanger recovery](docs/chapter-two-hanger.md).

For supporting evidence, see [Original logic](docs/original-logic.md), [Original graphics](docs/original-graphics.md), [Original audio](docs/original-audio.md), and [Puzzle fidelity](docs/puzzle-fidelity.md).

`OriginalSuitcaseContents` isolates process 35 object layout, visibility, hit masks, dragging and selection actions. It receives original texels and game state. `OriginalSuitcaseContentsProcess` owns compartment transitions, item animation, dialogue suspension and exit timing. `OriginalSuitcaseContentsRenderer` draws the source model and object textures. The session preserves the process while a shared response runs, then resumes it with the returned game state. Native input now takes the cash and returns to room inspection. Client-list storage uses the existing item-use script. The bitmap library can load checked DTX payloads directly, preserving logical and allocated texture sizes. See [Suitcase contents recovery](docs/chapter-two-suitcase-contents.md).
