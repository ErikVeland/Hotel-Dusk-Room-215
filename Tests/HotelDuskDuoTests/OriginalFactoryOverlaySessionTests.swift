import CoreGraphics
import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalFactoryOverlaySessionTests: XCTestCase {
    func testAllScriptProcessesHaveNativeHandlers() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let handledProcessIDs = Set<UInt16>([
            24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 38, 39, 40,
            41, 42, 43, 44, 45, 46, 47, 48, 51, 52, 53, 54, 55, 56, 57, 58,
            50, 59, 60, 61, 62, 63, 64, 67, 68, 69, 70, 71, 73, 74, 75, 76, 77, 78, 79, 80, 81,
            84, 85, 86, 87, 88, 89, 90, 91, 126
        ])
        var scriptProcessIDs = Set<UInt16>()
        for programName in catalog.programNames {
            let program = try catalog.loadProgram(programName)
            for event in try program.blocks.tables[2] {
                if let processID = try OriginalEventCompletion.embeddedProcessID(event: event) {
                    scriptProcessIDs.insert(processID)
                }
            }
        }

        XCTAssertFalse(scriptProcessIDs.isEmpty)
        let unrecoveredProcessIDs = scriptProcessIDs.subtracting(handledProcessIDs)
        XCTAssertTrue(unrecoveredProcessIDs.isEmpty,
                       "Update this audit when script processes change")
    }

    func testLoungeTVUsesRecoveredSystemResponsesAndReturnsToTheProcess() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("System")
        let event = try XCTUnwrap(try program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 50
        })
        let eventKey = UInt16(event.raw[4]) | (UInt16(event.raw[5]) << 8)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(0, previous: game.mapID)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: eventKey,
            nowTime: game.nowTime, mapID: 0)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection, scope: .system)
        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 50))
        XCTAssertNotNil(play.loungeTV)
        play.loungeTVAction(.cartoon)
        XCTAssertTrue(dialogueText(play.runner).contains("cartoon"))
        for _ in 0..<20 where play.loungeTV?.isWaitingForResponse == true {
            play.advanceDialogue()
        }
        XCTAssertEqual(play.runner.phase, .process(id: 50))
        XCTAssertFalse(play.loungeTV?.isWaitingForResponse ?? true)

        play.loungeTVAction(.news)
        XCTAssertTrue(dialogueText(play.runner).contains("news"))
        for _ in 0..<20 where play.loungeTV?.isWaitingForResponse == true {
            play.advanceDialogue()
        }
        XCTAssertEqual(play.runner.phase, .process(id: 50))

        play.loungeTVAction(.leave)
        XCTAssertNil(play.loungeTV)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 0))
    }

    func testCoinEdgeVariantsStartNativeProcesses() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("System")
        for processID in UInt16(68)...UInt16(71) {
            let event = try XCTUnwrap(try program.blocks.tables[2].first {
                try OriginalEventCompletion.embeddedProcessID(event: $0) == processID
            })
            let eventKey = UInt16(event.raw[4]) | (UInt16(event.raw[5]) << 8)
            var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
            game.setMap(0, previous: game.mapID)
            var selection = OriginalEventSelectionContext(
                sceneID: .max, blockID: 0, modeID: 15, eventID: eventKey,
                nowTime: game.nowTime, mapID: 0)
            selection.debugEventSelection = true
            let runner = try OriginalEventRunner(program: program, game: game, selection: selection, scope: .system)
            let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)))
            defer { play.stop() }

            XCTAssertEqual(play.coinEdgePuzzle?.variant.rawValue, Int16(processID))
            XCTAssertNotNil(play.coinEdgePuzzleImage)
            if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
        }
    }

    func testCoinEdgeSquareCanFinishThroughSessionTouchInput() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("System")
        let event = try XCTUnwrap(try program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 68
        })
        let eventKey = UInt16(event.raw[4]) | (UInt16(event.raw[5]) << 8)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(0, previous: game.mapID)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: eventKey,
            nowTime: game.nowTime, mapID: 0)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection, scope: .system)
        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        let removedEdges: [(Bool, Int, Int)] = [
            (true, 0, 0), (true, 1, 1), (true, 1, 2),
            (false, 0, 0), (false, 0, 2), (false, 1, 2)
        ]
        for (horizontal, row, column) in removedEdges {
            let x: Float
            let y: Float
            if horizontal {
                x = Float((6 + column * 6 + 3) * 8)
                y = Float((4 + row * 6 + 4) * 8 + 4)
            } else {
                x = Float((6 + column * 6 - 1) * 8 + 4)
                y = Float((4 + row * 6 + 5) * 8 + 20)
            }
            play.holdCoinPuzzleTouch(x: x, y: y)
            play.advanceFrame()
            for _ in 0..<40 { play.advanceFrame() }
            play.releaseCoinPuzzleTouch()
        }

        XCTAssertNil(play.coinEdgePuzzle)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    func testWrongCoinEdgeBoardReturnsWithoutHaltingTheGame() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("System")
        let event = try XCTUnwrap(try program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 68
        })
        let eventKey = UInt16(event.raw[4]) | (UInt16(event.raw[5]) << 8)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(0, previous: game.mapID)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: eventKey,
            nowTime: game.nowTime, mapID: 0)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection, scope: .system)
        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        for row in 0..<2 {
            for column in 0..<3 {
                let x = Float((6 + column * 6 + 3) * 8)
                let y = Float((4 + row * 6 + 4) * 8 + 4)
                play.holdCoinPuzzleTouch(x: x, y: y)
                play.advanceFrame()
                for _ in 0..<40 { play.advanceFrame() }
                play.releaseCoinPuzzleTouch()
            }
        }

        XCTAssertNil(play.coinEdgePuzzle)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 0))
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    func testProcess89StartsTheCassetteDeckSideBVariant() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("System")
        let event = try XCTUnwrap(try program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 89
        })
        let eventKey = UInt16(event.raw[4]) | (UInt16(event.raw[5]) << 8)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(0, previous: game.mapID)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: eventKey,
            nowTime: game.nowTime, mapID: 0)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection, scope: .system)
        XCTAssertEqual(runner.phase, .process(id: 89))

        let play = OriginalPlaySession(runner: runner, audio: mutedAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            cassetteDeckRendererFactory: { try CassetteDeckRendererStub() })
        defer { play.stop() }

        XCTAssertEqual(play.cassetteDeck?.variant, .sideB)
        XCTAssertEqual(play.cassetteDeck?.sourceMusicSequenceID, 0x59)
        XCTAssertEqual(play.runner.phase, .process(id: 89))
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    private final class CassetteDeckRendererStub: OriginalCassetteDeckRendering {
        private let image: CGImage

        init() throws {
            guard let image = CGContext(data: nil, width: 192, height: 256,
                bitsPerComponent: 8, bytesPerRow: 192 * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage() else {
                throw OriginalDataError.invalid("Cassette deck test image")
            }
            self.image = image
        }

        func render(camera: OriginalCassetteDeckCamera,
                    state: OriginalCassetteDeckProcess.SceneState) throws -> CGImage { image }

        func hasHit(pageX: Int, pageY: Int, camera: OriginalCassetteDeckCamera,
                    state: OriginalCassetteDeckProcess.SceneState) throws -> Bool { true }
    }

    private func mutedAudio() -> AudioController {
        let audio = AudioController()
        audio.isMuted = true
        return audio
    }

    private func dialogueText(_ runner: OriginalEventRunner) -> String {
        guard case .dialogue(let packet) = runner.phase else { return "" }
        return packet.pages.flatMap { OriginalDialogueLines(page: $0).lines }
            .flatMap { $0.map(\.text) }.joined(separator: " ")
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
        XCTAssertNotNil(play.applePaintingImage)
        XCTAssertEqual(play.applePaintingImage.map { Double($0.width) / Double($0.height) } ?? 0,
                       0.75, accuracy: 0.001)
        play.advanceFrame()
        XCTAssertEqual(play.runner.phase, .process(id: 64))
        XCTAssertNotNil(play.applePainting)
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
        wordPlay.advanceFrame()
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
        play.advanceFrame()
        XCTAssertEqual(play.runner.phase, .process(id: 63))
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
