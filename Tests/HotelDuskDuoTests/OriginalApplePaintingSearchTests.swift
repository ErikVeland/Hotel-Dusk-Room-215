import XCTest
@testable import HotelDuskDuoKit

final class OriginalApplePaintingSearchTests: XCTestCase {
    func testBundledChapterNineEventsSelectRecoveredAlphabetModes() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let callSites: [(program: String, offset: Int, process: UInt16,
                         mode: OriginalAlphabetProcessMode)] = [
            ("EP9_R117", 84, 64, .paintingSearch),
            ("EP9_R125", 104, 64, .paintingSearch),
            ("EP9_R205", 248, 64, .paintingSearch),
            ("EP9_R207", 84, 64, .paintingSearch),
            ("EP9_R213", 84, 64, .paintingSearch),
            ("EP9_R125", 164, 81, .wordEntry)
        ]

        for callSite in callSites {
            let program = try catalog.loadProgram(callSite.program)
            let event = try XCTUnwrap(program.blocks.tables[2].first {
                $0.sourceOffset == callSite.offset
            }, "Missing event at \(callSite.program):\(callSite.offset)")
            XCTAssertEqual(try OriginalEventCompletion.embeddedProcessID(event: event), callSite.process)
            let invocation = OriginalEventRunner.EmbeddedProcessInvocation(
                processID: callSite.process, programName: callSite.program,
                eventIndex: event.index, eventSourceOffset: event.sourceOffset,
                eventBytes: event.raw,
                selection: .init(sceneID: 0, blockID: 0, modeID: 0, eventID: 0,
                                 nowTime: 0, mapID: 0))
            XCTAssertEqual(OriginalAlphabetProcessContext.mode(for: invocation), callSite.mode)
        }

        let unknownCall = invocation(program: "EP9_R125", offset: 104, process: 81)
        XCTAssertNil(OriginalAlphabetProcessContext.mode(for: unknownCall))
    }

    func testRecoveredPaintingMapsResolveWithinPaintingSearchCallSites() {
        for (index, mapID) in OriginalApplePaintingSearch.paintingMapIDs.enumerated() {
            let searchCall = invocation(program: "EP9_R117", offset: 84, process: 64, mapID: mapID)
            XCTAssertEqual(OriginalAlphabetProcessContext.paintingIndex(for: searchCall), index)

            let wordEntryCall = invocation(program: "EP9_R125", offset: 164, process: 81, mapID: mapID)
            XCTAssertNil(OriginalAlphabetProcessContext.paintingIndex(for: wordEntryCall))
        }
        let room111BackRoom = invocation(program: "EP9_R125", offset: 104, process: 64, mapID: 25)
        XCTAssertEqual(OriginalAlphabetProcessContext.paintingIndex(for: room111BackRoom), 0)
    }

    func testPaintingSuccessReturnSelectsTheSourceFourthPaintingTransition() {
        XCTAssertEqual(OriginalAlphabetProcessContext.successfulReturnValue(
            for: invocation(program: "EP9_R117", offset: 84, process: 64)), 0)
        XCTAssertEqual(OriginalAlphabetProcessContext.successfulReturnValue(
            for: invocation(program: "EP9_R125", offset: 104, process: 64)), 0)
        XCTAssertEqual(OriginalAlphabetProcessContext.successfulReturnValue(
            for: invocation(program: "EP9_R205", offset: 248, process: 64)), 2)
        XCTAssertEqual(OriginalAlphabetProcessContext.successfulReturnValue(
            for: invocation(program: "EP9_R207", offset: 84, process: 64)), 2)
        XCTAssertEqual(OriginalAlphabetProcessContext.successfulReturnValue(
            for: invocation(program: "EP9_R213", offset: 84, process: 64)), 2)
    }

    func testSourceCameraTransformAndInclusivePaintingHitBounds() throws {
        let leftTop = try XCTUnwrap(OriginalApplePaintingSearch.cameraPoint(
            pageX: 82, pageY: 157, cameraX: 0, cameraY: 0))
        XCTAssertEqual(leftTop, OriginalAlphabetTouchPoint(x: 54, y: 215))
        XCTAssertTrue(OriginalApplePaintingSearch.containsPainting(at: 0, cameraPoint: leftTop))

        let rightBottom = try XCTUnwrap(OriginalApplePaintingSearch.cameraPoint(
            pageX: 87, pageY: 162, cameraX: 0, cameraY: 0))
        XCTAssertEqual(rightBottom, OriginalAlphabetTouchPoint(x: 69, y: 230))
        XCTAssertTrue(OriginalApplePaintingSearch.containsPainting(at: 0, cameraPoint: rightBottom))

        let outside = try XCTUnwrap(OriginalApplePaintingSearch.cameraPoint(
            pageX: 88, pageY: 163, cameraX: 0, cameraY: 0))
        XCTAssertFalse(OriginalApplePaintingSearch.containsPainting(at: 0, cameraPoint: outside))
        XCTAssertFalse(OriginalApplePaintingSearch.containsPainting(at: 5, cameraPoint: leftTop))
        XCTAssertNil(OriginalApplePaintingSearch.cameraPoint(
            pageX: 82, pageY: 157, cameraX: .infinity, cameraY: 0))

        XCTAssertEqual(OriginalApplePaintingSearch.cameraPoint(
            pageX: 82, pageY: 157, cameraX: 128, cameraY: 96),
            OriginalAlphabetTouchPoint(x: 51, y: 212))
    }

    func testAppleArtworkMaskCoversEverySourceSelectionRegion() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let renderer = try OriginalApplePaintingRenderer(library: library)
        let anchors: [(x: Int32, y: Int32)] = [
            (86, 214), (32, 224), (188, 188), (160, 74), (186, 74)
        ]

        for (index, anchor) in anchors.enumerated() {
            let bitmap = try library.loadLinear(path: "trick/alphabet/apple\(index + 1).bin")
            let mask = try renderer.mask(for: index)
            let targetPoint = OriginalAlphabetTouchPoint(x: anchor.x - 24, y: anchor.y + 8)
            XCTAssertTrue(OriginalApplePaintingSearch.containsPainting(at: index, cameraPoint: targetPoint))
            XCTAssertTrue(mask.contains(targetPoint), "Painting \(index + 1) target is transparent")
            XCTAssertFalse(mask.contains(OriginalAlphabetTouchPoint(x: -1, y: 0)))
            let image = try renderer.render(index: index)
            XCTAssertEqual(image.width, OriginalApplePaintingRenderer.pageWidth)
            XCTAssertEqual(image.height, OriginalApplePaintingRenderer.pageHeight)
            XCTAssertEqual(bitmap.width, 256)
            XCTAssertEqual(bitmap.height, 256)
        }

        let firstBitmap = try library.loadLinear(path: "trick/alphabet/apple1.bin")
        let firstMask = OriginalApplePaintingMask(bitmap: firstBitmap)
        XCTAssertFalse(firstMask.contains(OriginalAlphabetTouchPoint(x: 0, y: 0)))
    }

    func testPaintingOverlayCompletesAfterTheLetterIsAcknowledged() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let renderer = try OriginalApplePaintingRenderer(library: library)
        let mask = try renderer.mask(for: 0)
        var process = try XCTUnwrap(OriginalApplePaintingProcess(paintingIndex: 0))

        XCTAssertFalse(process.select(pageX: 90, pageY: 157, mask: mask))
        XCTAssertTrue(process.select(pageX: 82, pageY: 157, mask: mask))
        XCTAssertEqual(process.phase, .revealed("J"))
        XCTAssertEqual(process.foundMask, 1)
        XCTAssertEqual(process.acknowledgeLetter(), 2)
        XCTAssertEqual(process.phase, .complete)
        XCTAssertNil(process.acknowledgeLetter())
    }

    func testPaintingCameraUsesRecoveredStepAndLimits() throws {
        var process = try XCTUnwrap(OriginalApplePaintingProcess(paintingIndex: 0))

        process.moveCamera(horizontalSteps: 1, verticalSteps: -1)
        XCTAssertEqual(process.cameraX, -0.03, accuracy: 0.0001)
        XCTAssertEqual(process.cameraY, 0.03, accuracy: 0.0001)

        process.moveCamera(horizontalSteps: 100, verticalSteps: 101)
        XCTAssertEqual(process.cameraX, 2, accuracy: 0.0001)
        XCTAssertEqual(process.cameraY, 3, accuracy: 0.0001)

        process.moveCamera(horizontalSteps: -300, verticalSteps: -400)
        XCTAssertEqual(process.cameraX, -2, accuracy: 0.0001)
        XCTAssertEqual(process.cameraY, -6, accuracy: 0.0001)
    }

    func testPreviouslyFoundPaintingStartsWithItsLetterAvailable() throws {
        var process = try XCTUnwrap(OriginalApplePaintingProcess(paintingIndex: 4, foundMask: 1 << 4))

        XCTAssertEqual(process.phase, .revealed("Y"))
        XCTAssertEqual(process.acknowledgeLetter(), 2)
        XCTAssertEqual(process.phase, .complete)
    }

    func testCallerQueryOnlyReturnsRecoveredSearchValue() {
        XCTAssertEqual(OriginalAlphabetProcessContext.callerValue(forKey: 0x15, mode: .paintingSearch), 10)
        XCTAssertNil(OriginalAlphabetProcessContext.callerValue(forKey: 0x15, mode: .wordEntry))
        XCTAssertNil(OriginalAlphabetProcessContext.callerValue(forKey: 0x14, mode: .paintingSearch))
    }

    func testCPRRequiresCloseThenFullReopen() {
        var process = OriginalCPRProcess()

        XCTAssertNil(process.receiveFold(isClosed: false, isFullyOpen: true))
        XCTAssertNil(process.receiveFold(isClosed: false, isFullyOpen: false))
        XCTAssertEqual(process.phase, .awaitingClose)
        XCTAssertNil(process.receiveFold(isClosed: true, isFullyOpen: false))
        XCTAssertEqual(process.phase, .awaitingReopen)
        XCTAssertNil(process.receiveFold(isClosed: false, isFullyOpen: false))
        XCTAssertEqual(process.receiveFold(isClosed: false, isFullyOpen: true), 0)
        XCTAssertEqual(process.phase, .complete)
        XCTAssertNil(process.receiveFold(isClosed: true, isFullyOpen: false))
    }

    func testAppleWordEntryRequiresAllFoundLettersAndOrderedPlayerTaps() throws {
        XCTAssertNil(OriginalAppleWordEntryProcess(foundMask: 0x0f))
        var process = try XCTUnwrap(OriginalAppleWordEntryProcess(foundMask: 0x1f))

        XCTAssertNil(process.selectLetter(at: 5))
        XCTAssertNil(process.selectLetter(at: 0))
        XCTAssertEqual(process.selectedLetters, ["J"])
        XCTAssertNil(process.selectLetter(at: 2))
        XCTAssertTrue(process.selectedLetters.isEmpty)

        for index in OriginalAppleWordEntryProcess.letters.indices.dropLast() {
            XCTAssertNil(process.selectLetter(at: index))
        }
        XCTAssertEqual(process.selectedLetters, Array("JENN"))
        XCTAssertEqual(process.selectLetter(at: 4), 0)
        XCTAssertTrue(process.isComplete)
        XCTAssertNil(process.selectLetter(at: 0))
    }

    func testFindsFivePaintingsInSourceMapOrderAndIgnoresOtherMaps() {
        var search = OriginalApplePaintingSearch()

        XCTAssertEqual(OriginalApplePaintingSearch.targetWord, "JENNY")
        XCTAssertEqual(OriginalApplePaintingSearch.paintingMapIDs, [11, 39, 17, 33, 31])
        XCTAssertNil(search.findPainting(onMap: 40))
        XCTAssertEqual(search.foundCount, 0)

        for (index, mapID) in OriginalApplePaintingSearch.paintingMapIDs.enumerated() {
            XCTAssertEqual(search.findPainting(onMap: mapID), index)
            XCTAssertTrue(search.hasFoundPainting(at: index))
        }

        XCTAssertEqual(search.foundCount, 5)
        XCTAssertTrue(search.isComplete)
    }

    func testDuplicatePaintingDoesNotIncreaseFoundCount() {
        var search = OriginalApplePaintingSearch()

        XCTAssertEqual(search.findPainting(onMap: 39), 1)
        XCTAssertEqual(search.findPainting(onMap: 39), 1)
        XCTAssertEqual(search.foundCount, 1)
        XCTAssertFalse(search.isComplete)
    }

    func testRecoveredPaintingRevealsItsLetterAndSetsItsFoundBit() {
        var search = OriginalApplePaintingSearch()

        let reveal = search.revealLetter(onMap: 39)

        XCTAssertEqual(reveal?.index, 1)
        XCTAssertEqual(reveal?.letter, "E")
        XCTAssertTrue(search.hasFoundPainting(at: 1))
        XCTAssertNil(search.revealLetter(onMap: 40))
    }

    func testInitialFoundMaskIgnoresBitsOutsideFivePaintingSlots() {
        let search = OriginalApplePaintingSearch(foundMask: 0xffff)

        XCTAssertEqual(search.foundCount, 5)
        XCTAssertTrue(search.isComplete)
        XCTAssertFalse(search.hasFoundPainting(at: -1))
        XCTAssertFalse(search.hasFoundPainting(at: 5))
    }

    private func invocation(program: String, offset: Int, process: UInt16, mapID: Int16 = 0)
        -> OriginalEventRunner.EmbeddedProcessInvocation {
        .init(processID: process, programName: program, eventIndex: 0,
              eventSourceOffset: offset, eventBytes: Data(),
              selection: .init(sceneID: 0, blockID: 0, modeID: 0, eventID: 0,
                               nowTime: 0, mapID: mapID))
    }
}
