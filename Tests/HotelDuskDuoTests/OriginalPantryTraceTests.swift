import XCTest
@testable import HotelDuskDuoKit

final class OriginalPantryTraceTests: XCTestCase {
    @MainActor
    func testCardsReadSeedDoesNotSelectQuizFromStandardPantryDoors() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let searchTable = try OriginalSearchTable.bundled(map: "R112")
        let upViews = try OriginalUpViewTable.bundled(map: "R112")
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(8)
        game.applyTimeChange(4)
        game.setMap(12, previous: 23)
        game.markEventCompleted(group: 23, event: 4)
        try game.apply(.addInventory(id: 41))
        try game.apply(.addInventory(id: 60))
        game.setMapPosition(SIMD3(0, 12288, 0), facing: 0)
        let program = try catalog.loadProgram("EP9_R112")
        var testedComponentCount = 0
        for door in searchTable.doors {
            guard let view = upViews.views.first(where: { UInt16(bitPattern: $0.id) == door.upViewID }) else { continue }
            var entryRunner = try OriginalEventRunner(program: program, game: game, deferArrival: true)
            entryRunner.interactWithDoor(area: door.areaID)
            XCTAssertNil(entryRunner.eventIndex, "Door entry area \(door.areaID) should not start the quiz")
            for layer in view.layers where layer.eventID >= 0 {
                var runner = try OriginalEventRunner(program: program, game: game, deferArrival: true)
                runner.interactWithDoor(area: door.areaID, upView: layer.eventID)
                XCTAssertNil(runner.eventIndex,
                    "Door area \(door.areaID), view \(view.id), component event \(layer.eventID) should not start the quiz")
                testedComponentCount += 1
            }
        }
        XCTAssertEqual(testedComponentCount, 6)
    }

    @MainActor
    func testCardsReadSeedTracesPantryBookshelfHitNoMatch() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(8)
        game.applyTimeChange(4)
        game.setMap(12, previous: 23)
        game.markEventCompleted(group: 23, event: 4)
        try game.apply(.addInventory(id: 41))
        try game.apply(.addInventory(id: 60))
        game.setMapPosition(SIMD3(0, 12288, 0), facing: 0)
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP9_R112"), game: game,
            deferArrival: true)
        let traceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-pantry-probe-\(UUID().uuidString).jsonl")
        let play = OriginalPlaySession(runner: runner, audio: originalRouteTestAudio(), catalog: catalog,
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        try play.enableRouteTracing(to: traceURL, runID: "chapter9-pantry-probe", checkpointName: "cards-read-seed")

        let pantry = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(pantry.room.nodes.first { $0.name == "s01" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        let room = try XCTUnwrap(play.lobby)
        let visible = room.objectVisibility.visibleNodes(in: room.room, map: room.mapID, area: nil,
            game: play.runner.game)
        XCTAssertEqual(try room.pickedRoomObject(page: SIMD2(0, 0), visibleNodes: visible), "obj18")

        play.selectLobbyRoomObject(x: 0, y: 0)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)

        XCTAssertEqual(play.runner.game.mapID, 12)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 12))
        let trace = try String(contentsOf: traceURL, encoding: .utf8)
        XCTAssertTrue(trace.contains("\"kind\":\"roomObjectHit\""))
        XCTAssertTrue(trace.contains("\"pickedNode\":\"obj18\""))
        XCTAssertTrue(trace.contains("\"mode\":\"10\""))
        XCTAssertTrue(trace.contains("\"area\":\"1\""))
        XCTAssertTrue(trace.contains("\"subarea\":\"18\""))
        XCTAssertTrue(trace.contains("\"result\":\"noMatch\""))
    }

    @MainActor
    func testCardsReadCheckpointObj9998HitFallsBackInsteadOfStartingQuiz() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter9-dunning-items-and-cards")).load() else {
            throw XCTSkip("The Chapter 9 cards-read checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        try OriginalChapterThreeRouteChecks.exit(play, to: 12, interrupt: true)

        let room = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(room.room.nodes.first { $0.name == "s03" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        let facingRoom = try XCTUnwrap(play.lobby)
        XCTAssertEqual(facingRoom.nearbySearchArea, 3)
        let visible = facingRoom.objectVisibility.visibleNodes(in: facingRoom.room, map: facingRoom.mapID,
            area: nil, game: play.runner.game)
        let hit = try XCTUnwrap(stride(from: 0, to: 256, by: 8).lazy.flatMap { y in
            stride(from: 0, to: 192, by: 8).map { x in SIMD2(Float(x), Float(y)) }
        }.first { point in
            try facingRoom.pickedRoomObject(page: point, visibleNodes: visible) == "obj9998"
        }, "No sampled room point selected the hit-only pantry helper")

        play.selectLobbyRoomObject(x: hit.x, y: hit.y)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)

        XCTAssertEqual(play.runner.game.mapID, 12)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 12))
        XCTAssertEqual(play.runner.session.selection.modeID, 10)
        XCTAssertEqual(play.runner.session.selection.areaID, 3)
        XCTAssertEqual(play.runner.session.selection.subareaID, 99)
    }

    @MainActor
    func testCardsReadCheckpointHiddenPantryDoorStartsQuizByRoomHit() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter9-dunning-items-and-cards")).load() else {
            throw XCTSkip("The Chapter 9 cards-read checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        let traceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-pantry-quiz-\(UUID().uuidString).jsonl")
        try play.enableRouteTracing(to: traceURL, runID: "chapter9-pantry-quiz",
            checkpointName: "chapter9-dunning-items-and-cards")
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 12, interrupt: true)

        var hit: (String, SIMD2<Float>)?
        for markerName in ["s01", "s03"] where hit == nil {
            let room = try XCTUnwrap(play.lobby)
            let marker = try XCTUnwrap(room.room.nodes.first { $0.name == markerName })
            let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
            try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
            OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
            guard let facingRoom = play.lobby else { continue }
            let visible = facingRoom.objectVisibility.visibleNodes(in: facingRoom.room, map: facingRoom.mapID,
                area: nil, game: play.runner.game)
            let points = stride(from: 0, to: 256, by: 4).flatMap { y in
                stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
            }
            for point in points {
                guard let node = try facingRoom.pickedRoomObject(page: point, visibleNodes: visible),
                      node == "obj9999" else { continue }
                hit = (node, point)
                break
            }
        }
        let target = try XCTUnwrap(hit, "The pantry top-wall helper masks should be selectable")
        play.selectLobbyRoomObject(x: target.1.x, y: target.1.y)

        XCTAssertEqual(target.0, "obj9999")
        XCTAssertEqual(target.1, SIMD2<Float>(164, 0))
        XCTAssertEqual(play.runner.program.name, "EP9_R107")
        XCTAssertEqual(play.runner.session.selection.mapID, 7)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let choices) = play.runner.phase else {
            return XCTFail("The pantry door should start Quiz 9, got \(play.runner.phase)")
        }
        XCTAssertTrue(choices.contains { $0.id == 5 })
        for answer: UInt16 in [5, 7, 12, 14, 16] {
            guard case .choice(let options) = play.runner.phase else {
                return XCTFail("Expected a Quiz 9 answer menu, got \(play.runner.phase)")
            }
            XCTAssertTrue(options.contains { $0.id == answer })
            play.choose(answer)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        if case .picture = play.runner.phase {
            let point = try XCTUnwrap((8...183).flatMap { x in
                (8...247).map { y in SIMD2<Int>(x, y) }
            }.first { play.touchPicture?.contains(pageX: $0.x, pageY: $0.y) == true },
                "The review transition picture should expose a normal touch target")
            play.activatePicture(pageX: point.x, pageY: point.y)
            for _ in 0..<24 where play.touchPicture != nil { play.advanceFrame() }
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        XCTAssertEqual(play.runner.reviewQuestionIndex, 5)
        XCTAssertTrue(play.chapterTransition?.stage == .prompt || play.chapterTransition?.stage == .title)
        XCTAssertEqual(play.runner.game.chapter, 9)
        play.answerChapterSave(false)
        XCTAssertEqual(play.chapterTransition?.stage, .title)
        play.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.program.name, "EP10_R108")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 8))

        let cellarCheckpoint = try play.walkingCheckpoint()
        let checkpointStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-normal-cellar-entry"))
        try checkpointStore.save(cellarCheckpoint)
        let resumed = try OriginalPlaySession.restoring(cellarCheckpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.runner.program.name, "EP10_R108")
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 8))
        XCTAssertTrue(resumed.runner.game.objectVisible(77), "The half-full bottle visibility flag should survive the Chapter 10 handoff")
        let entryMarker = try XCTUnwrap(resumed.lobby?.room.nodes.first { $0.name == "hyde_point00" })
        try OriginalChapterThreeRouteChecks.walk(resumed,
            to: SIMD2(Float(entryMarker.worldFixed[12]), Float(entryMarker.worldFixed[14])))
        let shelfMarker = try XCTUnwrap(resumed.lobby?.room.nodes.first { $0.name == "s01" })
        try OriginalChapterThreeRouteChecks.navigate(resumed,
            to: SIMD2(Float(shelfMarker.worldFixed[12]), Float(shelfMarker.worldFixed[14])))
        OriginalChapterThreeRouteChecks.face(resumed,
            x: Float(shelfMarker.worldFixed[12]), z: Float(shelfMarker.worldFixed[14]))
        XCTAssertEqual(resumed.lobby?.nearbySearchArea, 1)
        resumed.inspectLobbyCounter()
        let shelf = try XCTUnwrap(resumed.lobby)
        XCTAssertEqual(shelf.mode, .counter)
        XCTAssertEqual(shelf.searchAreaID, 1)
        let shelfVisible = shelf.objectVisibility.visibleNodes(in: shelf.counter, map: shelf.mapID,
            area: shelf.searchAreaID, game: resumed.runner.game)
        XCTAssertTrue(shelf.counter.nodes.enumerated().contains { $0.element.name == "obj21" && shelfVisible.contains($0.offset) })
        let shelfCheckpoint = try resumed.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-normal-cellar-shelf")).save(shelfCheckpoint)
        let shelfResume = try OriginalPlaySession.restoring(shelfCheckpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { shelfResume.stop() }
        shelfResume.resume()
        XCTAssertEqual(shelfResume.runner.phase, .exploration(mapID: 8))
        XCTAssertEqual(shelfResume.lobby?.mode, .counter)
        XCTAssertEqual(shelfResume.lobby?.searchAreaID, 1)
        XCTAssertEqual(shelfResume.runner.game.value(for: .eventFlag(group: 8, index: 9)), false)
        let hitTraceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hotel-dusk-cellar-hit-\(UUID().uuidString).jsonl")
        try shelfResume.enableRouteTracing(to: hitTraceURL, runID: "chapter10-normal-shelf-hit",
            checkpointName: "chapter10-normal-cellar-shelf")
        let resumedShelf = try XCTUnwrap(shelfResume.lobby)
        let resumedVisible = resumedShelf.objectVisibility.visibleNodes(in: resumedShelf.counter,
            map: resumedShelf.mapID, area: resumedShelf.searchAreaID, game: shelfResume.runner.game)
        let hitPoints = stride(from: 0, to: 256, by: 4).flatMap { y in
            stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        let bottlePoint = try XCTUnwrap(hitPoints.first { point in
            try resumedShelf.pickedCounterNode(page: point, visibleNodes: resumedVisible) == "obj21"
        })
        shelfResume.selectLobbyObject(x: bottlePoint.x, y: bottlePoint.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(shelfResume, interrupt: true)
        XCTAssertFalse(try shelfResume.runner.game.inventory.items.contains(77),
            "The cellar bottle event remains gated in this normal-route state")
        let hitTrace = try String(contentsOf: hitTraceURL, encoding: .utf8)
        XCTAssertTrue(hitTrace.contains("\"pickedNode\":\"obj21\""))
        XCTAssertTrue(hitTrace.contains("\"result\":\"noMatch\""))
        for offset in [480, 528, 576] {
            XCTAssertTrue(hitTrace.contains("\"conditionResult\":\"fail(sourceOffset: \(offset))\""))
        }
        let trace = try String(contentsOf: traceURL, encoding: .utf8)
        XCTAssertTrue(trace.contains("\"trigger\":\"chapter9-pantry-quiz\""))
        XCTAssertTrue(trace.contains("\"pickedNode\":\"\(target.0)\""))
    }
}
