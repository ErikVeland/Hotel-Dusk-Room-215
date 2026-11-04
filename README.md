# Hotel Dusk: Room 215

An unfinished native Swift and SwiftUI port for a two-page Duo display. The app
runs recovered game scripts and Swift implementations of the original processes.
A separate ROM runner supports comparison with the Nintendo DS game.

The bundled resources support ordinary play without the ROM. Source recovery and
some tests need local files that are not included in Git.

## Build and run

Use Xcode with the macOS SDK and Swift 5.9 or later. The package targets macOS 14
and iOS 17. Newer device APIs can require a newer SDK.

```sh
swift build
swift run HotelDuskDuoApp
```

For iOS, open `HotelDuskDuo.xcodeproj`, select **HotelDuskDuoiOS**, choose your
connected device and set your signing team. The project is generated from
`project.yml`. After changing that file, regenerate it with XcodeGen:

```sh
xcodegen generate
```

See [TestFlight preparation](docs/testflight-beta.md) for archives and distribution.

## Play

Select **Begin Chapter 1** to start in the lobby. **Continue** restores saved
progress, including supported conversations, puzzle inputs and notebook state.
Starting a new game requires confirmation when saved progress exists.

- Drag the room view to look around. Hold the movement pad to walk.
- Use **Door**, **Inspect** or **Talk** when close enough and facing the target.
- Open **Items** to inspect, use or show an owned item.
- Swipe right or select **Previous pages** to reread dialogue.
- Open **Book options** for pause, sound, music source and previous conversations.
- Close the Duo to pause. Reopening retains the session and reading position.

Progress saves after inputs and simulation updates. Failed saves retain the
previous file and expose the error in the pause menu. If an interaction cannot
continue, the app restores the last safe walking place. The interaction may need
to be repeated. Keep the `book-art` directory with any resume-save backup.

Debug builds also expose development previews under **Book options**.

## Verification and limits

Install the Python verification dependency in a local environment:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/requirements.txt
.venv/bin/python tools/verify.py --profile fast --strict
.venv/bin/python tools/verify_full_route.py --output .build/verification/full-route-001
```

The ordered route checks Chapter 1 through the Chapter 10 ending. It restores
checkpoints between sections and validates the required handoff saves. The
recorded 3 November 2026 run passed all 80 sections without failures or skips.
That result covers one tested route. Alternate branches, original-game fidelity
and device behaviour need separate checks.

Metal, audio and layout tests require the corresponding macOS services. Reference
tests also need recovered captures. Strict verification fails on missing-fixture
skips. Read the [verification guide](docs/verification.md) for profiles,
dependencies and result interpretation.

Open work includes character presentation, selected touch mappings, puzzle
gestures, audio parity, alternate branches and DS cartridge-save compatibility.
Enhanced artwork is bundled and active, but still needs visual and device review.
See [implementation status](docs/native-port-status.md) for specific limits.

## Repository

| Path | Contents |
| --- | --- |
| `Sources/HotelDuskDuoApp` | SwiftUI application entry point |
| `Sources/HotelDuskDuoKit` | Engine, renderers, views and bundled resources |
| `HotelDuskDuo` | iOS icon, privacy declaration and distribution settings |
| `Tests` | Swift tests and checked reference fixtures |
| `tools` | Recovery, artwork, verification and ROM comparison tools |
| `docs` | Format findings, route evidence and maintenance guides |

[Architecture](ARCHITECTURE.md) explains the runtime boundaries.
The [documentation index](docs/README.md) groups the recovery records by topic.

## Source recovery

Local recovery inputs live in ignored directories:

- `Source/ROM/Hotel Dusk - Room 215.nds`: supplied ROM.
- `extracted`: extracted bytes, recovered code and reference captures.
- `.tools`: local Ghidra and melonDS installations.

Typical recovery steps are:

```sh
python3 tools/extract_nds.py
python3 tools/unpack_wpf.py
python3 tools/recover_original_logic.py
python3 tools/bundle_original_scripts.py
python3 tools/decode_jigsaw.py
python3 tools/decode_anm.py
python3 tools/recover_lobby.py
```

Read the [logic recovery notes](docs/original-logic.md) before regenerating data.
ARM9 is compressed in the ROM. The old assembly listing made from compressed
bytes is not a valid disassembly. Recovery uses the decompressed ARM9 image and
original overlay metadata.
