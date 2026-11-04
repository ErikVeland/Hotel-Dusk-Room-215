import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

final class BookJourneyTests: XCTestCase {
    func testEachReturnVisitHasItsOwnIdentityAndIdleFramesDoNotExtendTheRoute() throws {
        var book = BookJourney.Record()
        book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        let first = try XCTUnwrap(book.activeVisit?.id)
        for _ in 0..<50 { book.walk(to: SIMD2(10, 20)) }
        XCTAssertEqual(book.activeVisit?.route.count, 1)
        book.walk(to: SIMD2(14, 20))
        XCTAssertEqual(book.activeVisit?.route, [SIMD2(10, 20), SIMD2(14, 20)])
        book.leave()
        book.visit(mapID: 3, chapter: 0, name: "Hallway", mapSize: SIMD2(256, 256), point: SIMD2(4, 5))
        book.leave()
        book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        XCTAssertNotEqual(book.activeVisit?.id, first)
    }

    func testCommittedSketchesKeepTheirOwnRouteAndSourceView() throws {
        var book = BookJourney.Record()
        book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        let image = Data([1, 2, 3])
        XCTAssertTrue(book.capture(.arrival, at: 0, facing: 0, view: image, floorPlan: nil))
        let arrival = try XCTUnwrap(book.entries.first)
        book.walk(to: SIMD2(40, 20))
        XCTAssertTrue(book.capture(.interaction, at: 8, facing: 1, view: Data([4, 5]), floorPlan: nil))
        XCTAssertEqual(book.entries[0], arrival)
        XCTAssertEqual(book.entries[0].route, [SIMD2(10, 20)])
        XCTAssertEqual(book.entries[1].route, [SIMD2(10, 20), SIMD2(40, 20)])
        XCTAssertEqual(book.entries[0].viewPNG, image)
        XCTAssertFalse(book.capture(.interaction, at: 9, facing: 1, view: nil, floorPlan: nil),
                       "Repeated settling must not duplicate an interaction")
    }

    func testIncrementalRecordAppendsOnlyNewImagesAndRoutePoints() throws {
        var old = BookJourney.Record()
        old.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        old.capture(.arrival, at: 0, facing: 0, view: Data(repeating: 3, count: 100_000), floorPlan: nil)
        var next = old
        next.walk(to: SIMD2(40, 20))
        let walking = try XCTUnwrap(BookJourney.Delta(previous: old, next: next))
        XCTAssertEqual(try walking.applying(to: old), next)
        XCTAssertLessThan(try JSONEncoder().encode(walking).count, 2_000)
        next.capture(.interaction, at: 9, facing: 1, view: Data([4, 5]), floorPlan: nil)
        let delta = try XCTUnwrap(BookJourney.Delta(previous: old, next: next))
        XCTAssertEqual(try delta.applying(to: old), next)
        XCTAssertLessThan(try JSONEncoder().encode(delta).count, 3_000, "Do not repeat the earlier image")
        var departed = next
        departed.leave()
        XCTAssertEqual(try XCTUnwrap(BookJourney.Delta(previous: next, next: departed)).applying(to: next), departed)
    }

    @MainActor
    func testJourneyLeavesHaveUniqueRangesBetweenDialogueAndSurviveRestore() throws {
        let book = DialogueNotebook()
        book.book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        book.recordJourney(.arrival, facing: 0, view: nil, floorPlan: nil)
        book.book.walk(to: SIMD2(40, 20))
        book.recordJourney(.interaction, facing: 1, view: nil, floorPlan: nil)
        let layout = DialogueNotebookLayout(runs: book.ink, size: CGSize(width: 260, height: 320), fontSize: 18, book: book.book)
        XCTAssertEqual(layout.pages.count, 2)
        XCTAssertTrue(layout.pages.allSatisfy { $0.length > 0 })
        XCTAssertNotEqual(layout.pages[0].location, layout.pages[1].location)
        XCTAssertTrue(layout.accessibleText(page: layout.pages[1]).contains("Lobby"))
        let state = try JSONDecoder().decode(DialogueNotebook.SavedState.self, from: JSONEncoder().encode(book.savedState()))
        let restored = DialogueNotebook()
        restored.restore(state)
        XCTAssertEqual(restored.book, book.book)
        XCTAssertEqual(restored.ink, book.ink)
    }

    @MainActor
    func testInstantFileLogRetainsJourneyArtworkAndAppendsOnlyNewRouteData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = OriginalResumeFileStore(directory: directory)
        let book = DialogueNotebook()
        book.book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        book.recordJourney(.arrival, facing: 0, view: Data(repeating: 3, count: 100_000), floorPlan: nil)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(2, previous: 1)
        var journal = OriginalPlayProgress(origin: .arrival, base: Data())
        journal.session = .mapSession(nowTime: game.nowTime, mapID: game.mapID)
        func save() throws -> OriginalResumeSave {
            journal.notebook = book.savedState()
            let checkpoint = try OriginalResumeSave(game: game, checkpointFacing: 0, musicSequenceID: nil,
                                                   savedAt: Date(timeIntervalSince1970: 0), progress: journal)
            try store.save(checkpoint)
            return checkpoint
        }
        _ = try save()
        book.book.walk(to: SIMD2(40, 20))
        let walked = try save()
        XCTAssertEqual(try OriginalResumeFileStore(directory: directory).load(), walked)
        book.recordJourney(.interaction, facing: 1, view: Data([4, 5]), floorPlan: nil)
        let interacted = try save()
        XCTAssertEqual(try OriginalResumeFileStore(directory: directory).load(), interacted)
        let steps = try Data(contentsOf: directory.appendingPathComponent("resume.steps"))
        XCTAssertGreaterThan(steps.count, 0)
        XCTAssertLessThan(steps.count, 10_000, "The earlier sketch must stay in the base, not each step")
        XCTAssertLessThan(try Data(contentsOf: directory.appendingPathComponent("resume.json")).count, 60_000)
        let digest = try XCTUnwrap(book.book.entries.first?.viewSHA256)
        let asset = directory.appendingPathComponent("book-art/\(digest).png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: asset.path))
        try FileManager.default.removeItem(at: asset)
        XCTAssertThrowsError(try OriginalResumeFileStore(directory: directory).load(), "Missing artwork must not silently erase history")
    }

    private func dialogue(_ text: String) -> OriginalEventRunner.Phase {
        let tokens = Array(text.utf8).enumerated().map {
            OriginalDialogueToken(textIndex: 0, byteOffset: $0.offset, kind: .glyph($0.element))
        }
        return .itemNotice(itemID: 1, page: .init(page: 0, entries: [], tokens: tokens))
    }

    @MainActor
    func testRepeatedDialogueBelongsToTheNewVisitInsteadOfJumpingBack() {
        let book = DialogueNotebook()
        let passage = dialogue("A room. One night.")
        book.record(passage, program: "test")
        book.book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        book.recordJourney(.arrival, facing: 0, view: nil, floorPlan: nil)
        book.record(passage, program: "test")
        XCTAssertEqual(book.ink.map(\.text).joined().components(separatedBy: "A room. One night.").count, 3)
    }

    @MainActor
    func testCompletedLeavesKeepTheirOwnPortraitWhenTheSpeakerChanges() throws {
        let book = DialogueNotebook()
        let first = BookJourney.Portrait(screen: 1, animationID: "Hy_hanas_", frameIndex: 0)
        book.record(dialogue(String(repeating: "The hotel keeps its secrets. ", count: 60)),
                    program: "test", portraits: [first])
        let layout = DialogueNotebookLayout(runs: book.ink, size: CGSize(width: 260, height: 320), fontSize: 18, book: book.book)
        book.configure(layout)
        book.finishWriting()
        let page = try XCTUnwrap(layout.pages.first)
        book.turnForward()
        book.finishTurn(revision: book.turnRevision)
        XCTAssertFalse(book.hasLivePortraits(on: page))
        book.record(dialogue("Another speaker."), program: "test",
                    portraits: [.init(screen: 1, animationID: "Jf_hanas_", frameIndex: 0)])
        XCTAssertEqual(book.portraits(on: page), [first])
        XCTAssertEqual(book.savedState().book?.leafArt.first?.portraits, [first])
    }

    @MainActor
    func testSelectedAnswerIsKeptOnceEvenWhenTheScriptRepeatsIt() {
        let book = DialogueNotebook()
        book.book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        book.recordJourney(.arrival, facing: 0, view: nil, floorPlan: nil)
        book.recordChoice("Cheap.")
        book.record(dialogue("Cheap."), program: "test")
        book.record(dialogue("A room is available."), program: "test")
        XCTAssertEqual(book.ink.map(\.text).joined().components(separatedBy: "Cheap.").count, 2)
        XCTAssertTrue(book.ink.map(\.text).joined().contains("A room is available."))
    }

    @MainActor
    func testJourneyBoundaryKeepsActorFreeMenuPagesBlank() throws {
        let book = DialogueNotebook()
        book.record(dialogue("An earlier conversation."), program: "test",
                    portraits: [.init(screen: 0, animationID: "Jf_hanas_", frameIndex: 0)])
        book.book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        book.recordJourney(.arrival, facing: 0, view: nil, floorPlan: nil)
        let layout = DialogueNotebookLayout(runs: book.ink, size: CGSize(width: 260, height: 320), fontSize: 18,
            menu: [.init(text: "Look around", selectable: true)], book: book.book)
        let page = try XCTUnwrap(layout.pages.last)
        XCTAssertTrue(layout.accessibleText(page: page).contains("Look around"))
        XCTAssertEqual(book.portraits(on: page), [])
        XCTAssertFalse(book.hasLivePortraits(on: page))
    }

    @MainActor
    func testNativeChapterSaveRetainsTheWholeBookWithoutReferenceFixtures() throws {
        let book = DialogueNotebook()
        book.book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        book.recordJourney(.departure, facing: 0, view: Data([1, 2, 3]), floorPlan: nil)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(31, previous: 31)
        try game.beginChapter(1)
        var checkpoint = try OriginalChapterSave(game: game, savedAt: Date(timeIntervalSince1970: 0))
        try checkpoint.attachNotebook(book.savedState())
        let decoded = try JSONDecoder().decode(OriginalChapterSave.self, from: JSONEncoder().encode(checkpoint))
        XCTAssertEqual(try decoded.gameState(), game)
        let restored = try OriginalPlaySession.restoring(decoded, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory))
        defer { restored.stop() }
        XCTAssertEqual(restored.dialogueNotebook.book, book.book)
        XCTAssertEqual(restored.dialogueNotebook.ink, book.ink)
    }

    @MainActor
    func testNewWorldEntriesCannotMoveEarlierDialoguePixels() throws {
        let book = DialogueNotebook()
        book.record(dialogue(String(repeating: "A room. One night. ", count: 45)), program: "test")
        let size = CGSize(width: 260, height: 320)
        let portrait = CGSize(width: 160, height: 150)
        let before = DialogueNotebookLayout(runs: book.ink, size: size, fontSize: 18,
                                            portraitSize: portrait, book: book.book)
        book.book.visit(mapID: 2, chapter: 0, name: "Lobby", mapSize: SIMD2(256, 256), point: SIMD2(10, 20))
        book.recordJourney(.arrival, facing: 0, view: nil, floorPlan: nil)
        book.record(dialogue("A different place, later in the journey."), program: "test")
        let after = DialogueNotebookLayout(runs: book.ink, size: size, fontSize: 18,
                                           portraitSize: portrait, book: book.book)
        func pixels(_ layout: DialogueNotebookLayout, page: NSRange) throws -> Data {
            let context = try XCTUnwrap(CGContext(data: nil, width: 260, height: 320, bitsPerComponent: 8,
                bytesPerRow: 1040, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            layout.draw(page: page, revealedEnd: NSMaxRange(page), in: context)
            return Data(bytes: try XCTUnwrap(context.data), count: 260 * 320 * 4)
        }
        XCTAssertEqual(Array(before.pages.dropLast()), Array(after.pages.prefix(before.pages.count - 1)))
        for page in before.pages {
            XCTAssertTrue(try pixels(before, page: page) == pixels(after, page: page),
                          "A later world entry moved earlier printed ink")
        }
        XCTAssertEqual(after.pages.filter { after.journey(on: $0) != nil }.count, 1)
    }
}
