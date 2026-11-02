import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalGameOverTests: XCTestCase {
    private final class ResumeStore: OriginalResumeSaveStore {
        var checkpoint: OriginalResumeSave?
        var writes = 0

        func load() throws -> OriginalResumeSave? { checkpoint }

        func save(_ checkpoint: OriginalResumeSave) throws {
            self.checkpoint = checkpoint
            writes += 1
        }
    }

    private func gameState(_ name: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
        let ram = try Data(contentsOf: path)
        return try OriginalGameState(snapshot: ram.subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func failedCrowbarPlay(audio: AudioController) throws -> (OriginalPlaySession, OriginalScriptCatalog) {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP2_R115"),
                                             game: gameState("chapter-two-crowbar-closeup/torn"))
        runner.useItemInCloseup(10, event: 125)
        for _ in 0..<30 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: break
            }
        }
        XCTAssertEqual(runner.phase, .process(id: 30))
        runner.finishCrowbar(returnValue: 3)
        var reachedGameOver = false
        for _ in 0..<200 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            case .exploration:
                reachedGameOver = runner.processRequests.contains(where: { $0.kind == 7 })
                if reachedGameOver { break }
            default: break
            }
            if reachedGameOver { break }
        }
        XCTAssertTrue(reachedGameOver)
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        return (play, catalog)
    }

    private func session(resumeStore: ResumeStore, audio: AudioController) -> GameSession {
        GameSession(audioController: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            resumeStore: resumeStore, safePlaceStore: ResumeStore(),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
    }

    func testRetryRestoresTheSourceCheckpointAfterDroppedCrowbar() throws {
        let audio = originalRouteTestAudio()
        let (failedPlay, _) = try failedCrowbarPlay(audio: audio)
        defer { failedPlay.stop() }
        let session = session(resumeStore: ResumeStore(), audio: audio)
        defer { session.endOriginalGame() }
        session.attachPlay(failedPlay)
        XCTAssertTrue(failedPlay.isGameOverPresented)

        var expected = failedPlay.runner.game
        expected.restoreRetryCheckpoint()
        session.retryOriginalGameOver()

        let retried = try XCTUnwrap(session.play)
        XCTAssertFalse(retried.isGameOverPresented)
        XCTAssertEqual(retried.runner.phase, .exploration(mapID: expected.mapID))
        XCTAssertEqual(retried.runner.game.bytes, expected.bytes,
            "Retry must restore the complete source buffer, including current event flags")
        XCTAssertEqual(retried.runner.game.conditionGlobalByte, expected.conditionGlobalByte)
        XCTAssertEqual(retried.runner.game.mapID, expected.mapID)
        XCTAssertEqual(retried.runner.game.mapPosition, expected.mapPosition)
        XCTAssertEqual(retried.runner.game.facing, expected.facing)
    }

    func testBackToTitleLeavesResumeCheckpointUntouchedAfterDroppedCrowbar() throws {
        let audio = originalRouteTestAudio()
        let (failedPlay, _) = try failedCrowbarPlay(audio: audio)
        defer { failedPlay.stop() }
        let resumeStore = ResumeStore()
        resumeStore.checkpoint = try OriginalResumeSave(game: gameState("chapter-two-crowbar-closeup/torn"),
            checkpointFacing: 0, musicSequenceID: nil, savedAt: Date(timeIntervalSince1970: 1))
        let session = session(resumeStore: resumeStore, audio: audio)
        defer { session.endOriginalGame() }
        session.attachPlay(failedPlay)
        XCTAssertTrue(failedPlay.isGameOverPresented)
        let savedCheckpoint = resumeStore.checkpoint
        let savedWriteCount = resumeStore.writes

        session.returnToTitleAfterGameOver()

        XCTAssertNil(session.play)
        XCTAssertEqual(resumeStore.checkpoint, savedCheckpoint)
        XCTAssertEqual(resumeStore.writes, savedWriteCount)
    }
}
