# Hotel Dusk: Room 215 — native Duo rewrite

This is an unfinished Swift and SwiftUI rewrite of the supplied Nintendo DS game. The ROM is a reference for recovering and comparing behavior. The app does not execute ARM code or embed a DS emulator. **The complete original game is not yet playable.**

The former demonstration dialogue, arbitrary initial inventory, chapter shortcuts, suspicion meter, floor plan and procedural corridor have been removed from the app. Their source is retained outside the build in `archive/retired-prototype`. The normal launch states that the native rewrite is in progress. Development previews remain available through **Book options** in debug builds.

## Recovered native components

| Component | Implemented and checked | Remaining limits |
| --- | --- | --- |
| Script data | Native Swift CiNG decompression; 610 byte-exact source members with compressed and decoded SHA-256 checks; 115 BLK programs and their text, choice, debug and condition records | Decoding records is not event execution. |
| Original commands | Verified text references, wait-counter behavior, two flag banks and ordered inventory changes | Most dispatcher handlers, animation scheduling, dialogue controls and boot context remain incomplete. Unknown commands stay explicit. |
| Conditions | Original CHK spans and pure checks for event flags, game flags, inventory, doors and puzzle flags | Other condition kinds and selection-context side effects are not implemented. Unknown state is not treated as false. |
| Animation | Original delta-frame and palette decoder; 346 animations, 3,021 frames checked against an independent Python decoder; original loop positions and restorable index buffers | One bracelet animation remains unsupported. Story timing and the original colour-mesh compositor need further recovery. All 347 ANM and 54 MTC source payloads are preserved. |
| Audio | Original SDAT constituents and sequence metadata; native music playback adapter with original note events, sample data and recovered loop ranges | Original scene cue selection and sound-effect sequencing are not complete. Apple's sampler still needs acoustic comparison with DS envelopes and modulation. |
| Jigsaw | Original twenty-piece art, rotation controls, reverse and tabletop; session-owned assembly and first-open folding response | This is a development preview. Original placement tolerance, rotation increments and complete story gating still need verification. |
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
```

See each tool's help and the recovery documents before regenerating optional outputs. The ROM remains at `Source/ROM/Hotel Dusk - Room 215.nds`; original extracted bytes remain under `extracted`.

ARM9 is compressed in the ROM. The old assembly listing under `extracted/binaries` was made from compressed bytes and is not a valid complete disassembly. Recovery produces the 1,031,352-byte decompressed ARM9 image, original overlay load metadata and a verified 54-entry operation dispatch map under `extracted/recovered_logic`. An ELF wrapper or extracted asset is not decompiled game logic.

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
