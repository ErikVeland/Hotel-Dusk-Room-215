import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalPencilSharpenerSessionTests: XCTestCase {
    func testChapterTenProcess59StartsTheFactoryMappedPencilSharpener() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 440 })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, OriginalEventRunner.Phase.process(id: 59))

        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertNotNil(play.pencilSharpener)
        XCTAssertEqual(play.pencilSharpenerImage?.width, 192)
        XCTAssertEqual(play.pencilSharpenerImage?.height, 256)
        XCTAssertNil(play.appleWordEntry)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    func testChapterTenProcess59ExitTouchReturnsThroughTheSession() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 440 })
        let returnPath = try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: program.conditions, processReturn: 2)
        guard case .completed(let completion) = returnPath,
              let transition = completion.transition else {
            return XCTFail("Pencil-sharpener result 2 must select its source event")
        }
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        play.tapPencilSharpener(pageX: 19, pageY: 15)
        for _ in 0..<OriginalPencilSharpenerProcess.exitAnimationFrames {
            play.advanceFrame()
        }

        XCTAssertNil(play.pencilSharpener)
        if case .process(59) = play.runner.phase { XCTFail("Pencil sharpener did not return") }
        XCTAssertEqual(play.runner.session.selection.eventID, transition.eventID)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    func testChapterNineProcess81StartsWordEntryAfterAllLettersAreFound() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP9_R125")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 164 })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.applePaintingFoundMask = 0x1f
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }

        XCTAssertNotNil(play.appleWordEntry)
        XCTAssertNil(play.pencilSharpener)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }
}
