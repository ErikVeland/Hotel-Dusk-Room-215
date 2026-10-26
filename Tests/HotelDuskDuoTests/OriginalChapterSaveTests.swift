import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterSaveTests: XCTestCase {
    private func state(_ name: String = "chapter-one-review-final/page32") throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("The original chapter capture is unavailable") }
        return try OriginalGameState(snapshot: Data(contentsOf: url).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private final class Store: OriginalChapterSaveStore {
        var slots: [Int: OriginalChapterSave] = [:]
        var fails = false
        func load(slot: Int) throws -> OriginalChapterSave? { slots[slot] }
        func save(_ checkpoint: OriginalChapterSave, slot: Int) throws {
            if fails { throw OriginalDataError.invalid("Injected storage failure") }
            slots[slot] = checkpoint
        }
    }

    @MainActor private func play(store: any OriginalChapterSaveStore) throws -> OriginalPlaySession {
        let catalog = try OriginalScriptCatalog.bundled()
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP2_R205"), game: state(), deferArrival: true)
        let audio = AudioController()
        audio.isMuted = true
        return OriginalPlaySession(runner: runner, audio: audio, catalog: catalog, saveStore: store,
            saveDate: { Date(timeIntervalSince1970: 100) }, chapterTransition: OriginalChapterTransition())
    }

    func testFilesRetainAllStateAndRejectInvalidOrDamagedRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OriginalChapterFileStore(directory: directory)
        let game = try state()
        let checkpoint = try OriginalChapterSave(game: game, savedAt: Date(timeIntervalSince1970: 100))
        XCTAssertNil(try store.load(slot: 0))
        for slot in 0..<3 {
            try store.save(checkpoint, slot: slot)
            XCTAssertEqual(try OriginalChapterFileStore(directory: directory).load(slot: slot)?.gameState(), game)
        }
        XCTAssertThrowsError(try store.load(slot: -1))
        XCTAssertThrowsError(try store.save(checkpoint, slot: 3))
        var invalid = game
        try invalid.beginChapterTitle(label: " 05:30PM")
        XCTAssertThrowsError(try OriginalChapterSave(game: invalid, savedAt: Date()))
        var record = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
        record["stateSHA256"] = "damaged"
        try JSONSerialization.data(withJSONObject: record).write(to: directory.appendingPathComponent("slot-1.json"))
        XCTAssertThrowsError(try store.load(slot: 0))
        XCTAssertEqual(try store.load(slot: 1), checkpoint)
    }

    @MainActor func testDecliningSaveMatchesOriginalTitleAndStartsChapterTwo() throws {
        let store = Store()
        let play = try play(store: store)
        defer { play.stop() }
        play.answerChapterSave(false)
        XCTAssertEqual(play.chapterTransition?.stage, .title)
        XCTAssertEqual(play.runner.game, try state("chapter-two-no-save/next"))
        XCTAssertTrue(store.slots.isEmpty)
        XCTAssertNotNil(play.chapterTitleImages)
        play.continueChapterTitle()
        XCTAssertEqual(play.runner.program.name, "EP2_R205")
        XCTAssertEqual(play.runner.eventIndex, 0)
        XCTAssertNotNil(play.runner.keywords)
        guard case .dialogue = play.runner.phase else { return XCTFail("Expected the Chapter 2 opening") }
    }

    @MainActor func testCancellingSlotSelectionThenLeavingSaveReachesTitle() throws {
        let store = Store()
        let play = try play(store: store)
        defer { play.stop() }
        play.answerChapterSave(true)
        play.selectChapterSaveSlot(2)
        play.cancelChapterSave()
        XCTAssertEqual(play.chapterTransition?.stage, .slots)
        XCTAssertNil(play.chapterTransition?.selectedSlot)
        play.cancelChapterSave()
        XCTAssertEqual(play.chapterTransition?.stage, .title)
        XCTAssertTrue(store.slots.isEmpty)
        XCTAssertEqual(play.runner.game, try state("chapter-two-save-back/back"))
    }

    @MainActor func testSaveFailureRetryOverwriteAndFreshSessionRestore() throws {
        let store = Store()
        let saving = try self.play(store: store)
        defer { saving.stop() }
        saving.answerChapterSave(true)
        saving.confirmChapterSaveSlot()
        XCTAssertTrue(store.slots.isEmpty)
        saving.selectChapterSaveSlot(1)
        store.fails = true
        saving.confirmChapterSaveSlot()
        XCTAssertEqual(saving.chapterTransition?.stage, .slots)
        XCTAssertNotNil(saving.chapterTransition?.error)
        XCTAssertTrue(store.slots.isEmpty)
        store.fails = false
        saving.confirmChapterSaveSlot()
        XCTAssertEqual(saving.chapterTransition?.stage, .title)
        let checkpoint = try XCTUnwrap(store.slots[1])
        XCTAssertEqual(try checkpoint.gameState(), try state())
        let audio = AudioController()
        audio.isMuted = true
        let resumeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: resumeDirectory) }
        let fresh = GameSession(audioController: audio, saveStore: store,
            resumeStore: OriginalResumeFileStore(directory: resumeDirectory))
        XCTAssertEqual(fresh.chapterSaves[1], checkpoint)
        fresh.loadChapterSave(slot: 1)
        let restored = try XCTUnwrap(fresh.play)
        defer { fresh.endOriginalGame() }
        XCTAssertEqual(restored.chapterTransition?.stage, .title)
        XCTAssertEqual(restored.runner.game, saving.runner.game)
        restored.continueChapterTitle()
        saving.continueChapterTitle()
        XCTAssertEqual(restored.runner.game, saving.runner.game)
        XCTAssertEqual(restored.runner.phase, saving.runner.phase)
        for play in [restored, saving] {
            for _ in 0..<100 {
                switch play.runner.phase {
                case .dialogue: play.advanceDialogue()
                case .waiting: play.advanceFrame()
                default: break
                }
            }
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
            XCTAssertEqual(play.lobby?.mode, .walking)
            let expected = try state("chapter-two-room/page4").bytes
            XCTAssertEqual(play.runner.game.bytes.indices.filter { play.runner.game.bytes[$0] != expected[$0] }, [])
        }
        let replacing = try self.play(store: store)
        defer { replacing.stop() }
        replacing.answerChapterSave(true)
        replacing.selectChapterSaveSlot(1)
        replacing.confirmChapterSaveSlot()
        XCTAssertEqual(replacing.chapterTransition?.stage, .overwrite)
        replacing.confirmChapterOverwrite(false)
        XCTAssertEqual(replacing.chapterTransition?.stage, .slots)
        XCTAssertEqual(store.slots[1], checkpoint)
        replacing.confirmChapterSaveSlot()
        replacing.confirmChapterOverwrite(true)
        XCTAssertEqual(replacing.chapterTransition?.stage, .title)
    }
}
