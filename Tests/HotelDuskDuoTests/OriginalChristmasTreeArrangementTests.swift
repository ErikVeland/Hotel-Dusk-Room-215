import XCTest
@testable import HotelDuskDuoKit

final class OriginalChristmasTreeArrangementTests: XCTestCase {
    func testDropMustLandInsideRecoveredTargetAndCompletionUsesPackedOrder() {
        var arrangement = OriginalChristmasTreeArrangement()

        XCTAssertNil(arrangement.drop(decoration: 0, at: SIMD2(0, 0)))
        XCTAssertFalse(arrangement.isComplete)
        for decoration in 0..<11 {
            let target = OriginalChristmasTreeLayout.modelDecorationTargets[decoration]
            XCTAssertEqual(arrangement.drop(decoration: decoration, at: target), decoration)
        }

        XCTAssertTrue(arrangement.isComplete)
        guard let encodedOrder = arrangement.encodedOrder else {
            return XCTFail("Expected a representable ornament order")
        }
        XCTAssertEqual(OriginalChristmasTreeLayout.decorationOrder(encodedOrder: encodedOrder), Array(0..<11))
    }

    func testMovingDecorationReleasesItsPreviousTarget() {
        var arrangement = OriginalChristmasTreeArrangement()
        let first = OriginalChristmasTreeLayout.modelDecorationTargets[0]
        let second = OriginalChristmasTreeLayout.modelDecorationTargets[1]

        XCTAssertEqual(arrangement.drop(decoration: 0, at: first), 0)
        XCTAssertEqual(arrangement.drop(decoration: 0, at: second), 1)
        XCTAssertNil(arrangement.decorationAtTarget[0])
        XCTAssertEqual(arrangement.decorationAtTarget[1], 0)
    }

    func testUnsupportedPermutationDoesNotComplete() {
        var arrangement = OriginalChristmasTreeArrangement()
        for decoration in 0..<10 {
            let target = OriginalChristmasTreeLayout.modelDecorationTargets[decoration]
            XCTAssertEqual(arrangement.drop(decoration: decoration, at: target), decoration)
        }
        let lastTarget = OriginalChristmasTreeLayout.modelDecorationTargets[10]
        XCTAssertEqual(arrangement.drop(decoration: 9, at: lastTarget), 10)

        XCTAssertFalse(arrangement.isComplete)
        XCTAssertNil(arrangement.encodedOrder)
    }
}
