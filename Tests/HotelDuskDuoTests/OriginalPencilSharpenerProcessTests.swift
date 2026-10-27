import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalPencilSharpenerProcessTests: XCTestCase {
    func testCapturedQuitTouchStartsTheExitAnimation() {
        var process = OriginalPencilSharpenerProcess()

        XCTAssertTrue(process.tap(pageX: 19, pageY: 15))
        XCTAssertEqual(process.phase, .exitAnimation)
        XCTAssertNil(process.returnedProcessValue)
    }

    func testCapturedRawExitTouchMapsToThePortraitMask() throws {
        let pagePoint = try XCTUnwrap(OriginalPencilSharpenerProcess.pagePoint(rawTouch: SIMD2(15, 172)))
        XCTAssertEqual(pagePoint, SIMD2(19, 15))
        XCTAssertTrue(OriginalPencilSharpenerProcess.containsExitMask(pageX: pagePoint.x, pageY: pagePoint.y))
        XCTAssertNil(OriginalPencilSharpenerProcess.pagePoint(rawTouch: SIMD2(256, 172)))
    }

    func testExitReturnsSourceValueTwoAfterSixtyUpdates() {
        var process = OriginalPencilSharpenerProcess()
        XCTAssertTrue(process.tap(pageX: 19, pageY: 15))

        for _ in 0..<(OriginalPencilSharpenerProcess.exitAnimationFrames - 1) {
            process.updateOneFrame()
        }
        XCTAssertNil(process.returnedProcessValue)

        process.updateOneFrame()
        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.returnedProcessValue, 2)
    }

    func testRoundedExitMaskRejectsPointsOutsideTheIcon() {
        XCTAssertTrue(OriginalPencilSharpenerProcess.containsExitMask(pageX: 19, pageY: 15))
        XCTAssertFalse(OriginalPencilSharpenerProcess.containsExitMask(pageX: 3, pageY: 3))
        XCTAssertFalse(OriginalPencilSharpenerProcess.containsExitMask(pageX: 36, pageY: 15))
        XCTAssertFalse(OriginalPencilSharpenerProcess.containsExitMask(pageX: 19, pageY: 28))
    }

    func testRendererLoadsTheCapturedPortraitScene() throws {
        let renderer = try OriginalPencilSharpenerRenderer()
        XCTAssertEqual(renderer.image.width, 192)
        XCTAssertEqual(renderer.image.height, 256)
    }

    func testChapterTenEventRunsProcess59AndReturnsToItsParent() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 440 })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(40, previous: 39)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 59))

        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.pencilSharpenerImage?.width, 192)
        XCTAssertEqual(play.pencilSharpenerImage?.height, 256)
        play.tapPencilSharpener(pageX: 19, pageY: 15)
        XCTAssertEqual(play.pencilSharpener?.phase, .exitAnimation)
        for _ in 0..<OriginalPencilSharpenerProcess.exitAnimationFrames { play.advanceFrame() }

        XCTAssertNil(play.pencilSharpener)
        XCTAssertNil(play.pencilSharpenerImage)
        XCTAssertNotEqual(play.runner.phase, .process(id: 59))
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }
}
