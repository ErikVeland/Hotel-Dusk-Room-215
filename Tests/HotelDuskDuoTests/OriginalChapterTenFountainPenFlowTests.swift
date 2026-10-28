import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterTenFountainPenFlowTests: XCTestCase {
    @MainActor
    func testProcess74LoadsFountainPenAssetsFromItsFactoryGroup() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 74
        })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(40, previous: 39)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        _ = try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            puzzleSeed: { 0x00A7 })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 74))
        XCTAssertNotNil(play.fountainPen)
        XCTAssertEqual(play.fountainPenImage?.width, 192)
        XCTAssertEqual(play.fountainPenImage?.height, 256)
        XCTAssertNil(play.typewriter)
    }
}
