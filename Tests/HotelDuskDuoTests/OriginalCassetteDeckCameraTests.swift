import simd
import XCTest
@testable import HotelDuskDuoKit

final class OriginalCassetteDeckCameraTests: XCTestCase {
    func testTargetProjectsToScreenCentreFromSourceCameraVectors() {
        let camera = OriginalCassetteDeckCamera(
            positionFixed20_12: SIMD3(-5325, 22118, 15974),
            upFixed20_12: SIMD3(-4096, 0, 0),
            targetFixed20_12: SIMD3(-5325, 6554, 0)
        )
        let clip = camera.viewProjection * SIMD4(camera.target, 1)

        XCTAssertGreaterThan(clip.w, 0)
        XCTAssertEqual(clip.x / clip.w, 0, accuracy: 0.0001)
        XCTAssertEqual(clip.y / clip.w, 0, accuracy: 0.0001)
    }
}
