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

    func testPencilRewindMatchesCapturedSwipeAndReturnTiming() {
        var process = OriginalCassetteRewindProcess()
        process.update(rawTouch: SIMD2(141, 130))
        for x in stride(from: 140, through: 135, by: -1) {
            process.update(rawTouch: SIMD2(x, 130))
        }
        for y in stride(from: 129, through: 100, by: -1) {
            process.update(rawTouch: SIMD2(135, y))
        }
        for _ in 0..<5 {
            process.update(rawTouch: SIMD2(135, 100))
        }

        XCTAssertEqual(process.phase, .rewindAnimation)
        XCTAssertEqual(process.dragProgress, 85)
        XCTAssertEqual(process.qualifyingTouchFrames, OriginalCassetteRewindProcess.completionCounter)

        for _ in 0..<OriginalCassetteRewindProcess.animationWaitUpdates {
            process.update(rawTouch: nil)
        }
        XCTAssertEqual(process.phase, .returnPending)
        XCTAssertNil(process.returnedProcessValue)

        process.update(rawTouch: nil)
        XCTAssertNil(process.returnedProcessValue)
        process.update(rawTouch: nil)
        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.returnedProcessValue, 0)
    }

    func testOppositeSwipeDoesNotRewindTape() {
        var process = OriginalCassetteRewindProcess()
        process.update(rawTouch: SIMD2(141, 130))
        for x in stride(from: 140, through: 135, by: -1) {
            process.update(rawTouch: SIMD2(x, 130))
        }
        for y in 131...190 {
            process.update(rawTouch: SIMD2(135, y))
        }

        XCTAssertEqual(process.phase, .tracking)
        XCTAssertEqual(process.dragProgress, 100)
        XCTAssertEqual(process.qualifyingTouchFrames, 0)
    }

    func testProcess45QuitTapReturnsThroughTheCapturedSixtyUpdateFade() {
        var process = OriginalCassetteRewindProcess()
        process.update(rawTouch: nil, pressedTouch: SIMD2(15, 170))

        XCTAssertEqual(process.phase, .quitFade)
        XCTAssertEqual(process.opacity, 1)
        XCTAssertNil(process.returnedProcessValue)

        for _ in 0..<(OriginalCassetteRewindProcess.quitFadeUpdates - 1) {
            process.update(rawTouch: nil)
        }
        XCTAssertEqual(process.phase, .quitFade)
        XCTAssertNil(process.returnedProcessValue)
        XCTAssertGreaterThan(process.opacity, 0)

        process.update(rawTouch: nil)

        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.returnedProcessValue, 2)
        XCTAssertEqual(process.opacity, 1)
    }
}
