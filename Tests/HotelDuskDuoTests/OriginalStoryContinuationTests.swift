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
