import XCTest
@testable import HotelDuskDuoKit

final class OriginalChristmasTreeProcessTests: XCTestCase {
    @MainActor
    func testCompletedArrangementPersistsItsSavedOrderThroughTheSession() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP7_R122")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 43
        })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: try OriginalBytes(event.raw).u16(4), nowTime: game.nowTime, mapID: game.mapID)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 43))

        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        for _ in 0..<70 { play.advanceFrame() }
        let renderer = try OriginalChristmasTreeRenderer(library: .bundled())
        for (slot, decoration) in try XCTUnwrap(play.christmasTree).decorationOrder.enumerated() {
            let state = try XCTUnwrap(play.christmasTree)
            let centreX = 9 + slot * 17
            let start = try XCTUnwrap((232..<249).lazy.flatMap { y in
                (max(0, centreX - 8)..<min(192, centreX + 9)).lazy.map { SIMD2<Float>(Float($0), Float(y)) }
            }.first { renderer.decoration(at: $0, process: state) == decoration })
            let destination = OriginalChristmasTreeLayout.pageDecorationTargets[slot]
            play.holdChristmasTreeTouch(x: start.x, y: start.y)
            play.releaseChristmasTreeTouch(x: destination.x, y: destination.y)
        }

        XCTAssertEqual(play.christmasTree?.arrangement.decorationAtTarget.compactMap { $0 }, Array(0..<11))

        for _ in 0..<100 where play.christmasTree != nil { play.advanceFrame() }

        XCTAssertNil(play.christmasTree)
        XCTAssertEqual(play.runner.game.christmasTreeDecorationOrder, 0xE400)
    }

    func testProcessUsesSavedDecorationOrder() {
        XCTAssertEqual(OriginalChristmasTreeProcess().decorationOrder, Array(0..<11))
        XCTAssertEqual(OriginalChristmasTreeProcess(savedOrder: 0x7207).decorationOrder,
                       [1, 0, 3, 2, 6, 4, 7, 5, 9, 8, 10])
    }

    func testMenuExitFadesAndReturnsOriginalValueTwo() {
        var process = OriginalChristmasTreeProcess()

        XCTAssertEqual(process.update(), [.fadeIn(60)])
        XCTAssertTrue(process.canOpenMenu)
        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertFalse(process.canOpenMenu)
        XCTAssertEqual(process.update(), [])
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
        XCTAssertEqual(process.result, 2)
    }

    func testMenuExitCanOnlyBeRequestedAfterTheSceneStarts() {
        var process = OriginalChristmasTreeProcess()

        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeIn(60)])
        XCTAssertNil(process.result)
    }

    func testDecorationDropsUseTheRecoveredArrangementRule() {
        var process = OriginalChristmasTreeProcess()
        let target = OriginalChristmasTreeLayout.modelDecorationTargets[0]

        XCTAssertNil(process.dropDecoration(0, at: target))
        _ = process.update()
        XCTAssertEqual(process.dropDecoration(0, at: target), 0)
        XCTAssertEqual(process.arrangement.decorationAtTarget[0], 0)

        process.openMenu()
        XCTAssertNil(process.dropDecoration(1, at: OriginalChristmasTreeLayout.modelDecorationTargets[1]))
    }

    func testStarIsAvailableOnlyAfterTheTenDecorationsArePlaced() {
        var process = OriginalChristmasTreeProcess()
        _ = process.update()
        XCTAssertFalse(process.canPickDecoration(10))
        XCTAssertNil(process.dropDecoration(10, at: OriginalChristmasTreeLayout.modelDecorationTargets[10]))

        for decoration in 0..<10 {
            XCTAssertTrue(process.canPickDecoration(decoration))
            _ = process.dropDecoration(decoration,
                                       at: OriginalChristmasTreeLayout.modelDecorationTargets[decoration])
        }

        XCTAssertTrue(process.canPickDecoration(10))
        XCTAssertEqual(process.dropDecoration(10,
                                              at: OriginalChristmasTreeLayout.modelDecorationTargets[10]), 10)
        XCTAssertEqual(process.arrangement.encodedOrder,
                       OriginalChristmasTreeLayout.encodedDecorationOrder(Array(0..<11)))
    }

    func testDragUsesTouchDeltaAndRecordsTheSourceTarget() {
        var process = OriginalChristmasTreeProcess()
        _ = process.update()
        let start = OriginalChristmasTreeLayout.modelDecorationTargets[0]
        let destination = OriginalChristmasTreeLayout.modelDecorationTargets[1]
        let pageStart = SIMD2<Float>(96, 128)
        let pageEnd = pageStart + SIMD2((destination.x - start.x) * 96,
                                        (start.y - destination.y) * 128)

        XCTAssertTrue(process.beginDecorationDrag(0, at: start, pagePoint: pageStart))
        XCTAssertFalse(process.canOpenMenu)
        let dragged = process.dragDecoration(to: pageEnd)
        XCTAssertEqual(dragged?.x ?? .nan, destination.x, accuracy: 0.0001)
        XCTAssertEqual(dragged?.y ?? .nan, destination.y, accuracy: 0.0001)
        XCTAssertEqual(process.endDecorationDrag(at: pageEnd), 1)
        XCTAssertNil(process.draggedDecoration)
        XCTAssertEqual(process.arrangement.decorationAtTarget[1], 0)
        XCTAssertTrue(process.canOpenMenu)
    }

    func testMenuExitStillStartsAFadeAfterTheOpeningFadeCompletes() {
        var process = OriginalChristmasTreeProcess()
        _ = process.update()
        _ = process.update(fadeComplete: true)
        process.openMenu()

        XCTAssertEqual(process.update(fadeComplete: true), [.fadeOut(60)])
    }

    func testElevenPlacedObjectsFadeOutAndReturnSourceProcessValueTwo() {
        var process = OriginalChristmasTreeProcess()
        _ = process.update()
        for index in 0..<11 {
            XCTAssertEqual(process.dropDecoration(index, at: OriginalChristmasTreeLayout.modelDecorationTargets[index]), index)
        }

        XCTAssertTrue(process.arrangement.isComplete)
        XCTAssertFalse(process.canOpenMenu)
        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertEqual(process.update(), [])
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
        XCTAssertEqual(process.result, 2)
    }
}
