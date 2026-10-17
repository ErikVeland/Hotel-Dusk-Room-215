# Puzzle fidelity record

This is a partial native port. Extracted graphics and text do not establish that every original puzzle or story transition has been implemented. Unverified prototype interactions must not be presented as original game content.

## Melissa's jigsaw

The folding sequence belongs to Chapter 3, at 6:20 PM, in Room 219. Melissa first asks Kyle to assemble the full puzzle. The completed picture is Pinkie Rabbit. The earlier stairs encounter in Chapter 1 uses an incomplete version of the same picture; it is a separate story event.

| Element | Evidence | Port requirement |
| --- | --- | --- |
| Front, pieces, reverse, table | `extracted/unpacked_wpf/trick/zig/` | Decode and use the supplied ROM artwork. Keep the original piece silhouettes and reverse lettering. Do not substitute a generated rabbit, generic tile image, or typeset message. |
| Rotation and placement | [iyqyqr's walkthrough](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46753) describes rotation controls in both upper corners and pieces snapping into correct positions. | Let players select, turn, and place pieces. Incorrect positions or rotations must not solve a piece. The port currently uses quarter-turns and an eight-pixel snap radius in the original stage coordinates. Exact source rotation increments and snap tolerance still need footage or code verification. |
| Fold direction | [RE4FREAK's walkthrough](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46852), Chapter 3, Room 219 | In right-handed mode the completed front is on the left page. After a close/reopen cycle, the reverse is on the right. Mirror page roles for left-handed mode. |
| Original dialogue | `extracted/unpacked_wpf/local/us/textdata_usa/EP3_R209.txt` | Use original context in its story position. `Resources/JigsawDialogue.json` records selected original lines and string indices. It is reference data, not an instruction overlay. |
| Reveal | Same original script, string indices 195–212 | The message concerns Melissa's mother. There is no hotel stamp, transfer target, or instruction to search under Kyle's desk. |

The Duo should respond when a closed device first reports an open state. Requiring a flat 180-degree posture changes the physical puzzle. Closing during assembly must preserve all piece positions and rotations without completing it. Ordinary folds outside this puzzle must not award its reveal. Added labels, target outlines, button titles, accessibility descriptions, and notebook entries must not disclose the folding solution before discovery.

## Source text extraction

The WPF unpacker retains a 32-byte archive header. The following payload begins with Cing's `12 3D DA 01` compression header. Decoding the Chapter 3 source produces 11,103 bytes. The first little-endian integer is the string count, followed by an offset table and null-terminated strings. Control tokens are removed only for the selected dialogue reference; the original script remains untouched.

Format research: [Jason Harley's Hotel Dusk reverse-engineering notes](https://jasonharley2o.com/reverse/hoteldusk/). The JSON records the source SHA-256 so its text can be checked against this ROM.

## Prototype content to exclude

The former stamp/order-sheet puzzle, `CHECK UNDER THE DESK IN ROOM 215` reward, and Room 215 three-digit drawer with a fixed 215 combination were invented. The original game does have a numbered cabinet puzzle in Dunning's office, but it uses a discovered memo and a variable combination. A brass 215 drawer is not a replacement for that sequence.

The former gallery matchbook, boiler's 215 PSI clue, and wine-rack crowbar advice were also unsourced. Do not retain their dialogue or automatic notebook rewards as puzzle content.

## Remaining work

The complete Chapter 1 and Chapter 3 event scripts, inventory prerequisites, and surrounding Melissa/Kevin conversations are not fully reconstructed by a standalone jigsaw. Other original interactions—lock picking, the office cabinet, bookmark box, electrical switches, cassette, matchsticks, coins, and later folding events—require their own verified mechanics, original graphics, and story conditions. Their source assets alone do not mean these puzzles are playable or faithful. Keep unfinished interactions unavailable instead of filling gaps with invented puzzles or solution hints.

## Validation on 16 October 2026

All 30 package tests pass. These cover placement and rotation requirements, all 20 pieces, reopening before the hinge is flat, incomplete and inactive puzzle folds, repeated folds, and preservation of puzzle and session state. Rendered snapshots check both handedness settings, page edges, cover sizes, paper material and spine angles. Paper tests check finite settling and seeded variation. Six offscreen corridor renders check for white openings, and movement tests keep the camera inside the model. The current iOS simulator build, including the paperback material and corridor fixes, succeeds and is installed on the Duo simulator.

The running iOS app exposes the original rotation controls, and selection and rotation were checked through accessibility actions. Native drag automation returned `noWindowsAvailable`; a complete touch drag-and-fold cycle still needs a hands-on check. The app owns one session above its display windows so a cover-to-inner-display transition does not create a new session. This preserves state during a running session; saving across process termination is a separate feature.
