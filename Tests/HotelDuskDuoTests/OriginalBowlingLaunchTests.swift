import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingLaunchTests: XCTestCase {
    func testAveragesTheTwoFinalDragDeltas() {
        let velocity = OriginalBowlingLaunch.velocity(
            currentDelta: SIMD3(20, -10, -500),
            previousDelta: SIMD3(10, 30, -400)
        )

        XCTAssertEqual(velocity, SIMD3(15, 0, -450))
    }

    func testRejectsForwardDeltaAtOrAboveLaunchThreshold() {
        XCTAssertNil(OriginalBowlingLaunch.velocity(
            currentDelta: SIMD3(0, 0, -205), previousDelta: SIMD3(0, 0, -205)))
        XCTAssertNil(OriginalBowlingLaunch.velocity(
            currentDelta: SIMD3(0, 0, -200), previousDelta: SIMD3(0, 0, -100)))
    }

    func testClampsForwardVelocityToSourceMinimum() {
        let velocity = OriginalBowlingLaunch.velocity(
            currentDelta: SIMD3(0, 0, -2000), previousDelta: SIMD3(0, 0, -2000)
        )

        XCTAssertEqual(velocity, SIMD3(0, 0, -819))
    }

    func testCapturedCentreRollDeltaPassesTheSourceLaunchGate() {
        let velocity = OriginalBowlingLaunch.velocity(
            currentDelta: SIMD3(-61, 1467, -1755),
            previousDelta: SIMD3(-82, 1467, -2341))

        XCTAssertEqual(velocity, SIMD3(-71, 0, -819))
    }
}
