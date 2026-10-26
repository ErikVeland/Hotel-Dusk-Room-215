import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalCashboxDialTests: XCTestCase {
    private struct Snapshot: Decodable {
        let phase: Int, stage: Int, nextPhase: Int, returnValue: Int16
        let angles: [Float], wheelX: [Int32], wheelY: [Int32], holding: Bool, selected: Int, target: [Int]
    }
    private struct Trace: Decodable { let initial: Snapshot; let steps: [String: Snapshot] }

    func testCashboxWheelMotionMatchesOriginalProcessCaptures() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(Trace.self, from: Data(contentsOf: root.appendingPathComponent("Fixtures/Cashbox/source-trace.json")))
        var puzzle = OriginalCabinetDialProcess(randomValue: 0, retainedValue: 0, variant: .cashbox)
        func update(_ page: SIMD2<Float>? = nil, count: Int) {
            for _ in 0..<count { puzzle.update(touch: page.flatMap { OriginalCabinetDialProjection.touch(page: $0, process: puzzle) }) }
        }
        func compare(_ state: Snapshot, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(puzzle.phase, state.phase, file: file, line: line)
            XCTAssertEqual(puzzle.stage, state.stage, file: file, line: line)
            XCTAssertEqual(puzzle.returnValue, state.returnValue, file: file, line: line)
            XCTAssertEqual(puzzle.angles, state.angles, file: file, line: line)
            XCTAssertEqual(puzzle.wheelCentres, state.wheelX, file: file, line: line)
            XCTAssertEqual(puzzle.wheelY, state.wheelY, file: file, line: line)
            XCTAssertEqual(puzzle.holding, state.holding, file: file, line: line)
            XCTAssertEqual(puzzle.selected, state.selected, file: file, line: line)
            XCTAssertEqual(puzzle.target, state.target, file: file, line: line)
        }
        update(count: 2); compare(trace.initial)
        for (wheel, count, y) in [(0, 4, 40), (1, 2, 220), (2, 1, 40)] {
            for index in 0..<count {
                let x = Float([35, 99, 161][wheel])
                update(.init(x, 130), count: 3)
                update(.init(x, Float(y)), count: 3)
                compare(try XCTUnwrap(trace.steps["drag\(wheel)_\(index)"]))
                update(count: 90)
                compare(try XCTUnwrap(trace.steps["wheel\(wheel)_\(index)"]))
            }
        }
    }

    func testCashboxUsesItsOwnRetainedNumberAndOriginalCombination() throws {
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.storeCabinetDialValue(800)
        game.storeCashboxDialValue(481)
        let restored = try OriginalGameState(snapshot: Data(game.bytes))
        XCTAssertEqual(restored.cabinetDialRetainedValue, 800)
        var puzzle = OriginalCabinetDialProcess(randomValue: 999, retainedValue: restored.cashboxDialRetainedValue, variant: .cashbox)
        XCTAssertEqual(puzzle.target, [5, 1, 8])
        XCTAssertEqual(puzzle.digits, [5, 1, 8])
        puzzle.update(); puzzle.update()
        puzzle.quit(); puzzle.update()
        XCTAssertEqual(puzzle.update(fadeComplete: true), [.completed(2)])
        XCTAssertEqual(puzzle.retainedValue, 481)
    }

    @MainActor func testChapterTenCashboxCompletesThroughOriginalWheelInput() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(9)
        game.setMap(40, previous: 39)
        let selection = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0, modeID: 15,
            eventID: 2, nowTime: game.nowTime, mapID: game.mapID)
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP10_R301"), game: game, selection: selection)
        let audio = AudioController(); audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.phase, .process(id: 80))
        XCTAssertEqual(play.cabinetDial?.variant, .cashbox)
        for _ in 0..<65 { play.advanceFrame() }
        if let image = play.cabinetDialImage {
            let url = URL(fileURLWithPath: "/tmp/hotel-cashbox-dial.png")
            let output = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(output, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(output))
        }
        for (wheel, count, y) in [(0, 4, 40), (1, 2, 220), (2, 1, 40)] {
            for _ in 0..<count {
                let x = Float([35, 99, 161][wheel])
                play.holdCabinetDialTouch(x: x, y: 130)
                for _ in 0..<3 { play.advanceFrame() }
                play.holdCabinetDialTouch(x: x, y: Float(y))
                for _ in 0..<3 { play.advanceFrame() }
                play.releaseCabinetDialTouch()
                for _ in 0..<90 { play.advanceFrame() }
            }
        }
        XCTAssertEqual(play.cabinetDial?.digits, [5, 1, 8])
        XCTAssertEqual(play.cabinetDial?.returnValue, 0)
        for _ in 0..<300 where play.cabinetDial != nil {
            XCTAssertEqual(play.cabinetDial?.showsDrawer, false)
            play.advanceFrame()
        }
        XCTAssertNil(play.cabinetDial)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 56)), true)
        XCTAssertEqual(play.runner.game.cashboxDialRetainedValue, 0)
    }
}
