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
}
