import Metal
import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingRendererTests: XCTestCase {
    @MainActor
    func testCapturedReadySceneRendersAndBallMaskContainsTheSourceSelectionTouch() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is unavailable in this test environment.")
        }
        let pins = OriginalBowlingPinField().pins
        let state = try OriginalBowlingRenderer.SceneState(
            cameraMatrixFixed20_12: [
                0, 12_288, 21_709, 0, 2_048, -43_827, 0, 0,
                0, -4_096, 0, 0, 0, 4_096, 0, 0
            ],
            ballPositionFixed20_12: SIMD3(0, 1_556, 10_240), pins: pins)
        let renderer = try OriginalBowlingRenderer()
        let image = try renderer.render(state)

        XCTAssertEqual(image.width, 768)
        XCTAssertEqual(image.height, 1024)
        XCTAssertTrue(try renderer.selectsBall(pagePoint: SIMD2(105, 240), state: state))
        XCTAssertFalse(try renderer.selectsBall(pagePoint: SIMD2(40, 30), state: state))
    }
}
