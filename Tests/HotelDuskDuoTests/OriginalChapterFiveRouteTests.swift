import XCTest
@testable import HotelDuskDuoKit

/// Chapter 5 through normal input: Rachel's Osterzone call, Mila's memos, the doll, the gun and Jeff.
@MainActor
final class OriginalChapterFiveRouteTests: XCTestCase {
    private typealias Route = OriginalChapterThreeRouteChecks

    private var directory: String {
        get throws {
            guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] else {
                throw XCTSkip("Set HOTEL_DUSK_ROUTE_CHECKPOINTS to run the native route")
            }
            return directory
        }
    }

    private func session(_ checkpoint: OriginalResumeSave) throws -> OriginalPlaySession {
        let audio = originalRouteTestAudio()
        return try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) },
            suitcaseContentsRendererFactory: { try OriginalRouteBitmapSuitcaseContentsRenderer() },
            toiletTankRendererFactory: { try OriginalRouteBitmapToiletTankRenderer() })
    }

    private func restore(_ name: String) throws -> OriginalPlaySession {
        guard let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: try directory)
            .appendingPathComponent(name)).load() else {
            throw XCTSkip("Generate the \(name) checkpoint through the native route first")
        }
        let play = try session(checkpoint)
        Route.drain(play, interrupt: true)
        return play
    }

    private func save(_ play: OriginalPlaySession, _ name: String) throws {
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: try directory).appendingPathComponent(name))
            .save(play.walkingCheckpoint())
    }

    /// Rachel's call, Jeff and Dunning in the hallway, Mila's memos, and Melissa's doll.
    func testChapterFiveMilaAndDoll() throws {
        guard let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: try directory)
            .appendingPathComponent("chapter5-normal-entry")).load() else {
            throw XCTSkip("Complete Chapter 4 through the native route first")
        }
        let play = try session(checkpoint)
        defer { play.stop() }
        Route.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.chapter, 4)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try Route.navigate(play, to: .init(8000, 4000), interrupt: true)
        try Route.navigate(play, to: .init(-15500, 7800), interrupt: true)
        Route.face(play, x: -49684, z: 7750)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true)
        Route.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 5)), true, "Rachel's Osterzone call")
        try Route.exit(play, to: 39, interrupt: true)
        try Route.exit(play, to: 17, interrupt: true)
        try Route.navigate(play, to: .init(0, -12000), interrupt: true)
        try Route.conversation(play, answers: ["What's wrong now?", "Like what?", "You lost $20,000, right?", "What's the problem?"],
                               topics: Array(0..<128))
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        try Route.exit(play, to: 3, interrupt: true)
        try Route.exit(play, to: 18, interrupt: true)
        try Route.talk(play, to: 3)
        try Route.conversation(play, answers: ["Sure."], topics: Array(0..<128))
        XCTAssertEqual(play.runner.game.nowTime, 1)
        // Mila writes in the notebook; each new memo is read before her next answer.
        try Route.exit(play, to: 13, interrupt: true)
        try Route.picture(play, interrupt: true)
        try Route.picture(play, interrupt: true)
        try Route.conversation(play, answers: [], topics: Array(0..<128))
        XCTAssertTrue(play.runner.game.memoRead(0) && play.runner.game.memoRead(1), "Mila's first two memos")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 18))
        try Route.navigate(play, to: .init(5000, -14688), interrupt: true)
        for destination: Int16 in [3, 17, 39, 31] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.navigate(play, to: .init(8000, 4000), interrupt: true)
        try Route.exit(play, to: 39, interrupt: true, expectArrival: false)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31), "Melissa stops Kyle at the door")
        try Route.navigate(play, to: .init(-10000, 15000), interrupt: true)
        Route.face(play, x: -10816, z: 35181)
        try Route.search(play, node: "obj03", closeupEvent: 255, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(19), "Mini sewing machine")
        try Route.talk(play, to: 11)
        try Route.conversation(play, answers: [], topics: Array(0..<128))
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 14)), true, "Doll repaired")
        XCTAssertEqual(play.runner.game.nowTime, 2)
        try save(play, "chapter5-doll")
    }

    /// The linen cart, Louie's distraction, Jeff's room, the newspaper and the stored cash.
    func testChapterFiveEvidenceAgainstJeff() throws {
        let play = try restore("chapter5-doll")
        defer { play.stop() }
        try Route.exit(play, to: 39, interrupt: true)
        try Route.navigate(play, to: .init(-14549, 7000), interrupt: true)
        Route.face(play, x: -14549, z: 15905)
        try Route.doorComponent(play, 1, interrupt: true)
        play.leaveDoor()
        for destination: Int16 in [17, 19, 11] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.navigate(play, to: .init(-5341, 5000), interrupt: true)
        Route.face(play, x: -5341, z: 20464)
        try Route.search(play, node: "obj01", interrupt: true)
        try Route.searchLinenWagon(play)
        try Route.conversation(play, answers: ["I found something good.", "Create a distraction."], topics: Array(0..<128))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(52), "Pistol")
        XCTAssertEqual(play.runner.game.nowTime, 3)
        for destination: Int16 in [19, 17, 39, 33] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.navigate(play, to: .init(0, -11000), interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 33, index: 1)), true, "Louie's distraction")
        try Route.exit(play, to: 39, interrupt: true)
        try Route.exit(play, to: 29, interrupt: true)
        try Route.navigate(play, to: .init(10000, 0), interrupt: true)
        Route.face(play, x: -10608, z: -1934)
        try Route.search(play, node: "obj08", closeupEvent: 242, interrupt: true)
        for _ in 0..<4 where play.closeup != nil { play.leaveSearchCloseup() }
        try Route.search(play, node: "obj09", closeupEvent: 244, interrupt: true)
        for item: UInt8 in [40, 68] { XCTAssertTrue(try play.runner.game.inventory.items.contains(item), "Item \(item)") }
        try Route.exit(play, to: 39, interrupt: true, expectArrival: false)
        try Route.conversation(play, answers: ["You hid cash in my john.", "I got an eyewitness."], topics: Array(0..<128),
                               show: [40, 68, 52])
        // Jeff demands proof: the newspaper in the lobby and the cash in Kyle's suitcase.
        for _ in 0..<4 where play.closeup != nil { play.leaveSearchCloseup() }
        for destination: Int16 in [39, 17, 3, 2] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.navigate(play, to: .init(-4000, 9000), interrupt: true)
        Route.face(play, x: -23781, z: 9155)
        try Route.search(play, node: "obj06", interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(67), "Lobby newspaper")
        for destination: Int16 in [3, 17, 39, 31] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.navigate(play, to: .init(8000, 12000), interrupt: true)
        Route.face(play, x: 18672, z: 29104)
        try Route.search(play, node: "obj04", interrupt: true)
        try Route.takeFromSuitcase(play, lowerIndex: 9)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(28), "Stack of cash")
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try Route.exit(play, to: 39, interrupt: true)
        try Route.navigate(play, to: .init(-14549, 7000), interrupt: true)
        Route.face(play, x: -14549, z: 15905)
        try Route.doorComponent(play, 1, interrupt: true)
        if play.door != nil { play.leaveDoor() }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 29), "Jeff lets Kyle in")
        try save(play, "chapter5-jeff")
    }

    /// Jeff's confession and the Chapter 5 review.
    func testChapterFiveConfessionAndReview() throws {
        let play = try restore("chapter5-jeff")
        defer { play.stop() }
        try Route.talk(play, to: 6)
        for item: UInt8 in [67, 40, 28] {
            play.showItemInConversation(item)
            Route.drain(play, interrupt: true)
        }
        play.ask(6)
        Route.drain(play, interrupt: true)
        try Route.choose(play, "You wanted trouble.", interrupt: true)
        play.showItemInConversation(52)
        Route.drain(play, interrupt: true)
        play.ask(7)
        Route.drain(play, interrupt: true)
        try Route.choose(play, "You wanted it found.", interrupt: true)
        try Route.conversation(play, answers: ["Jeff Damon.", "Did Dunning say anything?", "Robert Evans", "A gun",
                                               "Jeff's Student ID", "Lawyer"], topics: Array(0..<128))
        XCTAssertTrue(play.chapterTransition?.stage == .prompt || play.chapterTransition?.stage == .title)
        XCTAssertEqual(play.runner.game.chapter, 5)
        if play.chapterTransition?.stage == .prompt { play.answerChapterSave(false) }
        play.continueChapterTitle()
        Route.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: try directory)
            .appendingPathComponent("chapter6-entry")).save(play.walkingCheckpoint())
    }
}
