import XCTest
@testable import HotelDuskDuoKit

final class OriginalAfterConfessProcessTests: XCTestCase {
    func testSourceSceneGroupsAdvanceToReturnTwo() {
        var process = OriginalAfterConfessProcess()

        for _ in 0..<OriginalAfterConfessProcess.frameCounts[0] { XCTAssertFalse(process.update()) }
        XCTAssertEqual(process.phase, .secondScene)
        XCTAssertEqual(process.frameInPhase, 0)

        for _ in 0..<OriginalAfterConfessProcess.frameCounts[1] { XCTAssertFalse(process.update()) }
        XCTAssertEqual(process.phase, .finalScene)

        for _ in 0..<(OriginalAfterConfessProcess.frameCounts[2] - 1) {
            XCTAssertFalse(process.update())
        }
        XCTAssertTrue(process.update())
        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.resultValue, 2)
        XCTAssertFalse(process.update())
    }
}
