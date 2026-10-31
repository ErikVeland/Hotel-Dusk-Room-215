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

    func testProcess64ReturnsToChapterNineAfterAPlayerFindsTheLetter() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP9_R117")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 84 })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 11)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog)
        defer { play.stop() }

        play.touchApplePainting(pageX: 82, pageY: 157)
        XCTAssertEqual(play.applePainting?.phase, .revealed("J"))
        play.acknowledgeApplePaintingLetter()

        XCTAssertNil(play.applePainting)
        XCTAssertEqual(play.runner.game.applePaintingFoundMask, 1)
        XCTAssertNotEqual(play.runner.phase, .process(id: 64))
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    func testChapterNineAppleProcessSequenceCarriesAllLettersIntoWordEntry() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let calls: [(program: String, offset: Int, mapID: Int16,
                     touch: SIMD2<Int>, successEventID: UInt16)] = [
            ("EP9_R117", 84, 11, SIMD2(82, 157), 2),
            ("EP9_R125", 104, 39, SIMD2(67, 163), 3),
            ("EP9_R205", 248, 17, SIMD2(119, 151), 5),
            ("EP9_R207", 84, 33, SIMD2(109, 113), 4),
            ("EP9_R213", 84, 31, SIMD2(118, 113), 4)
        ]
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)

        for (index, call) in calls.enumerated() {
            let play = try makeAlphabetSession(
                catalog: catalog, game: game, programName: call.program,
                sourceOffset: call.offset, processID: 64, mapID: call.mapID)
            XCTAssertEqual(play.runner.phase, .process(id: 64))
            XCTAssertEqual(play.applePainting?.paintingIndex, index)

            let foundPoint = (call.touch.x - 1...call.touch.x + 1).contains { pageX in
                (call.touch.y - 1...call.touch.y + 1).contains { pageY in
                    play.touchApplePainting(pageX: pageX, pageY: pageY)
                    return play.applePainting?.phase == .revealed(
                        Array(OriginalApplePaintingSearch.targetWord)[index])
                }
            }
            XCTAssertTrue(foundPoint, "Painting (index + 1) must reveal its source letter")
            play.acknowledgeApplePaintingLetter()
            game = play.runner.game
            XCTAssertEqual(game.applePaintingFoundMask, UInt16((1 << (index + 1)) - 1))
            XCTAssertEqual(game.appleNotebookPageMask, game.applePaintingFoundMask)
            XCTAssertEqual(play.runner.session.selection.eventID, call.successEventID)
            XCTAssertNotEqual(play.runner.phase, .process(id: 64))
            if case .halted(let halt) = play.runner.phase {
                XCTFail("Painting call \(call.program):\(call.offset) halted: \(halt.reason)")
            }
            play.stop()
        }

        let wordPlay = try makeAlphabetSession(
            catalog: catalog, game: game, programName: "EP9_R125",
            sourceOffset: 164, processID: 81, mapID: 39)
        defer { wordPlay.stop() }
        XCTAssertEqual(wordPlay.runner.phase, .process(id: 81))
        XCTAssertNotNil(wordPlay.appleWordEntry)

        for index in OriginalAppleWordEntryProcess.letters.indices {
            wordPlay.selectAppleWordLetter(at: index)
        }

        XCTAssertNil(wordPlay.appleWordEntry)
        XCTAssertEqual(wordPlay.runner.session.selection.eventID, 6)
        XCTAssertNotEqual(wordPlay.runner.phase, .process(id: 81))
        if case .halted(let halt) = wordPlay.runner.phase {
            XCTFail("Word-entry call halted: \(halt.reason)")
        }
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

    func testProcess63ReturnsToChapterNineAfterCloseAndFullReopen() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP9_R116")
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 304 })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog)
        defer { play.stop() }

        play.receiveCPRFold(isClosed: true, isFullyOpen: false)
        XCTAssertEqual(play.cpr?.phase, .awaitingReopen)
        play.receiveCPRFold(isClosed: false, isFullyOpen: true)

        XCTAssertNil(play.cpr)
        XCTAssertNotEqual(play.runner.phase, .process(id: 63))
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    private func makeAlphabetSession(catalog: OriginalScriptCatalog,
                                     game initialGame: OriginalGameState,
                                     programName: String,
                                     sourceOffset: Int,
                                     processID: UInt16,
                                     mapID: Int16) throws -> OriginalPlaySession {
        let program = try catalog.loadProgram(programName)
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            $0.sourceOffset == sourceOffset
        })
        XCTAssertEqual(try OriginalEventCompletion.embeddedProcessID(event: event), processID)
        var game = initialGame
        game.setMap(mapID, previous: game.mapID)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: mapID)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        return OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
    }
}
