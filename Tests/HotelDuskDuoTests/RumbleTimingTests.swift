import XCTest
@testable import HotelDuskDuoKit

final class RumbleTimingTests: XCTestCase {
    @MainActor
    func testGameSessionUsesTheSystemHapticAdapterByDefault() {
        let session = GameSession()

        XCTAssertTrue(session.rumbleFeedback is SystemRumbleFeedback)
    }

    func testOneFrameCueUsesMinimumHapticDuration() {
        XCTAssertEqual(RumbleTiming.durationSeconds(frameCount: 1, updatesPerSecond: 59.8261), 0.08)
    }

    func testLongerCueUsesSourceFrameDuration() {
        XCTAssertEqual(RumbleTiming.durationSeconds(frameCount: 20, updatesPerSecond: 59.8261), 20 / 59.8261, accuracy: 0.000_001)
    }

    func testMissingCueDurationUsesDefaultPulse() {
        XCTAssertEqual(RumbleTiming.durationSeconds(frameCount: nil, updatesPerSecond: 59.8261), 8 / 59.8261, accuracy: 0.000_001)
    }

    func testCueDurationIsBounded() {
        XCTAssertEqual(RumbleTiming.durationSeconds(frameCount: -1, updatesPerSecond: 59.8261), 0.08)
        XCTAssertEqual(RumbleTiming.durationSeconds(frameCount: 10_000, updatesPerSecond: 59.8261), 30)
    }
}
