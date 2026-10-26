import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalSwitchboardTests: XCTestCase {
    private func ready() -> OriginalSwitchboardProcess {
        var puzzle = OriginalSwitchboardProcess()
        _ = puzzle.update()
        return puzzle
    }

    func testSingleSwitchFallsBackAndOriginalHintsEscalate() {
        var puzzle = ready()
        for attempt in 1...4 {
            _ = puzzle.update(pageTouch: .init(48, 170))
            _ = puzzle.update(pageTouch: .init(48, 160))
            XCTAssertTrue(puzzle.leftOn)
            XCTAssertFalse(puzzle.rightOn)
            XCTAssertFalse(puzzle.lightOn)
            let effects = puzzle.update()
            XCTAssertTrue(effects.contains(.hint(pairA: 18, pairB: attempt < 4 ? 1 : 2)))
            XCTAssertFalse(puzzle.leftOn)
            XCTAssertTrue(puzzle.awaitingHint)
            XCTAssertEqual(puzzle.update(pageTouch: .init(96, 120)), [])
            puzzle.finishHint()
        }
        XCTAssertNil(puzzle.result)
    }

    func testConnectingBarRequiresAnUnbrokenUpwardGesture() {
        for x in [48, 144] {
            var puzzle = ready()
            _ = puzzle.update(pageTouch: .init(x, 170))
            _ = puzzle.update(pageTouch: .init(96, 170))
            _ = puzzle.update(pageTouch: .init(96, 168))
            XCTAssertFalse(puzzle.lightOn)
            _ = puzzle.update(pageTouch: .init(96, 166))
            XCTAssertTrue(puzzle.leftOn && puzzle.rightOn && puzzle.lightOn)
            XCTAssertFalse(puzzle.canQuit)
            for _ in 0..<300 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
            XCTAssertEqual(puzzle.result, 0)
        }
        var released = ready()
        _ = released.update(pageTouch: .init(48, 170))
        _ = released.update(pageTouch: .init(96, 170))
        _ = released.update()
        _ = released.update(pageTouch: .init(96, 160))
        XCTAssertFalse(released.lightOn)
        released.quit()
        _ = released.update()
        _ = released.update(fadeComplete: true)
        XCTAssertEqual(released.result, 1)
    }

    @MainActor func testOriginalScriptStartsPanelAndTouchCompletionReturnsToStory() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(2)
        game.applyTimeChange(3)
        game.setMap(9, previous: 17)
        let selection = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0, modeID: 15,
            eventID: 2, nowTime: game.nowTime, mapID: game.mapID)
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP3_R109"), game: game, selection: selection)
        let audio = AudioController(); audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .process(id: 41))
        XCTAssertNotNil(play.switchboard)
        play.advanceFrame()
        for point: SIMD2<Float> in [.init(48, 170), .init(96, 170), .init(96, 160)] {
            play.holdSwitchboardTouch(x: point.x, y: point.y)
            play.advanceFrame()
        }
        play.releaseSwitchboardTouch()
        for _ in 0..<400 where play.switchboard != nil { play.advanceFrame() }
        XCTAssertNil(play.switchboard)
        XCTAssertNotEqual(play.runner.phase, .process(id: 41))
        XCTAssertTrue(play.runner.game.value(for: .trickFlag(index: 17)) == true)
    }

    @MainActor func testSourcePanelArtRendersBothStates() throws {
        let renderer = try OriginalSwitchboardRenderer()
        var puzzle = ready()
        let off = try renderer.render(puzzle)
        _ = puzzle.update(pageTouch: .init(48, 170))
        _ = puzzle.update(pageTouch: .init(96, 170))
        _ = puzzle.update(pageTouch: .init(96, 160))
        let on = try renderer.render(puzzle)
        XCTAssertEqual(on.width, 192)
        XCTAssertEqual(on.height, 256)
        XCTAssertNotEqual(off.dataProvider?.data as Data?, on.dataProvider?.data as Data?)
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_PUZZLE_PREVIEWS"] {
            for (name, image) in [("switchboard-off", off), ("switchboard-on", on)] {
                let url = URL(fileURLWithPath: directory).appendingPathComponent(name + ".png")
                let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                XCTAssertTrue(CGImageDestinationFinalize(destination))
            }
        }
    }
}
