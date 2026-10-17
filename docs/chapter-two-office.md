# Chapter 2 office search

The native route now enters Dunning's office after payment. It reads the guest ledger, birthday card, supervisory log and calendar. The route also pulls the trapped memo and receives the torn paper. Memo drawing and inventory reopening are connected. Crowbar lifting, the cabinet combination and red-box acquisition are connected. Later Chapter 2 routes remain unfinished. See [Cabinet combination](chapter-two-cabinet-combination.md). See [Memo drawing](chapter-two-memo-drawing.md). See [Trapped memo](chapter-two-memo-pull.md).

## Source route

The supplied guides identify the office search requirements in `CHP215` and the spoiler-free Chapter 2 section. The reference run follows ordinary input from the completed payment route.

1. Enter the unlocked office from the lobby.
2. Finish Kyle's arrival dialogue.
3. Walk around the cabinet collision boundary and inspect its upper-right drawer.
4. Read the guest ledger inside the drawer.
5. Walk to the desk and inspect the birthday card and supervisory log.
6. Inspect the calendar and its circled date.

The original guest ledger names Kyle Hyde, Room 215 and 30 June 1979. The calendar marks 5 December. The log identifies the guest-registration and lost-property drawers. These details come from the supplied original images and scripts.

## Map integration

R115 uses map ID 15. Its collision member is now bundled by `tools/recover_lobby.py`, with source, compressed-payload and decoded hashes in the game-data manifest.

| Field | Original value or source |
| --- | --- |
| Entry from R103 | `out_r103`, position `(-19579,12288,15319)` |
| Map origin | `(12,-7)` from `0x020E02AC`, plus the existing eight-pixel marker offset |
| Map scale | `16.2` from `0x020DFF60` |
| Floor-plan image | `map/fmapscr/R115.bin`, 256×256 pixels |
| Initial search model | `R115_s02` |
| Guest-record cabinet | Search area 4, close-up 127 |
| Desk | Search area 1, close-ups 130 and 133 |

The existing room-map scroll rules now include R115. Movement, collision, search picking, visibility and rendering use the existing native boundaries.

## Detail-image responses

The guest ledger previously stopped at the unsupported detail-image guard. The close-up model now exposes the selected layer's detail asset. The shared session runs this original sequence:

1. Run mode 11 for the selected component.
2. Load and display its detail bitmap.
3. Run mode 12 for the same area, subarea and event.
4. Remove the detail image and restore the close-up after the response ends.

The source sequence is `0x02062C08`. `0x02059E1C` reads the detail name, and `0x02059700` starts its image load. The native event runner retains the original selection context and System fallback. Views only display the active image and forward input.

This route uses `115meibup`, `115kanriup` and `115calenup`. Item use retains its existing selection path. Detail images remain visible while dialogue is active, including pause and resume.

The original detail fade and asynchronous image-load timing are not reproduced. Other detail-image branches and process requests need further route checks.

## Evidence and checks

Reference scripts are under `tools/reference/`. Their captures remain local under `extracted/reference/`.

| Script prefix | Reference output | Evidence |
| --- | --- | --- |
| `chapter-two-office-enter` | `chapter-two-office-enter-ready` | Office entry and introduction. |
| `chapter-two-office-walking`, `chapter-two-office-arrival` | Matching directory names | Completed arrival and floor plan. |
| `chapter-two-office-records-approach` | `chapter-two-office-records-ready` | Cabinet approach and search view. |
| `chapter-two-office-records-drawer` | Matching directory name | Open drawer. |
| `chapter-two-office-records-detail` | `chapter-two-office-ledger` | Guest-ledger detail and dialogue. |
| `chapter-two-office-ledger-return` | Matching directory name | Return to the drawer. |
| `chapter-two-office-desk-approach`, `chapter-two-office-desk-items` | Matching directory names | Desk and book/card close-up. |
| `chapter-two-office-card-log` | Matching directory name | Birthday card and supervisory log. |
| `chapter-two-office-calendar`, `chapter-two-office-calendar-date` | Matching directory names | Calendar entry and circled-date response. |

`OriginalOfficeRouteChecks` extends the Chapter 2 and full new-game checks. It compares all 32,088 game-state bytes at arrival and each completed search checkpoint. It also checks detail-image lifetime and pause behaviour.

`OriginalOfficeTests` checks the original entry marker, scale, map origin and selected floor-plan pixels. It checks detail-asset selection and five guest-ledger pixel samples. Existing close-up checks cover the brochure, parcels, hanger and nested toolbox.

The office-detail milestone passed 13 tests with no failures or skips: the full new-game route, three office checks and nine existing close-up checks. `git diff --check` also passed. Native room and ledger snapshots were inspected.

```sh
SNAPSHOT_DIR=/tmp/hotel-office-complete \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter 'OriginalOfficeTests|LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock|OriginalSearchCloseupTests'
```

The route now continues from `chapter-two-office-cabinet-approach/search` through native memo pulling and torn-paper acquisition. See [Trapped memo](chapter-two-memo-pull.md) for the later checks and presentation limits.

## Next work

- Complete the memo process captions and tear-message presentation.
- Complete the crowbar game-over presentation and alternative whole-memo route. Placement, lifting and joined-paper retrieval are connected. See [Crowbar recovery](chapter-two-crowbar-recovery.md).
- Continue from the acquired red box to the office exit. Combination entry now uses the saved memo code.
- Check the wall keys and the office-exit conditions for Louie's conversation.
- Continue the remaining Chapter 2 conversations and review.

The complete game and original presentation remain unfinished.
