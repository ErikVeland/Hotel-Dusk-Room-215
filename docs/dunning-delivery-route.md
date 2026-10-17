# Dunning questions and the delivery knock

The native Chapter 1 route now supports both registration interrupts and their required questions. It can answer Dunning's later payment-reminder call, break the suitcase key and reach the parcel-knock dialogue.

The earlier route remains covered separately. It skips the two registration interrupts, completes the paperclip and thin-wire puzzles, and does not meet the delivery conditions.

## Registration route

The detailed walkthrough's `CHP101` section identifies the relevant choices. The original KIF table supplies their IDs:

| Choice | KIF ID | Selected event |
| --- | --- | --- |
| What's your problem?! | 5 | `EP1_R102` event 22 |
| What story? | 6 | `EP1_R102` event 25 |

Use the interrupt when Dunning reacts to Kyle's name. Use the later interrupt when he dismisses the room's story. These choices make keywords 1 and 2 available. They do not themselves mark the questions answered.

The required keywords are:

| Keyword | Original label |
| --- | --- |
| 0 | I'm waiting for a package. |
| 1 | What won't you talk about? |
| 2 | My room grants wishes? |

The package discussion can also unlock optional keyword 3, `What was the trouble?`. The native route checks that branch separately from the captured route that skips its interrupt.

The unmodified original run now continues through Helen's lobby scene and R103 to the Central Hallway. Skipping keyword 3 leaves only R103 event 2, the package-trouble reminder. Its full game state matches the native branch. The extended native route answers keyword 3 and suppresses that reminder. The recording through the remaining route to Room 215 is still pending.

## Replay correction

`OriginalEventRunner` replays the parent dialogue after an interrupt. `0x0203F57C` skips `%!` and `%?` pages, then clears the replay state at the next ordinary page. The marker check must still run when that ordinary page is skipped. A skipped page can also open an interrupt window, which must disarm the old interrupt.

The previous implementation returned before this cleanup. It could skip the brochure picture and acquisition, or offer the same interrupt again. The corrected runner handles skipped-page cleanup and resets the previous event's marker on event selection.

The original talk-controller captures use vtable `0x020F3060`. The marker is at offset `0x3E8`. Window and armed bytes are at `0x94` and `0x96`. The shared text-window short remains separate.

`OriginalDunningRouteTests` starts from the captured post-registration state and selects the observed event 19 context. It checks both choices, key and brochure pictures, question availability and every game-state byte at the menu. The three required answers also match all 32,088 original bytes after each answer and on return to the lobby. The existing Jeff conversation comparison guards the other recovered interrupt sequence.

## Room 215 route

The extended native route answers Rachel, then selects the phone again for Dunning's call. `EP1_R205` events 14 and 15 provide the payment reminder. The earlier route already had game flag 9 and skipped this call.

Event 28 requires completed keywords 0–2 and Room 215 event flag 25, which follows the broken suitcase key. Region 1 then selects event 30, the parcel-knock dialogue. The thin-wire puzzle is not a prerequisite in that condition record. The knock can therefore start while the player walks back from the suitcase.

`LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock` follows ordinary native input from arrival to this dialogue. The original paperclip and thin-wire route remains in `testRenderPlayableLobbyAndRingBellThroughSession`.

## Remaining work

The native route now continues from the knock dialogue through the clock transition and returns to Room 215. Event 30 ends with opcode 16 and the original `5:10 PM` time transition. The command handler, ordinary clock process and state changes are now connected. The special morning transition remains unsupported. See [Time transition](time-transition.md). The native Door action now reaches Louie's event 32. The native route now takes the parcel, identifies Louie and completes his first conversation. See [Louie’s delivery](louie-delivery.md) for the original comparison checkpoints. The original unlocked-side rule now removes the extra native door close-up.

The original Dunning captures establish the registration choices and state checkpoints. A matching complete original run from those choices through the knock and delivery still needs recording. Native route checks and script conditions do not replace that comparison.

Character drawing, original fades, exact dialogue timing and device behaviour remain separate gaps.

## Reference material

- Guide: `Source/Walkthrough/spoilers.txt`, `CHP101`, `CHP107`, `CHP110` and `CHP111`.
- Inputs: `tools/reference/dunning-*.txt`.
- Local original captures: `extracted/reference/dunning-*`.
- Native snapshots: generated with `SNAPSHOT_DIR` during the targeted route checks.

The reference inputs use ordinary buttons and touches. They do not modify original RAM. Exploratory captures retain their original filenames, including the missed first attempt at the wish interrupt.

## Validation recorded on 17 October 2026

The combined run passed 17 tests with no failures or skips, including both full native routes and the existing Jeff comparisons. A subsequent targeted run passed both Dunning state tests, including the newly added three-answer comparison. The final run passed three tests: both Dunning comparisons and the native route to the visible parcel announcement. The announcement snapshot was inspected. `git diff --check` passed.
