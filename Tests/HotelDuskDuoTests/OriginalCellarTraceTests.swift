import XCTest
@testable import HotelDuskDuoKit

final class OriginalCellarTraceTests: XCTestCase {
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
