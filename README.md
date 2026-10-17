# Hotel Dusk: Room 215 — native Duo rewrite

This is an unfinished Swift and SwiftUI rewrite of the supplied Nintendo DS game. The ROM is a reference for recovering and comparing behavior. The app does not execute ARM code or embed a DS emulator. **The complete original game is not yet playable.**

The former demonstration dialogue, arbitrary initial inventory, chapter shortcuts, suspicion meter, floor plan and procedural corridor have been removed from the app. Their source is retained outside the build in `archive/retired-prototype`. **Begin Chapter 1** now reaches the original lobby, counter and bell through normal play. Development previews remain available through **Book options** in debug builds.

Hold a point on the floor plan to walk towards it. At the front desk, face the counter and select **Inspect**. Use the slider to look across the counter. Select the bell, then press **Look** or tap it again. Ring it three times to continue. See [Lobby to bell](docs/lobby-to-bell.md) for the checked route and remaining limits.

After registration and the first question menu, play returns to the lobby. Face Dunning and select **Talk** to continue his saved conversation. His position at the desk disables counter inspection. You can continue through the Central Hallway, complete Melissa’s first jigsaw, collect the dropped piece and enter the upstairs corridor. Walking west starts Jeff’s conversation. Its three interrupts and both questions now have original state comparisons. A separate route resolves Dunning’s registration questions and reaches the later delivery knock. Its ordinary time transition now runs and returns to Room 215. Selecting **Door** then reaches Louie's arrival. The route now takes his parcel, identifies him and completes his first conversation. Bed inspection then opens the wrong parcel and awards its brown notebook. Leaving Room 215 now reaches Melissa near the stairs. Her conversation, notebook picture, puzzle-piece return and departure are connected. The notebook now displays her drawing and supports three writable pages, erasing and undo. See [Original notebook](docs/notebook.md). The checked route then returns to the lobby, meets Mila and Rosa, and reaches the 5:20 time change. See [Mila and Rosa](docs/mila-rosa.md). The route then returns upstairs, knocks on Room 213 and completes Jeff’s Mila questions. See [Jeff at Room 213](docs/jeff-room213.md). It then completes Iris’s introduction and Summer’s visit, returns the notebook and takes Kyle’s parcel. See [Iris and Summer](docs/iris-summer.md). Bed inspection then collects the client list and order sheet. See [Order documents](docs/order-documents.md). Rachel’s next call and all five Chapter 1 review answers now run through native input. Play now offers a save, shows the Chapter 2 title and returns to walking in Room 215. Native saves can resume this checkpoint after restarting the app. The checked route then leaves Room 215 and completes Rosa’s corridor conversation. See [Rosa in Chapter 2](docs/chapter-two-rosa.md). The route now reaches the Linens Closet, completes Louie’s conversation and collects the pliers, crowbar, screwdriver and magazine. See [Chapter 2 Linens Closet](docs/chapter-two-linens.md). The route also completes Helen’s introduction, her Room 212 questions and the return to Room 215. See [Helen in Chapter 2](docs/chapter-two-helen.md). Hanger inspection and cutting are connected. The native route uses the pliers, makes two cuts and receives the thick wire. It then inserts that wire, latches the pins and opens the suitcase. The route now opens the suitcase contents, moves the pencil, takes the cash and returns to room inspection. Client-list storage is connected through the existing item-use script. The route then returns downstairs, knocks on Dunning’s office door and completes payment. The apology choice and returned state have original comparisons. The route now enters the office and reads the guest ledger, birthday card, supervisory log and calendar. The route now pulls the trapped memo, tears it and receives the torn paper. Memo drawing, Clear, Back and inventory reopening are connected. Crowbar placement, lifting and joined-paper retrieval are connected. The route now turns the cabinet number wheels, opens drawer 3, takes the red box and returns to the lobby. It then follows Louie’s Nile conversation and Rosa’s questions. See [Nile and Rosa](docs/chapter-two-louie-office.md). See [Cabinet combination](docs/chapter-two-cabinet-combination.md). See [Crowbar recovery](docs/chapter-two-crowbar-recovery.md). See [Memo drawing](docs/chapter-two-memo-drawing.md). See [Trapped memo](docs/chapter-two-memo-pull.md). See [Office search](docs/chapter-two-office.md). See [Chapter 2 payment](docs/chapter-two-payment.md). See [Thick-wire suitcase lock](docs/chapter-two-thick-wire.md). See [Hanger recovery](docs/chapter-two-hanger.md). See [Chapter 2 transition and saves](docs/chapter-two-transition.md). See [Chapter 1 review](docs/chapter-one-review.md). See [Melissa’s notebook and piece return](docs/melissa-notebook.md). See [Wrong parcel and notebook](docs/wrong-parcel.md). See [Louie's delivery](docs/louie-delivery.md). See [Dunning and delivery](docs/dunning-delivery-route.md). You can unlock Room 215 with its key, enter the room, walk to the dresser and answer Rachel’s telephone call. You can then inspect the suitcase, insert its key and break it through the original puzzle. Return to the dresser, inspect the brochure and collect its paperclip. Select **Items → Paper Clip** to straighten it, then receive the thin wire. Use it on the suitcase, insert it and press all three pins to reach the original failed-attempt dialogue. See [Thin-wire lock attempt](docs/thin-wire-lock.md). See [Paperclip straightening](docs/paperclip-straightening.md). See [Brochure and paperclip](docs/paperclip.md). See [Room 215](docs/room215.md) and [Suitcase key](docs/suitcase-key.md). See [Chapter 1 jigsaw](docs/chapter-one-jigsaw.md) for the comparisons and rendering limits.

## Recovered native components

The suitcase-contents process now connects source graphics, object dragging, item acquisition, shared dialogue and back navigation. Original comparisons cover pencil positions, item animation and the complete returned cash state. See [Suitcase contents recovery](docs/chapter-two-suitcase-contents.md).

| Component | Implemented and checked | Remaining limits |
| --- | --- | --- |
| Script data | Native Swift CiNG decompression; 610 byte-exact source members with compressed and decoded SHA-256 checks; 115 BLK programs and their text, choice, debug and condition records | Decoding records is not event execution. |
| Original commands | Verified text references, wait-counter behavior, two flag banks and ordered inventory changes | Most dispatcher handlers, animation scheduling, dialogue controls and boot context remain incomplete. Unknown commands stay explicit. |
| Conditions | Original CHK spans and pure checks for event flags, game flags, inventory, doors and puzzle flags | Other condition kinds and selection-context side effects are not implemented. Unknown state is not treated as false. |
| Lobby exploration | Original floor plan, geometry, collision, counter selection and bell; return after registration, nearby-person selection, saved conversation blocks, the event 55 walking trigger, R102/R103 return travel, the R117 stairway conversation and the R213 upstairs entrance | Further rooms, other search areas and character drawing remain incomplete. |
| Animation | Original delta-frame and palette decoder; 346 animations, 3,021 frames checked against an independent Python decoder; original loop positions and restorable index buffers | One bracelet animation remains unsupported. Story timing and the original colour-mesh compositor need further recovery. All 347 ANM and 54 MTC source payloads are preserved. |
| Audio | Original SDAT constituents and sequence metadata; native music playback adapter with original note events, sample data and recovered loop ranges | Original scene cue selection and sound-effect sequencing are not complete. Apple's sampler still needs acoustic comparison with DS envelopes and modulation. |
| Jigsaw | Chapter 1 process with original randomisation, rotation, placement, hints, quit results and story return; separate full-puzzle folding preview | Chapter 1 projection and presentation retain approximations. The Chapter 3 preview is not connected to its original story. |
| Book | Full-bleed paper on both pages; weathered source-cover treatment; real Metal paper, curvature light and spine passes | Book rendering is a port presentation layer, separate from original gameplay. |

The existing music exports were not assumed intact: source recovery found truncated PCM and invalid sample tails. Recovered ROM audio is used to repair the playback banks. Unimplemented sound effects remain silent; synthetic replacements have been removed.

## Source recovery

```sh
python3 tools/extract_nds.py
python3 tools/unpack_wpf.py
python3 tools/recover_original_logic.py
python3 tools/bundle_original_scripts.py
python3 tools/decode_jigsaw.py
python3 tools/decode_anm.py
python3 tools/recover_lobby.py
```

See each tool's help and the recovery documents before regenerating optional outputs. The ROM remains at `Source/ROM/Hotel Dusk - Room 215.nds`; original extracted bytes remain under `extracted`.

ARM9 is compressed in the ROM. The old assembly listing under `extracted/binaries` was made from compressed bytes and is not a valid complete disassembly. Recovery produces the 1,031,352-byte decompressed ARM9 image, original overlay load metadata and a verified 54-entry operation dispatch map under `extracted/recovered_logic`. An ELF wrapper or extracted asset is not decompiled game logic.

- [Architecture and system boundaries](ARCHITECTURE.md)
- [Original logic evidence and addresses](docs/original-logic.md)
- [Puzzle fidelity and remaining mechanics](docs/puzzle-fidelity.md)
- [Paperback artwork provenance](docs/paperback-art.md)
- [Native implementation status](docs/native-port-status.md)

## Book and hinge behavior

The display is split at its physical centre before content safe-area margins are applied. Paper fills both screens. Handedness swaps page roles without moving the binding. Partial openings retain the two-page book layout.

`Metal/BookPaper.metal` provides the paper stock, curvature lighting and binding. Fixed grain avoids a crawling texture. Each opening produces a small, independently seeded, damped settling response on each page. Lighting stops updating after 1.8 seconds, while hidden, when closed or when inactive. Reduce Motion disables settling. Text and touch targets stay fixed. The shaded spine widens and deepens as the hinge closes.

The closed cover uses the weathered paperback treatment of `Source/Cover`, fills the entire display and adds no text. The app owns its session above the display windows. A cover-to-inner-screen transition preserves loaded data, original animation buffers, notebook drafts and jigsaw placements. The jigsaw responds to the first explicit open report; it does not require 180 degrees. These checks cover the running session. Original save-game compatibility and persistence across process termination remain unfinished.

## Build and verification

```sh
swift test
swift run HotelDuskDuoApp
```

The GPU and audio tests need Metal, CoreAudio and window-server access. They are not substitutes for playing the ROM and native implementation through matching checkpoints. `SNAPSHOT_DIR` exports book, material and puzzle previews.

```sh
xcodegen generate
xcodebuild -project HotelDuskDuo.xcodeproj -scheme HotelDuskDuoiOS \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -derivedDataPath .build/xcode build
```

The iOS build uses `UIHingeInteraction` when available. On macOS, debug book options simulate the same fold event path. Development animation previews advance manually: ANM metadata does not provide an FPS field, and the game animation clock must be recovered before assigning playback timing.

## Completion criteria

A faithful native release needs the original startup, all chapters and branches, dialogue controls, inventory acquisition, movement and collision, puzzle state machines, original render and sound cues, notebook behavior, saves, failure paths and endings. Each must be compared with the supplied ROM at matching states and input sequences, including closure and the first partial reopening. No generated dialogue, guessed event order, substitute graphics, invented puzzle or extra solution hint may fill an unrecovered system.
