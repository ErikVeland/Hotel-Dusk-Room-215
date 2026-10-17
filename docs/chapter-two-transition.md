# Chapter 2 transition and native saves

The normal native route now completes the Chapter 1 review, offers a save, shows the Chapter 2 title and enters Room 215. The opening room event finishes and returns control to walking. The remaining Chapter 2 route is unfinished.

## Original behaviour

Request 4 resets chapter-local state through `0x0202C264` and `0x020340D0`. It changes the chapter, sets numeric time to zero, and clears conversation blocks, item-check flags, keywords and both event banks. Inventory, notebook pixels and unrelated state remain intact. Request 1 records the same-map return. The map host stores Kyle’s live pose.

Process 140 asks whether to save. Its Yes branch starts process 120, which offers three slots and a separate Confirm action. Leaving the unselected slot screen also continues to the title. Process 147 is a sentinel in this controller, not the chapter clock.

Process 9 owns the chapter title. Initialisation at `0x02017278` records ` 05:30PM`, including the leading space, and clears byte `0x137B`. The title waits for player input. Assembly at `0x02018310` calls `0x020987CC` to save the retry checkpoint before the room arrival. `EP2_R205` event 0 then runs and relocates Kyle through its request 9.

## Native ownership

- `OriginalGameState` applies the recovered reset, time label and retry-state effects.
- `OriginalPlaySession` consumes the chapter request, owns the save/title modal and loads the new program and keyword table.
- `OriginalChapterTransition` holds slot selection, overwrite confirmation and storage errors.
- `OriginalChapterSaveStore` supplies a small injected storage boundary.
- `OriginalChapterFileStore` writes three independent files atomically under the app’s `Application Support/HotelDuskDuo/ChapterSaves` directory.
- `GameSession` lists available saves and starts a fresh play session from the selected checkpoint.

The native save format contains all 32,088 original game-state bytes, the separate condition byte, a format version, a state checksum and a native timestamp. It is not a DS cartridge save. Loading validates the version, checksum, state size and supported checkpoint. Save failures retain the slot screen and allow retry. Occupied slots require explicit replacement confirmation.

Only the Chapter 2 starting checkpoint is currently supported. Loading replays the title and room arrival without repeating the chapter reset. General midgame saves, other chapter checkpoints and DS save import remain unfinished.

## Presentation limits

The title uses original background, clock and item bitmaps. Its text uses native fonts. The original letter animation, fades and title audio are not reproduced. Save controls also use native components. These presentation limits do not establish a complete original presentation match.

## Validation

Twenty targeted checks pass across chapter review, chapter saves, ordinary time transitions and the event runner. Checks cover:

- All original state bytes at the save prompt, title and completed Chapter 2 room arrival.
- Save cancellation, storage failure, retry and overwrite confirmation.
- All three file slots, damaged records and invalid slot indices.
- Restore in a fresh session, followed by the same room event and state as uninterrupted play.

The native route check uses ordinary session inputs from hotel arrival through the review and Chapter 2 room entry. Screenshots cover the save prompt, title and returned room. Physical Duo checks remain outstanding.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OriginalChapterSaveTests|OriginalChapterReviewTests|OriginalTimeTransitionTests|OriginalEventRunnerTests'
SNAPSHOT_DIR=/tmp/hotel-chapter-two-final DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock
```

There is no package-script wrapper for these Swift checks, so validation uses the package’s native test command.

## Original captures

The scripts in `tools/reference/` continue the modified delivery fixture without additional memory writes. They do not establish an unmodified original playthrough from a new game.

| Script | Evidence |
| --- | --- |
| `chapter-two-no-save.txt` | Decline save and reach the chapter title |
| `chapter-two-clock.txt` | Title waits, then starts the room event |
| `chapter-two-save-menu.txt` | Open three empty save slots |
| `chapter-two-save-slot.txt` | Select slot 1 and show Confirm/Cancel |
| `chapter-two-save-confirm.txt` | Confirm the write in an isolated generated cartridge-save directory |
| `chapter-two-save-finish.txt` | Successful save returns to the title |
| `chapter-two-save-back.txt` | Back from unselected slots returns to the title |
| `chapter-two-room.txt` | Finish the opening room event |

The walkthrough’s `CHP201` route leaves Room 215 and talks to Rosa. That native continuation is now connected. See [Rosa in Chapter 2](chapter-two-rosa.md). The [Linens Closet and toolbox route](chapter-two-linens.md) is also connected.
