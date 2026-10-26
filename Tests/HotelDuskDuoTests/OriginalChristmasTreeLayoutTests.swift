import XCTest
import simd
@testable import HotelDuskDuoKit

final class OriginalChristmasTreeLayoutTests: XCTestCase {
    func testDecorationTargetsMatchOverlayData() {
        XCTAssertEqual(OriginalChristmasTreeLayout.decorationTargets, [
            SIMD2(48, 306), SIMD2(121, 200), SIMD2(108, 104), SIMD2(119, 334),
            SIMD2(187, 189), SIMD2(62, 167), SIMD2(197, 294), SIMD2(191, 349),
            SIMD2(92, 272), SIMD2(141, 141), SIMD2(128, 24)
        ])
    }

    func testPlacementUsesTheOriginalSquaredDistanceThreshold() {
        let target = OriginalChristmasTreeLayout.modelDecorationTargets[0]

        XCTAssertTrue(OriginalChristmasTreeLayout.isPlaced(target + SIMD2(0.2499, 0), at: 0))
        XCTAssertFalse(OriginalChristmasTreeLayout.isPlaced(target + SIMD2(0.25, 0), at: 0))
        XCTAssertFalse(OriginalChristmasTreeLayout.isPlaced(.init(.infinity, 0), at: 0))
        XCTAssertFalse(OriginalChristmasTreeLayout.isPlaced(target, at: 11))
    }

    func testRawTargetsUseOverlayInitialisationTransform() {
        XCTAssertEqual(OriginalChristmasTreeLayout.modelDecorationTargets[0], SIMD2(-80.0 / 96, 78.0 / 128))
        XCTAssertEqual(OriginalChristmasTreeLayout.modelDecorationTargets[10], SIMD2(0, 360.0 / 128))
    }

    func testPageTouchUsesTheOriginalClipCoordinateTransform() {
        XCTAssertEqual(OriginalChristmasTreeLayout.clipPoint(forPagePoint: .zero), SIMD2(-1, 1))
        XCTAssertEqual(OriginalChristmasTreeLayout.clipPoint(forPagePoint: .init(96, 128)), .zero)
        XCTAssertEqual(OriginalChristmasTreeLayout.clipPoint(forPagePoint: .init(192, 256)), SIMD2(1, -1))
        XCTAssertNil(OriginalChristmasTreeLayout.clipPoint(forPagePoint: .init(.infinity, 0)))
    }

    func testDragAppliesTheOriginalPageTouchDeltaInModelSpace() {
        XCTAssertEqual(
            OriginalChristmasTreeLayout.draggedModelPoint(
                startingAt: .init(0.25, -0.5), from: .init(96, 128), to: .init(120, 160)),
            SIMD2(0.5, -0.75))
        XCTAssertNil(OriginalChristmasTreeLayout.draggedModelPoint(
            startingAt: .init(.infinity, 0), from: .zero, to: .zero))
    }

    func testDecorationOrderDecodesTheSavedSourceBits() {
        XCTAssertEqual(OriginalChristmasTreeLayout.decorationOrder(encodedOrder: 0), Array(0..<11))
        let order = OriginalChristmasTreeLayout.decorationOrder(encodedOrder: 0x7207)
        XCTAssertEqual(order, [1, 0, 3, 2, 6, 4, 7, 5, 9, 8, 10])
        XCTAssertEqual(OriginalChristmasTreeLayout.encodedDecorationOrder(order), 0x7207)
    }

    func testDecorationOrderEncoderRejectsLayoutsTheSourceCannotStore() {
        XCTAssertNil(OriginalChristmasTreeLayout.encodedDecorationOrder(Array(0..<10)))
        XCTAssertNil(OriginalChristmasTreeLayout.encodedDecorationOrder([0, 1, 2, 3, 4, 5, 6, 7, 9, 8, 11]))
        XCTAssertNil(OriginalChristmasTreeLayout.encodedDecorationOrder([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].reversed()))
    }
}
