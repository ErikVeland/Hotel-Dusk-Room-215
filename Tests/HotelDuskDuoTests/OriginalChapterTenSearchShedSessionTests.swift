import XCTest
import Metal
@testable import HotelDuskDuoKit

final class OriginalChapterTenSearchShedSessionTests: XCTestCase {
    func testR304SearchShedTransitionTableHasOnlyReturnZero() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP10_R304")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 79
        })
        let validResults = (0...3).compactMap { result -> Int16? in
            guard case .completed = try? OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: program.conditions, processReturn: Int16(result)) else { return nil }
            return Int16(result)
        }

        XCTAssertEqual(validResults, [0])
    }

    @MainActor
    func testChapterTenSearchShedUsesOverlayFortyHandler() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R304")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 79
        })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(43, previous: 42)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 43)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        audio.isMuted = true
        _ = try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 79))
        XCTAssertEqual(play.searchShed?.objects.count, 26)
        XCTAssertEqual(play.searchShedImage?.width, 192)
        XCTAssertEqual(play.searchShedImage?.height, 256)
    }
}
