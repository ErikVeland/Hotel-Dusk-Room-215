# Architecture

The app loads recovered game data and runs native Swift state machines. SwiftUI
presents a two-page book. Metal draws recovered models and book materials.
AVFoundation plays recovered audio and the optional recorded soundtrack.

The ROM comparison runner lives under `tools/reference`. It executes separately
and is never linked into the app.

## Targets and directories

`Package.swift` defines `HotelDuskDuoKit`, `HotelDuskDuoApp` and the XCTest target.
`project.yml` defines the iOS application and generates the checked Xcode project.
The iOS application depends on the same package library as the macOS application.

| Directory in `Sources/HotelDuskDuoKit` | Responsibility |
| --- | --- |
| `Engine` | Session ownership, assets, hinge state and audio |
| `Engine/Original` | Recovered state, scripts, event selection and puzzle processes |
| `Models` | Book layout, transcript, journey and notebook drafts |
| `Renderer` | Binary graphics decoders, projections, image composition and Metal renderers |
| `Views` | Pages, controls and input forwarding |
| `Metal` | Book material and lighting shaders |
| `Resources` | Original payloads, lookup manifests, enhanced artwork and recordings |

## Session and input

```text
HotelDuskDuoApp
  GameSession
    DuoHingeManager, AudioController, MemoDraft, JigsawPuzzleManager
    OriginalPlaySession
      OriginalEventRunner
      OriginalMapExploration
      active puzzle process and renderer

Player input -> view coordinate mapping -> play session -> event runner or process
Game state -> published session state -> book pages
Hinge input -> hinge manager -> pause/resume and fold events
```

The app creates one `GameSession` above its display windows. Display changes keep
the loaded game, animation buffers, drafts and puzzle placements alive.
`DuoBookContainerView` retains the inner pages while the cover or preview hides them.

Views convert touches into original page coordinates. The session forwards these
to the active process and handles timing, audio, pause and story return. Puzzle
rules belong in process types. Views must not invent state transitions.

`DuoBookLayout` splits the display at its physical centre before applying safe
areas. Handedness changes page roles without moving the binding. Some original
coordinate paths still need device checks for complete left-handed support.

`DuoHingeManager` distinguishes closed, partially open and fully open states.
Closing pauses play. The first explicit reopening can complete a fold action
without requiring a flat posture. A manual menu pause remains active after opening.

## Game runtime

| Layer | Main types and role |
| --- | --- |
| Binary access | `OriginalData` decodes CiNG containers and bounds-checks reads. |
| Script data | `OriginalScriptCatalog` loads programs. `OriginalBlockGraph` retains BLK records and source offsets. |
| Selection | `OriginalConditions`, `OriginalEventSelector` and `OriginalEventSession` evaluate conditions and retain selection context. |
| State | `OriginalGameState`, `OriginalInventory` and `OriginalStateCommand` read and update recovered state fields. |
| Execution | `OriginalEventRunner` manages dialogue, choices, questions, process requests and event completion. |
| Host | `OriginalPlaySession` connects execution to maps, timing, audio, saves and native processes. |
| Exploration | `OriginalMapExploration` handles movement, collision, search, nearby people, cameras and object selection. |

`OriginalEventRunner` is a value type with explicit phases. A halt retains its
reason, program, event and source offset where available. Unsupported required
behaviour returns the player to the latest safe walking place. It does not mark
the interaction successful. Recognised presentation operations can run without
full original output. The runner records those in `unrenderedPresentation`.

Map movement uses the recovered fixed-point trigonometric rules. Door, region and
search tables drive arrivals, departures and close-ups. Object visibility applies
the same flags to rendering and picking. Search scenes retain their parent when
a nested close-up or shared System response runs.

Process types hold recovered puzzle state and outcomes. Projection types map
native touches into source coordinates. Renderers draw the matching assets.
The script resumes only after the process returns through its defined boundary.
Source addresses and process-specific limits live in the linked recovery records.

## Saves and the book

`GameSession` keeps an exact resume save and a separate safe walking checkpoint.
Resume data includes a base state and a journal of native inputs. Restore replays
the journal and checks state, phase, seeds and save operations. Interrupted final
writes retain the preceding complete record.

Inputs, simulation steps and writing updates save incrementally. Walking
boundaries compact the journal. Pausing, backgrounding and returning to the title
flush progress. A failed write retains the previous file and the live session.

Continue validates the resume save, then tries the safe walking checkpoint. If
neither restores, play starts at Chapter 1. Valid legacy chapter saves remain
available. A new game requires confirmation when readable or unreadable progress
exists. Native save support does not provide DS cartridge-save compatibility.

`DialogueNotebook` lays out and retains the written transcript. `BookJourney`
records arrivals, walked routes, interactions and departures. Entries keep their
own portraits and sketches. Earlier saves restore their own book. Older save
formats remain readable and begin recording journey entries after restore.

`BookArtworkStore` stores each drawing once in `book-art` beside the save files.
Save checksums include image references. Restore checks the referenced bytes.
A backup must include the save files and their `book-art` directory.

`OriginalNotebook` separately owns the game's writable pages, acquired drawings,
eraser and undo state. Original pages use recovered state bytes. Native added
pages and supported reading positions persist through interaction replay.

## Graphics and audio

Bitmap, animation, texture and model libraries load through `Bundle.module`.
Manifests identify payloads and retain checksums and decoder coverage. Source
payloads remain available for decoding and reference comparisons. Optional
detailed decoder reports can be regenerated with the recovery tools.

`OriginalAnimationDecoder` retains delta-frame buffers and source-bound
checkpoints. Decoded frame order does not establish original animation timing.
`OriginalMapRenderer` uses recovered models, textures and cameras. CPU hit tests
do not establish that visible device geometry maps to the same touch points.

`OriginalArtwork` resolves optional enhanced images by source pixels. Missing or
invalid overrides fall back to original artwork. Enhanced dimensions do not
change logical game coordinates or hit masks. The active pack needs further
visual, motion and target-device review.

`BookPaper.metal` draws fixed paper grain, mounting card, tape and binding.
Materials are cached. Hinge lighting settles for a finite interval and stops
while hidden or inactive. Reduce Motion disables settling and page animation.

`AudioController` coordinates native and recorded music, mute, volume and effects.
`OriginalSoundArchive`, `OriginalSequenceMachine`, `OriginalSoundDriver` and
`OriginalEffectRenderer` implement recovered sequence and sample playback.
`OriginalEffectPlayback` adapts output to AVFoundation. Switching music sources
retains the cue and position with a short crossfade.

Recovered rumble cues pass through an injected feedback boundary. Supported iOS
devices use Core Haptics. Other devices use a no-op adapter. Acoustic and physical
feedback parity still require original-device comparison.

## Recovery and verification

Ordinary bundled-data access does not need the ROM. Recovery tools read local
`Source`, `extracted` and `.tools` inputs. These directories remain outside Git.
Do not delete captures or source bytes as build cache.

Use the [verification guide](docs/verification.md) for commands and dependencies.
Keep these kinds of evidence distinct:

| Check | Establishes |
| --- | --- |
| Manifest and hash checks | Stored bytes match their expected digests. |
| Decoder tests | Covered outputs match recorded values. |
| State and process tests | Covered behaviour matches asserted rules. |
| Matching ROM/native traces | Covered behaviour agrees at matching inputs and states. |
| Render and audio tests | Covered output works on the test host. |
| Device checks | Tested touch, hinge, display and lifecycle paths work on that device. |

Missing fixtures must remain visible. A historical pass does not validate a new
checkout. Handler presence does not prove route completion or presentation parity.
Preserve original identifiers, raw records, hashes and offsets when changing
recovered code. Keep unknown behaviour explicit.

See the [documentation index](docs/README.md) for format records and route evidence,
and [implementation status](docs/native-port-status.md) for the remaining gaps.
