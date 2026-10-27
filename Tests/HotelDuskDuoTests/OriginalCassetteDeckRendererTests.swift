import Metal
import XCTest
@testable import HotelDuskDuoKit

final class OriginalCassetteDeckRendererTests: XCTestCase {
    @MainActor func testCapturedSceneRendersAndBuildsFullModelMasks() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalCassetteDeckRenderer()
        let camera = OriginalCassetteDeckCamera(
            positionFixed20_12: SIMD3(16794, 12288, 49971),
            upFixed20_12: SIMD3(-4096, 0, 0),
            targetFixed20_12: SIMD3(2048, 6554, 0)
        )
        let state = OriginalCassetteDeckRenderer.SceneState(
            radio: .init(rotationDegrees: SIMD3(0, 180, 0), translation: SIMD3(3.55, -1, 0)),
            front: .init(rotationDegrees: .zero, translation: .zero),
            tape: .init(rotationDegrees: .zero, translation: SIMD3(1.45, 0.9, -0.65))
        )

        for object in [OriginalCassetteDeckRenderer.Object.radio, .front, .tape] {
            let mask = try renderer.hitMask(for: object, camera: camera, state: state)
            XCTAssertGreaterThan(mask.triangleCount, 0)
            XCTAssertFalse(mask.bounds.isNull)
        }
        XCTAssertNotNil(try renderer.hitTest(pagePoint: SIMD2(156, 179), camera: camera, state: state))
        let image = try renderer.render(camera: camera, state: state)
        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 256)
    }
}
