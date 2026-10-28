import simd
import XCTest
@testable import HotelDuskDuoKit

final class OriginalStoryContinuationTests: XCTestCase {
    @MainActor func testChapterSixReachesBarFromChapterFiveSave() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let save = try OriginalChapterFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6")).load(slot: 0) else {
            throw XCTSkip("Generate the Chapter 6 save through the Chapter 5 route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(save, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        play.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)

        XCTAssertEqual(play.runner.game.chapter, 5)
        XCTAssertEqual(play.runner.program.name, "EP6_R205")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))

        // The first exit attempt starts the Chapter 6 phone event and cancels
        // departure. Answer the ringing phone in Room 215, then try the door again.
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true, expectArrival: false)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-16687, 7450), interrupt: true)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)

        for destination: Int16 in [39, 17, 26, 4] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
            XCTAssertEqual(play.runner.game.mapID, destination)
        }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-bar")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSixFromBarExitThroughRosaErrand() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-after-bar-exit")).load() else {
            throw XCTSkip("Generate the Rosa checkpoint through the earlier Chapter 6 route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.talk(play, to: 3)
        guard case .questions = play.runner.phase else { return XCTFail("Expected Rosa's topic menu") }
        play.ask(9)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let topics) = play.runner.phase else { return XCTFail("Expected Rosa's story topic") }
        XCTAssertEqual(topics.map(\.keyword), [10])
        play.ask(10)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.exit(play, to: 4, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 4))
        try OriginalChapterThreeRouteChecks.talk(play, to: 2)
        guard case .choice(let choices) = play.runner.phase else { return XCTFail("Expected Dunning's history choice") }
        XCTAssertEqual(choices.map(\.id), [12, 13])
        play.choose(12)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let historyTopics) = play.runner.phase else { return XCTFail("Expected Dunning's history topics") }
        XCTAssertEqual(historyTopics.map(\.keyword), [11, 12])
        play.ask(11)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(12)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let remaining) = play.runner.phase else { return XCTFail("Expected Dunning's final topic") }
        XCTAssertEqual(remaining.map(\.keyword), [13])
        play.ask(13)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let pastChoices) = play.runner.phase else { return XCTFail("Expected Dunning's past choice") }
        XCTAssertEqual(pastChoices.map(\.id), [14, 15])
        play.choose(15)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 4))
        XCTAssertEqual(play.runner.game.nowTime, 2)
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.talk(play, to: 3)
        guard case .choice(let rosaChoices) = play.runner.phase else { return XCTFail("Expected Rosa's favour choice") }
        XCTAssertEqual(rosaChoices.map(\.id), [10, 11])
        play.choose(10)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let rosaTopics) = play.runner.phase else { return XCTFail("Expected Rosa's favour topics") }
        XCTAssertEqual(rosaTopics.map(\.keyword), [14])
        play.ask(14)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let sonComparison) = play.runner.phase else { return XCTFail("Expected Rosa's comparison topic") }
        XCTAssertEqual(sonComparison.map(\.keyword), [15])
        play.ask(15)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let sonTopic) = play.runner.phase else { return XCTFail("Expected Rosa's son topic") }
        XCTAssertEqual(sonTopic.map(\.keyword), [16])
        play.ask(16)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        XCTAssertEqual(play.runner.game.nowTime, 3)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-rosa-errand")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSixMatchsticksAndKitchenWineBottles() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-normal-rosa-errand")).load() else {
            throw XCTSkip("Generate the post-Rosa Chapter 6 checkpoint first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 4, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(15_000, 20_000))
        let lobby = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(lobby.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        for node in ["obj02", "obj03", "obj04"] {
            try OriginalChapterThreeRouteChecks.search(play, node: node)
        }
        try OriginalChapterThreeRouteChecks.search(play, node: "obj05")
        XCTAssertEqual(play.runner.phase, .process(id: 53))
        try OriginalChapterThreeRouteChecks.solveMatchsticks(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-after-matchsticks")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 6, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 6))
        func inspectWine(area: Int, point: SIMD2<Float>, object: String) throws {
            try OriginalChapterThreeRouteChecks.navigate(play, to: point)
            let room = try XCTUnwrap(play.lobby)
            let marker = try XCTUnwrap(room.room.nodes.first { $0.name == String(format: "s%02d", area) })
            OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
            XCTAssertEqual(play.lobby?.nearbySearchArea, UInt16(area))
            try OriginalChapterThreeRouteChecks.search(play, node: object)
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 6))
            if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        }
        try inspectWine(area: 3, point: .init(-50_000, 15_000), object: "obj06")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-red-wine")).save(play.walkingCheckpoint())
        try inspectWine(area: 1, point: .init(-15_000, 5_000), object: "obj09")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-white-wine")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSixFindRoseWine() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-normal-white-wine")).load() else {
            throw XCTSkip("Generate the Chapter 6 white-wine checkpoint first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(-50_000, -10_000))
        let lobby = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(lobby.room.nodes.first { $0.name == "s02" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01")
        XCTAssertEqual(play.runner.phase, .process(id: 58))
        try OriginalChapterThreeRouteChecks.playJukebox(play, record: 24)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 4, interrupt: true)
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(5_000, 0))
        let restaurant = try XCTUnwrap(play.lobby)
        let tableMarker = try XCTUnwrap(restaurant.room.nodes.first { $0.name == "s04" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(tableMarker.worldFixed[12]), z: Float(tableMarker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 4)
        for object in ["obj01", "obj02", "obj03", "obj04", "obj05"] {
            try OriginalChapterThreeRouteChecks.search(play, node: object)
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 4))
            if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-rose-wine")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSixGetsAdhesiveRemoverFromEdPackage() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-normal-rose-wine")).load() else {
            throw XCTSkip("Generate the Chapter 6 rosé checkpoint first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        for destination: Int16 in [26, 17, 39, 31] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
        }
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(0, 20_000))
        OriginalChapterThreeRouteChecks.face(play, x: 14, z: 24_407)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj03", closeupEvent: 257)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(50), "Adhesive remover from Ed's package")
        for _ in 0..<4 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        XCTAssertTrue(play.canSaveWalkingCheckpoint)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-with-adhesive-remover")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSixIdentifiesWinesAndStartsLabelPeel() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-normal-with-adhesive-remover")).load() else {
            throw XCTSkip("Generate the Chapter 6 adhesive-remover checkpoint first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        let target = try OriginalChapterThreeRouteChecks.doorMarker(play, 32)
        try OriginalChapterThreeRouteChecks.navigate(play, to: target + SIMD2<Float>(0, -8_000))
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.nearbyDoor, 32)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        guard case .questions(let irisTopics) = play.runner.phase,
              irisTopics.contains(where: { $0.keyword == 17 }) else {
            return XCTFail("Expected Iris's wine question: \(play.runner.phase)")
        }
        play.ask(17)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertTrue(play.runner.game.keywordAsked(17, person: 9), "Iris's wine answer")
        let summerDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 27)
        try OriginalChapterThreeRouteChecks.navigate(play, to: summerDoor + SIMD2<Float>(0, -8_000))
        OriginalChapterThreeRouteChecks.face(play, x: summerDoor.x, z: summerDoor.y)
        XCTAssertEqual(play.nearbyDoor, 27)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        guard case .questions(let summerTopics) = play.runner.phase,
              let wineTopic = summerTopics.first(where: { $0.label.localizedCaseInsensitiveContains("wine") }) else {
            return XCTFail("Expected Summer's wine question: \(play.runner.phase)")
        }
        play.ask(wineTopic.keyword)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertTrue(play.runner.game.keywordAsked(Int(wineTopic.keyword), person: 8), "Summer's wine answer")
        for destination: Int16 in [17, 26, 6] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
        }
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(-50_000, 15_000))
        let kitchen = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(kitchen.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-wine-clues")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.useItem(play, 50, on: "obj06")
        XCTAssertEqual(play.runner.phase, .process(id: 46))
    }

    @MainActor func testChapterSixHelenStoryAndChapterSevenEntryFromHandoffSave() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-helen-room")).load() else {
            throw XCTSkip("Generate the Helen-room handoff save through the Chapter 6 route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        func assertChoiceIDs(_ expected: [UInt16]) {
            guard case .choice(let choices) = play.runner.phase else {
                XCTFail("Expected choices \(expected): \(play.runner.phase)")
                return
            }
            XCTAssertEqual(choices.map(\.id), expected)
        }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 28))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(66), "Helen's wine label handoff")
        try OriginalChapterThreeRouteChecks.talk(play, to: 7)
        play.ask(18)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.showItemInConversation(66)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.leaveConversation()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.choose(32)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.choose(34)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(19)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.choose(36)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(21)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(20)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.choose(38)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(22)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(23)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))

        let summerDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 27)
        try OriginalChapterThreeRouteChecks.navigate(play, to: summerDoor + SIMD2<Float>(0, -8_000), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: summerDoor.x, z: summerDoor.y)
        XCTAssertEqual(play.nearbyDoor, 27)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 35))
        try OriginalChapterThreeRouteChecks.picture(play, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(27), "Summer's fountain pen")
        try OriginalChapterThreeRouteChecks.exit(play, to: 28, interrupt: true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 7)
        play.showItemInConversation(27)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(25)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(24)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let review) = play.runner.phase else {
            return XCTFail("Expected the Chapter 6 memory review: \(play.runner.phase)")
        }
        XCTAssertEqual(review.map(\.id), [16, 17, 18])
        play.choose(17)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        assertChoiceIDs([19, 20, 21])
        play.choose(19)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        assertChoiceIDs([22, 23, 24])
        play.choose(24)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        assertChoiceIDs([25, 26, 27])
        play.choose(26)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        assertChoiceIDs([28, 29, 30])
        play.choose(28)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)

        XCTAssertEqual(play.chapterTransition?.stage, .prompt)
        XCTAssertEqual(play.runner.game.chapter, 6)
        XCTAssertEqual(play.runner.game.nowTime, 0)
        play.answerChapterSave(false)
        play.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-normal-entry")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenLeavesRoom215ForSecondFloorHallway() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-normal-entry")).load() else {
            throw XCTSkip("Complete the Chapter 6 review through the normal title transition first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.game.chapter, 6)
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-second-floor-hallway")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenReachesCentralHallwayFromSecondFloorHallway() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-second-floor-hallway")).load() else {
            throw XCTSkip("Leave Room 215 through the normal hallway route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        XCTAssertEqual(play.runner.program.name, "EP7_R117")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-central-hallway")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenReachesBarFromCentralHallway() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-central-hallway")).load() else {
            throw XCTSkip("Reach R117 from Room 215 through the normal Chapter 7 route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 26)
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 5)
        XCTAssertEqual(play.runner.program.name, "EP7_R105")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-bar")).save(play.walkingCheckpoint())
        XCTAssertTrue(play.lobby?.people(in: play.runner.game).contains { $0.id == 4 } == true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 4)
        guard case .choice(let drinks) = play.runner.phase else { return XCTFail("Expected Louie's drink menu") }
        XCTAssertEqual(drinks.map(\.label), ["Give me a scotch.", "I'll have a martini."])
        try OriginalChapterThreeRouteChecks.choose(play, "Give me a scotch.")
        guard case .choice(let secrets) = play.runner.phase else { return XCTFail("Expected Louie's follow-up choice") }
        XCTAssertEqual(secrets.map(\.label), ["Not this guy!", "I might..."])
        try OriginalChapterThreeRouteChecks.choose(play, "I might...")
        guard case .questions(let storyTopics) = play.runner.phase else { return XCTFail("Expected Louie's story topic") }
        XCTAssertEqual(storyTopics.map(\.label), ["What story did I tell you?"])
        play.ask(0)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let memoryChoices) = play.runner.phase else { return XCTFail("Expected Louie's story response") }
        XCTAssertEqual(memoryChoices.map(\.label), ["I don't remember this...", "I yelled at you, huh?"])
        try OriginalChapterThreeRouteChecks.choose(play, "I don't remember this...")
        guard case .questions(let fatherTopics) = play.runner.phase else { return XCTFail("Expected Louie's father topic") }
        XCTAssertEqual(fatherTopics.map(\.label), ["I told you about my father?"])
        play.ask(1)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let beliefTopics) = play.runner.phase else { return XCTFail("Expected Louie's belief topic") }
        XCTAssertEqual(beliefTopics.map(\.label), ["You believed my story?"])
        play.ask(2)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let beliefChoices) = play.runner.phase else { return XCTFail("Expected Louie's belief response") }
        XCTAssertEqual(beliefChoices.map(\.label), ["...It's a lie.", "It's true."])
        try OriginalChapterThreeRouteChecks.choose(play, "It's true.")
        guard case .choice(let bowlingChoices) = play.runner.phase else { return XCTFail("Expected Louie's bowling prompt") }
        XCTAssertEqual(bowlingChoices.map(\.label), ["I don't get it.", "I REALLY don't get it."])
        try OriginalChapterThreeRouteChecks.choose(play, "I don't get it.")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        try OriginalChapterThreeRouteChecks.talk(play, to: 8)
        guard case .choice(let summerTopics) = play.runner.phase else { return XCTFail("Expected Summer's topic choice") }
        XCTAssertEqual(summerTopics.map(\.label), ["Talk about Alan.", "Talk about plagiarism."])
        try OriginalChapterThreeRouteChecks.choose(play, "Talk about Alan.")
        guard case .choice(let summerTruth) = play.runner.phase else { return XCTFail("Expected Summer's truth choice") }
        XCTAssertEqual(summerTruth.map(\.label), ["I'll tell him the truth.", "I better lie to him."])
        try OriginalChapterThreeRouteChecks.choose(play, "I'll tell him the truth.")
        guard case .questions(let summerNews) = play.runner.phase else { return XCTFail("Expected Summer's news topic") }
        XCTAssertEqual(summerNews.map(\.label), ["What do you want to talk about?"])
        play.ask(3)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let cecilyTopic) = play.runner.phase else { return XCTFail("Expected Summer's Cecily topic") }
        XCTAssertEqual(cecilyTopic.map(\.label), ["Who is Cecily Lee?"])
        play.ask(4)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        XCTAssertEqual(play.runner.game.nowTime, 0)
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 26)
        XCTAssertEqual(play.runner.program.name, "EP7_R126")
        XCTAssertTrue(play.lobby?.people(in: play.runner.game).contains { $0.id == 11 } == true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 11)
        guard case .choice(let presents) = play.runner.phase else { return XCTFail("Expected Melissa's presents choice") }
        XCTAssertEqual(presents.map(\.label), ["I'm not a presents guy.", "Oh, yeah. Tons."])
        try OriginalChapterThreeRouteChecks.choose(play, "I'm not a presents guy.")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        let rosaRegion = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "event03" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2(Float(rosaRegion.worldFixed[12]), Float(rosaRegion.worldFixed[14])), interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let rosaTopics) = play.runner.phase else { return XCTFail("Expected Rosa's Melissa response") }
        XCTAssertEqual(rosaTopics.map(\.label), ["Her dad's a jerk.", "She misses her mom."])
        try OriginalChapterThreeRouteChecks.choose(play, "She misses her mom.")
        XCTAssertEqual(play.runner.phase, .questions([]))
        play.leaveConversation()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let treeChoices) = play.runner.phase else { return XCTFail("Expected Rosa's tree answer") }
        XCTAssertEqual(treeChoices.map(\.label), ["She didn't get one.", "Don't know. Don't care."])
        try OriginalChapterThreeRouteChecks.choose(play, "She didn't get one.")
        XCTAssertEqual(play.runner.game.nowTime, 1)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-after-rosa")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 3)
        try OriginalChapterThreeRouteChecks.exit(play, to: 18, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 18)
        try OriginalChapterThreeRouteChecks.exit(play, to: 22, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 22)
        XCTAssertEqual(play.runner.program.name, "EP7_R122")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-storage")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenStorageSearchAreaFromCheckpoint() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-storage")).load() else {
            throw XCTSkip("Reach Chapter 7 storage through the normal route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(13598, -1065), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: 13598, z: -1065)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let hits = try stride(from: 8, to: 248, by: 8).flatMap { y in
            stride(from: 8, to: 184, by: 8).map { SIMD2<Float>(Float($0), Float(y)) }
        }.compactMap { try counter.pickedCounterNode(page: $0, visibleNodes: visible) }
        XCTAssertTrue(hits.contains { $0 == "obj01_08" })
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01_08", interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 55))
        let bagSearch = try XCTUnwrap(play.bagSearch)
        let library = try OriginalModelLibrary.bundled()
        let models = try ["p01", "p02", "p03", "kaban"].map {
            try library.load(path: "trick/bag/\($0).mdf")
        }
        let projection = try OriginalBagSearchProjection(models: models)
        let treeBox = try XCTUnwrap(bagSearch.objects.firstIndex { $0.type == 3 })
        let masks = try projection.objectMasks(process: bagSearch)
        let treeBoxMask = try XCTUnwrap(masks.first { $0.0 == treeBox }?.1)
        var startCandidate: (point: SIMD2<Float>, error: Int64)?
        for y in stride(from: max(0, Int(treeBoxMask.bounds.minY)),
                        to: min(256, Int(treeBoxMask.bounds.maxY.rounded(.up))), by: 2) {
            for x in stride(from: max(0, Int(treeBoxMask.bounds.minX)),
                            to: min(192, Int(treeBoxMask.bounds.maxX.rounded(.up))), by: 2) {
                let point = SIMD2<Float>(Float(x), Float(y))
                guard let depth = treeBoxMask.depth(at: point) else { continue }
                let frontDepth = masks.compactMap { $0.1.depth(at: point) }.min() ?? .infinity
                guard depth <= frontDepth, let plane = projection.planePointFixed(at: point) else { continue }
                let dx = Int64(bagSearch.objects[treeBox].positionFixed.x - plane.x)
                let dz = Int64(bagSearch.objects[treeBox].positionFixed.z - plane.y)
                let error = dx * dx + dz * dz
                if startCandidate == nil || error < startCandidate!.error {
                    startCandidate = (point, error)
                }
            }
        }
        let start = try XCTUnwrap(startCandidate?.point)
        let startPlane = try XCTUnwrap(projection.planePointFixed(at: start))
        let initialPosition = bagSearch.objects[treeBox].positionFixed
        let targetPlane = SIMD2(startPlane.x - initialPosition.x, startPlane.y - initialPosition.z)
        let clip = projection.viewProjection * SIMD4(Float(targetPlane.x) / 4096, 0,
                                                     Float(targetPlane.y) / 4096, 1)
        let target = SIMD2((clip.x / clip.w + 1) * 96, (1 - clip.y / clip.w) * 128)
        XCTAssertEqual(projection.planePointFixed(at: target), targetPlane)
        play.holdBagSearchTouch(x: start.x, y: start.y)
        play.holdBagSearchTouch(x: target.x, y: target.y)
        play.releaseBagSearchTouch()
        XCTAssertEqual(play.bagSearch?.phase, .found)
        play.openBagSearchMenu()
        for _ in 0..<70 where play.bagSearch != nil { play.advanceFrame() }
        XCTAssertNil(play.bagSearch)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 43))
        for _ in 0..<70 { play.advanceFrame() }
        let treeRenderer = try OriginalChristmasTreeRenderer(library: .bundled())
        for (slot, decoration) in try XCTUnwrap(play.christmasTree).decorationOrder.enumerated() {
            let tree = try XCTUnwrap(play.christmasTree)
            let centreX = 9 + slot * 17
            let start = try XCTUnwrap((232..<249).lazy.flatMap { y in
                (max(0, centreX - 8)..<min(192, centreX + 9)).lazy.map { SIMD2<Float>(Float($0), Float(y)) }
            }.first { treeRenderer.decoration(at: $0, process: tree) == decoration })
            let destination = OriginalChristmasTreeLayout.pageDecorationTargets[slot]
            play.holdChristmasTreeTouch(x: start.x, y: start.y)
            play.releaseChristmasTreeTouch(x: destination.x, y: destination.y)
        }
        XCTAssertEqual(play.christmasTree?.arrangement.decorationAtTarget.compactMap { $0 }, Array(0..<11))
        for _ in 0..<100 where play.christmasTree != nil { play.advanceFrame() }
        XCTAssertNil(play.christmasTree)
        XCTAssertEqual(play.runner.game.christmasTreeDecorationOrder, 0xE400)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        print("AFTER DECORATING TREE", play.runner.phase, play.runner.eventIndex as Any,
              play.runner.eventTrail, play.lobby?.people(in: play.runner.game) ?? [])
    }

    @MainActor func testChapterThreeFromPlayedCheckpoint() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let save = try OriginalChapterFileStore(directory: URL(fileURLWithPath: directory)).load(slot: 0) else {
            throw XCTSkip("Generate the Chapter 3 save with the full opening route first")
        }
        let audio = AudioController()
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(save, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        play.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.run(play)
    }

    @MainActor func testChapterThreeAfterDinner() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("dinner")).load() else {
            throw XCTSkip("Generate the dinner checkpoint through the full native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000))
        play.turnFirstPerson(by: atan2(64423 - (play.lobby?.position.x ?? 0), -28450 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17)
        if let mila = play.lobby?.people(in: play.runner.game).first(where: { $0.id == 5 }) {
            try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, mila.position.z - 8000))
            play.turnFirstPerson(by: atan2(mila.position.x - (play.lobby?.position.x ?? 0), mila.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
            play.talkToNearbyPerson()
            OriginalChapterThreeRouteChecks.drain(play)
        }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -48000), interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "Well...maybe...")
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 30000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8500, 30885), interrupt: true)
        try OriginalChapterThreeRouteChecks.door(play, destination: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-30000, -27000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-35000, 10000), interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "A free drink? I'm in!")
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-30000, -27000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000), interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 27))
        let penPoint = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Int>($0, y) }
        }.first { play.touchPicture?.contains(pageX: $0.x, pageY: $0.y) == true })
        play.activatePicture(pageX: penPoint.x, pageY: penPoint.y)
        for _ in 0..<100 where play.touchPicture != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000))
        play.turnFirstPerson(by: atan2(64423 - (play.lobby?.position.x ?? 0), -28450 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(27))
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-4000, 20000))
        play.turnFirstPerson(by: -.pi / 2 - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let boardPoint = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try ["obj01", "obj04", "obj05"].contains(counter.pickedCounterNode(page: $0, visibleNodes: visible) ?? "") })
        play.selectLobbyObject(x: boardPoint.x, y: boardPoint.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.closeup?.view.id, 171)
        play.useItemInCloseup(27)
        let chalk = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Int>($0, y) }
        }.first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == 2 })
        play.selectCloseupComponent(x: chalk.x, y: chalk.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.phase, .process(id: 42))
        for _ in 0..<65 { play.advanceFrame() }
        for x in stride(from: 45, through: 145, by: 4) {
            for y in stride(from: 80, through: 212, by: 4) where play.fountainPen?.phase == 1 && play.fountainPen?.stage == 0 {
                play.releaseFountainPenTouch(); play.advanceFrame()
                play.holdFountainPenTouch(x: 90, y: 140); play.advanceFrame()
                play.holdFountainPenTouch(x: Float(x), y: Float(y)); play.advanceFrame()
            }
        }
        play.releaseFountainPenTouch()
        for _ in 0..<200 where play.fountainPen?.stage != 2 || play.fountainPen?.phase != 2 { play.advanceFrame() }
        XCTAssertEqual(play.fountainPen?.phase, 2)
        XCTAssertEqual(play.fountainPen?.stage, 2)
        for _ in 0..<100 where play.fountainPen?.stage == 2 {
            play.releaseFountainPenTouch(); play.advanceFrame()
            play.holdFountainPenTouch(x: 96, y: 140); play.advanceFrame()
        }
        play.releaseFountainPenTouch()
        for _ in 0..<400 where play.fountainPen != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertNil(play.fountainPen)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 18)), true)
        if play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] {
            try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("pen"))
                .save(play.walkingCheckpoint())
        }

    }

    @MainActor func testChapterThreeAfterPen() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("pen")).load() else {
            throw XCTSkip("Generate the pen checkpoint through the native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 30000))
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8500, 30885))
        try OriginalChapterThreeRouteChecks.door(play, destination: 26)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(50000, -27000))
        let louie = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 4 }))
        play.turnFirstPerson(by: atan2(louie.position.x - (play.lobby?.position.x ?? 0), louie.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [])
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000))
        play.turnFirstPerson(by: atan2(64423 - (play.lobby?.position.x ?? 0), -28450 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -20000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -48000), interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(45000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(44332, -1676), interrupt: true)
        play.turnFirstPerson(by: .pi - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.nearbyDoor, 35)
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        play.showItemInConversation(24)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [23])
        XCTAssertEqual(play.runner.game.mapID, 35)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(0, -10000), interrupt: true)
        if let melissa = play.lobby?.people(in: play.runner.game).first(where: { $0.id == 11 }) {
            play.turnFirstPerson(by: atan2(melissa.position.x - (play.lobby?.position.x ?? 0), melissa.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
            play.talkToNearbyPerson()
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(37500, -23000), interrupt: true)
        play.turnFirstPerson(by: atan2(51033 - (play.lobby?.position.x ?? 0), -27394 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let puzzlePoint = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj05" })
        play.selectLobbyObject(x: puzzlePoint.x, y: puzzlePoint.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 285)
        let lid = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Int>($0, y) }
        }.first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == 1 })
        play.selectCloseupComponent(x: lid.x, y: lid.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 39))
        for _ in 0..<65 { play.advanceFrame() }
        for _ in 0..<20 {
            let puzzle = try XCTUnwrap(play.jigsaw)
            let index = try XCTUnwrap(puzzle.pieces.indices.filter { !puzzle.isPlaced($0) }
                .max { puzzle.pieces[$0].depth < puzzle.pieces[$1].depth })
            let centre = OriginalJigsawProjection.centre(puzzle.pieces[index])
            play.dragJigsaw(pageX: centre.x, pageY: centre.y)
            XCTAssertEqual(play.jigsaw?.selected, index)
            play.releaseJigsaw()
            for _ in 0..<2 { play.advanceFrame() }
            for _ in 0..<4 where play.jigsaw?.pieces[index].angle != 1.5 {
                play.rotateJigsaw(increasing: false)
                for _ in 0..<20 { play.advanceFrame() }
            }
            play.dragJigsaw(pageX: centre.x, pageY: centre.y)
            let target = OriginalJigsawProcess.target(index)
            play.dragJigsaw(pageX: 96 + Float(target.x + 2048) / 4096 * OriginalJigsawProjection.pixelsPerUnit,
                pageY: 128 - (Float(target.y + 2048) / 4096 + 0.5) * OriginalJigsawProjection.pixelsPerUnit)
            play.releaseJigsaw()
            XCTAssertEqual(play.jigsaw?.isPlaced(index), true)
            for _ in 0..<2 { play.advanceFrame() }
        }
        for _ in 0..<350 where play.jigsaw?.variant == .full { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 40))
        for _ in 0..<65 { play.advanceFrame() }
        play.receiveJigsawFold(isClosed: true)
        play.receiveJigsawFold(isClosed: false)
        for _ in 0..<500 where play.jigsaw != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 15)), true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 16)), true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: ["Easy! Don't scare Melissa."], topics: [2, 24])
        for _ in 0..<5 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        if play.runner.game.mapID == 35 {
            try OriginalChapterThreeRouteChecks.walk(play, to: .init(0, -10000), interrupt: true)
        }
        if play.runner.game.mapID == 35 {
            try OriginalChapterThreeRouteChecks.walk(play, to: .init(82, 3277), interrupt: true)
        }
        if play.runner.game.mapID == 35 {
            play.turnFirstPerson(by: -(play.lobby?.facing ?? 0))
            try OriginalChapterThreeRouteChecks.door(play, destination: 39, interrupt: true)
        }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(play.runner.game.nowTime, 3)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("jigsaw"))
            .save(play.walkingCheckpoint())

    }

    @MainActor func testChapterThreeAfterJigsaw() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("jigsaw")).load() else {
            throw XCTSkip("Generate the jigsaw checkpoint through the native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(45000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-77000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-77419, 11630), interrupt: true)
        play.turnFirstPerson(by: -(play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 31, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(0, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-10353, 8041), interrupt: true)
        play.turnFirstPerson(by: -(play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let box = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj02" })
        play.selectLobbyObject(x: box.x, y: box.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 47))
        for _ in 0..<65 { play.advanceFrame() }
        func press(_ point: SIMD2<Float>) {
            play.releaseBookmarkBoxTouch(); play.advanceFrame()
            play.holdBookmarkBoxTouch(x: point.x, y: point.y); play.advanceFrame()
            play.releaseBookmarkBoxTouch(); play.advanceFrame()
        }
        for point: SIMD2<Float> in [.init(16, 128), .init(96, 240), .init(16, 128)] {
            press(point)
            for _ in 0..<45 { play.advanceFrame() }
        }
        for _ in 0..<10 { press(.init(96, 128)) }
        press(.init(176, 128))
        for _ in 0..<45 { play.advanceFrame() }
        press(.init(96, 128))
        for _ in 0..<130 { play.advanceFrame() }
        XCTAssertEqual(play.bookmarkBox?.phase, 2)
        play.holdBookmarkBoxTouch(x: 50, y: 140); play.advanceFrame()
        for x in stride(from: 52, through: 150, by: 2) {
            play.holdBookmarkBoxTouch(x: Float(x), y: 140); play.advanceFrame()
        }
        play.releaseBookmarkBoxTouch()
        for _ in 0..<700 where play.bookmarkBox != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertNil(play.bookmarkBox)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 23)), true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(25))
        for _ in 0..<5 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("bookmark"))
            .save(play.walkingCheckpoint())
    }

    @MainActor func testChapterThreeAfterBookmark() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("bookmark")).load() else {
            throw XCTSkip("Generate the bookmark checkpoint through the native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(0, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(9994, -15811), interrupt: true)
        play.turnFirstPerson(by: .pi - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-77000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(87000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(87270, 10765), interrupt: true)
        play.turnFirstPerson(by: -(play.lobby?.facing ?? 0))
        XCTAssertEqual(play.nearbyDoor, 27)
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        play.showItemInConversation(25)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: ["Angel Opening a Door?"], topics: [21, 22])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertTrue(play.runner.game.keywordAsked(21, person: 8))
        XCTAssertTrue(play.runner.game.keywordAsked(22, person: 8))
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(87000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(16000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, -1500), interrupt: true)
        play.turnFirstPerson(by: .pi - (play.lobby?.facing ?? 0))
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
            play.leaveDoor()
        }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(20700, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(20700, -48000), interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 30000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8500, 30885), interrupt: true)
        try OriginalChapterThreeRouteChecks.door(play, destination: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(50000, -27000), interrupt: true)
        let louie = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 4 }))
        play.turnFirstPerson(by: atan2(louie.position.x - (play.lobby?.position.x ?? 0), louie.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: ["I know enough."], topics: [])
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000), interrupt: true)
        play.turnFirstPerson(by: atan2(64423 - (play.lobby?.position.x ?? 0), -28450 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -27000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8110, -27116), interrupt: true)
        play.turnFirstPerson(by: -.pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 19, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5000, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5249, -53128), interrupt: true)
        play.turnFirstPerson(by: .pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 9, interrupt: true)
        print("AT ELECTRICAL ROOM", play.runner.phase, play.lobby?.position as Any)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 9))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("electrical"))
            .save(play.walkingCheckpoint())
    }

    @MainActor func testChapterThreeElectricalRescue() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("electrical")).load() else {
            throw XCTSkip("Generate the electrical-room checkpoint through the native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(12533, -10453), interrupt: true)
        play.turnFirstPerson(by: .pi / 2 - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let panel = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj01" })
        play.selectLobbyObject(x: panel.x, y: panel.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 41))
        for _ in 0..<65 { play.advanceFrame() }
        for point: SIMD2<Float> in [.init(48, 170), .init(96, 170), .init(96, 160)] {
            play.holdSwitchboardTouch(x: point.x, y: point.y); play.advanceFrame()
        }
        play.releaseSwitchboardTouch()
        for _ in 0..<400 where play.switchboard != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 17)), true)
        for _ in 0..<5 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5652, 0), interrupt: true)
        play.turnFirstPerson(by: -.pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 19, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5000, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(25289, 0), interrupt: true)
        play.turnFirstPerson(by: .pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -27000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -48000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(16000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, -1500), interrupt: true)
        play.turnFirstPerson(by: .pi - (play.lobby?.facing ?? 0))
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        XCTAssertEqual(play.runner.phase, .process(id: 77))
        for _ in 0..<65 { play.advanceFrame() }
        let paths: [[SIMD2<Float>]] = [
            [.init(88, 121), .init(84, 121), .init(84, 86)],
            [.init(88, 106), .init(84, 118), .init(124, 118)],
            [.init(104, 88), .init(155, 98), .init(155, 138), .init(108, 138), .init(108, 180)],
            [.init(88, 154), .init(110, 154), .init(110, 138), .init(70, 138)]
        ]
        let frames = [[4, 4, 40], [4, 4, 40], [1, 24, 16, 18, 40], [1, 12, 8, 40]]
        for index in 0..<4 {
            play.releaseThinWireTouch(); play.advanceFrame()
            for (step, point) in paths[index].enumerated() {
                play.holdThinWireTouch(x: point.x, y: point.y)
                for _ in 0..<frames[index][step] where play.thinWire?.pins[index].reached == false { play.advanceFrame() }
            }
            XCTAssertEqual(play.thinWire?.pins[index].reached, true)
        }
        play.releaseThinWireTouch()
        for _ in 0..<400 where play.thinWire != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 53)), true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [])
        if play.door != nil { play.leaveDoor() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.runner.game.mapID == 39 { try OriginalChapterThreeRouteChecks.door(play, destination: 34, interrupt: true) }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 34))
        XCTAssertFalse(try play.runner.game.inventory.items.contains(16))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("rescue"))
            .save(play.walkingCheckpoint())
    }

    @MainActor func testChapterThreeMelissaAfterRescue() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("rescue")).load() else {
            throw XCTSkip("Generate the rescued-room checkpoint through the native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        let melissa = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 11 }))
        print("RESCUED MELISSA", melissa.position)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(melissa.position.x, melissa.position.z + 8500), interrupt: true)
        play.turnFirstPerson(by: atan2(melissa.position.x - (play.lobby?.position.x ?? 0), melissa.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [
            "Things aren't going well?", "Why do you think that?", "Did Dad know this place?",
            "He hated to see you sad.", "It wasn't your fault.", "I'm sure your dad knows."
        ], topics: Array(0..<128))
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 34))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("melissa"))
            .save(play.walkingCheckpoint())
    }

    @MainActor func testChapterThreeRooftopAfterMelissa() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("melissa")).load() else {
            throw XCTSkip("Generate the post-Melissa checkpoint through the native route first")
        }
        let audio = AudioController(); audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(82, 6308), interrupt: true)
        play.turnFirstPerson(by: 0 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(48000, 7000), interrupt: true)
        let kevin = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 10 }))
        play.turnFirstPerson(by: atan2(kevin.position.x - (play.lobby?.position.x ?? 0), kevin.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: Array(0..<128))
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(148877, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(148877, 4638), interrupt: true)
        play.turnFirstPerson(by: .pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 45, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 45)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(103055, 50000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8848, 50000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8848, 59000), interrupt: true)
        let iris = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 9 }))
        play.turnFirstPerson(by: atan2(iris.position.x - (play.lobby?.position.x ?? 0), iris.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        let answers = ["Just needed some air.", "You need air too?", "Melissa", "A bookmark", "Osterzone", "Room 218", "On the roof"]
        for _ in 0..<20 where play.chapterTransition == nil {
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
            if play.chapterTransition != nil { break }
            guard case .choice(let choices) = play.runner.phase,
                  let choice = choices.first(where: { answers.contains($0.label) }) else {
                throw OriginalDataError.invalid("Rooftop/review stopped: \(play.runner.phase)")
            }
            play.choose(choice.id)
        }
        XCTAssertEqual(play.chapterTransition?.stage, .prompt)
        XCTAssertEqual(play.runner.game.chapter, 3)
        let chapter = try OriginalChapterSave(game: play.runner.game, savedAt: Date())
        try OriginalChapterFileStore(directory: URL(fileURLWithPath: directory)).save(chapter, slot: 2)
        play.answerChapterSave(false)
        play.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        print("CHAPTER FOUR", play.runner.phase, play.lobby?.position as Any)

    }

    @MainActor func testLouieEndingFromPlayedCheckpoint() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let save = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("louie")).load() else {
            throw XCTSkip("Generate the checkpoint with the full opening route first")
        }
        let audio = AudioController()
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(save, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        try OriginalLouieRoomRouteChecks.finishConversation(play)
    }
}
