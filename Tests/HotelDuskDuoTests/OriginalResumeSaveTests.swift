import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalResumeSaveTests: XCTestCase {
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
        func load(slot: Int) throws -> OriginalChapterSave? { nil }
        func save(_ checkpoint: OriginalChapterSave, slot: Int) throws {}
    }

    private func session(_ store: Store = Store()) -> GameSession {
        let audio = AudioController()
        audio.isMuted = true
        return GameSession(audioController: audio, saveStore: ChapterStore(), resumeStore: store)
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
        store.fails = true
        current.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<20 { current.advanceFrame() }
        current.releaseLobbyTouch()
        XCTAssertNotNil(saving.saveError)
        XCTAssertEqual(store.checkpoint, checkpoint)
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
}
