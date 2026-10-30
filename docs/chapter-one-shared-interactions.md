# Chapter 1 shared interactions

The vending-machine purchase and generic shown-item responses now have native
handlers. Both are reached through shared System events, so a chapter-only
embedded-process audit did not detect their missing handlers.

## Vending machine

Using item 30 (Coins) on R103 area 2, object 1 selects System event 252, then
process 57 through event 256. Overlay 34 initialises this process at
0x021FCD3C. The keypad update is 0x021FF17C, code checking is 0x02200D7C,
and digit insertion and clearing are 0x02204F04 and 0x02204F48.

| Code | Item | Process result | System award event |
| --- | --- | --- | --- |
| 10 | Potato chips (38) | 4 | 261 |
| 11 | Chocolate (34) | 0 | 257 |
| 12 | NougaChew! (35) | 1 | 258 |
| 13 | Candy (36) | 2 | 259 |

The native process requires a coin before entry, retains at most two digits,
rejects already-acquired products using their acquisition-state bytes, and keeps
credit after an invalid code. Returning the coin clears entry; leaving returns
3, whose source event awards nothing. Purchases complete through the original
System events, which add the correct item and show its original dialogue.

The hidden prize still uses the ten original code bytes at 0x02205734 and the
persistent puzzle random value. The shifted play variant changes both the row
and the prize. The UI does not reveal the hidden code. Acquisition states also
prevent claiming the same hidden prize again.

The presentation uses the original keypad and product artwork in a native
book-page layout, including enhanced art when available. The original moving
3D camera and mechanical animation sequence are not reproduced by this change.
The original result selection and inventory writes are preserved. Inputs are
recorded through the existing instant-save replay log.

An isolated ROM component trace used the existing walking checkpoint, injected
process 57 and then used real touch input. It entered the keypad through raw
(128,157), inserted a coin at (160,48), entered 10 through (113,36) and (33,76),
and pressed enter at (33,116). Source memory changed from no credit to credit,
stored digit IDs [20,11], then cleared them, selected product 0, and wrote result
4. These are isolated component observations, not a complete Chapter 1 route.
Scratch captures are under .build/vending-reference.

## Shown items

0x02028E4C scans the chapter script first, then System. On a missing specific
System mode-16 response, 0x0203A444 retries with item and subarea zero.
The native host retains the current conversation while this shared response
runs, then merges state and restores the same question menu.

For example, showing Dunning the suitcase key now uses System event 32 and its
original response, "The hell's that?". Showing the pager selects its specific
System event instead. The response marks the actual item as shown, preserves
inventory changes, and does not mark a System event in the chapter event bank.
Shared mode-27 responses can refresh available topics when returning.

## Melissa and Jeff presentation

The original encounters include character art and animation. EP1_R117 event 16
contains Melissa/Kyle portrait and changing-pose metadata. EP1_R213 events 2
and 3 contain Jeff entrance/pose metadata; event 9 includes animation start and
wait commands (43/44).

The native runner currently records those presentation commands as unrendered.
The character animation decoder is connected to the recovery preview, not the
story presentation clock. This is why the encounters currently appear as text.
These interaction fixes do not implement that separate animation layer.

## Validation

The focused checks cover vending entry, all four purchases, coin requirements,
return and cancellation, unavailable codes, random and shifted hidden prizes,
serialised purchase input replay, specific and generic shown-item selection,
System mode-27 item changes, repeated responses, parent-menu restoration and
serialised conversation input replay. The previous numbered-sticker regressions
are included. All 23 focused tests pass, and the iOS simulator Swift package
compiles. Native vending-page rendering was visually checked at 752 by 568.

The full suite was attempted and stopped at its 180-second limit. Before
termination it reported 39 failed cases and 101 skipped cases.
Observed failures include unavailable audio units, restricted Metal rendering,
missing source assets and an existing late-chapter completion assertion. This
is not a passing full-suite result. Individual failures were:

- `HotelDuskDuoTests.HotelDuskDuoTests testNativeBuildDoesNotStartInventedGameplay`
- `HotelDuskDuoTests.LayoutSnapshotTests testRenderConversationParticipantInk`
- `HotelDuskDuoTests.LayoutSnapshotTests testRenderNoirNotebookExploration`
- `HotelDuskDuoTests.LayoutSnapshotTests testRenderPlayableLobbyAndRingBellThroughSession`
- `HotelDuskDuoTests.LayoutSnapshotTests testRenderRequiredDunningQuestionsAndDeliveryKnock`
- `HotelDuskDuoTests.LayoutSnapshotTests testRenderSuitcaseKeyStages`
- `HotelDuskDuoTests.LayoutSnapshotTests testRenderWrittenDialoguePages`
- `HotelDuskDuoTests.OriginalApplePaintingSearchTests testAppleArtworkMaskCoversEverySourceSelectionRegion`
- `HotelDuskDuoTests.OriginalArtworkUpscaleTests testTexturesUseDoubleResolutionWithoutChangingSourcePixels`
- `HotelDuskDuoTests.OriginalBookmarkBoxTests testOriginalArtworkRendersBothPuzzleStages`
- `HotelDuskDuoTests.OriginalBookmarkBoxTests testSourceScriptStartsBoxAndInputCompletionSetsOriginalFlag`
- `HotelDuskDuoTests.OriginalCabinetDialTests testOriginalRenderer`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenCellarPassageCheckpointRestoresAlternateRoom`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenCellarPassageExitsToR304ThroughNormalMovement`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenCellarSelectsR304DoorFromMatchingSearchRecord`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenR301AreaTwoObjectsReturnToSearchView`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenR301CableHitSavesAfterCounterCameraPan`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenR301CounterOneCheckpointFromNormalSearch`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenR301DeskReachesTheFiveLookStoryGate`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenR301DeskSearchRunsFirstStoryClue`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenR301MachineSearchResumesFromInstantSave`
- `HotelDuskDuoTests.OriginalChapterReviewTests testChapterTenR304BarUnlocksR301DoorThroughNormalInput`
- `HotelDuskDuoTests.OriginalClockProcessTests testRendererKeepsTheClockFaceOpaque`
- `HotelDuskDuoTests.OriginalCrowbarTests testRendererUsesOriginalAssets`
- `HotelDuskDuoTests.OriginalDifferencesTests testSourceEventStartsPuzzleAndReturnsItsSuccessBranch`
- `HotelDuskDuoTests.OriginalDoorWireTests testOriginalDoorArtLoadsAndRenders`
- `HotelDuskDuoTests.OriginalEventCompletionTests testUnrecoveredLateChapterInspectionCounterStaysExplicit`
- `HotelDuskDuoTests.OriginalFactoryOverlaySessionTests testChapterNineAppleProcessSequenceCarriesAllLettersIntoWordEntry`
- `HotelDuskDuoTests.OriginalFactoryOverlaySessionTests testProcess64StartsTheApplePaintingOverlay`
- `HotelDuskDuoTests.OriginalHangerRendererTests testRenderHangerAndCuttingStages`
- `HotelDuskDuoTests.OriginalJukeboxProcessTests testBundledRecordTitlesLoadForTheNativeProcess`
- `HotelDuskDuoTests.OriginalJukeboxProcessTests testChapterSixProcess58StartsJukeboxAndReturnsThroughItsStoryEvent`
- `HotelDuskDuoTests.OriginalMapAudioTests testWalkingHostStartsAlternatingStepsAndOwnsRoomAmbience`
- `HotelDuskDuoTests.OriginalMapCoverageTests testLateChapterSearchScenesLoadTheirOriginalModels`
- `HotelDuskDuoTests.OriginalMapCoverageTests testSearchSceneCanUseAnUnambiguousTextureFromItsRoomArchive`
- `HotelDuskDuoTests.OriginalMapCoverageTests testSupportedRoomsLoadAtOriginalEntryMarkersAndRender`
- `HotelDuskDuoTests.OriginalMatchstickAssetTests testBundledStickTextureLoadsForTheNativeRenderer`
- `HotelDuskDuoTests.OriginalMemoPullTests testRendererUsesOriginalCabinetAndPaper`
- `HotelDuskDuoTests.OriginalModelMetalTests testLouieRoomLoadsAndRendersAtItsDoorEntry`
