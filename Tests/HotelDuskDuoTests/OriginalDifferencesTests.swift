import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalDifferencesTests: XCTestCase {
    private func ready() throws -> OriginalDifferencesProcess {
        var puzzle = try OriginalDifferencesProcess(mask: Array(repeating: 0, count: 0xC000))
        _ = puzzle.update()
        return puzzle
    }
    private func draw(_ points: [SIMD2<Int>], on puzzle: inout OriginalDifferencesProcess) {
        for point in points { _ = puzzle.update(touch: point) }
        _ = puzzle.update(); _ = puzzle.update()
    }
    private func circle(_ rect: SIMD4<Int>) -> [SIMD2<Int>] {
        [.init(rect.x - 5, rect.y - 5), .init(rect.z + 5, rect.y - 5),
         .init(rect.z + 5, rect.w + 5), .init(rect.x - 5, rect.w + 5), .init(rect.x - 5, rect.y - 5)]
    }
    func testBothDifferencesRequireSeparateSurroundingStrokes() throws {
        var puzzle = try ready()
        for target in OriginalDifferencesProcess.targets { draw(circle(target), on: &puzzle) }
        XCTAssertEqual(puzzle.found, 3)
        for _ in 0..<250 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
    }
    func testTouchingOrCrossingDifferenceDoesNotCountAsCirclingIt() throws {
        for points: [SIMD2<Int>] in [[.init(148, 108)], [.init(139, 99), .init(148, 108), .init(157, 117)]] {
            var puzzle = try ready()
            draw(points, on: &puzzle)
            XCTAssertEqual(puzzle.found, 0)
            puzzle.quit(); _ = puzzle.update()
            XCTAssertEqual(puzzle.update(fadeComplete: true), [.completed(1)])
        }
        var untouched = try ready()
        untouched.quit(); _ = untouched.update()
        XCTAssertEqual(untouched.update(fadeComplete: true), [.completed(2)])
    }
    func testTwoFailedAttemptsRequireClearAfterTheOriginalHint() throws {
        var puzzle = try ready()
        draw([.init(40, 40)], on: &puzzle)
        draw([.init(40, 40)], on: &puzzle)
        var effects: [OriginalDifferencesProcess.Effect] = []
        for _ in 0..<40 { effects += puzzle.update() }
        XCTAssertTrue(effects.contains(.hint(pairA: 50, pairB: 1)))
        XCTAssertTrue(puzzle.awaitingHint)
        puzzle.finishHint()
        for _ in 0..<31 { _ = puzzle.update() }
        puzzle.clear()
        for target in OriginalDifferencesProcess.targets { draw(circle(target), on: &puzzle) }
        for _ in 0..<250 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
    }
    @MainActor func testSourceEventStartsPuzzleAndReturnsItsSuccessBranch() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(3)
        game.applyTimeChange(4)
        game.setMap(27, previous: 39)
        let selection = OriginalEventSelectionContext(sceneID: 8, blockID: 1, modeID: 15,
            eventID: 80, nowTime: game.nowTime, mapID: game.mapID)
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP4_R201"), game: game, selection: selection)
        let audio = AudioController(); audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .process(id: 73))
        for _ in 0..<65 { play.advanceFrame() }
        for target in OriginalDifferencesProcess.targets {
            for point in circle(target) {
                play.holdDifferencesTouch(x: Float(point.x), y: Float(point.y)); play.advanceFrame()
            }
            play.releaseDifferencesTouch(); play.advanceFrame(); play.advanceFrame()
        }
        for _ in 0..<300 where play.differences != nil { play.advanceFrame() }
        XCTAssertNil(play.differences)
        XCTAssertNotEqual(play.runner.phase, .process(id: 73))
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 49)), true)
    }

    @MainActor func testPamphletArtworkAndOriginalMaskedInk() throws {
        let renderer = try OriginalDifferencesRenderer()
        var puzzle = try renderer.makeProcess()
        _ = puzzle.update()
        let before = try renderer.render(puzzle)
        draw(circle(OriginalDifferencesProcess.targets[0]), on: &puzzle)
        let after = try renderer.render(puzzle)
        XCTAssertEqual(after.width, 192); XCTAssertEqual(after.height, 256)
        XCTAssertNotEqual(before.dataProvider?.data as Data?, after.dataProvider?.data as Data?)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(URL(fileURLWithPath: "/tmp/hotel-pamphlet.png") as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, after, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
