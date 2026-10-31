import XCTest
@testable import HotelDuskDuoKit

final class OriginalCellarTraceTests: XCTestCase {
    @MainActor
    func testNormalCellarRouteFindsBottleAndOpensPassage() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-normal-cellar-entry")).load() else {
            throw XCTSkip("The normal Chapter 10 cellar entry checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()

        func enterArea(_ area: String, id: UInt16) throws {
            if play.closeup != nil { play.leaveSearchCloseup() }
            if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
            let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == area })
            let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
            try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
            OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
            XCTAssertEqual(play.lobby?.nearbySearchArea, id)
            play.inspectLobbyCounter()
            XCTAssertEqual(play.lobby?.searchAreaID, id)
        }

        func counterPoint(_ node: String) throws -> SIMD2<Float> {
            let scene = try XCTUnwrap(play.lobby)
            let visible = scene.objectVisibility.visibleNodes(in: scene.counter, map: scene.mapID,
                area: scene.searchAreaID, game: play.runner.game)
            return try XCTUnwrap(try stride(from: 0, to: 256, by: 4)
                .flatMap { y in stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) } }
                .first { try scene.pickedCounterNode(page: $0, visibleNodes: visible) == node },
                "Search area \(scene.searchAreaID) must expose \(node)")
        }

        let arrival = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "hyde_point00" })
        try OriginalChapterThreeRouteChecks.walk(play,
            to: SIMD2(Float(arrival.worldFixed[12]), Float(arrival.worldFixed[14])))

        try enterArea("s03", id: 3)
        let caseObject = try counterPoint("obj09")
        play.selectLobbyObject(x: caseObject.x, y: caseObject.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 52)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 53, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 8, index: 9)), true,
            "The back-shelf layer should expose the missing half-full bottle")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-cellar-event9-normal")).save(try play.progressCheckpoint())

        try enterArea("s01", id: 1)
        let bottle = try counterPoint("obj21")
        play.selectLobbyObject(x: bottle.x, y: bottle.y)
        XCTAssertEqual(play.lobby?.selectedNode, "obj21")
        play.selectLobbyObject(x: bottle.x, y: bottle.y)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(77))

        try enterArea("s02", id: 2)
        let secondBottle = try counterPoint("obj22")
        play.useItemInSearchView(77)
        play.selectLobbyObject(x: secondBottle.x, y: secondBottle.y, confirmImmediately: true)
        XCTAssertEqual(play.runner.session.selection.modeID, 16)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(82))

        try enterArea("s03", id: 3)
        let bottleCase = try counterPoint("obj09")
        play.useItemInSearchView(82)
        play.selectLobbyObject(x: bottleCase.x, y: bottleCase.y, confirmImmediately: true)
        XCTAssertEqual(play.runner.session.selection.modeID, 16)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 59)), true)
        let shelf = try counterPoint("obj01")
        play.selectLobbyObject(x: shelf.x, y: shelf.y, confirmImmediately: true)
        XCTAssertEqual(play.runner.session.selection.modeID, 3)
        XCTAssertEqual(play.runner.eventIndex, 20)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 31)), true)
        XCTAssertTrue(try XCTUnwrap(play.lobby).room.nodes.contains { $0.name == "in_r304" })
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-cellar-passage-normal")).save(try play.progressCheckpoint())

        try OriginalChapterThreeRouteChecks.exit(play, to: 43, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 43)
        XCTAssertEqual(play.runner.program.name, "EP10_R304")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter10-r304-entry-normal")).save(try play.walkingCheckpoint())
    }

    @MainActor
    func testCellarBackShelfCloseupLayersFromNormalRoute() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let entry = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-normal-cellar-entry")).load() else {
            throw XCTSkip("The normal Chapter 10 cellar entry checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(entry, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        let arrival = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "hyde_point00" })
        try OriginalChapterThreeRouteChecks.walk(play,
            to: SIMD2(Float(arrival.worldFixed[12]), Float(arrival.worldFixed[14])))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s03" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let points = stride(from: 0, to: 256, by: 4).flatMap { y in
            stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        let point = try XCTUnwrap(try points.first {
            try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj09"
        })
        play.selectLobbyObject(x: point.x, y: point.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 52)
        let viewSave = try play.progressCheckpoint()
        for event: Int16 in [53, 54, 55] {
            let probe = try OriginalPlaySession.restoring(viewSave, audio: originalRouteTestAudio(),
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)),
                mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
            probe.resume()
            let traceURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("hotel-dusk-cellar-layer-\(event)-\(UUID().uuidString).jsonl")
            try probe.enableRouteTracing(to: traceURL, runID: "chapter10-cellar-layer-\(event)",
                checkpointName: "chapter10-normal-cellar-entry")
            try OriginalChapterThreeRouteChecks.closeupLayer(probe, event: event, interrupt: true)
            print("R108 view52 layer=\(event) phase=\(probe.runner.phase) eventIndex=\(String(describing: probe.runner.eventIndex)) " +
                "view=\(String(describing: probe.closeup?.view.id)) flag8:9=\(String(describing: probe.runner.game.value(for: .eventFlag(group: 8, index: 9)))) " +
                "item77=\(try probe.runner.game.inventory.items.contains(77))")
            let trace = try String(contentsOf: traceURL, encoding: .utf8)
            for line in trace.split(separator: "\n") where line.contains("\"kind\":\"candidate\"") ||
                line.contains("\"kind\":\"selection\"") || line.contains("\"kind\":\"operation\"") {
                print("CELLAR TRACE \(line)")
            }
            probe.stop()
        }
    }

    @MainActor
    func testNormalCellarAreaThreeHitMaskSweep() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let entry = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-normal-cellar-entry")).load() else {
            throw XCTSkip("The normal Chapter 10 cellar entry checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(entry, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        let arrival = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "hyde_point00" })
        try OriginalChapterThreeRouteChecks.walk(play,
            to: SIMD2(Float(arrival.worldFixed[12]), Float(arrival.worldFixed[14])))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s03" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        XCTAssertEqual(counter.searchAreaID, 3)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let points = stride(from: 0, to: 256, by: 4).flatMap { y in
            stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        var hits = [String: SIMD2<Float>]()
        for point in points {
            guard let node = try counter.pickedCounterNode(page: point, visibleNodes: visible),
                  hits[node] == nil else { continue }
            hits[node] = point
        }
        XCTAssertFalse(hits.isEmpty, "Cellar search area 3 should expose counter hit masks")
        let areaThree = try play.progressCheckpoint()
        for (node, point) in hits.sorted(by: { $0.key < $1.key }) {
            let probe = try OriginalPlaySession.restoring(areaThree, audio: originalRouteTestAudio(),
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)),
                mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
            probe.resume()
            probe.selectLobbyObject(x: point.x, y: point.y, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(probe, interrupt: true)
            print("R108 area3 node=\(node) point=\(point) mode=\(probe.runner.session.selection.modeID) " +
                "event=\(probe.runner.session.selection.eventID) eventIndex=\(String(describing: probe.runner.eventIndex)) " +
                "closeup=\(String(describing: probe.closeup?.view.id)) layers=\(probe.closeup?.view.layers.map(\.eventID) ?? []) " +
                "flag8:9=\(String(describing: probe.runner.game.value(for: .eventFlag(group: 8, index: 9)))) " +
                "item77=\(try probe.runner.game.inventory.items.contains(77)) item82=\(try probe.runner.game.inventory.items.contains(82)) " +
                "flag59=\(String(describing: probe.runner.game.value(for: .gameFlag(index: 59))))")
            probe.stop()
        }
    }

    @MainActor
    func testCellarCaseCounterHitRecordsCloseupLayers() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-normal-cellar-shelf")).load() else {
            throw XCTSkip("The normal Chapter 10 cellar shelf checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        let shelf = try XCTUnwrap(play.lobby)
        XCTAssertEqual(shelf.mode, .counter)
        let visible = shelf.objectVisibility.visibleNodes(in: shelf.counter, map: shelf.mapID,
            area: shelf.searchAreaID, game: play.runner.game)
        let points = stride(from: 0, to: 256, by: 4).flatMap { y in
            stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        let point = try XCTUnwrap(try points.first {
            try shelf.pickedCounterNode(page: $0, visibleNodes: visible) == "obj09"
        }, "The shelf case needs a normal counter hit")
        play.selectLobbyObject(x: point.x, y: point.y)
        XCTAssertEqual(play.lobby?.selectedNode, "obj09")
        play.selectLobbyObject(x: point.x, y: point.y)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        print("R108 obj09 case: mode=\(play.runner.session.selection.modeID) " +
            "eventIndex=\(String(describing: play.runner.eventIndex)) closeup=\(String(describing: play.closeup?.view.id)) " +
            "layers=\(play.closeup?.view.layers.map(\.eventID) ?? []) flag8:9=\(String(describing: play.runner.game.value(for: .eventFlag(group: 8, index: 9))))")
        XCTAssertEqual(play.runner.game.mapID, 8)
    }

    @MainActor
    func testCellarBottleCounterHitRecordsCloseupLayers() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-normal-cellar-shelf")).load() else {
            throw XCTSkip("The normal Chapter 10 cellar shelf checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        let shelf = try XCTUnwrap(play.lobby)
        let visible = shelf.objectVisibility.visibleNodes(in: shelf.counter, map: shelf.mapID,
            area: shelf.searchAreaID, game: play.runner.game)
        let points = stride(from: 0, to: 256, by: 4).flatMap { y in
            stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        let point = try XCTUnwrap(try points.first {
            try shelf.pickedCounterNode(page: $0, visibleNodes: visible) == "obj21"
        }, "The whiskey bottle needs a normal counter hit")
        play.selectLobbyObject(x: point.x, y: point.y)
        XCTAssertEqual(play.lobby?.selectedNode, "obj21")
        play.selectLobbyObject(x: point.x, y: point.y)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        let labels = try OriginalItemNames.bundled().names
        let inventory = try play.runner.game.inventory.items
        print("R108 obj21 bottle: inventory=\(inventory.map { "\($0):\(labels[$0] ?? "?")" }) " +
            "mode=\(play.runner.session.selection.modeID) " +
            "eventIndex=\(String(describing: play.runner.eventIndex)) closeup=\(String(describing: play.closeup?.view.id)) " +
            "layers=\(play.closeup?.view.layers.map(\.eventID) ?? []) flag8:9=\(String(describing: play.runner.game.value(for: .eventFlag(group: 8, index: 9)))) " +
            "item77=\(try play.runner.game.inventory.items.contains(77))")
        XCTAssertEqual(play.runner.game.mapID, 8)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 8, index: 9)), false)
        XCTAssertFalse(try play.runner.game.inventory.items.contains(77))
    }

    @MainActor
    func testCellarBackShelfRoomMaskIsNotSelectableFromSearchArea() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-normal-cellar-entry")).load() else {
            throw XCTSkip("The normal Chapter 10 cellar entry checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        let entry = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "hyde_point00" })
        try OriginalChapterThreeRouteChecks.walk(play,
            to: SIMD2(Float(entry.worldFixed[12]), Float(entry.worldFixed[14])))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        let lobby = try XCTUnwrap(play.lobby)
        let visible = lobby.objectVisibility.visibleNodes(in: lobby.room, map: lobby.mapID,
            area: nil, game: play.runner.game)
        let point = try stride(from: 0, to: 256, by: 4).flatMap { y in
            stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try lobby.pickedRoomObject(page: $0, visibleNodes: visible) == "obj0121" }
        print("R108 search-area-1 obj0121 room mask: \(String(describing: point))")
        XCTAssertNil(point, "The sampled shelf room hit is outside the valid search-area view")
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 8, index: 9)), false)
    }

    @MainActor
    func testCellarRoomHitMasksFromNormalChapterTenEntry() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-normal-cellar-entry")).load() else {
            throw XCTSkip("The normal Chapter 10 cellar entry checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { play.stop() }
        play.resume()
        XCTAssertEqual(play.runner.game.mapID, 8)
        XCTAssertEqual(play.lobby?.mode, .walking)

        var hits = [String: (marker: String, point: SIMD2<Float>)]()
        for markerName in ["hyde_point00", "s01", "s02", "s03"] {
            guard let scene = play.lobby,
                  let marker = scene.room.nodes.first(where: { $0.name == markerName }) else { continue }
            let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
            try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
            OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
            guard let facing = play.lobby else { continue }
            let visible = facing.objectVisibility.visibleNodes(in: facing.room, map: facing.mapID,
                area: nil, game: play.runner.game)
            for y in stride(from: 0, to: 256, by: 4) {
                for x in stride(from: 0, to: 192, by: 4) {
                    let point = SIMD2<Float>(Float(x), Float(y))
                    guard let node = try facing.pickedRoomObject(page: point, visibleNodes: visible) else { continue }
                    if hits[node] == nil { hits[node] = (markerName, point) }
                }
            }
        }

        for (node, hit) in hits.sorted(by: { $0.key < $1.key }) {
            print("R108 room hit node=\(node) marker=\(hit.marker) point=\(hit.point)")
        }
        XCTAssertFalse(hits.isEmpty, "The cellar room should expose selectable normal room hit masks")
    }

    @MainActor
    func testCellarCounterHitSweepFromNormalCheckpoint() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter10-normal-cellar-shelf")).load() else {
            throw XCTSkip("The normal Chapter 10 cellar shelf checkpoint is not available")
        }
        let seed = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
        defer { seed.stop() }
        seed.resume()
        var firstHit: [String: (pan: Float, point: SIMD2<Float>)] = [:]
        var bottleHits: [(pan: Float, point: SIMD2<Float>)] = []
        for step in 0...4 {
            let pan = Float(step) / 4
            seed.panLobbyCounter(pan)
            let currentShelf = try XCTUnwrap(seed.lobby)
            let visible = currentShelf.objectVisibility.visibleNodes(in: currentShelf.counter,
                map: currentShelf.mapID, area: currentShelf.searchAreaID, game: seed.runner.game)
            for y in stride(from: 0, to: 256, by: 4) {
                for x in stride(from: 0, to: 192, by: 4) {
                    let point = SIMD2<Float>(Float(x), Float(y))
                    if let node = try currentShelf.pickedCounterNode(page: point, visibleNodes: visible) {
                        if firstHit[node] == nil { firstHit[node] = (pan, point) }
                        if node == "obj21", !bottleHits.contains(where: { $0.pan == pan }) {
                            bottleHits.append((pan, point))
                        }
                    }
                }
            }
        }
        seed.stop()

        let hits = firstHit.map { (node: $0.key, pan: $0.value.pan, point: $0.value.point) } +
            bottleHits.filter { $0.pan != firstHit["obj21"]?.pan }
                .map { (node: "obj21", pan: $0.pan, point: $0.point) }
        for hit in hits.sorted(by: { ($0.node, $0.pan) < ($1.node, $1.pan) }) {
            let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)),
                mapRendererFactory: { name, _ in try OriginalRouteBitmapMapRenderer(mapName: name) })
            play.resume()
            play.panLobbyCounter(hit.pan)
            play.selectLobbyObject(x: hit.point.x, y: hit.point.y, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
            let result = "node=\(hit.node) pan=\(hit.pan) point=\(hit.point) mode=\(play.runner.session.selection.modeID) " +
                "event=\(play.runner.session.selection.eventID) eventIndex=\(String(describing: play.runner.eventIndex)) " +
                "flag8:9=\(String(describing: play.runner.game.value(for: .eventFlag(group: 8, index: 9)))) " +
                "item77=\(try play.runner.game.inventory.items.contains(77)) phase=\(play.runner.phase)"
            print(result)
            XCTAssertNil(play.runner.eventIndex, "\(hit.node) at pan \(hit.pan) should not start a script event")
            XCTAssertFalse(try play.runner.game.inventory.items.contains(77),
                "\(hit.node) at pan \(hit.pan) should not award the whiskey")
            XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 8, index: 9)), false,
                "\(hit.node) at pan \(hit.pan) should not set the cellar event flag")
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 8))
            play.stop()
        }
        XCTAssertFalse(firstHit.isEmpty, "The visible cellar counter should have selectable hit meshes")
        XCTAssertGreaterThanOrEqual(bottleHits.count, 3,
            "The back-shelf object should be reachable at several sampled counter pans")
    }
}
