import simd
import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterReviewTests: XCTestCase {
    private func state(_ path: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original review capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func advance(_ runner: inout OriginalEventRunner) {
        for _ in 0..<600 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: return
            }
        }
        XCTFail("The review dialogue did not finish")
    }

    private func beginCall() throws -> OriginalEventRunner {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: state("order-leave-parcel/inspect"))
        runner.lookInSearchView(area: 1, subarea: 1, table: try .bundled(map: "R205"))
        XCTAssertEqual(runner.eventIndex, 121)
        advance(&runner)
        return runner
    }

    private func compare(_ runner: OriginalEventRunner, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try state(path).bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], file: file, line: line)
    }

    func testCallAndReviewAnswersMatchOriginalState() throws {
        var runner = try beginCall()
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected the first review question: \(runner.phase)") }
        XCTAssertEqual(choices.map(\.id), [60, 61, 62])
        XCTAssertEqual(runner.reviewQuestionIndex, 0)
        try compare(runner, "order-rachel-call/page55")
        runner.choose(61)
        advance(&runner)
        guard case .choice(let next) = runner.phase else { return XCTFail("Expected the second review question: \(runner.phase)") }
        XCTAssertEqual(next.map(\.id), [63, 64, 65])
        XCTAssertEqual(runner.reviewQuestionIndex, 1)
        try compare(runner, "chapter-one-review-first/page18")
        runner.choose(63)
        advance(&runner)
        guard case .choice(let third) = runner.phase else { return XCTFail("Expected the third review question") }
        XCTAssertEqual(third.map(\.id), [66, 67, 68])
        XCTAssertEqual(runner.reviewQuestionIndex, 2)
        try compare(runner, "chapter-one-review-second/page24")
        runner.choose(68)
        advance(&runner)
        guard case .choice(let fourth) = runner.phase else { return XCTFail("Expected the fourth review question") }
        XCTAssertEqual(fourth.map(\.id), [69, 70, 71])
        XCTAssertEqual(runner.reviewQuestionIndex, 3)
        try compare(runner, "chapter-one-review-third/page20")
        runner.choose(70)
        advance(&runner)
        guard case .choice(let last) = runner.phase else { return XCTFail("Expected the last review question") }
        XCTAssertEqual(last.map(\.id), [72, 73, 74])
        XCTAssertEqual(runner.reviewQuestionIndex, 4)
        try compare(runner, "chapter-one-review-fourth/page24")
    }

    func testAllChapterReviewTablesDecode() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        for chapter in 1...9 {
            let table = try OriginalChapterReview(decoded: catalog.decodedFile("EP\(chapter)_.spn"))
            XCTAssertFalse(table.questions.isEmpty)
            XCTAssertEqual(table.questions.last?.nextEvent, .max)
            XCTAssertTrue(table.questions.allSatisfy { $0.answers.contains { $0.advances } })
        }
        XCTAssertTrue(try catalog.decodedFile("EP10_.spn").isEmpty)
    }

    @MainActor func testChapterNineReviewStartsChapterTenInR108() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        try game.beginChapter(8)
        game.setMap(7, previous: 1)
        try game.apply(.addInventory(id: 41))
        try game.apply(.addInventory(id: 60))
        var bytes = Data(game.bytes)
        bytes[2] = 4
        bytes[3] = 0
        game = try OriginalGameState(snapshot: bytes)

        let selection = OriginalEventSelectionContext(sceneID: 1, blockID: 0, modeID: 24,
            eventID: 2, nowTime: 4, mapID: 7)
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP9_R107"), game: game,
            selection: selection)
        advance(&runner)

        for (index, answer) in [UInt16(5), 7, 12, 14, 16].enumerated() {
            guard case .choice(let choices) = runner.phase else {
                return XCTFail("Expected Chapter 9 review question \(index + 1): \(runner.phase)")
            }
            XCTAssertTrue(choices.contains { $0.id == answer })
            runner.choose(answer)
            advance(&runner)
        }
        while case .picture = runner.phase {
            runner.finishPicture()
            advance(&runner)
        }

        XCTAssertEqual(runner.reviewQuestionIndex, 5)
        XCTAssertTrue(runner.processRequests.contains(.init(kind: 4, value: 9)))
        XCTAssertEqual(runner.game.chapter, 8)
        let exploration = try OriginalMapExploration.bundled(mapID: 7,
            previousMapID: runner.game.previousMapID, savedGame: runner.game)

        let play = OriginalPlaySession(runner: runner, audio: originalRouteTestAudio(), catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)), restoredExploration: exploration,
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        XCTAssertEqual(play.chapterTransition?.stage, .prompt)
        XCTAssertEqual(play.runner.game.chapter, 9)
        play.answerChapterSave(false)
        XCTAssertEqual(play.chapterTransition?.stage, .title)
        play.continueChapterTitle()
        XCTAssertEqual(play.runner.program.name, "EP10_R108")
        for _ in 0..<200 where play.runner.phase != .exploration(mapID: 8) {
            switch play.runner.phase {
            case .dialogue, .itemNotice:
                play.advanceDialogue()
            case .waiting:
                play.advanceFrame()
            default:
                XCTFail("Chapter 10 entry stopped at \(play.runner.phase)")
                return
            }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 8))
    }

    @MainActor func testChapterTenCellarBottleEventUsesHitMaskAndInstantSave() throws {
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(9)
        game.setMap(8, previous: 7)
        game.setMapPosition(SIMD3(5259, 12288, 4761), facing: 0)
        var bytes = Data(game.bytes)
        let cellarReadyFlagOffset = 0xD15 + 8 * 32 + 9 / 8
        bytes[cellarReadyFlagOffset] |= 1 << (9 % 8)
        game = try OriginalGameState(snapshot: bytes)

        let seed = try OriginalResumeSave(game: game, checkpointFacing: 0,
            musicSequenceID: nil, savedAt: Date(timeIntervalSince1970: 100))
        let play = try OriginalPlaySession.restoring(seed, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.enableInstantSaves()
        var instantCheckpoint: OriginalResumeSave?
        play.onProgressCheckpoint = { instantCheckpoint = $0 }

        let cellar = try XCTUnwrap(play.lobby)
        let shelfMarker = try XCTUnwrap(cellar.room.nodes.first { $0.name == "s01" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2(Float(shelfMarker.worldFixed[12]), Float(shelfMarker.worldFixed[14])))
        OriginalChapterThreeRouteChecks.face(play, x: Float(shelfMarker.worldFixed[12]), z: Float(shelfMarker.worldFixed[14]))
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let points = stride(from: 0, to: 256, by: 4)
            .flatMap { y in stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) } }
        let picks = try points.compactMap { point in
            try counter.pickedCounterNode(page: point, visibleNodes: visible).map { ($0, point) }
        }
        let target = try XCTUnwrap(picks.first { $0.0 == "obj21" }?.1)
        play.selectLobbyObject(x: target.x, y: target.y, confirmImmediately: true)
        XCTAssertEqual(play.runner.program.name, "EP10_R108")
        XCTAssertNotNil(play.runner.eventIndex)
        XCTAssertEqual(play.runner.session.selection.modeID, 10)
        XCTAssertEqual(play.runner.session.selection.areaID, 1)
        XCTAssertEqual(play.runner.session.selection.subareaID, 21)
        guard case .dialogue = play.runner.phase else {
            return XCTFail("The cellar bottle response did not start: \(play.runner.phase)")
        }
        XCTAssertNotNil(instantCheckpoint?.progress, "The normal object selection should be saved immediately")
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(77))
        let secondBottleMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s02" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2(Float(secondBottleMarker.worldFixed[12]), Float(secondBottleMarker.worldFixed[14])))
        OriginalChapterThreeRouteChecks.face(play,
            x: Float(secondBottleMarker.worldFixed[12]), z: Float(secondBottleMarker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        play.inspectLobbyCounter()
        let secondCounter = try XCTUnwrap(play.lobby)
        let secondVisible = secondCounter.objectVisibility.visibleNodes(in: secondCounter.counter,
            map: secondCounter.mapID, area: secondCounter.searchAreaID, game: play.runner.game)
        let secondTarget = try XCTUnwrap(try stride(from: 0, to: 256, by: 4)
            .flatMap { y in stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) } }
            .first { try secondCounter.pickedCounterNode(page: $0, visibleNodes: secondVisible) == "obj22" })
        play.useItemInSearchView(77)
        play.selectLobbyObject(x: secondTarget.x, y: secondTarget.y, confirmImmediately: true)
        XCTAssertEqual(play.runner.program.name, "EP10_R108")
        XCTAssertEqual(play.runner.session.selection.modeID, 16)
        XCTAssertEqual(play.runner.session.selection.areaID, 2)
        XCTAssertEqual(play.runner.session.selection.subareaID, 22)
        guard case .dialogue = play.runner.phase else {
            return XCTFail("The second bottle response did not start: \(play.runner.phase)")
        }
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(82),
            "Filling the second bottle should produce the full bottle item")
        let shelfCabinetMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s03" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2(Float(shelfCabinetMarker.worldFixed[12]), Float(shelfCabinetMarker.worldFixed[14])))
        OriginalChapterThreeRouteChecks.face(play,
            x: Float(shelfCabinetMarker.worldFixed[12]), z: Float(shelfCabinetMarker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let bottleCase = try XCTUnwrap(play.lobby)
        let bottleCaseVisible = bottleCase.objectVisibility.visibleNodes(in: bottleCase.counter,
            map: bottleCase.mapID, area: bottleCase.searchAreaID, game: play.runner.game)
        let bottleCaseTarget = try XCTUnwrap(try stride(from: 0, to: 256, by: 4)
            .flatMap { y in stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) } }
            .first { try bottleCase.pickedCounterNode(page: $0, visibleNodes: bottleCaseVisible) == "obj09" })
        play.useItemInSearchView(82)
        play.selectLobbyObject(x: bottleCaseTarget.x, y: bottleCaseTarget.y, confirmImmediately: true)
        XCTAssertEqual(play.runner.program.name, "EP10_R108")
        XCTAssertEqual(play.runner.session.selection.modeID, 16)
        XCTAssertEqual(play.runner.session.selection.areaID, 3)
        XCTAssertEqual(play.runner.session.selection.subareaID, 9)
        guard case .dialogue = play.runner.phase else {
            return XCTFail("The full bottle did not reach the back shelf: \(play.runner.phase)")
        }
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 59)), true)
        let shelfSearch = try XCTUnwrap(play.lobby)
        let shelfVisible = shelfSearch.objectVisibility.visibleNodes(in: shelfSearch.counter,
            map: shelfSearch.mapID, area: shelfSearch.searchAreaID, game: play.runner.game)
        let shelfTarget = try XCTUnwrap(try stride(from: 0, to: 256, by: 4)
            .flatMap { y in stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) } }
            .first { try shelfSearch.pickedCounterNode(page: $0, visibleNodes: shelfVisible) == "obj01" })
        play.selectLobbyObject(x: shelfTarget.x, y: shelfTarget.y, confirmImmediately: true)
        XCTAssertEqual(play.runner.program.name, "EP10_R108")
        XCTAssertEqual(play.runner.session.selection.modeID, 3)
        XCTAssertEqual(play.runner.eventIndex, 20)
        guard case .dialogue = play.runner.phase else {
            return XCTFail("Opening the cellar shelf did not start its passage dialogue: \(play.runner.phase)")
        }
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.game.mapID, 8)
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 31)), true)
        let openedCellar = try XCTUnwrap(play.lobby)
        XCTAssertTrue(openedCellar.room.nodes.contains { $0.name == "in_r304" },
            "The cellar-ready state should load the alternate room with its underpass exit")
        let startMarker = try XCTUnwrap(openedCellar.room.nodes.first { $0.name == "hyde_point00" })
        XCTAssertEqual(openedCellar.position.x, Float(startMarker.worldFixed[12]))
        XCTAssertEqual(openedCellar.position.z, Float(startMarker.worldFixed[14]))
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] {
            try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("chapter10-cellar-passage"))
                .save(try play.progressCheckpoint())
        }
    }

    @MainActor func testChapterTenCellarPassageCheckpointRestoresAlternateRoom() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-cellar-passage")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()

        XCTAssertEqual(play.runner.game.mapID, 8)
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 31)), true)
        let lobby = try XCTUnwrap(play.lobby)
        XCTAssertTrue(lobby.room.nodes.contains { $0.name == "in_r304" })
        XCTAssertTrue(lobby.collision.disabledDoorMarkers.contains("in_r304"))
        let startMarker = try XCTUnwrap(lobby.room.nodes.first { $0.name == "hyde_point00" })
        XCTAssertEqual(lobby.position.x, Float(startMarker.worldFixed[12]))
        XCTAssertEqual(lobby.position.z, Float(startMarker.worldFixed[14]))
    }

    @MainActor func testChapterTenCellarPassageExitsToR304ThroughNormalMovement() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-cellar-passage")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()

        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(11_854, -5_242))
        if play.runner.game.mapID == 8 {
            try OriginalChapterThreeRouteChecks.walk(play, to: SIMD2(11_854, -5_242))
        }
        XCTAssertEqual(play.runner.game.mapID, 43)
        XCTAssertEqual(play.lobby?.mapName, "R304")
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] {
            try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-r304-entry")).save(try play.progressCheckpoint())
        }
    }

    @MainActor func testChapterTenR304BarUnlocksR301DoorThroughNormalInput() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-entry-normal")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(68_239, -47_186))
        OriginalChapterThreeRouteChecks.face(play, x: 68_239, z: -47_186)
        XCTAssertEqual(play.nearbyDoor, 40)
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play)
        if let point = stride(from: 8, to: 248, by: 2).flatMap({ y in stride(from: 8, to: 184, by: 2).map { ($0, y) } })
            .first(where: { play.doorImage?.hit(pageX: $0.0, pageY: $0.1) == 3 }) {
            play.selectDoorComponent(x: point.0, y: point.1, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play)
        } else {
            XCTFail("The cellar bar has no hit mask")
        }
        XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 42)), false)
        XCTAssertTrue((8..<184).contains { x in (8..<248).contains { y in play.doorImage?.hit(pageX: x, pageY: y) == 2 } },
            "The removed plate should expose the handle hit mask")
        try OriginalChapterThreeRouteChecks.door(play, destination: 40)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.game.mapID, 40)
        XCTAssertEqual(play.lobby?.mapName, "R301")
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] {
            try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-r301-entry")).save(try play.progressCheckpoint())
        }
    }

    @MainActor func testChapterTenR301CounterOneCheckpointFromNormalSearch() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        let lobby = try XCTUnwrap(play.lobby)
        var targets = [String: SIMD2<Float>]()
        for x in stride(from: -60_000, through: 60_000, by: 2_048) {
            for z in stride(from: -60_000, through: 60_000, by: 2_048) {
                let point = SIMD3<Float>(Float(x), lobby.position.y, Float(z))
                for region in lobby.collision.matchingRegions(containing: point, prefix: "search") {
                    guard targets[region] == nil, lobby.collision.resolve(point) == point else { continue }
                    targets[region] = SIMD2(Float(x), Float(z))
                }
            }
        }
        let target = try XCTUnwrap(targets["search01"])
        try OriginalChapterThreeRouteChecks.navigate(play, to: target)
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01")
        XCTAssertEqual(play.runner.phase, .process(id: 86))
        play.quitTypewriter()
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj02")
        XCTAssertEqual(play.runner.game.bytes[0x1380], 1)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-counter1")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR301DeskReachesTheFiveLookStoryGate() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.enableInstantSaves()
        var instantCheckpoint: OriginalResumeSave?
        play.onProgressCheckpoint = { instantCheckpoint = $0 }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-14_944, -8_800))
        let clueMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play,
            x: Float(clueMarker.worldFixed[12]), z: Float(clueMarker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01_01")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        XCTAssertEqual(play.runner.game.bytes[0x1380], 1)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 98)), true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 101)), true)
        for _ in 1...14 {
            try OriginalChapterThreeRouteChecks.search(play, node: "obj01_01")
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        XCTAssertEqual(play.runner.game.bytes[0x1380], 15)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 104)), true)
        XCTAssertNotNil(instantCheckpoint?.progress, "Every desk action should save immediately")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-counter15")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR301CableHitSavesAfterCounterCameraPan() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-counter15")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.enableInstantSaves()
        var instantCheckpoint: OriginalResumeSave?
        play.onProgressCheckpoint = { instantCheckpoint = $0 }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-2_656, -25_184))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.search(play, node: "obj04")
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 390)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(71), "The toolbox should add the Hammer")
        XCTAssertNotNil(instantCheckpoint?.progress, "Taking the Hammer should save immediately")

        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-2_656, -25_184))
        let cableMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(cableMarker.worldFixed[12]), z: Float(cableMarker.worldFixed[14]))
        play.inspectLobbyCounter()
        var cablePoint: SIMD2<Float>?
        for step in 0...20 where cablePoint == nil {
            play.panLobbyCounter(Float(step) / 20)
            guard let scene = play.lobby else { continue }
            let visible = scene.objectVisibility.visibleNodes(in: scene.counter, map: 40, area: 1, game: play.runner.game)
            cablePoint = try stride(from: 8, to: 248, by: 4).flatMap { y in
                stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
            }.first { try scene.pickedCounterNode(page: $0, visibleNodes: visible) == "obj08" }
        }
        let point = try XCTUnwrap(cablePoint, "The cable needs a selectable object mask from a counter camera angle")
        play.selectLobbyObject(x: point.x, y: point.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        XCTAssertEqual(play.runner.session.selection.areaID, 1)
        XCTAssertEqual(play.runner.session.selection.subareaID, 8)
        let saved = try XCTUnwrap(instantCheckpoint, "Inspecting the cable should save immediately")
        XCTAssertNotNil(saved.progress)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-cable-look")).save(saved)
    }

    @MainActor func testChapterTenR301PencilUseWaitsForEvent27FromNormalInput() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let traceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-r301-pencil-gate-\(UUID().uuidString).jsonl")
        try play.enableRouteTracing(to: traceURL, runID: "r301-pencil-gate",
                                    checkpointName: "chapter10-r301-entry")
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 27)), false)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-2_656, -25_184))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.search(play, node: "obj06")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        XCTAssertEqual(play.closeup?.view.id, 395)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 396, item: 44)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40), "The source event is gated until R301 event 27 completes")
        XCTAssertNil(play.pencilSharpener)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 27)), false)
        XCTAssertFalse(try play.runner.game.inventory.items.contains(70))
        let trace = try String(contentsOf: traceURL, encoding: .utf8)
        XCTAssertTrue(trace.contains("\"candidateEventIndex\":\"13\""))
        XCTAssertTrue(trace.contains("\"conditionResult\":\"fail(sourceOffset: 2512)\""))
    }

    @MainActor func testChapterTenR301PlugInspectionOpensPencilGateFromNormalInput() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.enableInstantSaves()
        var instantCheckpoint: OriginalResumeSave?
        play.onProgressCheckpoint = { instantCheckpoint = $0 }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 22)), false)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-2_656, -25_184))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))

        play.inspectLobbyCounter()
        var plugPoint: SIMD2<Float>?
        for step in 0...20 where plugPoint == nil {
            play.panLobbyCounter(Float(step) / 20)
            guard let scene = play.lobby else { continue }
            let visible = scene.objectVisibility.visibleNodes(in: scene.counter, map: 40, area: 1,
                                                               game: play.runner.game)
            plugPoint = try stride(from: 8, to: 248, by: 4).flatMap { y in
                stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
            }.first { try scene.pickedCounterNode(page: $0, visibleNodes: visible) == "obj08" }
        }
        let point = try XCTUnwrap(plugPoint, "The plug needs the counter camera pan to become selectable")
        play.selectLobbyObject(x: point.x, y: point.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.closeup?.view.id, 398)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 400)
        XCTAssertEqual(Array(play.runner.eventTrail.suffix(2)), [25, 27])
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 27)), true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 22)), false)
        XCTAssertNil(play.runner.eventIndex)

        play.leaveSearchCloseup()
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-2_656, -25_184))
        let toolboxMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(toolboxMarker.worldFixed[12]),
                                             z: Float(toolboxMarker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.search(play, node: "obj04")
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 390)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(71),
                      "The normal R301 toolbox route must add the Hammer")
        play.leaveSearchCloseup()
        try OriginalChapterThreeRouteChecks.search(play, node: "obj06")
        XCTAssertEqual(play.closeup?.view.id, 395)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 396, item: 44)
        XCTAssertEqual(play.runner.phase, .process(id: 59))
        XCTAssertNotNil(play.pencilSharpener)
        XCTAssertNotNil(instantCheckpoint?.progress)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-pencil-process")).save(try play.progressCheckpoint())

        for _ in 0..<6 {
            play.holdPencilSharpenerTouch(pageX: 91, pageY: 100)
            play.holdPencilSharpenerTouch(pageX: 121, pageY: 70)
            play.holdPencilSharpenerTouch(pageX: 91, pageY: 100)
            play.releasePencilSharpenerTouch()
        }
        play.advanceFrame()
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(70),
                      "Repeated pencil strokes should return result 0 and award Graphite Powder")
        guard case .exploration(mapID: 40) = play.runner.phase else {
            return XCTFail("Process 59 result 0 should return to R301 exploration")
        }

        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-2_656, -25_184))
        let resultMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(resultMarker.worldFixed[12]),
                                             z: Float(resultMarker.worldFixed[14]))
        play.inspectLobbyCounter()
        var powderTarget: (point: SIMD2<Float>, pan: Float)?
        for step in 0...20 where powderTarget == nil {
            let pan = Float(step) / 20
            play.panLobbyCounter(pan)
            guard let scene = play.lobby else { continue }
            let visible = scene.objectVisibility.visibleNodes(in: scene.counter, map: 40, area: 1,
                                                               game: play.runner.game)
            let point = try stride(from: 8, to: 248, by: 4).flatMap { y in
                stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
            }.first { try scene.pickedCounterNode(page: $0, visibleNodes: visible) == "obj08" }
            if let point { powderTarget = (point, pan) }
        }
        let target = try XCTUnwrap(powderTarget)
        play.panLobbyCounter(target.pan)
        play.useItemInSearchView(70)
        play.selectLobbyObject(x: target.point.x, y: target.point.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play)
        if case .picture = play.runner.phase {
            let point = try XCTUnwrap(stride(from: 8, to: 184, by: 2).flatMap { x in
                stride(from: 8, to: 248, by: 2).map { SIMD2<Int>(x, $0) }
            }.first { play.touchPicture?.contains(pageX: $0.x, pageY: $0.y) == true })
            play.activatePicture(pageX: point.x, pageY: point.y)
            for _ in 0..<24 { play.advanceFrame() }
            OriginalChapterThreeRouteChecks.drain(play)
        }
        XCTAssertEqual(play.runner.session.selection.areaID, 1)
        XCTAssertEqual(play.runner.session.selection.subareaID, 8)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 22)), true)
        XCTAssertFalse(try play.runner.game.inventory.items.contains(70))
        play.leaveLobbyCounter()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-powder-used")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR301PowderUnlocksTypewriterFromNormalInput() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-powder-used")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let traceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-r301-powder-used-\(UUID().uuidString).jsonl")
        try play.enableRouteTracing(to: traceURL, runID: "r301-powder-used",
                                    checkpointName: "chapter10-r301-powder-used")
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 22)), true)
        XCTAssertFalse(try play.runner.game.inventory.items.contains(70))

        try OriginalChapterThreeRouteChecks.search(play, node: "obj01")
        XCTAssertEqual(play.runner.phase, .process(id: 74))
        XCTAssertNotNil(play.typewriter)

        let cipher = try XCTUnwrap(play.typewriter?.cipher)
        play.adjustTypewriterShift(by: cipher.expectedShift)
        for answer in ["OSTERZONE IS", "DUNNING SMITH"] {
            for character in answer {
                let encoded: Character
                if character == " " {
                    encoded = "s"
                } else {
                    let base = Int(character.asciiValue ?? 0)
                    let shifted = (base - 65 + cipher.expectedShift) % 26 + 65
                    encoded = Character(UnicodeScalar(shifted)!)
                }
                let key = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == encoded })
                play.tapTypewriter(pageX: key.y + 1, pageY: 254 - key.x)
            }
            let enterKey = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == "e" })
            play.tapTypewriter(pageX: enterKey.y + 1, pageY: 254 - enterKey.x)
        }
        XCTAssertNil(play.typewriter)
        for _ in 0..<200 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            case .exploration: break
            default: XCTFail("The R301 typewriter return stopped at \(play.runner.phase)"); return
            }
            if case .exploration = play.runner.phase { break }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 35)), true)
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 43, expectArrival: false)
        XCTAssertEqual(play.runner.game.mapID, 43)
        XCTAssertEqual(play.runner.game.nowTime, 1)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-time1")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR301BlueBookLayerStartsTrapEventFromNormalInput() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.enableInstantSaves()
        var instantCheckpoint: OriginalResumeSave?
        play.onProgressCheckpoint = { instantCheckpoint = $0 }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-14_944, 7_584))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s02" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.search(play, node: "obj12")
        XCTAssertEqual(play.closeup?.view.id, 401)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 402)
        if case .picture = play.runner.phase {
            let point = try XCTUnwrap(stride(from: 8, to: 184, by: 2).flatMap { x in
                stride(from: 8, to: 248, by: 2).map { SIMD2<Int>(x, $0) }
            }.first { play.touchPicture?.contains(pageX: $0.x, pageY: $0.y) == true })
            play.activatePicture(pageX: point.x, pageY: point.y)
            for _ in 0..<24 { play.advanceFrame() }
            OriginalChapterThreeRouteChecks.drain(play)
        }
        XCTAssertTrue(play.runner.eventTrail.contains(7))
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 7)), true)
        XCTAssertEqual(Array(play.runner.eventTrail.suffix(2)), [7, 8])
        XCTAssertNil(play.runner.eventIndex, "The blue-book story sequence should return control to exploration")
        let items = try play.runner.game.inventory.items
        XCTAssertTrue(items.contains(53))
        XCTAssertTrue(items.contains(54))
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 27)), false)
        XCTAssertNotNil(instantCheckpoint?.progress, "The trap interaction should save immediately")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-blue-book-trap")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR301MachineSearchResumesFromInstantSave() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-cable-look")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.enableInstantSaves()
        var instantCheckpoint: OriginalResumeSave?
        play.onProgressCheckpoint = { instantCheckpoint = $0 }
        let traceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-r301-machine-\(UUID().uuidString).jsonl")
        try play.enableRouteTracing(to: traceURL, runID: "r301-machine", checkpointName: "chapter10-r301-cable-look")
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        if play.closeup != nil { play.leaveSearchCloseup() }
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01")
        XCTAssertEqual(play.runner.phase, .process(id: 86))
        XCTAssertNotNil(play.typewriter, "The machine should open its typewriter process")
        play.quitTypewriter()
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        XCTAssertNotNil(instantCheckpoint?.progress, "The machine selection should save immediately")
        let trace = try String(contentsOf: traceURL, encoding: .utf8)
        XCTAssertTrue(trace.contains("\"candidateEventIndex\":\"28\""))
        XCTAssertTrue(trace.contains("\"processID\":\"86\""))
        XCTAssertTrue(trace.contains("\"sourceOffset\":\"820\""))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-machine-look")).save(try XCTUnwrap(instantCheckpoint))
    }

    func testChapterTenR302DoorGateUsesBrickWallSuccessFlag() throws {
        let defaults = try OriginalStateDefaults.bundled()
        let restrictions = try OriginalMapRestrictions.bundled()
        var game = try OriginalGameState.newGame(defaults: defaults, timestamp: 0)
        game.setMap(43, previous: 40)
        let door = try XCTUnwrap(defaults.doorTable.connection(from: 43, to: 41))
        XCTAssertEqual(door.id, 43)
        XCTAssertFalse(restrictions.permitsDoor(to: 41, table: defaults.doorTable, game: game))

        let program = try OriginalScriptCatalog.bundled().loadProgram("EP10_R304")
        let brickProcessEvent = try XCTUnwrap(try program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 75
        })
        let brickWallCallers = try program.blocks.tables[2].filter { event in
            guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: program.conditions),
                let transition = completion.transition, transition.modeID == 15,
                transition.eventID == UInt16(brickProcessEvent.index) else { return false }
            return true
        }
        let brickWallCaller = try XCTUnwrap(brickWallCallers.first)
        let callerBytes = OriginalBytes(brickWallCaller.raw)
        XCTAssertEqual(brickWallCallers.count, 1)
        XCTAssertEqual(brickWallCaller.index, 20)
        XCTAssertEqual(try callerBytes.u16(0), 16)
        XCTAssertEqual(try callerBytes.u16(2), 18)
        XCTAssertEqual(callerBytes.bytes[16], 71)
        XCTAssertEqual(callerBytes.bytes[17], 2)
        XCTAssertEqual(try callerBytes.u16(18), 1)
        XCTAssertEqual(brickProcessEvent.sourceOffset, 672)
        guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
            event: brickProcessEvent, conditions: program.conditions, processReturn: 0) else {
            return XCTFail("The brick-wall success return needs a recovered transition")
        }
        XCTAssertEqual(completion.transition?.eventID, 25)
        let flagEvent = try XCTUnwrap(try program.blocks.tables[2].first { event in
            guard event.children != nil else { return false }
            return try program.blocks.operations(forEvent: event.index).contains {
                try OriginalOperation(record: $0) == .setFlag32(index: 32)
            }
        })
        XCTAssertEqual(flagEvent.index, 25)
        let flagOperations = try program.blocks.operations(forEvent: flagEvent.index)
            .map { try OriginalOperation(record: $0) }
        XCTAssertTrue(flagOperations.contains(.setFlag32(index: 32)))

        try game.apply(.setFlag32(index: 32))
        XCTAssertTrue(restrictions.permitsDoor(to: 41, table: defaults.doorTable, game: game))
    }

    func testChapterTenR304RegionEventSchedule() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP10_R304")
        var triggers = Set<String>()
        for scene in try program.blocks.tables[0] {
            guard let blocks = scene.children else { continue }
            for blockIndex in blocks {
                let block = try program.blocks.tables[1][blockIndex]
                guard let events = block.children else { continue }
                for eventIndex in events {
                    let event = try program.blocks.tables[2][eventIndex]
                    guard event.raw[0] == 3, event.raw[16] == 3 else { continue }
                    let region = try OriginalBytes(event.raw).u16(18)
                    let time = try OriginalBytes(block.raw).u16(2)
                    let eventID = try OriginalBytes(event.raw).u16(2)
                    triggers.insert("\(time):\(region):\(eventID)")
                }
            }
        }
        XCTAssertEqual(triggers, ["1:1:17", "1:4:40"])
    }

    func testChapterTenTimeTransitionCommandLocations() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let r301 = try catalog.loadProgram("EP10_R301")
        let event35 = try XCTUnwrap(try r301.blocks.tables[2].first { $0.index == 35 })
        XCTAssertEqual(try OriginalBytes(event35.raw).u16(0), 3)
        XCTAssertEqual(try OriginalBytes(event35.raw).u16(2), 35)
        let event106 = try XCTUnwrap(try r301.blocks.tables[2].first { $0.index == 106 })
        let event106Gate = try XCTUnwrap(r301.conditions.entries[106].first?.first)
        let gate = OriginalBytes(event106Gate.raw)
        XCTAssertEqual(gate.bytes[0], 0)
        XCTAssertEqual(try gate.u16(2), 40)
        XCTAssertEqual(try gate.u16(4), 35)
        XCTAssertEqual(gate.bytes[6], 0)
        XCTAssertEqual(try OriginalBytes(event106.raw).u16(0), 13)
        XCTAssertEqual(try OriginalBytes(event106.raw).u16(2), 105)
        let process74 = try XCTUnwrap(try r301.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 74
        })
        for (result, expectedEvent): (Int16, UInt16) in [(0, 35), (1, 37), (2, 38)] {
            guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
                event: process74, conditions: r301.conditions, processReturn: result) else {
                return XCTFail("R301 process 74 return \(result) should complete")
            }
            XCTAssertEqual(completion.transition?.eventID, expectedEvent)
        }
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        let event21 = try XCTUnwrap(try r301.blocks.tables[2].first { $0.index == 21 })
        let itemEvent = OriginalBytes(event21.raw)
        XCTAssertEqual(try itemEvent.u16(0), 16)
        XCTAssertEqual(itemEvent.bytes[16], 70)
        XCTAssertEqual(itemEvent.bytes[17], 1)
        XCTAssertEqual(try itemEvent.u16(18), 8)
        XCTAssertEqual(try OriginalItemNames.bundled().names[70], "Graphite Powder")
        guard case .completed(let itemUse) = try OriginalEventCompletion.stateOnlyExit(
            event: event21, conditions: r301.conditions) else {
            return XCTFail("R301 item-70 use should transition to event 22")
        }
        XCTAssertEqual(itemUse.transition?.eventID, 22)
        let event13 = try XCTUnwrap(try r301.blocks.tables[2].first { $0.index == 13 })
        let pencilUse = OriginalBytes(event13.raw)
        XCTAssertEqual(try pencilUse.u16(0), 16)
        XCTAssertEqual(pencilUse.bytes[16], 44)
        XCTAssertEqual(try pencilUse.u16(18), 396)
        let pencilUseGate = try XCTUnwrap(r301.conditions.entries[13].first?.first { $0.raw[0] == 0 })
        let pencilGate = OriginalBytes(pencilUseGate.raw)
        XCTAssertEqual(try pencilGate.u16(2), 40)
        XCTAssertEqual(try pencilGate.u16(4), 27)
        XCTAssertEqual(pencilGate.bytes[6], 0)
        try game.apply(.addInventory(id: 44))
        XCTAssertEqual(try r301.conditions.evaluatePredicates(eventKey: 13, context: game),
            .fail(sourceOffset: pencilUseGate.sourceOffset))
        game.markEventCompleted(group: 40, event: 27)
        XCTAssertEqual(try r301.conditions.evaluatePredicates(eventKey: 13, context: game), .pass)
        let event25 = try XCTUnwrap(try r301.blocks.tables[2].first { $0.index == 25 })
        let event25Gate = try XCTUnwrap(r301.conditions.entries[25].first?.first)
        let event25GateBytes = OriginalBytes(event25Gate.raw)
        XCTAssertEqual(try event25GateBytes.u16(2), 40)
        XCTAssertEqual(try event25GateBytes.u16(4), 22)
        XCTAssertNotEqual(event25GateBytes.bytes[6], 0, "The plug event needs flag 40:22 to stay clear")
        XCTAssertEqual(try r301.conditions.evaluatePredicates(eventKey: 25, context: game), .pass)
        var event22CompleteGame = game
        event22CompleteGame.markEventCompleted(group: 40, event: 22)
        XCTAssertEqual(try r301.conditions.evaluatePredicates(eventKey: 25, context: event22CompleteGame),
            .fail(sourceOffset: event25Gate.sourceOffset))
        guard case .completed(let event25Return) = try OriginalEventCompletion.stateOnlyExit(
            event: event25, conditions: r301.conditions) else {
            return XCTFail("R301 event 25 should transition to event 27")
        }
        XCTAssertEqual(event25Return.transition?.eventID, 27)
        XCTAssertEqual(try OriginalBytes(try XCTUnwrap(r301.blocks.tables[2].first { $0.index == 27 }).raw).u16(0), 3)
        guard case .completed(let pencilUseReturn) = try OriginalEventCompletion.stateOnlyExit(
            event: event13, conditions: r301.conditions) else {
            return XCTFail("R301 pencil use should select the pencil-sharpener process")
        }
        XCTAssertEqual(pencilUseReturn.transition?.eventID, 14)
        let pencilSharpener = try XCTUnwrap(try r301.blocks.tables[2].first { $0.index == 14 })
        XCTAssertEqual(try OriginalEventCompletion.embeddedProcessID(event: pencilSharpener), 59)
        for (result, expectedEvent): (Int16, UInt16) in [(0, 15), (1, 16), (2, 17)] {
            guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
                event: pencilSharpener, conditions: r301.conditions, processReturn: result) else {
                return XCTFail("R301 process 59 return \(result) should select its source result event")
            }
            XCTAssertEqual(completion.transition?.eventID, expectedEvent)
        }
        let enoughPowderEvent = try XCTUnwrap(try r301.blocks.tables[2].first { $0.index == 15 })
        let graphiteAward = try XCTUnwrap(try r301.blocks.operations(forEvent: enoughPowderEvent.index).first {
            $0.raw.first == 6
        })
        let graphiteAwardBytes = OriginalBytes(graphiteAward.raw)
        XCTAssertEqual(try graphiteAwardBytes.u16(2), 70)
        XCTAssertEqual(try graphiteAwardBytes.u16(8), 210)
        XCTAssertEqual(try graphiteAwardBytes.u16(10), 1)
        let event30 = try XCTUnwrap(try r301.blocks.tables[2].first { $0.index == 30 })
        XCTAssertEqual(try OriginalBytes(event30.raw).u16(0), 10)
        XCTAssertEqual(try OriginalBytes(event30.raw).u16(2), 28)
        let event30Gate = try XCTUnwrap(r301.conditions.entries[30].first?.first)
        XCTAssertEqual(try OriginalBytes(event30Gate.raw).u16(2), 40)
        XCTAssertEqual(try OriginalBytes(event30Gate.raw).u16(4), 22)
        XCTAssertEqual(try OriginalConditions(decoded: r301.conditionData,
            eventCount: r301.blocks.tables[2].count).evaluatePredicates(eventKey: 30, context: game),
            .fail(sourceOffset: event30Gate.sourceOffset))
        game.markEventCompleted(group: 40, event: 22)
        XCTAssertEqual(try OriginalConditions(decoded: r301.conditionData,
            eventCount: r301.blocks.tables[2].count).evaluatePredicates(eventKey: 30, context: game), .pass)
        guard case .completed(let event30Return) = try OriginalEventCompletion.stateOnlyExit(
            event: event30, conditions: r301.conditions) else {
            return XCTFail("R301 event 30 should start process 74")
        }
        XCTAssertEqual(event30Return.transition?.eventID, 32)
        XCTAssertEqual(try OriginalEventCompletion.embeddedProcessID(event: process74), 74)
        XCTAssertEqual(try r301.conditions.evaluatePredicates(eventKey: 106, context: game),
            .fail(sourceOffset: event106Gate.sourceOffset))
        game.markEventCompleted(group: 40, event: 35)
        XCTAssertEqual(try r301.conditions.evaluatePredicates(eventKey: 106, context: game), .pass)
        let process86 = try XCTUnwrap(try r301.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 86
        })
        for result: Int16 in 0...2 {
            let completion = try OriginalEventCompletion.stateOnlyExit(event: process86,
                conditions: r301.conditions, processReturn: result)
            guard case .completed(let value) = completion else {
                return XCTFail("R301 process 86 return \(result) should complete")
            }
            XCTAssertNil(value.transition, "R301 process 86 return \(result) has no recovered time transition")
        }
        var eventsOpeningTimeTransition: Set<String> = []
        for event in try r301.blocks.tables[2] {
            for result: Int16 in 0...2 {
                guard case .completed(let completion)? = try? OriginalEventCompletion.stateOnlyExit(
                    event: event, conditions: r301.conditions, processReturn: result),
                    completion.transition?.eventID == 108 else { continue }
                eventsOpeningTimeTransition.insert("\(event.index):\(result)")
            }
        }
        XCTAssertEqual(eventsOpeningTimeTransition, ["106:0", "106:1", "106:2"])

        var timeTransitions: Set<String> = []
        for map in ["R102", "R103", "R108", "R117", "R118", "R205", "R210", "R213", "R301", "R302", "R304", "R305", "R401"] {
            let program = try catalog.loadProgram("EP10_\(map)")
            for operation in try program.blocks.tables[3] where operation.raw[0] == 16 {
                let event = try XCTUnwrap(try program.blocks.tables[2].first {
                    $0.children?.contains(operation.index) == true
                })
                let block = try XCTUnwrap(try program.blocks.tables[1].first {
                    $0.children?.contains(event.index) == true
                })
                let transition = try OriginalTimeTransition(record: operation)
                timeTransitions.insert("\(program.name):\(try OriginalBytes(block.raw).u16(2)):\(event.index):\(transition.request.kind):\(transition.request.value):\(transition.label)")
            }
        }
        XCTAssertEqual(timeTransitions, [
            "EP10_R205:2:0:3:3:08:00AM",
            "EP10_R301:0:108:3:1:NONE",
            "EP10_R305:1:53:3:2:NONE"
        ])
    }

    @MainActor func testChapterTenR304SampledEventRegionsDoNotStartRouteAtTimeZero() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-entry-normal")).load())
        for (region, target) in [(UInt16(1), SIMD2<Float>(88_896, 9_024)),
                                 (2, SIMD2<Float>(95_040, -19_648)),
                                 (3, SIMD2<Float>(25_408, 9_024)),
                                 (4, SIMD2<Float>(101_184, -36_032))] {
            let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)),
                mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
            play.resume()
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
            try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
            XCTAssertEqual(play.runner.game.mapID, 43)
            XCTAssertEqual(play.runner.game.nowTime, 0)
            XCTAssertEqual(play.lobby?.eventRegion, region)
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 43))
            play.stop()
        }
    }

    @MainActor func testChapterTenR304TimeOneRegionOneRunsEvent17() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-time1")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(88_896, 9_024), interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 43)
        XCTAssertEqual(play.runner.game.nowTime, 1)
        XCTAssertEqual(play.lobby?.eventRegion, 1)
        XCTAssertTrue(play.runner.eventTrail.contains(17))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-after-region17")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR304HammerStartsBrickWallFromNormalInput() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-after-region17")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.enableInstantSaves()
        var instantCheckpoint: OriginalResumeSave?
        play.onProgressCheckpoint = { instantCheckpoint = $0 }
        let traceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-r304-hammer-\(UUID().uuidString).jsonl")
        try play.enableRouteTracing(to: traceURL, runID: "r304-hammer", checkpointName: "chapter10-r304-after-region17")
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s02" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14])), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.useItem(play, 71, on: "obj01", interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 75))
        XCTAssertNotNil(instantCheckpoint?.progress, "Starting the wall puzzle should save its live state")
        let process = try XCTUnwrap(play.brickWall)
        let wallCheckpoint = try XCTUnwrap(instantCheckpoint)
        XCTAssertEqual(wallCheckpoint.progress?.puzzleSeeds.count, 1,
            "Instant saves must retain the Process 75 layout seed")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-brick-wall-start")).save(wallCheckpoint)
        let restored = try OriginalPlaySession.restoring(wallCheckpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { restored.stop() }
        XCTAssertEqual(restored.brickWall, process,
            "Restoring the normal route must rebuild the same Process 75 board")
        for index in OriginalBrickWallLayout.doorwayIndices.reversed() {
            guard case .process(75) = play.runner.phase, let current = play.brickWall,
                  current.objects[index].position.y >= -1 else { continue }
            var touches: [SIMD2<Float>] = []
            for y in stride(from: 0, to: 256, by: 4) {
                for x in stride(from: 0, to: 192, by: 4) {
                    let touch = SIMD2<Float>(Float(x), Float(y))
                    if OriginalBrickWallHitMask.object(at: touch, objects: current.objects) == index {
                        touches.append(touch)
                    }
                }
            }
            var move: (touch: SIMD2<Float>, destination: SIMD2<Float>)?
            search: for touch in touches.sorted(by: { $0.y < $1.y }) {
                for x in stride(from: 0, to: 192, by: 4) {
                    let destination = SIMD2<Float>(Float(x), 255)
                    var probe = current
                    guard probe.beginDrag(at: touch, hammerAvailable: true),
                          probe.selectedObject == index else { continue }
                    probe.drag(to: destination)
                    guard probe.objects[index].position.y < -1 else { continue }
                    move = (touch, destination)
                    break search
                }
            }
            guard let move else {
                XCTFail("Doorway brick \(index) has no sampled clear drag at seed \(wallCheckpoint.progress?.puzzleSeeds.first ?? 0)")
                break
            }
            play.holdBrickWallTouch(x: move.touch.x, y: move.touch.y)
            play.holdBrickWallTouch(x: move.destination.x, y: move.destination.y)
            play.releaseBrickWallTouch()
        }
        XCTAssertNil(play.brickWall, "Clearing the doorway must complete Process 75")
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.session.selection.eventID, 25)
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 32)), true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-brick-wall-open")).save(try play.progressCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 41, interrupt: true, expectArrival: false)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.nearbyDoor, 41)
        let handle = try XCTUnwrap(stride(from: 8, to: 248, by: 2).flatMap { y in
            stride(from: 8, to: 184, by: 2).map { ($0, y) }
        }.first { play.doorImage?.hit(pageX: $0.0, pageY: $0.1) == 2 }, "R302 door must expose a tappable handle")
        play.selectDoorComponent(x: handle.0, y: handle.1, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 41)
        XCTAssertEqual(play.lobby?.mapName, "R302")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r302-entry")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR302PaletteKnifePeelsPaintingFromNormalInput() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r302-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.enableInstantSaves()
        var instantCheckpoint: OriginalResumeSave?
        play.onProgressCheckpoint = { instantCheckpoint = $0 }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertFalse(try play.runner.game.inventory.items.contains(72), "The palette knife must be picked up in the hidden room")
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-1_000, 13_000), interrupt: true)
        let tableMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s02" })
        OriginalChapterThreeRouteChecks.face(play,
            x: Float(tableMarker.worldFixed[12]), z: Float(tableMarker.worldFixed[14]))
        play.inspectLobbyCounter()
        play.panLobbyCounter(0.15)
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: 41,
            area: counter.searchAreaID, game: play.runner.game)
        let points = stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        let point = try XCTUnwrap(try points.first {
            try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj10"
        })
        play.selectLobbyObject(x: point.x, y: point.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.session.selection.areaID, 2)
        XCTAssertEqual(play.runner.session.selection.subareaID, 10)
        XCTAssertEqual(play.closeup?.view.id, 407)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 408, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(72), "Inspecting the palette knife must add it to inventory")
        XCTAssertTrue(play.runner.eventTrail.contains(7), "The palette-knife table event must run")
        let knifeCheckpoint = try XCTUnwrap(instantCheckpoint)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r302-palette-knife")).save(knifeCheckpoint)

        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        let target = SIMD2<Float>(-21_568, -19_520)
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        let paintingMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(paintingMarker.worldFixed[12]),
            z: Float(paintingMarker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        play.inspectLobbyCounter()
        let canvasCounter = try XCTUnwrap(play.lobby)
        let canvasVisible = canvasCounter.objectVisibility.visibleNodes(in: canvasCounter.counter, map: 41,
            area: canvasCounter.searchAreaID, game: play.runner.game)
        var paintingPoints: [SIMD2<Float>] = []
        for y in stride(from: 8, to: 248, by: 4) {
            for x in stride(from: 8, to: 184, by: 4) {
                let point = SIMD2<Float>(Float(x), Float(y))
                if try canvasCounter.pickedCounterNode(page: point, visibleNodes: canvasVisible) == "obj01" {
                    paintingPoints.append(point)
                }
            }
        }
        let canvasPoint = try XCTUnwrap(paintingPoints.min {
            simd_length_squared($0 - SIMD2<Float>(96, 128)) < simd_length_squared($1 - SIMD2<Float>(96, 128))
        }, "The covered painting must have a normal object hit mask in area 1")
        play.useItemInSearchView(72)
        play.selectLobbyObject(x: canvasPoint.x, y: canvasPoint.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 61))
        XCTAssertEqual(play.runner.session.selection.areaID, 1)
        XCTAssertEqual(play.runner.session.selection.subareaID, 1)
        XCTAssertNotNil(play.picturePeel)
        for y in stride(from: 2, to: OriginalPicturePeelProcess.height, by: 6) {
            for x in [0, 95, 191] {
                play.holdPicturePeelTouch(x: Float(x), y: Float(y))
                play.advanceFrame()
            }
            if play.picturePeel?.isComplete == true { break }
        }
        XCTAssertGreaterThanOrEqual(play.picturePeel?.clearedPixelCount ?? 0,
            OriginalPicturePeelProcess.clearedPixelThreshold)
        play.releasePicturePeelTouch()
        play.advanceFrame()
        play.quitPicturePeel()
        XCTAssertNil(play.picturePeel)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.session.selection.eventID, 9)
        XCTAssertTrue(play.runner.eventTrail.contains(9), "The successful picture peel must select the story return event")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r302-painting-revealed")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR302RevealedPaintingCompletesNormalEnding() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r302-painting-revealed")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 43, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 43)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(101_184, -36_032), interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 44)
        try OriginalChapterThreeRouteChecks.choose(play, "You talked to him here.", interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "It was Bradley.", interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(1)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "It was Nile.", interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(4)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(2)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "You lied.", interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(3)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "He didn't say a thing.", interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(6)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(5)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.picture(play, interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        for _ in 0..<OriginalAfterConfessProcess.frameCounts.reduce(0, +) { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.game.chapter, 9)
        XCTAssertEqual(play.runner.game.nowTime, 3)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-ending")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenR301AreaTwoObjectsReturnToSearchView() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-counter1")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-14_944, 7_584))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s02" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        let expected: [(node: String, mode: UInt16, subarea: UInt16, counter: UInt8)] = [
            ("obj04", 10, 4, 1), ("obj05", 10, 5, 2),
            ("obj06", 11, 6, 2), ("obj07", 11, 6, 2), ("obj08", 11, 6, 2),
            ("obj09", 11, 6, 2), ("obj11", 11, 6, 2), ("obj12", 11, 6, 2)
        ]
        for sample in expected {
            try OriginalChapterThreeRouteChecks.search(play, node: sample.node)
            let selection = play.runner.session.selection
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 40), sample.node)
            XCTAssertEqual(selection.modeID, sample.mode, sample.node)
            XCTAssertEqual(selection.areaID, 2, sample.node)
            XCTAssertEqual(selection.subareaID, sample.subarea, sample.node)
            XCTAssertNil(play.runner.eventIndex, sample.node)
            XCTAssertEqual(play.runner.game.bytes[0x1380], sample.counter, sample.node)
            XCTAssertEqual(play.runner.game.nowTime, 0, sample.node)
        }
    }

    @MainActor func testChapterTenR301DeskSearchRunsFirstStoryClue() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(-14_944, -8_800))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01_01")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        XCTAssertEqual(play.runner.game.bytes[0x1380], 1)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 98)), true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 40, index: 101)), true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r301-first-clue")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterTenCellarSelectsR304DoorFromMatchingSearchRecord() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-cellar-passage")).load())
        var game = try checkpoint.gameState()
        game.setMapPosition(SIMD3(15_516, 12_288, -18_000), facing: .pi)
        let positioned = try OriginalResumeSave(game: game, checkpointFacing: .pi,
            musicSequenceID: nil, savedAt: checkpoint.savedAt)
        let play = try OriginalPlaySession.restoring(positioned, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()

        XCTAssertEqual(play.nearbyDoor, 43)
        play.inspectNearbyDoor()
        XCTAssertEqual(play.door?.doorID, 49)
        XCTAssertEqual(play.door?.area, 5)
        XCTAssertEqual(play.door?.view.id, 59)
    }

    func testWrongAnswerReplaysTheSameQuestion() throws {
        var runner = try beginCall()
        runner.choose(60)
        advance(&runner)
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected the first question again") }
        XCTAssertEqual(choices.map(\.id), [60, 61, 62])
        XCTAssertEqual(runner.reviewQuestionIndex, 0)
        try compare(runner, "chapter-one-review-wrong/page18")
    }

    func testEachWrongAnswerRetriesAndCorrectAnswersRequestChapterTwo() throws {
        var runner = try beginCall()
        for (index, answers) in [(60, 61), (64, 63), (66, 68), (69, 70), (73, 72)].enumerated() {
            guard case .choice(let original) = runner.phase else { return XCTFail("Expected a review menu") }
            runner.choose(UInt16(answers.0))
            advance(&runner)
            XCTAssertEqual(runner.phase, .choice(original))
            XCTAssertEqual(runner.reviewQuestionIndex, index)
            runner.choose(UInt16(answers.1))
            advance(&runner)
            XCTAssertEqual(runner.reviewQuestionIndex, index + 1)
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(runner.processRequests.suffix(2), [.init(kind: 1, value: 31), .init(kind: 4, value: 1)])
        XCTAssertEqual(runner.game.chapter, 0, "The host consumes the chapter request after the review returns")
    }

    func testChapterResetAndTitleMatchOriginalState() throws {
        var runner = try beginCall()
        for answer: UInt16 in [61, 63, 68, 70, 72] {
            runner.choose(answer)
            advance(&runner)
        }
        var game = runner.game
        try game.beginChapter(1)
        game.setMap(31, previous: 31)
        game.setMapPosition(SIMD3(-16687, 12288, 3735), facing: 4.71238899230957)
        let save = try state("chapter-one-review-final/page32").bytes
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != save[$0] }, [])
        try game.beginChapterTitle(label: " 05:30PM")
        let title = try state("chapter-two-no-save/next").bytes
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != title[$0] }, [])
    }
}
