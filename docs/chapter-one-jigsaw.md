# Chapter 1 jigsaw

Normal play now reaches and completes Melissa's partly assembled jigsaw. This implements process 26, overlay 2, variant 0. It is separate from the development preview and the later Chapter 3 folding sequence.

## Recovered behaviour

| Behaviour | Original evidence | Native implementation |
| --- | --- | --- |
| Start with fifteen seated pieces | Default mask at `0x0220183C`, initialiser `0x021FCDB4` | Loose indices 3, 5, 6, 9 and 10, mask `0x668`. A saved nonzero mask replaces the default. |
| Scatter loose pieces | `0x02200F04` | Original LCG, rejected regions, fixed-point conversion and random quarter-turn angles. The host supplies a seed. |
| Select and drag | `0x02201280`, `0x021FDB30` | Select the nearest unplaced rectangle, retain the grab offset, raise its depth and clamp its position. |
| Rotate | `0x021FDB30` | Change the target by half a π unit. Ease by 0.3 per update, then normalise modulo 2. |
| Snap | `0x021FDB30`, `0x02201130` | Require the matching slot, angle 1.5 and squared world-space distance below 0.09. Store exact seated coordinates and clear its loose flag. |
| Idle hint | `0x021FD72C`, `0x022015E4`, `0x0220153C` | After a release or rotation, five idle seconds request mode 20, pair `(3, 1)` or `(3, 2)`. Play original System dialogue and resume the same puzzle. |
| Completion | `0x021FE234`, `0x02064DC4` | Start the completion fade, play archive 1 entry 0, wait through the original counter and exit. |
| Quit result | `0x021FE578` | Twenty placed pieces return 0. Fifteen return 2. Other counts return 1. |
| Save loose pieces | Destructor `0x021FD478`, mask builder `0x021FF900` | Write the mask at original address `0x02111638`, game-state offset `0x14AC`, before resuming the parent event. |

`OriginalJigsawProcess` owns these rules. `OriginalPlaySession` supplies timing, sound, hint execution and script return. `OriginalJigsawPageView` forwards touches and presents the original artwork.

Mode-20 hints use System scene 202. They do not mark a normal map event complete. A suspended story runner retains its event and operation position while the hint runs.

## Original execution evidence

All listed runs use ordinary touch and button inputs. They contain no diagnostic memory writes. The ROM, reference core revision and initial puzzle checkpoint are recorded in [Lobby to bell](lobby-to-bell.md).

| Local capture | Result |
| --- | --- |
| `r117-louie-help/puzzle` | Original initial state. The directory name predates the corrected character identification. |
| `jigsaw-piece5/placed` | Piece 5 snaps to `(-819, -4505)`, angle 1.5, loose flag zero. |
| `jigsaw-piece3/placed` | A rotation and drag seat piece 3. |
| `jigsaw-combined/after-dialogue` | All five pieces seat. Process 26 returns to R117 event 51. |
| `jigsaw-partial-quit/quit` | One additional piece seated. Saved mask `0x648`, result 1, R117 event 49. |
| `jigsaw-untouched-quit/quit` | No additional pieces seated. Saved mask `0x668`, result 2, R117 event 50. |
| `jigsaw-hint/hint` | Original System event 1502, mode 20, pair `(3, 2)`. |

[`jigsaw-to-completion.txt`](../tools/reference/jigsaw-to-completion.txt) replays the complete puzzle from the saved initial checkpoint. The combined file was executed successfully. It reaches event 51 without injected outcomes.

The initial seed `0x3DEAC027` reproduces all twenty captured piece records and final seed `0xC1DA6164`. The native checks compare position, depth, angle and loose flags against the original RAM capture.

Additional checkpoint SHA-256 values:

- Partial quit: `edf1f3db11e047b781c605ca31e527bf7ae38b593573a5cf3859ce577890b0fa`.
- Untouched quit: `52c068bf8a932e00a1636a2eaa190681c8639157e48f08e0c540ae59ef87c046`.
- Idle hint: `0ec8eda9e9a15941af97fdbb792b42613203f668c1da7f94340cfd2cc937640f`.

## Native checks and remaining limits

The normal session check starts at arrival and uses movement, conversation and puzzle input methods. It completes all five pieces, returns from an idle hint, reaches event 51, collects the dropped piece and continues to Jeff's entrance in R213. It supplies a repeatable random seed but does not inject a process result or game-state checkpoint.

Targeted checks cover initial RAM, randomisation, wrong rotation, snap threshold, drag bounds, all-piece completion, hint text, hint return, quit results and saved masks. Checks that need local captures skip explicitly when those captures are absent.

On 17 October 2026, 38 targeted Swift checks passed with no skips. They covered the jigsaw, event runner, game state, supported maps and normal-session page capture. Seven Python recovery checks and `git diff --check` also passed. The Swift run built the macOS app. This work did not check an iOS build or physical Duo input.

The page projection approximates the original fixed-point rays and per-piece depth. Original rasterisation, piece seams, selected-piece glow and exact display scheduling remain unverified. The right-edge textures retain their narrower source width. Fades affect process timing but are not drawn. The quit control is native. Kyle's portrait and talk background on the other page remain absent.

The dropped-piece interaction now blocks R117 event 52 until the player selects and confirms the piece. The next opcode adds item 3 and shows its original enlarged image. See [Touch pictures](touch-pictures.md) for the recovered mask, decoder checks and reference inputs.

After this interaction, native play now enters R213, the upstairs corridor, and reaches Jeff's entrance. Use the [walkthrough route plan](walkthrough-route-plan.md) for Jeff's conversation, Room 215 entry and the later suitcase sequence.
