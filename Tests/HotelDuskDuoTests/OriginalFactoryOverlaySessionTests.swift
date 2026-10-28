import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalFactoryOverlaySessionTests: XCTestCase {
    private func mutedAudio() -> AudioController {
        let audio = AudioController()
        audio.isMuted = true
        return audio
    }

    func testChapterTwoProcess34StartsThePointTieMemoOverlay() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP2_R115")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 648 })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 34))

        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertNotNil(play.memoDrawing)
        XCTAssertNil(play.applePainting)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    func testProcess64StartsTheApplePaintingOverlay() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP9_R117")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 84 })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 11)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 64))

        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertNotNil(play.applePainting)
        XCTAssertEqual(play.applePaintingImage?.width, 192)
        XCTAssertEqual(play.applePaintingImage?.height, 256)
        XCTAssertNil(play.memoDrawing)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    func testProcess63StartsTheChapterNineCPRInteraction() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP9_R116")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 304 })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 63))

        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertNotNil(play.cpr)
        XCTAssertNil(play.sign)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }
}
