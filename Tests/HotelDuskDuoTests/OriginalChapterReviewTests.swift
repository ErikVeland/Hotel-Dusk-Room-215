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
            .appendingPathComponent("chapter10-r304-entry")).load())
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
            .appendingPathComponent("chapter10-r301-first-clue")).load())
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
            .appendingPathComponent("chapter10-r301-five-look-clue")).load())
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
        for node in ["obj04", "obj05", "obj06", "obj07", "obj08", "obj09", "obj11", "obj12"] {
            try OriginalChapterThreeRouteChecks.search(play, node: node)
            print("R301 area2 \(node): phase=\(play.runner.phase) counter=\(play.runner.game.bytes[0x1380])")
            if play.runner.phase != .exploration(mapID: 40) { break }
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
