import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalLinenWagonIntegrationTests: XCTestCase {
    @MainActor func testChapterFiveWagonCanBeSearchedThroughNativeTouchInput() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(4); game.applyTimeChange(2)
        game.setMap(11, previous: 19)
        let selection = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0, modeID: 15,
            eventID: 1, nowTime: game.nowTime, mapID: game.mapID)
        let program = try catalog.loadProgram("EP5_R111")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.index == 1 })
        let sourceOutcome = try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: program.conditions, processReturn: 0)
        guard case .completed(let completion) = sourceOutcome,
              let transition = completion.transition else {
            return XCTFail("Linen-wagon success must select a source event")
        }
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController(); audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog, puzzleSeed: { 0 })
        defer { play.stop() }
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.phase, .process(id: 60))
        for _ in 0..<65 { play.advanceFrame() }
        func screenshot(_ name: String) throws {
            let image = try XCTUnwrap(play.linenWagonImage)
            let output = try XCTUnwrap(CGImageDestinationCreateWithURL(URL(fileURLWithPath: "/tmp/hotel-wagon-\(name).png") as CFURL,
                "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(output, image, nil); XCTAssertTrue(CGImageDestinationFinalize(output))
        }
        try screenshot("ready")
        play.holdLinenWagonTouch(x: 80, y: 100); play.advanceFrame()
        play.pause(); play.resume(); play.advanceFrame()
        XCTAssertNil(play.linenWagon?.selected)
        for index in 0..<6 {
            let point = try XCTUnwrap(play.linenWagon).pieces[index].pageCenter
            play.holdLinenWagonTouch(x: point.x.rounded(), y: point.y.rounded())
            for _ in 0..<3 { play.advanceFrame() }
            XCTAssertEqual(play.linenWagon?.selected, index)
            play.holdLinenWagonTouch(x: 0, y: point.y.rounded())
            for _ in 0..<3 { play.advanceFrame() }
            play.releaseLinenWagonTouch()
            for _ in 0..<65 { play.advanceFrame() }
            XCTAssertEqual(play.linenWagon?.pieces[index].throwDirection, 10)
        }
        XCTAssertEqual(play.linenWagon?.allSheetsRemoved, true)
        play.holdLinenWagonTouch(x: 96, y: 170); play.advanceFrame(); play.releaseLinenWagonTouch()
        for _ in 0..<35 { play.advanceFrame() }
        play.holdLinenWagonTouch(x: 96, y: 110); play.advanceFrame(); play.releaseLinenWagonTouch()
        for _ in 0..<100 { play.advanceFrame() }
        XCTAssertEqual(play.linenWagon?.gunAlpha, 31)
        try screenshot("revealed")
        play.holdLinenWagonTouch(x: 110, y: 120); play.advanceFrame(); play.releaseLinenWagonTouch()
        XCTAssertEqual(play.linenWagon?.returnValue, 0)
        for _ in 0..<350 where play.linenWagon != nil { play.advanceFrame() }
        XCTAssertNil(play.linenWagon)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 36)), true)
        XCTAssertEqual(play.runner.session.selection.eventID, transition.eventID)
    }
}
