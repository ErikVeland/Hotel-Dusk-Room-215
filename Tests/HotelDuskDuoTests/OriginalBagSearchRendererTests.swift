import XCTest
import Metal
import simd
@testable import HotelDuskDuoKit

final class OriginalBagSearchRendererTests: XCTestCase {
    func testOverlayThirtyCubeModelAndTextureDecode() throws {
        let models = try OriginalModelLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        let model = try models.load(path: "trick/searchshed/soko.mdf")
        XCTAssertFalse(model.nodes.isEmpty)
        XCTAssertTrue(model.groups.contains { $0.render != nil })
        for textureName in ["yuka", "kabe01", "tenjoh"] {
            _ = try bitmaps.loadTexture(path: "trick/searchshed/\(textureName).bin")
        }
    }

    func testCPUProjectionFindsTheRenderedTreeBoxSilhouetteAndGroundTarget() throws {
        let library = try OriginalModelLibrary.bundled()
        let models = [try library.load(path: "trick/searchshed/soko.mdf")]
        let projection = try OriginalBagSearchProjection(models: models)
        var process = OriginalBagSearchProcess()
        for index in process.objects.indices where index != 9 {
            let object = process.objects[index]
            let start = SIMD2(object.positionFixed.x, object.positionFixed.z)
            process.beginDrag(object: index, at: start)
            process.drag(to: SIMD2(start.x + 40_960, start.y + 40_960))
            _ = process.endDrag()
        }
        let treeBox = try XCTUnwrap(process.objects.firstIndex { $0.type == 3 })
        let masks = try projection.objectMasks(process: process)
        let treeBoxMask = try XCTUnwrap(masks.first { $0.0 == treeBox }?.1)
        var hitPoint: SIMD2<Float>?

        let minX = max(0, Int(treeBoxMask.bounds.minX))
        let maxX = min(192, Int(treeBoxMask.bounds.maxX.rounded(.up)))
        let minY = max(0, Int(treeBoxMask.bounds.minY))
        let maxY = min(256, Int(treeBoxMask.bounds.maxY.rounded(.up)))
        for y in stride(from: minY, to: maxY, by: 2) where hitPoint == nil {
            for x in stride(from: minX, to: maxX, by: 2) {
                let point = SIMD2(Float(x), Float(y))
                guard let depth = treeBoxMask.depth(at: point) else { continue }
                let frontDepth = masks.compactMap { $0.1.depth(at: point) }.min() ?? .infinity
                if depth <= frontDepth {
                    hitPoint = point
                    break
                }
            }
        }

        XCTAssertNotNil(hitPoint)
        _ = try XCTUnwrap((0..<256).flatMap { y in
            (0..<192).compactMap { x in projection.planePointFixed(at: SIMD2(Float(x), Float(y))) }
        }.first)
    }

    @MainActor
    func testOriginalCubeModelRendersAndExposesObjectShapedTouchMasks() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalBagSearchRenderer()
        let process = OriginalBagSearchProcess()
        let image = try renderer.render(process)

        XCTAssertEqual(image.width, 768)
        XCTAssertEqual(image.height, 1024)

        let touches = stride(from: 0, to: 256, by: 4).flatMap { y in
            stride(from: 0, to: 192, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        XCTAssertTrue(try touches.contains { try renderer.object(at: $0, process: process) != nil })

        let groundPoint = try XCTUnwrap(stride(from: 0, to: 256, by: 2).flatMap { y in
            stride(from: 0, to: 192, by: 2).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { renderer.planePointFixed(at: $0) != nil })
        XCTAssertNotNil(renderer.planePointFixed(at: groundPoint))
    }
}
