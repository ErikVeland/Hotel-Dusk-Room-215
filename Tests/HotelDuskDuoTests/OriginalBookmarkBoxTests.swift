import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import HotelDuskDuoKit

final class OriginalBookmarkBoxTests: XCTestCase {
    private func tap(_ puzzle: inout OriginalBookmarkBoxProcess, _ point: SIMD2<Int>) {
        _ = puzzle.update()
        _ = puzzle.update(pageTouch: point)
        _ = puzzle.update()
    }
    private func turn(_ puzzle: inout OriginalBookmarkBoxProcess, _ point: SIMD2<Int>) {
        tap(&puzzle, point)
        for _ in 0..<45 { _ = puzzle.update() }
        XCTAssertFalse(puzzle.isRotating)
    }
    private func loosen(_ puzzle: inout OriginalBookmarkBoxProcess) {
        _ = puzzle.update()
        turn(&puzzle, .init(16, 128))
        turn(&puzzle, .init(96, 240))
        turn(&puzzle, .init(16, 128))
        XCTAssertEqual(puzzle.angles, .init(0, 180, 270))
        XCTAssertTrue(puzzle.canDislodgeBookmark)
        for _ in 0..<10 { tap(&puzzle, .init(96, 128)) }
        XCTAssertEqual(puzzle.taps, 10)
    }
    private func extraction(_ puzzle: inout OriginalBookmarkBoxProcess) {
        loosen(&puzzle)
        turn(&puzzle, .init(176, 128))
        XCTAssertTrue(puzzle.openSideVisible)
        tap(&puzzle, .init(96, 128))
        XCTAssertEqual(puzzle.stage, 5)
        _ = puzzle.update(fadeComplete: true)
        _ = puzzle.update(fadeComplete: true)
        XCTAssertEqual(puzzle.phase, 2)
        XCTAssertEqual(puzzle.stage, 1)
    }
    func testWrongSideTapsAndCancellationCannotSolve() {
        var puzzle = OriginalBookmarkBoxProcess()
        _ = puzzle.update()
        for _ in 0..<12 { tap(&puzzle, .init(96, 128)) }
        XCTAssertEqual(puzzle.taps, 0)
        XCTAssertNil(puzzle.result)
        puzzle.quit()
        XCTAssertEqual(puzzle.update(), [.fadeOut(60)])
        XCTAssertEqual(puzzle.update(fadeComplete: true), [.completed(1)])
    }
    func testRotationTappingAndSlowPullCompleteThePuzzle() {
        var puzzle = OriginalBookmarkBoxProcess()
        extraction(&puzzle)
        _ = puzzle.update(pageTouch: .init(50, 140))
        for x in stride(from: 52, through: 150, by: 2) { _ = puzzle.update(pageTouch: .init(x, 140)) }
        XCTAssertGreaterThanOrEqual(puzzle.bookmarkX, 59)
        for _ in 0..<700 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
        XCTAssertEqual(puzzle.itemAlpha, 31)
    }
    func testFastBackwardAndOnePixelDragsDoNotExtractTheBookmark() {
        for delta in [-4, 1, 7, 20] {
            var puzzle = OriginalBookmarkBoxProcess()
            extraction(&puzzle)
            for _ in 0..<40 {
                _ = puzzle.update()
                _ = puzzle.update(pageTouch: .init(50, 140))
                _ = puzzle.update(pageTouch: .init(50 + delta, 140))
                _ = puzzle.update(pageTouch: .init(50 + delta, 140))
            }
            XCTAssertEqual(puzzle.bookmarkX, 27, "delta \(delta)")
            XCTAssertNil(puzzle.result)
        }
    }
    @MainActor func testSourceScriptStartsBoxAndInputCompletionSetsOriginalFlag() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(2)
        game.applyTimeChange(2)
        game.setMap(31, previous: 39)
        let program = try catalog.loadProgram("EP3_R205")
        let graph = try program.blocks
        let group = try XCTUnwrap(graph.tables[1].first { group in
            let bytes = OriginalBytes(group.raw)
            let start = Int(try bytes.u32(4)) / 20
            return (start..<(start + Int(try bytes.u32(8)))).contains(14)
        })
        let selection = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: try OriginalBytes(group.raw).u16(0), modeID: 15,
            eventID: 14, nowTime: game.nowTime, mapID: game.mapID)
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController(); audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .process(id: 47))
        for _ in 0..<65 { play.advanceFrame() }
        func press(_ point: SIMD2<Float>) {
            play.releaseBookmarkBoxTouch(); play.advanceFrame()
            play.holdBookmarkBoxTouch(x: point.x, y: point.y); play.advanceFrame()
            play.releaseBookmarkBoxTouch(); play.advanceFrame()
        }
        for point: SIMD2<Float> in [.init(16, 128), .init(96, 240), .init(16, 128)] {
            press(point)
            for _ in 0..<45 { play.advanceFrame() }
        }
        for _ in 0..<10 { press(.init(96, 128)) }
        press(.init(176, 128))
        for _ in 0..<45 { play.advanceFrame() }
        press(.init(96, 128))
        for _ in 0..<130 { play.advanceFrame() }
        XCTAssertEqual(play.bookmarkBox?.phase, 2)
        play.holdBookmarkBoxTouch(x: 50, y: 140); play.advanceFrame()
        for x in stride(from: 52, through: 150, by: 2) {
            play.holdBookmarkBoxTouch(x: Float(x), y: 140); play.advanceFrame()
        }
        play.releaseBookmarkBoxTouch()
        for _ in 0..<700 where play.bookmarkBox != nil { play.advanceFrame() }
        XCTAssertNil(play.bookmarkBox)
        XCTAssertNotEqual(play.runner.phase, .process(id: 47))
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 23)), true)
    }

    @MainActor func testOriginalArtworkRendersBothPuzzleStages() throws {
        let renderer = try OriginalBookmarkBoxRenderer()
        var puzzle = OriginalBookmarkBoxProcess()
        _ = puzzle.update()
        for (name, extract) in [("box", false), ("bookmark", true)] {
            if extract { extraction(&puzzle) }
            let image = try renderer.render(puzzle)
            XCTAssertEqual(image.width, 192); XCTAssertEqual(image.height, 256)
            let url = URL(fileURLWithPath: "/tmp/hotel-\(name).png")
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}
