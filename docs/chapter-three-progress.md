# Chapter 3 progress

The main native route now finishes Chapter 2 and starts Chapter 3. The full ten-chapter game remains unfinished.

## Checked story path

`OriginalLouieRoomRouteChecks` follows the confrontation in Louie's room. It selects the required interrupts, questions and answers, then activates the original photo hit mask. The script moves Kyle into the corridor. The review retries a wrong answer and accepts the five correct answers. Play then reaches the Chapter 3 save prompt and title, enters Room 215 and answers Rachel's telephone call.

`OriginalChapterThreeRouteChecks` continues through Kevin in the Central Hallway, Louie in the restaurant reception and Iris's conversation. It enters the dining room, collects Melissa's rag doll, completes dinner and asks Summer and Rosa the required questions. Talking to Louie afterwards completes the 6:20 PM clock transition and returns to walking in the restaurant reception. Route helpers use ordinary movement, collision, dialogue, question and interaction methods. They do not grant items or set story flags.

The optional `HOTEL_DUSK_ROUTE_CHECKPOINTS` test directory stores checkpoints reached by the full route. Focused continuation tests restore those files through the same native save APIs as the app. They explicitly skip when the checkpoints are absent. These files are test outputs, not bundled chapter shortcuts.

## Shared runtime changes

- Chapter metadata comes from the original title function and clock tables at `0x02017278` and `0x020EB130`–`0x020EB180`. Artwork and save labels use the current chapter.
- Map request 1 follows the destination after dialogue, as in `0x0202C264`. Chapter request 4 can carry a destination distinct from the room where the review finished.
- Walk-through collision exits resolve supported room names instead of an opening-only corridor list. Departure scripts can still cancel travel.
- The map catalog is generated from original origins, scales and floor-plan headers. Rooftop-style walking scenes can omit a search camera.
- A room with no chapter-specific program uses an empty local event table and existing System interactions. Partial or corrupt programs still fail.
- Search scenes can use a texture from another member of the same room archive when the name has one unambiguous decoded image. Conflicting images still fail instead of selecting one arbitrarily.

## Asset checks

The catalog enables 37 rooms with original collision data and floor plans. Every enabled walking scene has a native render check. Search scenes are not exhaustively checked. The restaurant reception's shared door texture has a separate load check. The texture decoder now covers 2,952 of 2,957 bundled textures. Five remain unsupported.

## Remaining work

Native handlers now cover the full, reverse and restored jigsaws (39, 40, 84), electrical panel (41), fountain pen (42), bookmark box (47) and four-pin door lock (77). Input and source-event tests cover these additions. The continuation replay has reached the pen rubbing and inspection, Louie's engraving conversation, Melissa's doll return, the full 20-piece jigsaw, its reverse-side fold and Kevin's conversation in Room 219. A further continuation restores the 6:40 PM corridor save, walks to Room 215, solves the bookmark box and obtains item 25 through the original script. The full Chapter 3 route, locked-room escape and chapter ending still require uninterrupted verification. Chapters 4–10, alternate branches, failure paths and endings require further implementation and route checks. Original character presentation and physical Duo testing also remain incomplete.

The author walkthrough identifies the route and dependencies: [neeker's walkthrough](https://gamefaqs.gamespot.com/ds/933043-hotel-dusk-room-215/faqs/46777). Recovered game scripts and native source determine state changes. New continuation checks establish native playability, not a complete byte-for-byte comparison with a matching original run.


## Build verification

The Duo simulator Debug build and the generic iOS Release build both succeeded. The simulator build was installed and launched with existing saved games retained. The device build is unsigned. Select a signing team in Xcode before installing it on the physical Duo. Physical-device touch and hinge behaviour remain unverified.

The room, script, save and texture regression group passed its executable checks. Ten original-reference comparisons skipped because the required local captures were absent. The new Chapter 3 continuation does not replace those original comparisons.

The final uninterrupted route replay passed on 22 October 2026 in 417 seconds, including restoration of walking checkpoints without replaying arrival events. Across this replay and the targeted regression group, 34 tests passed and 10 capture-dependent comparisons skipped. The earlier route-only failure was corrected by facing Louie before selecting Talk.

```sh
HOTEL_DUSK_ROUTE_CHECKPOINTS="$PWD/.build/story-checkpoints" \
  swift test --disable-sandbox \
  --filter LayoutSnapshotTests/testRenderRequiredDunningQuestionsAndDeliveryKnock
```

## Puzzle work on 26 October 2026

- Jigsaw masks remain separate for the incomplete, full and restored variants. The reverse puzzle requires a new close-and-open fold cycle and its original fade/hold sequence.
- Door locks use four source pin shapes, the original cursor boundary and four-second reset. Input tests solve process 77 through the touch model; process 78's ordered-pin path still needs a full solve check.
- The electrical panel requires one continuous gesture from a switch onto the connecting bar and upward. Single-switch attempts reset and request the original hint.
- The fountain pen uses the original rubbing mask, completion regions and dust-clearing random rule. Touch inspection and microphone clearing retain distinct return values. Microphone access is explicit and stops while play is suspended.
- The bookmark box uses the original Euler rotation cases, orientation-dependent tapping and slow rightward extraction. Both source entry and successful return have a native host check.
- The toilet tank (48) uses the source moving lid rectangle, cached touch deltas, slow sliding, flush animation and hint. Its source event and input completion pass. Overlay 26 records completion ID 49, distinct from launch ID 48. Likewise, the restored jigsaw records ID 40 rather than 84.
- The Chapter 5 doll repair (38) recognizes individual and continuous stitches across all three seam sections. Fifteen unsuccessful stitches trigger the original failure outcome and wing-drop sequence. Five checks pass, including the source-event success return. The original sprite alpha format is preserved.
- Chapter 4's signature comparison (process 73) is connected to the original image and circle-recognition rectangles. A circle must surround one target without crossing it. Two failed attempts request the original hint; Clear resets the drawing and recognition state.

These are native implementations, not complete visual comparisons with a running original. Remaining differences include character reactions, some layered fades and model/pixel projection. Physical hinge and microphone input have not been tested on the Duo. The static process audit is maintained separately in [story-process-coverage.md](story-process-coverage.md); handler presence does not establish a complete route.

### Current verification limits

The new tank model was rendered and inspected closed and open. The doll artwork and stitch rendering were also inspected. The bookmark box flap angles were corrected to the source values (230 degrees and -248 degrees). Source-event tests do not establish an uninterrupted chapter route.

The most recent Chapter 3 continuation successfully assembled the puzzle, revealed its back, completed Kevin's required response and saved in the corridor at 6:40 PM. The replay passed with Metal access in 15.9 seconds after the test was corrected to finish the arrival dialogue. The sandbox can compile the native package and run the doll tests with temporary cache directories, but cannot create a Metal device for walking scenes. Recent external-permission build requests were dismissed by the desktop before execution. Metal access was subsequently restored for the Chapter 3 replay. The iOS simulator Debug build subsequently passed with the tank and doll additions. The full opening-to-Chapter-3-dinner replay also passed after the shared completion-flag changes (142.9 seconds). The subsequent bookmark continuation passed in 21.4 seconds.

The isolated original-process captures for the tank and bookmark box currently contain corrupted texture colours. They are not valid pixel-comparison baselines. The native images use the checked original assets, but matching original presentation still needs valid captures. The component launch modifies only the reference runner's pending process; it is not part of native story-route evidence.

The native continuation now returns Summer’s bookmark, asks both painting topics, hears Melissa behind Room 218, talks to Louie, and enters the electrical room (9.9-second continuation check). A second route restores power through process 41 and opens the four-pin lock through process 77 (5.4 seconds). Both use normal movement, object selection, and touch input. The original script consumes the thick wire. Entering the room and the remaining Melissa/roof conversation are the next route checks.

The rescued Melissa conversation now passes using the original sympathetic choices
and all available question topics. The `melissa/resume.json` checkpoint is written
after Melissa leaves Room 218, through ordinary game input. The subsequent rooftop
route is under verification.
