import Foundation
import ImageIO
import Metal
import simd
import XCTest
@testable import HotelDuskDuoKit

final class OriginalModelMetalTests: XCTestCase {
    @MainActor func testLouieRoomLoadsAndRendersAtItsDoorEntry() throws {
        let map = try OriginalMapExploration.bundled(mapID: 14, previousMapID: 19)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(14, previous: 19)
        let renderer = try OriginalMapRenderer(mapName: "R114")
        let image = try renderer.render(map, game: game)
        XCTAssertGreaterThanOrEqual(image.width, 768)
        XCTAssertGreaterThanOrEqual(image.height, 1024)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertGreaterThan(Set(pixels).count, 32)
        if let output = ProcessInfo.processInfo.environment["HOTEL_DUSK_MODEL_PREVIEW"] {
            let url = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }

    func testNativeMetalDrawsOriginalRoomGeometryAndTextures() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal unavailable on this host") }
        let preview = try OriginalModelMetalPreview(modelPath: "map/R212/R212/R212.mdf",
            models: OriginalModelLibrary.bundled(), textures: OriginalTextureLibrary.bundled(), device: device)
        XCTAssertFalse(preview.texturePaths.isEmpty)
        // Diagnostic camera only. Gameplay must supply its recovered camera.
        let eye = SIMD3<Float>(0, 1.65, 4), target = SIMD3<Float>(0, 1.65, -2)
        let back = simd_normalize(eye - target)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), back))
        let up = simd_cross(back, right)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, back.x, 0), SIMD4(right.y, up.y, back.y, 0),
            SIMD4(right.z, up.z, back.z, 0),
            SIMD4(-simd_dot(right, eye), -simd_dot(up, eye), -simd_dot(back, eye), 1)))
        let aspect: Float = 0.75, near: Float = 0.1, far: Float = 100
        let sy = 1 / tan(Float.pi / 6), sx = sy / aspect
        let projection = simd_float4x4(columns: (
            SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, far / (near - far), -1), SIMD4(0, 0, near * far / (near - far), 0)))
        let room = Set(preview.model.nodes.indices.filter { preview.model.nodes[$0].name == "room" })
        XCTAssertFalse(room.isEmpty)
        let image = try preview.render(width: 384, height: 512, viewProjection: projection * view, visibleNodes: room)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertGreaterThan(pixels.enumerated().filter { $0.offset % 4 == 3 && $0.element > 0 }.count, 384 * 512 / 2)
        XCTAssertGreaterThan(Set(pixels).count, 32)
        if let output = ProcessInfo.processInfo.environment["HOTEL_DUSK_MODEL_PREVIEW"] {
            let url = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}
