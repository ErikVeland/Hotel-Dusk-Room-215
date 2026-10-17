import ImageIO
import Metal
import simd
import XCTest
@testable import HotelDuskDuoKit

final class OriginalLobbyExplorationTests: XCTestCase {
    func testArrivalCheckpointHeadingWaitsForWalkingUpdate() throws {
        var map = try OriginalMapExploration.bundled(mapID: 39, previousMapID: 37)
        XCTAssertEqual(map.position, SIMD3(133813, 12288, 12739))
        XCTAssertEqual(map.facing, .pi, accuracy: 0.000001)
        XCTAssertEqual(map.checkpointFacing, 0)
        map.update(heldPageTouch: nil)
        XCTAssertEqual(map.checkpointFacing, map.facing)
    }

    func testCharacterCollisionUsesTheFloorRadiusAndOriginalRounding() {
        let rosa = SIMD3<Float>(14166, 0, 4101)
        XCTAssertEqual(OriginalMapExploration.resolvePeople(SIMD3(16160, 12288, 11777), people: [rosa]),
                       SIMD3(16226, 12288, 12029))
        XCTAssertEqual(OriginalMapExploration.resolvePeople(SIMD3(0, 12288, 100), people: [.zero]),
                       SIMD3(0, 12288, 8192))
        XCTAssertEqual(OriginalMapExploration.resolvePeople(SIMD3(-100, 12288, 0), people: [.zero]),
                       SIMD3(-8192, 12288, 0))
        for point in [SIMD3<Float>(0, 12288, 8192), SIMD3(0, 12288, 8193), SIMD3(0, 12288, 0)] {
            XCTAssertEqual(OriginalMapExploration.resolvePeople(point, people: [.zero]), point)
        }
        XCTAssertEqual(OriginalMapExploration.resolvePeople(SIMD3(100, 12288, 0), people: []), SIMD3(100, 12288, 0))
    }

    func testTurningMatchesRosasOriginalApproach() {
        var facing: Float = 1.1678941249847412
        for _ in 0..<3 { facing = OriginalMapExploration.turn(from: facing, towards: 0) }
        XCTAssertEqual(facing, 0.9624416828155518)
        for _ in 0..<29 { facing = OriginalMapExploration.turn(from: facing, towards: Float(bitPattern: 0x40490FDB)) }
        XCTAssertEqual(facing, 2.9292964935302734)
        let fullTurn = Float(bitPattern: 0x40C90FDB)
        XCTAssertEqual(OriginalMapExploration.turn(from: fullTurn, towards: 0), fullTurn)
    }

    private func atCounter() throws -> OriginalMapExploration {
        var lobby = try OriginalMapExploration.bundled()
        // ROM inputs: raw (175,140) for 160 frames, then (180,70) for 45.
        for _ in 0..<160 { lobby.update(heldPageTouch: SIMD2(140, 80)) }
        XCTAssertEqual(lobby.position.x, 25156, accuracy: 4)
        XCTAssertEqual(lobby.position.z, -4267, accuracy: 4)
        // ROM polling starts one frame late and releases two frames late: 46 movement updates.
        for _ in 0..<46 { lobby.update(heldPageTouch: SIMD2(70, 75)) }
        XCTAssertEqual(lobby.position.x, 22396, accuracy: 4)
        XCTAssertEqual(lobby.position.z, -4267, accuracy: 4)
        XCTAssertEqual(lobby.facing, 3.50173974, accuracy: 0.02)
        XCTAssertTrue(lobby.canInspectCounter)
        return lobby
    }

    func testArrivalAndDeadZone() throws {
        var lobby = try OriginalMapExploration.bundled()
        XCTAssertEqual(lobby.position, SIMD3(-82, 12288, 21217))
        XCTAssertFalse(lobby.canInspectCounter)
        XCTAssertFalse(lobby.inspectCounter())
        for touch in [nil, SIMD2<Float>(96, 128), SIMD2<Float>(104, 128)] {
            lobby.update(heldPageTouch: touch)
        }
        XCTAssertEqual(lobby.position, SIMD3(-82, 12288, 21217))
    }

    func testWalkMatchesCapturedWallAndCounterPositions() throws {
        var lobby = try atCounter()
        XCTAssertTrue(lobby.inspectCounter())
        let position = lobby.position
        lobby.update(heldPageTouch: SIMD2(0, 0))
        XCTAssertEqual(lobby.position, position)
        lobby.leaveCounter()
        XCTAssertEqual(lobby.mode, .walking)
        XCTAssertTrue(lobby.canInspectCounter)
    }

    func testCameraAndBellSelectionUseOriginalModel() throws {
        var lobby = try atCounter()
        XCTAssertTrue(lobby.inspectCounter())
        XCTAssertEqual(lobby.pan, 0.7659817, accuracy: 0.002)
        lobby.setPan(0)
        let eye = lobby.camera.eye * 4096
        XCTAssertEqual(eye.x, 6677, accuracy: 3)
        XCTAssertEqual(eye.y, 12993, accuracy: 3)
        XCTAssertEqual(eye.z, -2786, accuracy: 3)
        let node = try XCTUnwrap(lobby.pickedCounterNode(page: SIMD2(126, 195)))
        XCTAssertEqual(OriginalMapExploration.subarea(node: node), 2)
        XCTAssertNil(try lobby.selectCounterObject(page: SIMD2(126, 195)))
        XCTAssertEqual(try lobby.selectCounterObject(page: SIMD2(126, 195)), 2)
        lobby.setPan(1)
        XCTAssertNil(lobby.selectedNode)
        XCTAssertNil(try lobby.pickedCounterNode(page: SIMD2(-1, 180)))
        XCTAssertNil(OriginalMapExploration.subarea(node: "desk"))
        XCTAssertNil(OriginalMapExploration.subarea(node: "objA2"))
        XCTAssertEqual(OriginalMapExploration.subarea(node: "obj02x2_BELL"), 2)
    }

    func testWalkAndModelPickEnterBellProcessWithoutFixture() throws {
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: .bundled(), defaults: .bundled())
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        runner.finishProcess(returnValue: 0)
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
        var lobby = try atCounter()
        XCTAssertTrue(lobby.inspectCounter())
        lobby.setPan(0)
        let node = try XCTUnwrap(lobby.pickedCounterNode(page: SIMD2(126, 195)))
        let subarea = try XCTUnwrap(OriginalMapExploration.subarea(node: node))
        runner.lookInSearchView(area: 2, subarea: subarea, table: try .bundled(map: "R102"))
        XCTAssertEqual(runner.eventIndex, 3)
        runner.acknowledgeDialogue()
        XCTAssertEqual(runner.phase, .process(id: 24))
        runner.finishProcess(returnValue: 1)
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(lobby.mode, .counter)
    }

    func testMapDecoderRejectsMalformedInput() throws {
        let bitmap = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/R102.bin")
        XCTAssertEqual(bitmap.width, 512)
        XCTAssertEqual(bitmap.height, 512)
        XCTAssertEqual(bitmap.rgba.count, 512 * 512 * 4)
        XCTAssertEqual(Set(bitmap.rgba).count, 32)
        XCTAssertThrowsError(try OriginalMapBitmap(data: Data(repeating: 0, count: 16)))
        XCTAssertThrowsError(try OriginalMapCollision(data: Data(repeating: 0, count: 48)))
    }

    @MainActor
    func testNativeLobbyAndCounterRender() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalMapRenderer()
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        var lobby = try atCounter()
        var images = [("lobby", try renderer.render(lobby, game: game)), ("map", renderer.map)]
        XCTAssertTrue(lobby.inspectCounter())
        lobby.setPan(0)
        images.append(("counter", try renderer.render(lobby, game: game)))
        for (name, image) in images {
            let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
            XCTAssertGreaterThanOrEqual(Set(pixels).count, 32)
            if let folder = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
                let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                XCTAssertTrue(CGImageDestinationFinalize(destination))
            }
        }
    }
}
