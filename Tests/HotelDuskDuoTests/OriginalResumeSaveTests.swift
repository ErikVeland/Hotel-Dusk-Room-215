import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

@MainActor
final class OriginalResumeSaveTests: XCTestCase {
    private final class MapRenderer: OriginalMapRendering {
        let map: CGImage
        init(_ name: String) throws {
            map = try XCTUnwrap(OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/\(name).bin").makeCGImage())
        }
        func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage { map }
    }
    private final class Store: OriginalResumeSaveStore {
        var checkpoint: OriginalResumeSave?
        var fails = false
        var writes = 0
        func load() throws -> OriginalResumeSave? { checkpoint }
        func save(_ checkpoint: OriginalResumeSave) throws {
            if fails { throw OriginalDataError.invalid("Disk unavailable") }
            self.checkpoint = checkpoint
            writes += 1
        }
    }

    private final class ChapterStore: OriginalChapterSaveStore {
        var slots: [Int: OriginalChapterSave] = [:]
        var writes = 0
        func load(slot: Int) throws -> OriginalChapterSave? { slots[slot] }
        func save(_ checkpoint: OriginalChapterSave, slot: Int) throws {
            slots[slot] = checkpoint
            writes += 1
        }
    }

    private func session(_ store: any OriginalResumeSaveStore = Store(), safePlaceStore: any OriginalResumeSaveStore = Store(), chapterStore: any OriginalChapterSaveStore = ChapterStore()) -> GameSession {
        let audio = AudioController(musicOutputFactory: { _, _, _ in ProgressMusicOutput() })
        audio.isMuted = true
        return GameSession(audioController: audio, saveStore: chapterStore, resumeStore: store, safePlaceStore: safePlaceStore,
            mapRendererFactory: { name, _ in try MapRenderer(name) })
    }

    private func enterLobby(_ session: GameSession) throws -> OriginalPlaySession {
        session.startOriginalGame()
        let play = try XCTUnwrap(session.play)
        for _ in 0..<1200 {
            switch play.runner.phase {
            case .dialogue: play.advanceDialogue()
            case .process(56):
                if play.entrance?.awaitingHandle == true { play.touchEntrance(pageX: 92, pageY: 175) }
                play.advanceFrame()
            case .waiting: play.advanceFrame()
            case .exploration:
                XCTAssertNotNil(play.lobby)
                return play
            default: XCTFail("Opening stopped at \(play.runner.phase)"); return play
            }
        }
        XCTFail("Opening did not finish")
        return play
    }

    func testLegacyDialogueCheckpointRestoresBeforeItsOriginalContinue() throws {
        let audio = originalRouteTestAudio()
        audio.restoresLegacyInteractions = true
        let play = try OriginalPlaySession.chapterOne(audio: audio, timestamp: 123)
        audio.restoresLegacyInteractions = false
        defer { play.stop() }
        let checkpoint = try play.progressCheckpoint()
        var journal = try XCTUnwrap(checkpoint.progress)
        journal.qualityOfLifeVersion = nil
        let legacy = try OriginalResumeSave(game: checkpoint.gameState(),
            checkpointFacing: checkpoint.checkpointFacing, musicSequenceID: checkpoint.musicSequenceID,
            savedAt: checkpoint.savedAt, progress: journal)
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(OriginalResumeSave.self, from: data)
        XCTAssertNil(decoded.progress?.qualityOfLifeVersion)
        let restored = try OriginalPlaySession.restoring(decoded, audio: originalRouteTestAudio(), saveStore: ChapterStore())
        defer { restored.stop() }
        XCTAssertEqual(restored.runner.phase, play.runner.phase)
        XCTAssertEqual(restored.runner.game.bytes, play.runner.game.bytes)
    }

    func testFreshSessionRestoresPositionAndContinuesWithoutReplayingArrival() throws {
        let store = Store()
        let first = session(store)
        defer { first.endOriginalGame() }
        let play = try enterLobby(first)
        play.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<80 { play.advanceFrame() }
        play.releaseLobbyTouch()
        let checkpoint = try XCTUnwrap(store.checkpoint)
        let liveBytes = play.runner.game.bytes
        XCTAssertEqual(try checkpoint.gameState().previousMapID, 1)
        XCTAssertEqual(try checkpoint.gameState().mapPosition, play.lobby?.position)
        first.openPauseMenu()
        let fresh = session(store)
        defer { fresh.endOriginalGame() }
        fresh.continueSavedGame()
        let restored = try XCTUnwrap(fresh.play)
        XCTAssertEqual(restored.runner.phase, .exploration(mapID: 2))
        XCTAssertTrue(restored.runner.eventTrail.isEmpty)
        XCTAssertEqual(restored.lobby?.position, play.lobby?.position)
        XCTAssertEqual(restored.lobby?.facing, play.lobby?.facing)
        XCTAssertEqual(restored.lobby?.checkpointFacing, play.lobby?.checkpointFacing)
        XCTAssertEqual(play.runner.game.bytes, liveBytes, "Saving must not alter the live reference state")
        first.closePauseMenu()
        for current in [play, restored] {
            current.holdLobbyTouch(x: 140, y: 80)
            for _ in 0..<80 { current.advanceFrame() }
            current.holdLobbyTouch(x: 70, y: 75)
            for _ in 0..<46 { current.advanceFrame() }
            current.releaseLobbyTouch()
            current.inspectLobbyCounter()
            current.panLobbyCounter(0)
            current.selectLobbyObject(x: 126, y: 195)
            current.confirmLobbyObject()
            current.advanceDialogue()
            XCTAssertEqual(current.runner.phase, .process(id: 24))
        }
        XCTAssertEqual(restored.runner.eventTrail, Array(play.runner.eventTrail.suffix(restored.runner.eventTrail.count)))
        XCTAssertEqual(restored.lobby?.position, play.lobby?.position)
    }

    func testReloadLiveSessionKeepsRestoredWalkingMusic() throws {
        let store = Store()
        let game = session(store)
        defer { game.endOriginalGame() }
        let previous = try enterLobby(game)
        XCTAssertEqual(game.audioController.currentSequenceID, 17)
        game.continueSavedGame()
        XCTAssertTrue(previous.isPaused)
        XCTAssertNotNil(game.play)
        XCTAssertEqual(game.audioController.currentSequenceID, 17)
        XCTAssertNil(game.audioController.lastError)
    }

    func testRecoverableStopReturnsToLastSafeWalkingPlace() throws {
        let safePlaceStore = Store()
        let game = session(safePlaceStore: safePlaceStore)
        defer { game.endOriginalGame() }
        let play = try enterLobby(game)
        let checkpoint = try XCTUnwrap(safePlaceStore.checkpoint)
        let position = play.lobby?.position

        game.recoverFromStop(.init(reason: "Test halt", program: "fixture", eventIndex: 3, sourceOffset: nil))

        let restored = try XCTUnwrap(game.play)
        XCTAssertEqual(restored.runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(restored.lobby?.position, position)
        XCTAssertEqual(game.play?.runner.game.bytes, try checkpoint.gameState().bytes)
        XCTAssertEqual(game.play?.lobby?.checkpointFacing, checkpoint.checkpointFacing)
        XCTAssertTrue(game.recoveryNotice?.contains("last safe place") == true)
    }

    func testPausedPlayerCanReturnToLastSafePlaceFromAnActiveInteraction() throws {
        let resumeStore = Store(), safePlaceStore = Store()
        let game = session(resumeStore, safePlaceStore: safePlaceStore)
        defer { game.endOriginalGame() }
        let play = try enterLobby(game)
        play.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<160 { play.advanceFrame() }
        play.holdLobbyTouch(x: 70, y: 75)
        for _ in 0..<46 { play.advanceFrame() }
        play.releaseLobbyTouch()
        let checkpoint = try XCTUnwrap(safePlaceStore.checkpoint)
        let safePosition = play.lobby?.position
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.mode, .counter)

        game.openPauseMenu()
        XCTAssertTrue(game.canReturnToSafePlace)
        game.returnToSafePlace()

        let restored = try XCTUnwrap(game.play)
        XCTAssertEqual(restored.runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(restored.lobby?.position, safePosition)
        XCTAssertEqual(try resumeStore.checkpoint?.gameState().bytes, try checkpoint.gameState().bytes)
        XCTAssertFalse(game.isPauseMenuOpen)
        XCTAssertTrue(game.recoveryNotice?.contains("unfinished interaction") == true)
    }

    func testRecoverableStopWithoutSafePlaceStartsChapterOne() throws {
        let game = session()
        defer { game.endOriginalGame() }

        game.recoverFromStop(.init(reason: "Test halt", program: "fixture", eventIndex: 3, sourceOffset: nil))

        let play = try XCTUnwrap(game.play)
        if case .halted = play.runner.phase { XCTFail("Chapter 1 fallback must not remain halted") }
        XCTAssertEqual(play.runner.game.chapter, 0)
        XCTAssertTrue(game.recoveryNotice?.contains("beginning") == true)
    }

    func testInspectionCannotReplaceLastWalkingCheckpoint() throws {
        let store = Store(), game = session()
        defer { game.endOriginalGame() }
        let play = try enterLobby(game)
        play.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<160 { play.advanceFrame() }
        play.holdLobbyTouch(x: 70, y: 75)
        for _ in 0..<46 { play.advanceFrame() }
        play.releaseLobbyTouch()
        let checkpoint = try play.walkingCheckpoint()
        try store.save(checkpoint)
        play.onWalkingCheckpoint = { try? store.save($0) }
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.mode, .counter)
        XCTAssertFalse(play.canSaveWalkingCheckpoint)
        XCTAssertThrowsError(try play.walkingCheckpoint())
        play.pause()
        XCTAssertEqual(store.checkpoint, checkpoint)
    }

    func testFirstPersonInputStopsOnReleaseAndPauseAndSavesHeading() throws {
        let game = session()
        defer { game.endOriginalGame() }
        let play = try enterLobby(game)
        let initial = try XCTUnwrap(play.lobby)
        play.turnFirstPerson(by: -0.3)
        XCTAssertEqual(play.lobby?.position, initial.position)
        play.holdFirstPersonMovement(strafe: 0, forward: 1)
        play.advanceFrame()
        XCTAssertNotEqual(play.lobby?.position, initial.position)
        play.releaseLobbyTouch()
        let released = play.lobby?.position
        play.advanceFrame()
        XCTAssertEqual(play.lobby?.position, released)
        play.holdFirstPersonMovement(strafe: 1, forward: 0)
        game.openPauseMenu()
        let heading = play.lobby?.facing
        play.turnFirstPerson(by: 1)
        play.holdFirstPersonMovement(strafe: 0, forward: 1)
        game.closePauseMenu()
        play.advanceFrame()
        XCTAssertEqual(play.lobby?.position, released)
        XCTAssertEqual(play.lobby?.facing, heading)
        let checkpoint = try play.walkingCheckpoint()
        XCTAssertEqual(try checkpoint.gameState().facing, heading)
    }

    func testMenuBackgroundAndHingePauseReasonsDoNotCancelEachOther() throws {
        let game = session()
        defer { game.endOriginalGame() }
        let play = try enterLobby(game)
        game.openPauseMenu()
        let position = play.lobby?.position
        game.hingeManager.setHingeAngle(0)
        game.hingeManager.setHingeAngle(110)
        play.holdLobbyTouch(x: 140, y: 80)
        play.advanceFrame()
        XCTAssertEqual(play.lobby?.position, position)
        game.setApplicationActive(false)
        game.closePauseMenu()
        play.holdLobbyTouch(x: 140, y: 80)
        play.advanceFrame()
        XCTAssertEqual(play.lobby?.position, position)
        game.setApplicationActive(true)
        play.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<20 { play.advanceFrame() }
        XCTAssertNotEqual(play.lobby?.position, position)
        game.setApplicationActive(false)
        let stopped = play.lobby?.position
        game.setApplicationActive(true)
        play.advanceFrame()
        XCTAssertEqual(play.lobby?.position, stopped, "Resuming must release a held movement")
    }

    func testFailedAutosaveRetainsPreviousCheckpointAndCanRetry() throws {
        let store = Store(), game = session()
        defer { game.endOriginalGame() }
        let play = try enterLobby(game)
        let checkpoint = try play.walkingCheckpoint()
        try store.save(checkpoint)
        let saving = session(store)
        defer { saving.endOriginalGame() }
        saving.continueSavedGame()
        let current = try XCTUnwrap(saving.play)
        let previousCheckpoint = store.checkpoint
        store.fails = true
        current.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<20 { current.advanceFrame() }
        current.releaseLobbyTouch()
        XCTAssertNotNil(saving.saveError)
        XCTAssertEqual(store.checkpoint, previousCheckpoint)
        store.fails = false
        saving.saveWalkingProgress()
        XCTAssertNil(saving.saveError)
        XCTAssertNotEqual(store.checkpoint?.state, checkpoint.state)
        let writes = store.writes
        saving.saveWalkingProgress()
        XCTAssertEqual(store.writes, writes, "Unchanged checkpoints should not write again")
    }

    func testAtomicFileRoundTripAndChecksumRejection() throws {
        let game = session()
        defer { game.endOriginalGame() }
        let checkpoint = try enterLobby(game).walkingCheckpoint()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OriginalResumeFileStore(directory: directory)
        XCTAssertNil(try store.load())
        try store.save(checkpoint)
        XCTAssertEqual(try OriginalResumeFileStore(directory: directory).load(), checkpoint)
        var record = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
        record["stateSHA256"] = "damaged"
        try JSONSerialization.data(withJSONObject: record).write(to: directory.appendingPathComponent("resume.json"))
        XCTAssertThrowsError(try store.load())
    }
    private func assertRestores(_ game: GameSession, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(game.saveWalkingProgress(), game.saveError ?? "Save failed", file: file, line: line)
        let checkpoint = try XCTUnwrap(game.resumeSave, file: file, line: line)
        let original = try XCTUnwrap(game.play, file: file, line: line)
        let store = Store()
        store.checkpoint = try JSONDecoder().decode(OriginalResumeSave.self, from: JSONEncoder().encode(checkpoint))
        let fresh = session(store)
        defer { fresh.endOriginalGame() }
        fresh.continueSavedGame()
        XCTAssertNil(fresh.saveError, file: file, line: line)
        let restored = try XCTUnwrap(fresh.play, fresh.saveError ?? "No restored play", file: file, line: line)
        XCTAssertEqual(restored.runner.phase, original.runner.phase, file: file, line: line)
        XCTAssertEqual(Data(restored.runner.game.bytes), checkpoint.state, file: file, line: line)
        XCTAssertEqual(restored.entrance, original.entrance, file: file, line: line)
        XCTAssertEqual(restored.bell, original.bell, file: file, line: line)
        XCTAssertEqual(restored.sign, original.sign, file: file, line: line)
        XCTAssertEqual(restored.jigsaw, original.jigsaw, file: file, line: line)
        XCTAssertEqual(restored.chapterTransition?.stage, original.chapterTransition?.stage, file: file, line: line)
        XCTAssertEqual(restored.lobby?.mode, original.lobby?.mode, file: file, line: line)
        XCTAssertEqual(restored.dialogueNotebook.savedState(), original.dialogueNotebook.savedState(), file: file, line: line)
    }

    func testEveryOpeningStepSurvivesASeparateSession() throws {
        let game = session()
        defer { game.endOriginalGame() }
        game.startOriginalGame()
        let play = try XCTUnwrap(game.play)
        try assertRestores(game)
        for _ in 0..<20 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
            try assertRestores(game)
        }
        XCTAssertEqual(play.runner.phase, .process(id: 56))
        for _ in 0..<90 { play.advanceFrame() }
        try assertRestores(game)
        for _ in 0..<1000 {
            switch play.runner.phase {
            case .process(56):
                if play.entrance?.awaitingHandle == true { play.touchEntrance(pageX: 92, pageY: 175) }
                play.advanceFrame()
            case .dialogue: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: break
            }
            if case .exploration = play.runner.phase { break }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        try assertRestores(game)
        play.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<160 { play.advanceFrame() }
        play.holdLobbyTouch(x: 70, y: 75)
        for _ in 0..<46 { play.advanceFrame() }
        play.releaseLobbyTouch()
        play.inspectLobbyCounter()
        try assertRestores(game)
        play.panLobbyCounter(0)
        play.selectLobbyObject(x: 126, y: 195, confirmImmediately: true)
        try assertRestores(game)
        play.advanceDialogue()
        for _ in 0..<80 { play.advanceFrame() }
        XCTAssertEqual(play.bell?.awaitingTouch, true)
        try assertRestores(game)
        for _ in 0..<3 {
            play.touchEntrance(pageX: 96, pageY: 75)
            for _ in 0..<12 { play.advanceFrame() }
            try assertRestores(game)
        }
        for _ in 0..<400 { play.advanceFrame() }
        var signed = false
        for _ in 0..<600 {
            switch play.runner.phase {
            case .dialogue, .itemNotice:
                play.advanceDialogue()
                try assertRestores(game)
            case .choice(let options):
                play.choose(try XCTUnwrap(options.first).id)
                try assertRestores(game)
            case .questions(let topics):
                if let topic = topics.first { play.ask(topic.keyword) }
                else { play.leaveConversation() }
                try assertRestores(game)
            case .waiting: play.advanceFrame()
            case .picture:
                play.activatePicture(pageX: 96, pageY: 215)
                for _ in 0..<10 { play.advanceFrame() }
                try assertRestores(game)
                for _ in 0..<12 { play.advanceFrame() }
            case .process(25):
                for _ in 0..<40 { play.advanceFrame() }
                for row in [100, 140, 175, 200] {
                    play.holdTouch(pageX: 60, pageY: row)
                    play.advanceFrame()
                    play.holdTouch(pageX: 70, pageY: row)
                    play.advanceFrame()
                    play.releaseTouch()
                    try assertRestores(game)
                    for _ in 0..<300 { play.advanceFrame() }
                }
                signed = true
            case .exploration(2):
                XCTAssertTrue(signed)
                try assertRestores(game)
                return
            default: return XCTFail("Unexpected opening phase: \(play.runner.phase)")
            }
        }
        XCTFail("Registration did not finish")
    }

    func testBackgroundPreservesWrittenInkAndReadingPosition() throws {
        let store = Store()
        let game = session(store)
        defer { game.endOriginalGame() }
        _ = try enterLobby(game)
        let book = try XCTUnwrap(game.play).dialogueNotebook
        let size = CGSize(width: 140, height: 115)
        XCTAssertFalse(book.ink.isEmpty)
        book.configure(DialogueNotebookLayout(runs: book.ink, size: size, fontSize: 18))
        book.write(count: 12)
        let before = book.reader
        let ink = book.ink
        game.setApplicationActive(false)
        let fresh = session(store)
        defer { fresh.endOriginalGame() }
        fresh.continueSavedGame()
        let restored = try XCTUnwrap(fresh.play, fresh.saveError ?? "Resume failed").dialogueNotebook
        restored.configure(DialogueNotebookLayout(runs: restored.ink, size: size, fontSize: 18))
        XCTAssertEqual(restored.ink, ink)
        XCTAssertEqual(restored.reader, before)
    }

    func testFailedSaveKeepsLiveGameWhenReturningToTitle() throws {
        let store = Store()
        let game = session(store)
        game.startOriginalGame()
        let play = try XCTUnwrap(game.play)
        let previous = store.checkpoint
        store.fails = true
        play.advanceDialogue()
        game.endOriginalGame()
        XCTAssertNotNil(game.play)
        XCTAssertTrue(game.isPauseMenuOpen)
        XCTAssertNotNil(game.saveError)
        XCTAssertEqual(store.checkpoint, previous)
        store.fails = false
        game.endOriginalGame()
        XCTAssertNil(game.play)
        XCTAssertNil(game.saveError)
        XCTAssertNotEqual(store.checkpoint, previous)
    }

    func testInteractionChecksumRejectsAlteredInputs() throws {
        let game = session()
        defer { game.endOriginalGame() }
        game.startOriginalGame()
        let checkpoint = try XCTUnwrap(game.resumeSave)
        var record = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
        record["progressSHA256"] = "damaged"
        let damaged = try JSONDecoder().decode(OriginalResumeSave.self, from: JSONSerialization.data(withJSONObject: record))
        XCTAssertThrowsError(try damaged.gameState())
    }

    func testRandomisedJigsawRotationAndHeldInputResumeExactly() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: catalog, defaults: .bundled(), timestamp: 100)
        for _ in 0..<600 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .process: runner.finishProcess(returnValue: 0)
            case .picture: runner.finishPicture()
            case .waiting: runner.advanceWait()
            case .choice(let choices): runner.choose(try XCTUnwrap(choices.first).id)
            case .questions(let topics):
                if let topic = topics.first { runner.ask(topic.keyword) }
                else { runner.leave() }
            case .exploration:
                if (0...2).allSatisfy({ runner.game.keywordUsed($0) }) { break }
                runner.lookInSearchView(area: 2, subarea: 2, table: try .bundled(map: "R102"))
            case .halted: return XCTFail("Could not construct the walking test fixture")
            }
            if case .exploration = runner.phase,
               (0...2).allSatisfy({ runner.game.keywordUsed($0) }) { break }
        }
        var state = runner.game
        state.setMap(17, previous: 3)
        state.setMapPosition(.init(6636, 12288, 4014), facing: -1.572017)
        let store = Store()
        store.checkpoint = try OriginalResumeSave(game: state, checkpointFacing: -1.572017,
            musicSequenceID: nil, savedAt: Date(timeIntervalSince1970: 100))
        let game = session(store)
        defer { game.endOriginalGame() }
        game.continueSavedGame()
        let play = try XCTUnwrap(game.play)
        for _ in 0..<2 {
            play.holdLobbyTouch(x: 96, y: 45)
            for _ in 0..<140 {
                guard case .exploration = play.runner.phase else { break }
                play.advanceFrame()
            }
            for _ in 0..<100 {
                guard case .dialogue = play.runner.phase else { break }
                play.advanceDialogue()
            }
        }
        guard case .questions = play.runner.phase else { return XCTFail("Expected Melissa's puzzle question") }
        play.ask(8)
        for _ in 0..<100 {
            guard case .dialogue = play.runner.phase else { break }
            if play.runner.eventIndex == 41, play.runner.interruptAvailable {
                play.interrupt()
                break
            }
            play.advanceDialogue()
        }
        for _ in 0..<20 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        play.choose(22)
        for _ in 0..<100 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        for _ in 0..<4 { play.advanceFrame() }
        XCTAssertEqual(play.runner.phase, .process(id: 26))
        XCTAssertEqual(play.jigsaw?.placedCount, 15)
        try assertRestores(game)
        let piece = try XCTUnwrap(play.jigsaw?.pieces[3])
        let centre = OriginalJigsawProjection.centre(piece)
        play.dragJigsaw(pageX: centre.x, pageY: centre.y)
        play.releaseJigsaw()
        play.rotateJigsaw(increasing: true)
        for _ in 0..<6 { play.advanceFrame() }
        try assertRestores(game)
        play.receiveJigsawFold(isClosed: true)
        try assertRestores(game)
        play.receiveJigsawFold(isClosed: false)
        try assertRestores(game)
    }

    func testEverySimulationStepIsImmediatelyReadableFromDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OriginalResumeFileStore(directory: directory)
        let game = session(store)
        defer { game.endOriginalGame() }
        game.startOriginalGame()
        let play = try XCTUnwrap(game.play)
        for _ in 0..<20 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        XCTAssertEqual(play.runner.phase, .process(id: 56))
        for frame in 0..<160 {
            play.advanceFrame()
            if frame < 12 || frame % 16 == 0 || frame == 159 {
                let disk = try XCTUnwrap(OriginalResumeFileStore(directory: directory).load())
                let current = try play.progressCheckpoint()
                XCTAssertEqual(disk.stateSHA256, current.stateSHA256, "Simulation step \(frame)")
                XCTAssertEqual(disk.progress, current.progress, "Simulation step \(frame)")
            }
        }
        let last = try XCTUnwrap(store.load())
        let log = directory.appendingPathComponent("resume.steps")
        let size = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: log.path)[.size] as? NSNumber)
        XCTAssertGreaterThan(size.intValue, 0)
        let handle = try FileHandle(forWritingTo: log)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"baseID\":\"interrupted".utf8))
        try handle.close()
        XCTAssertEqual(try OriginalResumeFileStore(directory: directory).load(), last,
            "An interrupted final write must retain every preceding complete step")
        play.advanceFrame()
        XCTAssertEqual(try OriginalResumeFileStore(directory: directory).load()?.progress,
            try play.progressCheckpoint().progress, "A new step must repair the incomplete tail")
    }

    func testNativeNotebookInkSurvivesInstantSaveAndReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OriginalResumeFileStore(directory: directory)
        let game = session(store)
        defer { game.endOriginalGame() }
        let play = try enterLobby(game)
        play.openNotebook()
        XCTAssertEqual(play.notebook?.page, 0)
        var packed = Data(repeating: 0, count: OriginalNotebook.packedSize)
        packed[123] = 0x48
        let drawing = Data("native ink one".utf8)
        play.setNativeNotebookInk(page: 0, drawing: drawing, packed: packed)
        let saved = try XCTUnwrap(OriginalResumeFileStore(directory: directory).load())
        XCTAssertEqual(saved.progress?.nativeNotebookPages?["0"], drawing)
        let fresh = session(store)
        defer { fresh.endOriginalGame() }
        fresh.continueSavedGame()
        let restored = try XCTUnwrap(fresh.play, fresh.saveError ?? "No restored session")
        XCTAssertEqual(restored.nativeNotebookPages["0"], drawing)
        XCTAssertEqual(restored.notebook?.pixels, OriginalNotebook.unpack(Array(packed)))
        restored.closeNotebook()
        restored.openNotebook()
        XCTAssertEqual(restored.nativeNotebookPages["0"], drawing)
        XCTAssertEqual(restored.notebook?.pixels, OriginalNotebook.unpack(Array(packed)))
        XCTAssertEqual(try OriginalResumeFileStore(directory: directory).load()?.progress?.nativeNotebookPages?["0"], drawing)
    }

    func testEveryWritingUpdateIsSavedWithoutPausing() throws {
        let store = Store()
        let game = session(store)
        defer { game.endOriginalGame() }
        _ = try enterLobby(game)
        let book = try XCTUnwrap(game.play).dialogueNotebook
        XCTAssertFalse(book.ink.isEmpty)
        book.configure(DialogueNotebookLayout(runs: book.ink, size: CGSize(width: 240, height: 300), fontSize: 18))
        for _ in 0..<12 {
            book.write(count: 1)
            XCTAssertEqual(store.checkpoint?.progress?.notebook?.revealedEnd, book.reader.revealedEnd)
        }
        XCTAssertGreaterThan(store.writes, 12)
    }

    func testChapterTitlesUseInstantSavesAndRecallWithoutManualSlots() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var state = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 100)
        state.setMap(31, previous: 31)
        try state.beginChapter(1)
        let checkpoint = try OriginalChapterSave(game: state, savedAt: Date(timeIntervalSince1970: 100))
        let chapters = ChapterStore()
        chapters.slots[0] = checkpoint
        let game = session(Store(), chapterStore: chapters)
        defer { game.endOriginalGame() }
        game.loadChapterSave(slot: 0)
        let play = try XCTUnwrap(game.play)
        XCTAssertTrue(play.usesInstantSaves)
        XCTAssertEqual(play.chapterTransition?.stage, .title)
        try assertRestores(game)
        play.continueChapterTitle()
        try assertRestores(game)
        XCTAssertEqual(chapters.writes, 0)
        let audio = AudioController(musicOutputFactory: { _, _, _ in ProgressMusicOutput() })
        audio.isMuted = true
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP2_R205"), game: state, deferArrival: true)
        let transition = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            saveStore: chapters, chapterTransition: OriginalChapterTransition())
        defer { transition.stop() }
        transition.enableInstantSaves()
        XCTAssertEqual(transition.chapterTransition?.stage, .title)
        XCTAssertEqual(chapters.writes, 0)
    }

    func testConversationReviewRecallsItsPageAndTheLiveBookmark() throws {
        let store = Store()
        let game = session(store)
        defer { game.endOriginalGame() }
        _ = try enterLobby(game)
        let book = try XCTUnwrap(game.play).dialogueNotebook
        let size = CGSize(width: 60, height: 60)
        book.configure(DialogueNotebookLayout(runs: book.ink, size: size, fontSize: 18))
        book.finishWriting()
        XCTAssertTrue(book.canTurnForward)
        book.turnForward()
        book.finishTurn(revision: book.turnRevision)
        let live = book.reader
        game.reviewConversations()
        XCTAssertTrue(game.isReviewingConversations)
        book.turnBack()
        book.finishTurn(revision: book.turnRevision)
        let reviewed = book.reader
        let fresh = session(store)
        defer { fresh.endOriginalGame() }
        fresh.continueSavedGame()
        XCTAssertTrue(fresh.isReviewingConversations)
        let restored = try XCTUnwrap(fresh.play, fresh.saveError ?? "Review recall failed").dialogueNotebook
        restored.configure(DialogueNotebookLayout(runs: restored.ink, size: size, fontSize: 18))
        XCTAssertEqual(restored.reader, reviewed)
        fresh.closeConversationHistory()
        XCTAssertEqual(restored.reader, live)
    }

    func testInstantLogRejectsCorruptionInACompleteStep() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OriginalResumeFileStore(directory: directory)
        let game = session(store)
        defer { game.endOriginalGame() }
        game.startOriginalGame()
        let play = try XCTUnwrap(game.play)
        for _ in 0..<10 { play.advanceFrame() }
        let file = directory.appendingPathComponent("resume.steps")
        let lines = try Data(contentsOf: file).split(separator: 10)
        XCTAssertFalse(lines.isEmpty)
        var replacement = Data()
        for (index, line) in lines.enumerated() {
            if index == lines.count - 1 {
                var record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line)) as? [String: Any])
                record["progressSHA256"] = String(repeating: "0", count: 64)
                replacement.append(try JSONSerialization.data(withJSONObject: record))
            } else { replacement.append(contentsOf: line) }
            replacement.append(10)
        }
        try replacement.write(to: file)
        XCTAssertThrowsError(try OriginalResumeFileStore(directory: directory).load())
    }

}
