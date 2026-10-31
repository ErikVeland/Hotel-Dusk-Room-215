import XCTest
import SwiftUI
import ImageIO
import simd
@testable import HotelDuskDuoKit

final class OriginalMapIndicatorTests: XCTestCase {
    func testScrollingFloorPlanKeepsKyleAtTheOriginalTouchCentre() throws {
        var map = try OriginalMapExploration.bundled()
        XCTAssertEqual(map.mapPlayerPoint, SIMD2(96, 128))
        let offset = map.mapBitmapOffset
        for _ in 0..<20 { map.update(heldPageTouch: SIMD2(160, 128)) }
        XCTAssertNotEqual(map.mapBitmapOffset, offset)
        XCTAssertEqual(map.mapPlayerPoint, SIMD2(96, 128))
        map.turnView(by: .pi / 2)
        XCTAssertEqual(map.mapPlayerPoint, SIMD2(96, 128))
    }

    func testCompactFloorPlanMarkerFollowsKyleWhenScrollingReachesItsLimit() throws {
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(31, previous: 39)
        game.setMapPosition(SIMD3(0, 12288, 0), facing: 0)
        let centred = try OriginalMapExploration.bundled(mapID: 31, savedGame: game)
        XCTAssertEqual(centred.mapPlayerPoint, SIMD2(96, 128))
        game.setMapPosition(SIMD3(32768, 12288, -32768), facing: .pi)
        let edge = try OriginalMapExploration.bundled(mapID: 31, savedGame: game)
        XCTAssertEqual(edge.mapPlayerPoint.x, 116.6, accuracy: 0.001)
        XCTAssertEqual(edge.mapPlayerPoint.y, 95.4, accuracy: 0.001)
    }

    func testViewConeMatchesCameraForwardAndHorizontalFrustumAtEveryHeading() throws {
        var map = try OriginalMapExploration.bundled()
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        for _ in 0..<8 {
            let cone = OriginalMapViewCone(facing: map.facing,
                fieldOfView: OriginalMapExploration.walkingHorizontalFieldOfView)
            let path = cone.path(in: rect)
            let camera = map.camera
            let forward = simd_normalize(camera.target - camera.eye)
            let right = simd_normalize(simd_cross(forward, SIMD3(0, 1, 0)))
            for (side, inside) in [(Float(0), true), (0.46, true), (-0.46, true), (0.47, false), (-0.47, false)] {
                let ray = simd_normalize(forward + right * side)
                let point = CGPoint(x: 50 + CGFloat(ray.x) * 30, y: 50 + CGFloat(ray.z) * 30)
                let clip = map.viewProjection * SIMD4(camera.eye + ray * 3, 1)
                XCTAssertEqual(abs(clip.x / clip.w) < 1, inside)
                XCTAssertEqual(path.contains(point), inside, "Heading \(map.facing), side \(side)")
            }
            XCTAssertFalse(path.contains(CGPoint(x: 50 - CGFloat(forward.x) * 30,
                                                 y: 50 - CGFloat(forward.z) * 30)))
            map.turnView(by: .pi / 4)
        }
    }

    @MainActor func testIndicatorRendersOnFloorPlanAtRetinaScale() throws {
        let map = try OriginalMapExploration.bundled()
        let bitmap = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/R102.bin")
        let image = try XCTUnwrap(bitmap.makeCGImage())
        let renderer = ImageRenderer(content: OriginalFloorPlanView(image: image, exploration: map))
        renderer.scale = 3
        let rendered = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(rendered.width, 576)
        XCTAssertEqual(rendered.height, 768)
        let context = try XCTUnwrap(CGContext(data: nil, width: 576, height: 768,
            bitsPerComponent: 8, bytesPerRow: 576 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: 768)
        context.scaleBy(x: 1, y: -1)
        context.draw(rendered, in: CGRect(x: 0, y: 0, width: 576, height: 768))
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let centre = (384 * 576 + 288) * 4
        XCTAssertGreaterThan(Int(pixels[centre]), Int(pixels[centre + 1]) + 80)
        let arrow = (342 * 576 + 288) * 4
        XCTAssertGreaterThan(Int(pixels[arrow]), Int(pixels[arrow + 1]) + 80)
        if let folder = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            let url = URL(fileURLWithPath: folder).appendingPathComponent("floor-plan-navigation.png")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let output = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(output, rendered, nil)
            XCTAssertTrue(CGImageDestinationFinalize(output))
        }
    }
}
