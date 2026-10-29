import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalCoinTests: XCTestCase {
    private func ready() -> OriginalCoinProcess {
        var puzzle = OriginalCoinProcess()
        for _ in 0..<65 { _ = puzzle.update(fadeComplete: true) }
        return puzzle
    }
    func testCoinStackMatchesIndependentOriginalCaptures() throws {
        struct Snapshot: Decodable {
            let phase: Int, stage: Int, returnValue: Int16, coins: [[Int32]]
        }
        struct Trace: Decodable {
            let initial: Snapshot, steps: [String: Snapshot], checkedReturn: Int16
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(Trace.self,
            from: Data(contentsOf: root.appendingPathComponent("Fixtures/Coins/source-trace.json")))
        var puzzle = ready()
        func compare(_ snapshot: Snapshot, line: UInt = #line) {
            XCTAssertEqual(puzzle.phase, snapshot.phase, line: line)
            XCTAssertEqual(puzzle.stage, snapshot.stage, line: line)
            XCTAssertEqual(puzzle.returnValue, snapshot.returnValue, line: line)
            XCTAssertEqual(puzzle.coins.map { [$0.position.x, $0.position.y, $0.depth] }, snapshot.coins, line: line)
        }
        compare(trace.initial)
        for (name, touch): (String, SIMD2<Float>?) in [
            ("pick", .init(96, 51)), ("moved", .init(96, 128)), ("released", nil)
        ] {
            for _ in 0..<3 { _ = puzzle.update(pageTouch: touch) }
            compare(try XCTUnwrap(trace.steps[name]))
        }
        puzzle.check()
        for _ in 0..<300 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, trace.checkedReturn)
    }
    func testBothOriginalStackedCoinSolutionsRequireAnExplicitCheck() {
        for y: Float in [51, 166] {
            var puzzle = ready()
            _ = puzzle.update(pageTouch: .init(96, y))
            _ = puzzle.update(pageTouch: .init(96, 128))
            _ = puzzle.update()
            XCTAssertTrue(puzzle.isCorrect)
            XCTAssertNil(puzzle.result)
            for _ in 0..<200 { _ = puzzle.update() }
            XCTAssertNil(puzzle.result)
            puzzle.check()
            for _ in 0..<200 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
            XCTAssertEqual(puzzle.result, 0)
        }
    }
    func testWrongAnswerAndAbandonedMoveKeepDistinctOriginalReturns() {
        var wrong = ready()
        wrong.check()
        for _ in 0..<200 where wrong.result == nil { _ = wrong.update(fadeComplete: true) }
        XCTAssertEqual(wrong.result, 1)
        var abandoned = ready()
        _ = abandoned.update(pageTouch: .init(96, 51))
        _ = abandoned.update(pageTouch: .init(150, 190))
        _ = abandoned.update()
        abandoned.quit(); _ = abandoned.update()
        XCTAssertEqual(abandoned.update(fadeComplete: true), [.completed(2)])
    }
    func testPickMissAndSnapTolerance() {
        var puzzle = ready()
        let initial = puzzle.coins
        _ = puzzle.update(pageTouch: .init(12, 240))
        _ = puzzle.update(pageTouch: .init(96, 128))
        _ = puzzle.update()
        XCTAssertEqual(puzzle.coins, initial, "A drag must start on a coin")
        _ = puzzle.update(pageTouch: .init(96, 51))
        _ = puzzle.update(pageTouch: .init(100, 131))
        _ = puzzle.update()
        XCTAssertEqual(puzzle.coins[0].position, .zero)
        _ = puzzle.update(pageTouch: .init(96, 128))
        XCTAssertEqual(puzzle.selected, 0, "The most recently placed coin is above the centre coin")
    }
    @MainActor func testChapterSixCoinEventCompletesThroughTouchInput() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(5)
        game.setMap(5, previous: 17)
        let selection = OriginalEventSelectionContext(sceneID: 7, blockID: 2, modeID: 15,
            eventID: 37, nowTime: game.nowTime, mapID: game.mapID)
        let program = try catalog.loadProgram("EP6_R105")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.index == 37 })
        let sourceOutcome = try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: program.conditions, processReturn: 0)
        guard case .completed(let completion) = sourceOutcome,
              let transition = completion.transition else {
            return XCTFail("Coin-puzzle success must select a source event")
        }
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController(); audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .process(id: 51))
        for _ in 0..<65 { play.advanceFrame() }
        let image = try XCTUnwrap(play.coinPuzzleImage)
        let output = try XCTUnwrap(CGImageDestinationCreateWithURL(URL(fileURLWithPath: "/tmp/hotel-coins.png") as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(output, image, nil); XCTAssertTrue(CGImageDestinationFinalize(output))
        play.holdCoinPuzzleTouch(x: 96, y: 51); play.advanceFrame()
        play.pause(); play.resume(); play.advanceFrame()
        XCTAssertNil(play.coinPuzzle?.selected)
        play.holdCoinPuzzleTouch(x: 96, y: 51); play.advanceFrame()
        play.holdCoinPuzzleTouch(x: 96, y: 128); play.advanceFrame()
        play.releaseCoinPuzzleTouch(); play.advanceFrame()
        XCTAssertEqual(play.coinPuzzle?.isCorrect, true)
        play.checkCoinPuzzle()
        for _ in 0..<350 where play.coinPuzzle != nil { play.advanceFrame() }
        XCTAssertNil(play.coinPuzzle)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 27)), true)
        XCTAssertEqual(play.runner.session.selection.eventID, transition.eventID)
    }
}
