import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalChapterFourRouteTests: XCTestCase {
    private typealias Route = OriginalChapterThreeRouteChecks

    private func restore(_ name: String) throws -> (OriginalPlaySession, String) {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent(name)).load() else {
            throw XCTSkip("Generate the \(name) checkpoint through the native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        return (play, directory)
    }

    private func save(_ play: OriginalPlaySession, _ name: String, in directory: String) throws {
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent(name))
            .save(play.walkingCheckpoint())
    }

    func testChapterFourReturnsFromRoofToRoom215() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let save = try OriginalChapterFileStore(directory: URL(fileURLWithPath: directory)).load(slot: 2) else {
            throw XCTSkip("Complete Chapter 3 through the native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(save, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        play.continueChapterTitle()
        Route.drain(play)
        XCTAssertEqual(play.runner.game.chapter, 3)
        XCTAssertEqual(play.runner.game.mapID, 45)
        try Route.exit(play, to: 39, interrupt: true)
        try Route.exit(play, to: 31, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try self.save(play, "chapter4-room215", in: directory)
    }

    /// Rachel's call, Louie's key, Room 217's photo and lighter, Dunning, Jeff, then the toilet-tank cash.
    func testChapterFourRoom217AndTankCash() throws {
        let (play, directory) = try restore("chapter4-room215")
        defer { play.stop() }
        Route.drain(play, interrupt: true)
        // The dresser telephone starts Rachel's call; Louie then knocks.
        try Route.navigate(play, to: .init(-15500, 7800), interrupt: true)
        Route.face(play, x: -49684, z: 7750)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true)
        Route.drain(play, interrupt: true)
        try Route.navigate(play, to: .init(9994, -15811), interrupt: true)
        let door = try Route.doorMarker(play, 39)
        Route.face(play, x: door.x, z: door.y)
        play.inspectNearbyDoor()
        Route.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 28))
        try Route.picture(play, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(45), "Room 217 key")
        try Route.door(play, destination: 39, interrupt: true)
        // Room 217: the key opens the door from the corridor.
        try Route.navigate(play, to: .init(-43544, 1000), interrupt: true)
        Route.face(play, x: -43544, z: -6792)
        XCTAssertEqual(play.nearbyDoor, 33)
        play.inspectNearbyDoor()
        Route.drain(play, interrupt: true)
        play.useItemAtDoor(45)
        play.selectDoorComponent(x: 158, y: 180, confirmImmediately: true)
        Route.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 158, y: 180, confirmImmediately: true)
            Route.drain(play, interrupt: true)
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 33))
        try Route.navigate(play, to: .init(-28000, -39000), interrupt: true)
        Route.face(play, x: -40099, z: -29279)
        try Route.search(play, node: "obj02", closeupEvent: 274, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(55), "Photo behind the painting")
        try Route.navigate(play, to: .init(-8000, -32000), interrupt: true)
        Route.face(play, x: 5073, z: -37743)
        try Route.search(play, node: "obj08", closeupEvent: 278, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(73), "Bradley's lighter")
        // Leaving runs Dunning's confrontation, including opcode 34's mode-29 follow-up.
        try Route.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 33, index: 3)), true)
        try Route.talk(play, to: 6)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        // The departure script changes the clock before Room 215 selects its events.
        try Route.exit(play, to: 31, interrupt: true)
        XCTAssertEqual(play.runner.game.nowTime, 1)
        try Route.navigate(play, to: .init(8000, -5000), interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 8)), true)
        try Route.navigate(play, to: .init(-2600, -12000), interrupt: true)
        Route.nudge(play, toward: .init(-2600, -12000))
        Route.face(play, x: -10983, z: -12457)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 5)
        try Route.search(play, node: "obj15", interrupt: true)
        try Route.openToiletTank(play, interrupt: true)
        try Route.picture(play, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(28), "Cash from the tank")
        try Route.navigate(play, to: .init(-15500, 7800), interrupt: true)
        Route.face(play, x: -49684, z: 7750)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true)
        Route.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 17)), true)
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try save(play, "chapter4-cash", in: directory)
    }

    /// Jeff in the lobby, Rosa's novel, the theft report, Dunning, Summer and the newspaper.
    func testChapterFourTheftReportAndNewspaper() throws {
        let (play, directory) = try restore("chapter4-cash")
        defer { play.stop() }
        Route.drain(play, interrupt: true)
        for destination: Int16 in [39, 17, 3, 2] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.talk(play, to: 6)
        try Route.conversation(play, answers: ["Fine. Fill me in."], topics: [])
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 2, index: 0)), true)
        for destination: Int16 in [3, 17, 39] { try Route.exit(play, to: destination, interrupt: true) }
        // Region 4 reveals Rosa, who hands over Summer's novel.
        try Route.navigate(play, to: .init(57000, 8000), interrupt: true)
        try Route.talk(play, to: 3)
        try Route.conversation(play, answers: [], topics: Array(0..<128))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(26), "Summer's novel")
        XCTAssertEqual(play.runner.game.nowTime, 2)
        for destination: Int16 in [17, 3, 2] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.navigate(play, to: .init(-10000, -12000), interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 2, index: 7)), true, "Jeff reports the theft")
        try Route.talk(play, to: 2)
        try Route.conversation(play, answers: ["What happened?", "You suspect me?"], topics: Array(0..<128))
        try Route.talk(play, to: 8)
        try Route.conversation(play, answers: [], topics: Array(0..<128))
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 2, index: 44)), true, "Summer leaves the paper")
        try Route.navigate(play, to: .init(-4000, 9000), interrupt: true)
        Route.face(play, x: -23781, z: 9155)
        try Route.search(play, node: "obj06", closeupEvent: 6, interrupt: true)
        try Route.closeupLayer(play, event: 8, interrupt: true)
        try Route.closeupLayer(play, event: 7, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 2, index: 46)), true)
        try Route.navigate(play, to: .init(-10000, -12000), interrupt: true)
        XCTAssertEqual(play.runner.game.nowTime, 3)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        try save(play, "chapter4-lobby", in: directory)
    }

    /// Rosa's back-stairs clue, Dunning's missing equipment, and Summer's pen, autograph and notebook.
    func testChapterFourSummerPenAndNotebook() throws {
        let (play, directory) = try restore("chapter4-lobby")
        defer { play.stop() }
        Route.drain(play, interrupt: true)
        try Route.exit(play, to: 3, interrupt: true)
        try Route.navigate(play, to: .init(20000, -10000), interrupt: true)
        try Route.conversation(play, answers: ["Other stairs?"], topics: Array(0..<128))
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 3, index: 5)), true)
        try Route.exit(play, to: 18, interrupt: true)
        try Route.navigate(play, to: .init(-10000, 1000), interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 18, index: 0)), true)
        try Route.exit(play, to: 39, interrupt: true)
        try Route.navigate(play, to: .init(88000, 3000), interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 39, index: 20)), true, "Dunning leaves the closet")
        try Route.talk(play, to: 2)
        try Route.conversation(play, answers: ["You mean Jeff?"], topics: Array(0..<128))
        // Knock on Room 211; Summer opens the door.
        try Route.navigate(play, to: .init(89142, 7000), interrupt: true)
        Route.face(play, x: 89142, z: 15848)
        try Route.doorComponent(play, 1, interrupt: true)
        XCTAssertNotNil(play.door, "The invitation keeps the door view open")
        try Route.door(play, destination: 27, interrupt: true)
        try Route.talk(play, to: 8)
        try Route.conversation(play, answers: ["An unknown hotel?"], topics: Array(0..<128), show: [26, 27])
        try Route.talk(play, to: 8)
        try Route.conversation(play, answers: ["What's your name?"], topics: Array(0..<128), show: [26, 27])
        XCTAssertFalse(try play.runner.game.inventory.items.contains(27), "Summer keeps his pen")
        try Route.talk(play, to: 8)
        try Route.conversation(play, answers: [], topics: Array(0..<128), show: [26])
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 27, index: 18)), true, "Summer signs the novel")
        try Route.navigate(play, to: .init(10000, 24000), interrupt: true)
        Route.face(play, x: 12703, z: 37416)
        try Route.search(play, node: "obj09", interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(play.runner.game.nowTime, 4)
        try save(play, "chapter4-summer", in: directory)
    }

    /// Stashing the suspicious items, Rosa's autograph, the signature comparison and the Chapter 4 review.
    func testChapterFourConfrontationAndReview() throws {
        let (play, directory) = try restore("chapter4-summer")
        defer { play.stop() }
        Route.drain(play, interrupt: true)
        // Dunning searches anyone carrying hotel property or the cash (EP4_R117 events 1–8).
        try Route.exit(play, to: 31, interrupt: true)
        try Route.navigate(play, to: .init(8000, 12000), interrupt: true)
        Route.face(play, x: 18672, z: 29104)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        for item: UInt8 in [28, 13, 14, 45] { try Route.useItem(play, item, on: "obj04", interrupt: true) }
        try Route.exit(play, to: 39, interrupt: true)
        try Route.exit(play, to: 37, interrupt: true)
        try Route.navigate(play, to: .init(9000, -22000), interrupt: true)
        Route.face(play, x: 20521, z: -27504)
        try Route.search(play, node: "obj01", closeupEvent: 296, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 305)
        for item: UInt8 in [15, 10, 65] { try Route.closeupLayer(play, event: 306, item: item, interrupt: true) }
        let carried = try play.runner.game.inventory.items
        for item: UInt8 in [65, 15, 10, 28, 14, 45, 63, 13] { XCTAssertFalse(carried.contains(item), "Item \(item)") }
        for destination: Int16 in [39, 17] { try Route.exit(play, to: destination, interrupt: true) }
        XCTAssertNotEqual(play.runner.game.value(for: .eventFlag(group: 17, index: 10)), true, "Dunning finds nothing")
        for destination: Int16 in [26, 6] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.talk(play, to: 3)
        try Route.conversation(play, answers: [], topics: Array(0..<128), show: [26])
        XCTAssertFalse(try play.runner.game.inventory.items.contains(26), "Rosa keeps the signed novel")
        for destination: Int16 in [17, 39] { try Route.exit(play, to: destination, interrupt: true) }
        try Route.navigate(play, to: .init(89142, 7000), interrupt: true)
        Route.face(play, x: 89142, z: 15848)
        try Route.doorComponent(play, 1, interrupt: true)
        if play.door != nil { try Route.door(play, destination: 27, interrupt: true) }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 27))
        let answers = ["But if you can do it...", "Different handwriting.", "Your name's not Alan!", "It exposes you!",
                       "C'mon. Who really did it?", "An old photo", "Get an autograph", "A fountain pen",
                       "Summer's real name", "He stole a friend's work"]
        try Route.talk(play, to: 8)
        try Route.conversation(play, answers: answers, topics: Array(0..<128))
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 49)), true, "Signatures compared")
        try Route.talk(play, to: 8)
        try Route.conversation(play, answers: answers, topics: Array(0..<128))
        XCTAssertEqual(play.chapterTransition?.stage, .prompt)
        XCTAssertEqual(play.runner.game.chapter, 4)
        let chapter = try OriginalChapterSave(game: play.runner.game, savedAt: Date())
        try OriginalChapterFileStore(directory: URL(fileURLWithPath: directory)).save(chapter, slot: 1)
    }
}
