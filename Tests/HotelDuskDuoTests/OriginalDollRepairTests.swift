import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalDollRepairTests: XCTestCase {
    private func ready() -> OriginalDollRepairProcess {
        var puzzle = OriginalDollRepairProcess(); _ = puzzle.update(); return puzzle
    }
    private var seam: [SIMD2<Int>] { (0...10).map { .init($0 % 2 == 0 ? 150 : 180, 130 + $0 * 7) } }
    func testContinuousZigzagStitchesAllThreeSeamSections() {
        var puzzle = ready()
        for point in seam { _ = puzzle.update(pageTouch: point) }
        _ = puzzle.update(); _ = puzzle.update()
        XCTAssertEqual(puzzle.stitches.count, 10)
        XCTAssertEqual(puzzle.seamMask, 0x3F)
        for _ in 0..<200 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
    }
    func testTapsAndStraightHorizontalDragsDoNotMakeStitches() {
        var puzzle = ready()
        for _ in 0..<20 {
            _ = puzzle.update(pageTouch: .init(150, 140))
            _ = puzzle.update(pageTouch: .init(180, 140))
            _ = puzzle.update()
        }
        XCTAssertTrue(puzzle.stitches.isEmpty)
        XCTAssertNil(puzzle.result)
        puzzle.quit(); _ = puzzle.update()
        XCTAssertEqual(puzzle.update(fadeComplete: true), [.completed(2)])
    }
    func testFifteenWrongStitchesDropTheWingAndReturnFailure() {
        var puzzle = ready()
        for _ in 0..<15 {
            _ = puzzle.update(pageTouch: .init(30, 40))
            _ = puzzle.update(pageTouch: .init(50, 60))
            _ = puzzle.update()
        }
        XCTAssertEqual(puzzle.stitches.count, 15)
        XCTAssertEqual(puzzle.phase, 3)
        for _ in 0..<500 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
        XCTAssertGreaterThanOrEqual(puzzle.wingAngle, 90)
        XCTAssertGreaterThan(puzzle.wingY, 256)
        XCTAssertEqual(puzzle.result, 1)
    }
    @MainActor func testOriginalScriptAndSeamInputReturnSuccess() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(4); game.applyTimeChange(1); game.setMap(31, previous: 39)
        let selection = OriginalEventSelectionContext(sceneID: 11, blockID: 0, modeID: 15,
            eventID: 15, nowTime: game.nowTime, mapID: game.mapID)
        let program = try catalog.loadProgram("EP5_R205")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.index == 15 })
        let sourceOutcome = try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: program.conditions, processReturn: 0)
        guard case .completed(let completion) = sourceOutcome,
              let transition = completion.transition else {
            return XCTFail("Doll-repair success must select a source event")
        }
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController(); audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .process(id: 38))
        for _ in 0..<65 { play.advanceFrame() }
        for point in seam {
            play.holdDollRepairTouch(x: Float(point.x), y: Float(point.y)); play.advanceFrame()
        }
        play.releaseDollRepairTouch()
        for _ in 0..<300 where play.dollRepair != nil { play.advanceFrame() }
        XCTAssertNil(play.dollRepair)
        XCTAssertNotEqual(play.runner.phase, .process(id: 38))
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 14)), true)
        XCTAssertEqual(play.runner.session.selection.eventID, transition.eventID)
    }
    @MainActor func testOriginalDollArtworkAndStitches() throws {
        let renderer = try OriginalDollRepairRenderer()
        var puzzle = ready()
        let before = try renderer.render(puzzle)
        for point in seam { _ = puzzle.update(pageTouch: point) }
        _ = puzzle.update()
        let after = try renderer.render(puzzle)
        XCTAssertNotEqual(before.dataProvider?.data as Data?, after.dataProvider?.data as Data?)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(URL(fileURLWithPath: "/tmp/hotel-doll-stitches.png") as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, after, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
