import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingPinFieldTests: XCTestCase {
    func testPinCentresFollowTheRecoveredFourRowFormation() {
        let positions = OriginalBowlingPinField.initialPositions
        XCTAssertEqual(positions.count, 10)
        for (index, expected) in [
            SIMD2<Float>(0, -2.75), SIMD2(-0.2, -3.0964), SIMD2(0.2, -3.0964),
            SIMD2(-0.4, -3.4428), SIMD2(0, -3.4428), SIMD2(0.4, -3.4428),
            SIMD2(-0.6, -3.7892), SIMD2(-0.2, -3.7892), SIMD2(0.2, -3.7892),
            SIMD2(0.6, -3.7892)
        ].enumerated() {
            XCTAssertEqual(positions[index].x, expected.x, accuracy: 0.0001)
            XCTAssertEqual(positions[index].y, expected.y, accuracy: 0.0001)
        }
    }

    func testScoreCountsPinsWithNonZeroRotation() {
        var pins = OriginalBowlingPinField()

        XCTAssertEqual(pins.score, 0)
        XCTAssertTrue(pins.setRotation(1, forPin: 0))
        XCTAssertTrue(pins.setRotation(-1, forPin: 4))
        XCTAssertEqual(pins.score, 2)
    }

    func testZeroRotationLeavesPinStandingAndCanClearPriorRotation() {
        var pins = OriginalBowlingPinField()
        _ = pins.setRotation(12, forPin: 3)
        _ = pins.setRotation(0, forPin: 3)

        XCTAssertEqual(pins.score, 0)
    }

    func testRejectsPinIndicesOutsideTheOriginalTenPinField() {
        var pins = OriginalBowlingPinField()

        XCTAssertFalse(pins.setRotation(1, forPin: -1))
        XCTAssertFalse(pins.setRotation(1, forPin: OriginalBowlingPinField.pinCount))
        XCTAssertEqual(pins.score, 0)
    }
}
