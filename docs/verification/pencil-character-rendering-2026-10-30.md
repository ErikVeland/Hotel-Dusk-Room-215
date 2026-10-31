# Pencil character rendering verification — 30 October 2026

The modern presentation desaturates the available animation image and uses Multiply at 88% opacity. White fills reveal the existing paper, including its fixed grain. Dialogue portraits use 42% opacity; the original option retains 22%. No animation decoder, pose selection, playback clock or source assets were changed by this task. The option defaults on and is stored through AppStorage.

## Verified

- Native macOS package compiled successfully.
- Pixel rendering regression passes: white fills retain the paper colour, grey shading stays visible, and external dialogue opacity preserves the blend. Disabling the option restores white source fills.
- Kyle and Dunning comparisons were rendered using the shared app view and inspected. These examples use original-resolution fallback art because the enhanced pack is incomplete.
- OriginalAnimationTests: 4 passed, including all 3,021 decoded frames and original colour grids.
- OriginalEncounterAnimationTests: 4 passed, including every explicit bundled dialogue expression.
- Source whitespace check passed.

The red rendering regression reproduced the white fill covering the paper before the change, then passed after the change.

## Limits

Duo hardware and iOS runtime presentation have not been tested. The simulator service is unavailable in this environment. The rendering treatment preserves existing linework; it cannot recover missing source detail.

The full native test suite was attempted with `swift test --disable-sandbox --build-system native`. It recorded the failures below, then was interrupted after nearly two minutes without further output. Errors include unavailable Metal support, missing assets and story-state expectations. This is not a clean full-suite result, and these failures were not repaired as part of the visual change. No claim is made that the broad failures were isolated against a clean baseline.

## Failures observed in the interrupted full run

- `HotelDuskDuoTests.testNativeBuildDoesNotStartInventedGameplay`
- `LayoutSnapshotTests.testRenderNoirNotebookExploration`
- `LayoutSnapshotTests.testRenderPlayableLobbyAndRingBellThroughSession`
- `LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock`
- `LayoutSnapshotTests.testRenderSuitcaseKeyStages`
- `OriginalBookmarkBoxTests.testOriginalArtworkRendersBothPuzzleStages`
- `OriginalBookmarkBoxTests.testSourceScriptStartsBoxAndInputCompletionSetsOriginalFlag`
- `OriginalCabinetDialTests.testOriginalRenderer`
- `OriginalChapterReviewTests.testChapterTenCellarPassageCheckpointRestoresAlternateRoom`
- `OriginalChapterReviewTests.testChapterTenCellarPassageExitsToR304ThroughNormalMovement`
- `OriginalChapterReviewTests.testChapterTenCellarSelectsR304DoorFromMatchingSearchRecord`
- `OriginalChapterReviewTests.testChapterTenR301AreaTwoObjectsReturnToSearchView`
- `OriginalChapterReviewTests.testChapterTenR301CableHitSavesAfterCounterCameraPan`
- `OriginalChapterReviewTests.testChapterTenR301CounterOneCheckpointFromNormalSearch`
- `OriginalChapterReviewTests.testChapterTenR301DeskReachesTheFiveLookStoryGate`
- `OriginalChapterReviewTests.testChapterTenR301DeskSearchRunsFirstStoryClue`
- `OriginalChapterReviewTests.testChapterTenR301MachineSearchResumesFromInstantSave`
- `OriginalChapterReviewTests.testChapterTenR304BarUnlocksR301DoorThroughNormalInput`
- `OriginalClockProcessTests.testRendererKeepsTheClockFaceOpaque`
- `OriginalCrowbarTests.testRendererUsesOriginalAssets`
- `OriginalDifferencesTests.testPamphletArtworkAndOriginalMaskedInk`
- `OriginalDoorWireTests.testOriginalDoorArtLoadsAndRenders`
- `OriginalEventCompletionTests.testUnrecoveredLateChapterInspectionCounterStaysExplicit`
- `OriginalFactoryOverlaySessionTests.testChapterNineAppleProcessSequenceCarriesAllLettersIntoWordEntry`
- `OriginalFactoryOverlaySessionTests.testProcess64StartsTheApplePaintingOverlay`
- `OriginalHangerRendererTests.testRenderHangerAndCuttingStages`
- `OriginalJukeboxProcessTests.testBundledRecordTitlesLoadForTheNativeProcess`
- `OriginalJukeboxProcessTests.testChapterSixProcess58StartsJukeboxAndReturnsThroughItsStoryEvent`
- `OriginalMapAudioTests.testWalkingHostStartsAlternatingStepsAndOwnsRoomAmbience`
- `OriginalMapCoverageTests.testLateChapterSearchScenesLoadTheirOriginalModels`
- `OriginalMapCoverageTests.testSearchSceneCanUseAnUnambiguousTextureFromItsRoomArchive`
- `OriginalMapCoverageTests.testSupportedRoomsLoadAtOriginalEntryMarkersAndRender`
- `OriginalMapIndicatorTests.testIndicatorRendersOnFloorPlanAtRetinaScale`
- `OriginalMatchstickAssetTests.testBundledStickTextureLoadsForTheNativeRenderer`
- `OriginalMemoPullTests.testRendererUsesOriginalCabinetAndPaper`
- `OriginalModelMetalTests.testLouieRoomLoadsAndRendersAtItsDoorEntry`
