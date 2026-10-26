import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalToiletTankTests: XCTestCase {
    private func ready() -> OriginalToiletTankProcess {
        var puzzle = OriginalToiletTankProcess()
        _ = puzzle.update(); _ = puzzle.update(fadeComplete: true)
        return puzzle
    }
    private func stroke(_ puzzle: inout OriginalToiletTankProcess, direction: Int = -1) {
        _ = puzzle.update()
        let rect = puzzle.lidRectangle
        let x = direction < 0 ? rect.z - 5 : rect.x + 5
        let y = (rect.y + rect.w) / 2
        for i in 0..<20 { _ = puzzle.update(pageTouch: .init(x + direction * i, y)) }
        _ = puzzle.update()
    }
    func testLidFollowsSlowDragsAndRequiresFullOpening() {
        var puzzle = ready()
        stroke(&puzzle)
        XCTAssertLessThan(puzzle.lidAngle, 0)
        XCTAssertGreaterThan(puzzle.lidAngle, -33)
        let partial = puzzle.lidAngle
        stroke(&puzzle, direction: 1)
        XCTAssertGreaterThan(puzzle.lidAngle, partial)
        for _ in 0..<20 where puzzle.stage == 1 { stroke(&puzzle) }
        XCTAssertEqual(puzzle.lidAngle, -33)
        for _ in 0..<300 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
    }
    func testTapFastSwipeAndOutsideDragDoNotOpenTank() {
        for points: [SIMD2<Int>] in [[.init(100, 76)], [.init(180, 76), .init(50, 76), .init(50, 76)], [.init(100, 200), .init(96, 200)]] {
            var puzzle = ready()
            for point in points { _ = puzzle.update(pageTouch: point) }
            _ = puzzle.update()
            XCTAssertEqual(puzzle.lidAngle, 0)
            puzzle.quit(); _ = puzzle.update()
            XCTAssertEqual(puzzle.update(fadeComplete: true), [.completed(1)])
        }
    }
    func testFlushPlaysOriginalFailureHintAndReturnsToTank() {
        var puzzle = ready()
        for point: SIMD2<Int> in [.init(96, 128), .init(96, 132), .init(100, 136), .init(104, 140)] {
            _ = puzzle.update(pageTouch: point)
        }
        var effects: [OriginalToiletTankProcess.Effect] = []
        for _ in 0..<220 { effects += puzzle.update() }
        XCTAssertTrue(effects.contains(.sound(archive: 0, entry: 45)))
        XCTAssertTrue(effects.contains(.hint(pairA: 25, pairB: 1)))
        XCTAssertTrue(puzzle.awaitingHint)
        XCTAssertNil(puzzle.result)
        puzzle.finishHint()
        for _ in 0..<55 { _ = puzzle.update(fadeComplete: true) }
        XCTAssertTrue(puzzle.canQuit)
        XCTAssertEqual(puzzle.lidAngle, 0)
    }
    func testBackDuringFlushReturnsWithoutCompletingTheTank() {
        var puzzle = ready()
        for point: SIMD2<Int> in [.init(96, 128), .init(96, 132), .init(100, 136), .init(104, 140)] {
            _ = puzzle.update(pageTouch: point)
        }
        XCTAssertEqual(puzzle.phase, 2)
        XCTAssertTrue(puzzle.canQuit)
        puzzle.quit(); _ = puzzle.update()
        XCTAssertEqual(puzzle.update(fadeComplete: true), [.completed(1)])
    }
    @MainActor func testSourceEventCompletesThroughTouchInput() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(3)
        game.applyTimeChange(1)
        game.setMap(31, previous: 39)
        let selection = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0, modeID: 15,
            eventID: 11, nowTime: game.nowTime, mapID: game.mapID)
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP4_R205"), game: game, selection: selection)
        let audio = AudioController(); audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .process(id: 48))
        for _ in 0..<65 { play.advanceFrame() }
        for _ in 0..<20 where play.toiletTank?.stage == 1 {
            play.releaseToiletTankTouch(); play.advanceFrame()
            let rect = try XCTUnwrap(play.toiletTank?.lidRectangle)
            for i in 0..<20 {
                play.holdToiletTankTouch(x: Float(rect.z - 5 - i), y: Float((rect.y + rect.w) / 2))
                play.advanceFrame()
            }
        }
        play.releaseToiletTankTouch()
        for _ in 0..<400 where play.toiletTank != nil { play.advanceFrame() }
        XCTAssertNil(play.toiletTank)
        XCTAssertNotEqual(play.runner.phase, .process(id: 48))
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 25)), true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 24)), false)
    }
    @MainActor func testOriginalModelShowsMovingLid() throws {
        let renderer = try OriginalToiletTankRenderer()
        var puzzle = ready()
        let before = try renderer.render(puzzle)
        for _ in 0..<20 where puzzle.stage == 1 { stroke(&puzzle) }
        let after = try renderer.render(puzzle)
        XCTAssertNotEqual(before.dataProvider?.data as Data?, after.dataProvider?.data as Data?)
        for (name, image) in [("closed", before), ("open", after)] {
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(URL(fileURLWithPath: "/tmp/hotel-toilet-\(name).png") as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}
