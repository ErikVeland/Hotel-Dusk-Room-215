# Numbered sticker process

Examining the lobby vending-machine sticker selects shared `System` event 228,
whose dialogue leads to event 229 and embedded process 87. The chapter-only
process audit does not include this shared script. The native host previously
halted here with `Process 87 is not recovered`.

The original factory case `0x57` at `0x0200B334` loads slot 42, overlay 43.
The initializer at `0x021FCC08` selects one of seven room columns from the
70 signed bytes at `0x021FD79C`. The row is the persistent puzzle random value
from `0x02027CF4` modulo ten, incremented modulo ten when game byte `0x137F`
is set. The native implementation retains that random value in game state.

The original drawing function at `0x021FD49C` combines `trick/seal/bg.bin`
with the vertical `number.bin` glyph atlas. Its sign and two digits occupy
page rectangles starting at (48, 112), (80, 112) and (112, 112). The artwork
and glyphs are composited before rotation into the 192 by 256 book page.

The update function at `0x021FD0C8` fades in, waits for shared exit control 5,
fades out and returns 2. The native exit control covers page x 152 through 191
and y 224 through 255. Completion runs the original event operation, including
the kind-5 search refresh request, and restores the parent search runner.
The touch is recorded and replayed through the existing instant-save input log.

Regression tests exercise the normal chapter search fallback through shared
events 228 and 229, room-specific signed clues, the shifted random row, fade
and exit behaviour, artwork orientation, and serialised input replay through
the return to exploration. An isolated ROM checkpoint confirmed the exit
input at raw touch (15, 172); this is component evidence, not a full Chapter 1
playthrough comparison.

## Verification

All five `OriginalNumberSealTests` pass, including the original failing
shared-system event. The Swift package compiles for the iOS 17 simulator.

The fast profile ran 257 Swift tests: 256 passed and
`OriginalEventCompletionTests.testUnrecoveredLateChapterInspectionCounterStaysExplicit`
failed because the existing completion handler returns `completed` where that
test expects `requiresOriginalHandler(mode: 10)`. This change does not modify
that handler or test. The verification-tool tests and static story audit pass.

The full suite was interrupted after audio-unit and graphics availability
failures in this restricted environment. Observed affected cases were:

- `DialogueNotebookTests.testFoldPausesAtTheSameDialogueAndHistoryIsBlockedByPuzzles`
- `DialogueNotebookTests.testSessionRecordsBeforeRenderingAndDoesNotSkipUnwrittenDialogue`
- `HotelDuskDuoTests.testNativeBuildDoesNotStartInventedGameplay`
- `LayoutSnapshotTests.testRenderConversationParticipantInk`
- `LayoutSnapshotTests.testRenderNoirNotebookExploration`
- `LayoutSnapshotTests.testRenderPlayableLobbyAndRingBellThroughSession`

The Xcode application build could not resolve the existing local
`HotelDuskDuoKit` package product. The separate iOS package compilation succeeded;
no device installation or full application build is claimed.
