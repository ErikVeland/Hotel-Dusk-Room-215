import XCTest
@testable import HotelDuskDuoKit

final class OriginalCassetteTouchRegionTests: XCTestCase {
    func testMapsRawTouchUsingBothSourceOrientations() {
        XCTAssertEqual(OriginalCassetteTouchRegion.processPoint(rawTouch: SIMD2(141, 130), rotated: false),
                       SIMD2(114, 130))
        XCTAssertEqual(OriginalCassetteTouchRegion.processPoint(rawTouch: SIMD2(114, 60), rotated: true),
                       SIMD2(114, 131))
    }

    func testCorrectedPointHitsTheSourceGateAndOldProbeMisses() {
        XCTAssertTrue(OriginalCassetteTouchRegion.containsStartTap(SIMD2(141, 130), rotated: false))
        XCTAssertFalse(OriginalCassetteTouchRegion.containsStartTap(SIMD2(114, 130), rotated: false))
    }

    func testSourceGateIncludesItsEdgesAndRejectsPointsOutsideTheDisplay() {
        XCTAssertTrue(OriginalCassetteTouchRegion.containsStartTap(SIMD2(147, 100), rotated: false))
        XCTAssertTrue(OriginalCassetteTouchRegion.containsStartTap(SIMD2(135, 191), rotated: false))
        XCTAssertFalse(OriginalCassetteTouchRegion.containsStartTap(SIMD2(148, 130), rotated: false))
        XCTAssertFalse(OriginalCassetteTouchRegion.containsStartTap(SIMD2(141, 192), rotated: false))
        XCTAssertFalse(OriginalCassetteTouchRegion.containsStartTap(SIMD2(-1, 130), rotated: false))
    }
}
