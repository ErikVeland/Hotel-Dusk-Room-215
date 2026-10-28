import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterTenPicturePeelFlowTests: XCTestCase {
    @MainActor
    func testProcess61StartsThePicturePeelOverlay() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R302")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 61
        })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(41, previous: 40)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 41)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 61))
        XCTAssertEqual(play.picturePeelImage?.width, 192)
        XCTAssertEqual(play.picturePeelImage?.height, 256)
        XCTAssertEqual(play.picturePeelUpperImage?.width, 192)
        XCTAssertEqual(play.picturePeelUpperImage?.height, 256)
        XCTAssertNil(play.typewriter)
    }
}
