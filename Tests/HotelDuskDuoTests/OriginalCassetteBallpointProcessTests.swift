import XCTest
@testable import HotelDuskDuoKit

final class OriginalCassetteBallpointProcessTests: XCTestCase {
    func testSlotFiveQuitReturnsAfterDelayAndFade() {
        var process = OriginalCassetteBallpointProcess()
        process.update(newRawTouch: SIMD2(15, 170))

        XCTAssertEqual(process.phase, .quitDelay)
        for _ in 0..<OriginalCassetteBallpointProcess.quitDelayUpdates {
            process.update(newRawTouch: nil)
        }
        XCTAssertEqual(process.phase, .fading)

        for _ in 0..<OriginalCassetteBallpointProcess.quitFadeUpdates {
            process.update(newRawTouch: nil)
        }
        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.returnedProcessValue, 2)
    }

    func testTouchOutsideQuitTargetDoesNotReturn() {
        var process = OriginalCassetteBallpointProcess()
        process.update(newRawTouch: SIMD2(40, 170))

        XCTAssertEqual(process.phase, .waiting)
        XCTAssertNil(process.returnedProcessValue)
    }
}
