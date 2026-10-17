# Lobby to bell

## Playable route

Normal Chapter 1 play now connects the entrance and lobby to the counter bell. No debug fixture is required.

1. Select **Begin Chapter 1**.
2. Continue through Kyle's narration.
3. Tap the entrance handle.
4. Continue through the lobby dialogue.
5. Hold the floor plan towards the front desk to walk there.
6. Face the counter until **Inspect** becomes available.
7. Select **Inspect**.
8. Move the counter slider to bring the bell into view.
9. Select the bell, then press **Look** or tap the bell again.
10. Continue through Kyle's comment, then ring the bell three times.

The bell's quit control returns to the same counter view. **Back** returns from the counter to the lobby. Closing the book pauses play and clears held movement.

Continue through registration and the first question menu to return to walking. Face Dunning and select **Talk** to resume his conversation. Counter inspection stays disabled while he occupies standing position 0201.

## Source and implementation

| Part | Original evidence | Native owner |
| --- | --- | --- |
| Arrival position | `0x0202AF14`, map 2 from map 1 | `OriginalMapExploration` |
| Held-touch movement | `0x0202CE5C`, direction quantisation at `0x0202CD54`, speed table at `0x020DF5B0` | `OriginalMapExploration.update` |
| Wall collision | `R102.col`, eight radial probes at `0x0202D8C4` | `OriginalMapCollision` |
| Counter eligibility | `search02`, `s02`, facing check at `0x0202E4B8` | `canInspectCounter` |
| Entry camera | Signed angle between `s02→s02f` and `s02→player` at `0x0202F1D8` | `inspectCounter` |
| Counter orbit | Source `cam_pos1`, `cam_pos2`, `cam_at1`, functions `0x02038254` and `0x0203837C` | `camera` |
| Object selection | Hit display lists, repeat selection at `0x0209AF40`, `objNN` parsing at `0x02033528` | `selectCounterObject` |
| Bell transition | R102 search table, area 2/subarea 2, `EP1_R102` events 3–4 | `OriginalEventRunner`, process 24 |
| Floor plan | `map/fmapscr/R102.bin`, map offset `(258,312)`, scale 17, vertical marker adjustment 8 | `OriginalMapBitmap`, lobby view |
| Native drawing | `R102.mdf`, `R102_s02.mdf` and original DTX textures | `OriginalMapRenderer` |
| Saved conversation block | `0x0203A444`, `0x020296C4`, getter `0x02097BB4`, setter `0x02097B7C` | `OriginalGameState`, event runner |
| Nearby person and Talk | `0x0202E740`, map action `0x0202DEC4`, first event `0x020295B0` | Lobby state, play session, event runner |
| Occupied search restrictions | `0x0202E394`, `standplace.dat`, lookup `0x020B58EC`, table `0x020DF940` | `OriginalMapRestrictions` |
| Automatic region event | `0x0202E158`, selector `0x020285F0` | `OriginalRegionSelector`, play session |

The session owns exploration state. Views forward page coordinates and present the published state. The runtime timer and deterministic checks share `advanceFrame()`.

## Restored data

Run `python3 tools/recover_lobby.py` from the repository root. This command requires the restored `extracted/unpacked_wpf` tree.

The tool bundles the original compressed `R102.col`, `R103.col` and `R117.col` payloads and records member, payload and decoded hashes. It also bundles `standplace.dat` and the 47 room-permission bytes at ARM9 address `0x020DF940`. These additions need `extracted/root` and the recovered ARM9 image. The tool also updates the manifest entry for `R102/laungr.dtx`.

That texture has 1,296 compressed 4 × 4 blocks. Its allocated width and logical width are both 128. The original upload at `0x02083534` transfers a linear stream of blocks. The last row contains 16 of its 32 blocks. The decoder retains these blocks and leaves absent blocks transparent for the renderer to discard. It does not infer their colours. The original palette, texel stream and logical dimensions remain available.

Only this newly checked texture is promoted in the bundled manifest. The general decoder can read other equivalent block streams, but their manifest entries remain unsupported pending separate review. Full texture regeneration can therefore produce a wider coverage report.

## ROM comparison

The reference runner uses melonDS commit `906e9ebb27da8c6a715cd7abab4abfe8a8d29427`. It executes separately from the native app.

- ROM SHA-256: `134236d0793bad5d563de119068774a3e1c43a9b1614b1fe1c1fbf923eab676b`.
- Starting checkpoint: `extracted/reference/lobby-bell-08/advance6.mln`.
- Checkpoint SHA-256: `6ab55ef97d5085601348a0656f677852b4fca2c9c45f25b052ce8bb850530393`.
- Inputs: [`tools/reference/lobby-bell.txt`](../tools/reference/lobby-bell.txt).
- Recorded run: `extracted/reference/lobby-bell-route`.

The sequence uses ordinary touch and A-button inputs. It contains no memory writes. Its starting point is a restored lobby checkpoint, so this comparison does not establish a fresh boot-to-ending playthrough.

```sh
.build/rom-reference/hotel-reference \
  'Source/ROM/Hotel Dusk - Room 215.nds' \
  extracted/reference/lobby-bell-new-run < tools/reference/lobby-bell.txt
```

Use a fresh output directory. The checkpoint, ROM and generated captures remain local and ignored by Git.

| Checkpoint | Original result |
| --- | --- |
| Arrival | Position `(-82, 12288, 21217)` in 20.12 fixed units |
| Wall, after raw touch `(175,140)` | Position `(25156, 12288, -4267)` |
| Counter, after raw touch `(180,70)` | Position `(22396, 12288, -4267)`, yaw `3.50173974`, search area 2 available |
| Counter entry | Orbit fraction `0.76598173` |
| Slider at zero | Eye `(6677,12993,-2786)`, target `(19319,10642,-18792)` |
| Repeated raw touch `(60,126)` | Original bell comment, then process 24 after A |
| Three bell presses | Dunning's entrance begins |

Right-handed raw DS touch `(x,y)` maps to page `(y,255-x)`. The reference input manager starts this held touch one frame late and releases it two frames late. The 45-frame counter input therefore produces 46 movement updates. Native tests compare those updates, not equal numbers of host input frames.

The native counter image was visually compared with the ROM capture. Both show the original desk, telephone, calendar and bell in matching positions. This is a visual comparison, not a pixel-equivalence claim.

## Checks on 17 October 2026

- Native macOS debug build succeeded with Xcode 26.6.
- 33 targeted Swift tests passed with no skips. They cover the lobby, event runner, entrance, bell, choices, initial state and textures.
- The session test plays narration, entrance, walking, selection, bell quit/re-entry and three rings without a fixture or injected process result.
- Page snapshots were checked for the lobby, selected counter object and bell.
- All 2,920 manifest-supported textures match the independent Python RGBA hashes.
- Seven Python source-recovery checks passed.
- `git diff --check` passed. No repository lint command is configured.

The documented Swift command is used directly because this repository has no `package.json` scripts. On this host, the targeted command was:

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache" \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SNAPSHOT_DIR=/tmp/hotel-bell-native \
swift test --disable-sandbox --filter \
'OriginalLobbyExplorationTests|OriginalEventRunnerTests|OriginalBellProcessTests|OriginalTextureTests|OriginalEntranceProcessTests|OriginalChoiceTests|OriginalGameStateTests|LayoutSnapshotTests/testRenderPlayableLobbyAndRingBellThroughSession'
```

Rendering and session checks require Metal, CoreAudio and window-server access. The first sandboxed rendering check skipped Metal. The final run had the required access and no skips.

### Registration and return checks

The later run passed 34 targeted Swift tests with no skips. It covered map conversation blocks, standing-position restrictions, region selection, movement, the event runner, bell, signing, choices and initial state. The session test also completed registration, asked the package question, returned to walking and started Dunning's mode-0 event 50. It used session touches and signing strokes throughout. The resulting floor-plan snapshot showed **Inspect** disabled and **Talk** enabled.

The map-conversation checks include the original block offset `0x1C2` for map 2/person 2, the 87 standing-position records and region 3's time-dependent event selection. A seventh check compares the post-registration capture and the event 55 walking trigger.

The original run reached the lobby after registration and the package question using ordinary inputs, without memory writes. At `extracted/reference/post-registration-lobby/lobby.mln`, Kyle remained at `(22396,12288,-4267)`, facing `3.50173974` radians. Dunning's saved block was 6, his placement was map 2/point 1, Talk was enabled and Inspect was disabled. These values agree with the native route.

The checkpoint SHA-256 is `060a6d7e0e5a216eb6d7b4e4aff20c87b0e1055766037e74994dff6d017b9091`. The consolidated input file is [`registration-to-lobby.txt`](../tools/reference/registration-to-lobby.txt). It starts from `lobby-bell-route/dunning.mln`, SHA-256 `2ba183d8c56ab50c040300a398396375f6ab29bd70a88a40568e1d3a627da5cb`. The input file combines the executed checkpoint segments. The combined file has not yet been replayed as one run. It retains idle inputs and timing from the source segments.

From that lobby checkpoint, raw touch `(11,47)` selects Talk. The capture at `extracted/reference/post-registration-talk/talk` shows “What is it?” and event key 50, mode 0, event ID 49. The native selection agrees. A capture-dependent test compares Kyle's position, facing, nearby person, disabled inspection and saved block with the original RAM. It skips explicitly when that local capture is absent.

Walking west, then north, enters region 3 before the R103 doorway. The original capture at `extracted/reference/post-registration-exit/exit` selects event 55 at `(-7304,12288,-7777)`. Native movement and selection match. The original copies its current position at controller `+0x15514` to the conversation return position at `+0x1552C`. The previous frame's position at `+0x15520` is different. The native host therefore retains the region entry position while the event runs.

For this run, the Swift filter was:

```text
OriginalMapConversationTests|OriginalLobbyExplorationTests|OriginalEventRunnerTests|OriginalBellProcessTests|OriginalSignProcessTests|OriginalChoiceTests|OriginalGameStateTests|LayoutSnapshotTests/testRenderPlayableLobbyAndRingBellThroughSession
```

### Lobby, hallway and stairway checks

The final targeted run passed 37 Swift checks with no failures or skips. Seven Python recovery checks and `git diff --check` also passed.

Normal session input now covers the R102/R103 exit, return to R102, re-entry to R103 and the R117 corridor. It then reaches Melissa’s stairway question menu, interrupt and help choice. Process 26 is now connected. See [Chapter 1 jigsaw](chapter-one-jigsaw.md) for its later implementation and checks.

| Original checkpoint | Result |
| --- | --- |
| `r103-entry/entry` | Map 3 from map 2. Position `(28,12288,16679)`, facing π. |
| `r102-return/return` | Map 2 from map 3. Position `(-8190,12288,-26467)`, facing 0. |
| `r103-west/west` and `r103-reminders` | Region 2 selects reminder events 0, 1 and 2 on successive movement inputs. |
| `r103-reminders/third-walk` | Map 17 from map 3. Position `(6636,12288,4014)`, facing `-1.57201707`. |
| `r117-north/north` | Region 1 selects event 15 at `(6636,12288,-7301)`. |
| `r117-stairs/stairs` | The R213 departure selects event 10, then Melissa’s scene 11. |
| `r117-louie/menu` | Event 35 shows keyword 8, “A puzzle, huh?”. The local directory was misnamed during capture. |
| `r117-louie-interrupt/choices` | Event 44 offers IDs 23 and 22. ID 22 is “Let me help.” |
| `r117-louie-help/puzzle` | Event 48 starts overlay 2, process 26. The original jigsaw is partly assembled. |

The position and facing come from `out_<previous map>` model markers through `0x0202AF14` and `0x0209D828`. Floor-plan origins come from `0x020E02AC`. Corridor movement applies the original extra factor of 1.35 at `0x0202D888`. The R117 region position matches after 31 northward movement updates.

Departure selection uses `0x020287B0`. R102 event 54 cancels departure when the package question is still unasked and flag 16 is set. Request kind 2 restores the previous position, as `0x0202C264` specifies. Unit checks cover this branch and the permitted departure after the package question.

[`hallway-to-jigsaw.txt`](../tools/reference/hallway-to-jigsaw.txt) combines the executed input segments from `r103-entry/entry.mln` to the puzzle. It uses ordinary input without memory writes. The combined file has not yet been replayed as one run.

- R103 entry checkpoint SHA-256: `4b38b4a50d488ddb4c02a72a67a4eea4edb51d904a36554cf30c3ddc66431fdb`.
- Jigsaw checkpoint SHA-256: `9770cd26d7c45be3050aab0c3ed43025d28fc1e077acf6479edec1c6171f44c9`.

One rendering run crashed inside a CoreAudio output callback. Its retry passed. That audio lifecycle failure remains unresolved and is separate from the script comparisons.

## Remaining gaps

- This slice now supports R102, R103, R117 and R213, including the stairway jigsaw and Jeff's upstairs entrance. Other search areas remain unavailable.
- Map travel, saved conversations and the covered region triggers match the listed original checkpoints. Exact transition timing and stair animation remain unimplemented.
- Native camera smoothing and collision calculations use floating-point maths. The checked positions agree, but all directions and corner cases have not been compared with original execution.
- The floor-plan marker, cursor, slider and buttons use native controls. Search portrait composition remains absent, so the other counter page is blank.
- Character animation, original fades, bell swing drawing and exact audio timing retain their existing limits.
- The complete opening cinematic, original saves, other chapters and remaining puzzles remain incomplete.
- The iOS build, physical Duo touch and hinge behaviour were not checked in this work.

R213 entry and Jeff's walking trigger are now connected. See [Upstairs corridor](upstairs-corridor.md). Continue the original route towards Kyle's room using the [walkthrough route plan](walkthrough-route-plan.md).
