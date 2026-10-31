import CoreGraphics
import Foundation
import ImageIO
import Metal
import XCTest
@testable import HotelDuskDuoKit

final class OriginalSearchShedRendererTests: XCTestCase {
    @MainActor func testSourceBoxesRenderFromRecoveredTransforms() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalSearchShedRenderer()
        let image = try renderer.render(OriginalSearchShedProcess())
        XCTAssertEqual(image.width, 768)
        XCTAssertEqual(image.height, 1024)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertGreaterThan(pixels.enumerated().filter { $0.offset % 4 == 3 && $0.element > 0 }.count, 256)
        XCTAssertGreaterThan(Set(pixels).count, 16)
        if let output = ProcessInfo.processInfo.environment["HOTEL_DUSK_MODEL_PREVIEW"] {
            let url = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }

    @MainActor func testVisibleBoxMeshesProvideObjectHitMasks() throws {
        let model = try OriginalModelLibrary.bundled().load(path: "trick/searchshed/soko.mdf")
        var process = OriginalSearchShedProcess()
        _ = process.update()
        var hitObjects = Set<Int>()
        for y in stride(from: 4, to: 256, by: 8) {
            for x in stride(from: 4, to: 192, by: 8) {
                if let object = OriginalSearchShedRenderer.object(
                    at: SIMD2(Float(x), Float(y)), process: process, model: model) {
                    hitObjects.insert(object)
                }
            }
        }

        XCTAssertGreaterThan(hitObjects.count, 1)
        XCTAssertTrue(hitObjects.allSatisfy(process.objects.indices.contains))

        for index in process.objects.indices where index != 9 {
            let position = process.objects[index].position
            process.beginDrag(object: index, at: SIMD2(position.x, position.z))
            process.drag(to: SIMD2(position.x + 100, position.z))
            process.endDrag()
        }
        var targetIsSelectable = false
        for y in stride(from: 4, to: 256, by: 8) {
            for x in stride(from: 4, to: 192, by: 8) {
                if OriginalSearchShedRenderer.object(
                    at: SIMD2(Float(x), Float(y)), process: process, model: model) == 9 {
                    targetIsSelectable = true
                    break
                }
            }
            if targetIsSelectable { break }
        }
        XCTAssertTrue(targetIsSelectable)
    }
}
