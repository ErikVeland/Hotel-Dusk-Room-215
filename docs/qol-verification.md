# Quality of life verification

The dialogue, inspection and navigation changes are implemented. Native iOS library compilation succeeded. The final focused checks cover dialogue formatting and cipher preservation, repeat passages and history, fixed-image inspection pagination, empty command packets, camera movement, collision, input release, legacy saves, incremental disk saves and notebook ink.

## Focused results

- DialogueNotebookTests: 28 passed, no failures or skips.
- Navigation and selected save/resume checks: 8 passed, no failures or skips.
- iOS arm64 library compilation: passed using the installed iOS 27.2 SDK with an iOS 17 deployment target.
- Whitespace/error check: git diff --check passed.

Commands use CLANG_MODULE_CACHE_PATH and SWIFTPM_MODULECACHE_OVERRIDE pointing to writable temporary directories, with swift test/build --disable-sandbox and isolated --scratch-path directories.

## Limits

Metal devices and the Apple sampler are unavailable to this restricted execution session. The standalone Metal compiler component is also absent. The shader was included in both successful Swift builds, but runtime shader compilation, native GPU image output, performance and touch feel require verification on a device.

The 3D render target is 768 × 1024 while stationary and 384 × 512 during movement. Source texture detail remains a limit; nearby-door buttons use the original room labels so room numbers can be read without decoding a tiny texture.

Older interaction journals retain their original command pacing and walking speed during restoration. The next stable walking checkpoint uses the new pacing. Existing saves are not discarded.

## Wider suite

An earlier complete run executed 796 tests: 194 skipped, with 122 failure assertions. It was not a passing suite. Missing graphics/audio services, missing original assets/checkpoints, outdated intermediate event assertions and existing story-route failures were present. The failures below are recorded by test name; subsequent focused fixes are marked.

The chapter-nine apple-letter sequence also failed with legacy pacing explicitly restored: 12 assertions in that one test. It is not resolved by reverting the QoL pacing.

| Test | Observed failure / follow-up |
| --- | --- |
| DialogueNotebookTests.testFoldPausesAtTheSameDialogueAndHistoryIsBlockedByPuzzles | Passed in the subsequent focused run. |
| DialogueNotebookTests.testSessionRecordsBeforeRenderingAndDoesNotSkipUnwrittenDialogue | Passed in the subsequent focused run. |
| HotelDuskDuoTests.testNativeBuildDoesNotStartInventedGameplay | required condition is false: comp != nullptr (com.apple.coreaudio.avfaudio) |
| LayoutSnapshotTests.testRenderConversationParticipantInk | required condition is false: comp != nullptr (com.apple.coreaudio.avfaudio) |
| LayoutSnapshotTests.testRenderNoirNotebookExploration | required condition is false: comp != nullptr (com.apple.coreaudio.avfaudio) |
| LayoutSnapshotTests.testRenderPlayableLobbyAndRingBellThroughSession | XCTAssertEqual failed: ("Optional(1)") is not equal to ("Optional(27)") |
| LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock | XCTAssertEqual failed: ("Optional(0)") is not equal to ("Optional(27)") |
| LayoutSnapshotTests.testRenderSuitcaseKeyStages | failed: caught error: "missing("Metal device")" |
| LayoutSnapshotTests.testRenderWrittenDialoguePages | required condition is false: comp != nullptr (com.apple.coreaudio.avfaudio) |
| OriginalBookmarkBoxTests.testOriginalArtworkRendersBothPuzzleStages | failed: caught error: "missing("Metal device")" |
| OriginalBookmarkBoxTests.testSourceScriptStartsBoxAndInputCompletionSetsOriginalFlag | XCTAssertEqual failed: ("halted(HotelDuskDuoKit.OriginalEventRunner.Halt(reason: "The bookmark box could not be loaded: missing(\"Metal device\")", program: "EP3_R205", eventIndex: Optional(14), sourceOffset: nil))") is not equal to ("process(id: 47)") |
| OriginalCabinetDialTests.testOriginalRenderer | failed: caught error: "missing("Metal device")" |
| OriginalChapterReviewTests.testChapterTenCellarPassageCheckpointRestoresAlternateRoom | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenCellarPassageExitsToR304ThroughNormalMovement | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenCellarSelectsR304DoorFromMatchingSearchRecord | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenR301AreaTwoObjectsReturnToSearchView | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenR301CableHitSavesAfterCounterCameraPan | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenR301CounterOneCheckpointFromNormalSearch | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenR301DeskReachesTheFiveLookStoryGate | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenR301DeskSearchRunsFirstStoryClue | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenR301MachineSearchResumesFromInstantSave | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalChapterReviewTests.testChapterTenR304BarUnlocksR301DoorThroughNormalInput | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalCrowbarTests.testRendererUsesOriginalAssets | failed: caught error: "missing("Metal device")" |
| OriginalDifferencesTests.testSourceEventStartsPuzzleAndReturnsItsSuccessBranch | required condition is false: comp != nullptr (com.apple.coreaudio.avfaudio) |
| OriginalDoorWireTests.testOriginalDoorArtLoadsAndRenders | failed: caught error: "missing("Metal device")" |
| OriginalEventCompletionTests.testUnrecoveredLateChapterInspectionCounterStaysExplicit | XCTAssertEqual failed: ("completed(HotelDuskDuoKit.OriginalEventCompletion.Completion(transition: nil, preventContextRestore: false))") is not equal to ("requiresOriginalHandler(mode: 10)") |
| OriginalFactoryOverlaySessionTests.testChapterNineAppleProcessSequenceCarriesAllLettersIntoWordEntry | XCTAssertEqual failed: ("2") is not equal to ("4") |
| OriginalHangerRendererTests.testRenderHangerAndCuttingStages | failed: caught error: "missing("Metal device")" |
| OriginalJukeboxProcessTests.testBundledRecordTitlesLoadForTheNativeProcess | failed: caught error: "missing("trick/jukebox/JK_USA.txt")" |
| OriginalJukeboxProcessTests.testChapterSixProcess58StartsJukeboxAndReturnsThroughItsStoryEvent | XCTAssertEqual failed: ("nil") is not equal to ("Optional(36)") |
| OriginalMapAudioTests.testWalkingHostStartsAlternatingStepsAndOwnsRoomAmbience | required condition is false: comp != nullptr (com.apple.coreaudio.avfaudio) |
| OriginalMapCoverageTests.testLateChapterSearchScenesLoadTheirOriginalModels | XCTUnwrap failed: expected non-nil value of type "MTLDevice" |
| OriginalMapCoverageTests.testSearchSceneCanUseAnUnambiguousTextureFromItsRoomArchive | XCTUnwrap failed: expected non-nil value of type "MTLDevice" |
| OriginalMapCoverageTests.testSupportedRoomsLoadAtOriginalEntryMarkersAndRender | failed - R102: missing("Metal device") |
| OriginalMatchstickAssetTests.testBundledStickTextureLoadsForTheNativeRenderer | failed: caught error: "missing("trick/sticktex.bin")" |
| OriginalMemoPullTests.testRendererUsesOriginalCabinetAndPaper | failed: caught error: "missing("Metal device")" |
| OriginalModelMetalTests.testLouieRoomLoadsAndRendersAtItsDoorEntry | failed: caught error: "missing("Metal device")" |
| OriginalResumeSaveTests.testEverySimulationStepIsImmediatelyReadableFromDisk | Passed in the subsequent focused run. |
| OriginalResumeSaveTests.testNativeNotebookInkSurvivesInstantSaveAndReopen | Passed in the subsequent focused run. |
| OriginalStoryContinuationTests.testChapterNineAcceptsHitOnlyDunningRoomHelperMask | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineCallsEdAndAnswersRosasKnock | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineEntersDunningRoomAfterRosa | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineEntersTheRoom111BackRoom | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineFifthLetterContinuesFromInstantSave | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineFindsDunningItemsAndCardsThroughNormalPantryDoor | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineInspectsDunningRoomDesk | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineLeavesRoom111ForKevin | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineLouieTopicsAdvanceTheStory | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineOpensDunningRoomPaintingThroughNormalHit | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineR117PaintingReturnsFourthLetter | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineReachesRosasRoomAndResumesInstantly | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineReturnsTheKeyAndFindsTheFifthPainting | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineReturnsToTheLobbyAfterTheFourthLetter | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineRoom215ApplePaintingUsesNormalHitAndInstantRestores | XCTUnwrap failed: expected non-nil value of type "OriginalResumeSave" |
| OriginalStoryContinuationTests.testChapterNineViewlessLobbyDoorUsesOriginalDoorResponse | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineWalksFromDunningRoomToPantry | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalStoryContinuationTests.testChapterNineWalksThroughR118ToR213 | XCTUnwrap failed: expected non-nil value of type "String" |
| OriginalThickWireRendererTests.testWireIsVisibleInInsertionView | failed: caught error: "missing("Metal device")" |
| OriginalToiletTankTests.testOriginalModelShowsMovingLid | failed: caught error: "missing("Metal device")" |
| OriginalToiletTankTests.testSourceEventCompletesThroughTouchInput | XCTAssertEqual failed: ("halted(HotelDuskDuoKit.OriginalEventRunner.Halt(reason: "The toilet tank could not be loaded: missing(\"Metal device\")", program: "EP4_R205", eventIndex: Optional(11), sourceOffset: nil))") is not equal to ("process(id: 48)") |

The full suite was not repeated after the focused fixes. No device build was installed or launched.
