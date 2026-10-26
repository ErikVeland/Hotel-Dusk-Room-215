import XCTest
@testable import HotelDuskDuoKit

final class OriginalChristmasTreeProcessTests: XCTestCase {
    func testProcessUsesSavedDecorationOrder() {
        XCTAssertEqual(OriginalChristmasTreeProcess().decorationOrder, Array(0..<11))
        XCTAssertEqual(OriginalChristmasTreeProcess(savedOrder: 0x7207).decorationOrder,
                       [1, 0, 3, 2, 6, 4, 7, 5, 9, 8, 10])
    }

    func testMenuExitFadesAndReturnsOriginalValueTwo() {
        var process = OriginalChristmasTreeProcess()

        XCTAssertEqual(process.update(), [.fadeIn(60)])
        XCTAssertTrue(process.canOpenMenu)
        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertFalse(process.canOpenMenu)
        XCTAssertEqual(process.update(), [])
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
        XCTAssertEqual(process.result, 2)
    }

    func testMenuExitCanOnlyBeRequestedAfterTheSceneStarts() {
        var process = OriginalChristmasTreeProcess()

        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeIn(60)])
        XCTAssertNil(process.result)
    }

    func testDecorationDropsUseTheRecoveredArrangementRule() {
        var process = OriginalChristmasTreeProcess()
        let target = OriginalChristmasTreeLayout.modelDecorationTargets[0]

        XCTAssertNil(process.dropDecoration(0, at: target))
        _ = process.update()
        XCTAssertEqual(process.dropDecoration(0, at: target), 0)
        XCTAssertEqual(process.arrangement.decorationAtTarget[0], 0)

        process.openMenu()
        XCTAssertNil(process.dropDecoration(1, at: OriginalChristmasTreeLayout.modelDecorationTargets[1]))
    }

    func testStarIsAvailableOnlyAfterTheTenDecorationsArePlaced() {
        var process = OriginalChristmasTreeProcess()
        _ = process.update()
        XCTAssertFalse(process.canPickDecoration(10))
        XCTAssertNil(process.dropDecoration(10, at: OriginalChristmasTreeLayout.modelDecorationTargets[10]))

        for decoration in 0..<10 {
            XCTAssertTrue(process.canPickDecoration(decoration))
            _ = process.dropDecoration(decoration,
                                       at: OriginalChristmasTreeLayout.modelDecorationTargets[decoration])
        }

        XCTAssertTrue(process.canPickDecoration(10))
        XCTAssertEqual(process.dropDecoration(10,
                                              at: OriginalChristmasTreeLayout.modelDecorationTargets[10]), 10)
        XCTAssertEqual(process.arrangement.encodedOrder,
                       OriginalChristmasTreeLayout.encodedDecorationOrder(Array(0..<11)))
    }

    func testDragUsesTouchDeltaAndRecordsTheSourceTarget() {
        var process = OriginalChristmasTreeProcess()
        _ = process.update()
        let start = OriginalChristmasTreeLayout.modelDecorationTargets[0]
        let destination = OriginalChristmasTreeLayout.modelDecorationTargets[1]
        let pageStart = SIMD2<Float>(96, 128)
        let pageEnd = pageStart + SIMD2((destination.x - start.x) * 96,
                                        (start.y - destination.y) * 128)

        XCTAssertTrue(process.beginDecorationDrag(0, at: start, pagePoint: pageStart))
        XCTAssertFalse(process.canOpenMenu)
        let dragged = process.dragDecoration(to: pageEnd)
        XCTAssertEqual(dragged?.x ?? .nan, destination.x, accuracy: 0.0001)
        XCTAssertEqual(dragged?.y ?? .nan, destination.y, accuracy: 0.0001)
        XCTAssertEqual(process.endDecorationDrag(at: pageEnd), 1)
        XCTAssertNil(process.draggedDecoration)
        XCTAssertEqual(process.arrangement.decorationAtTarget[1], 0)
        XCTAssertTrue(process.canOpenMenu)
    }

    func testMenuExitStillStartsAFadeAfterTheOpeningFadeCompletes() {
        var process = OriginalChristmasTreeProcess()
        _ = process.update()
        _ = process.update(fadeComplete: true)
        process.openMenu()

        XCTAssertEqual(process.update(fadeComplete: true), [.fadeOut(60)])
    }

    func testElevenPlacedObjectsFadeOutAndReturnSourceProcessValueTwo() {
        var process = OriginalChristmasTreeProcess()
        _ = process.update()
        for index in 0..<11 {
            XCTAssertEqual(process.dropDecoration(index, at: OriginalChristmasTreeLayout.modelDecorationTargets[index]), index)
        }

        XCTAssertTrue(process.arrangement.isComplete)
        XCTAssertFalse(process.canOpenMenu)
        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertEqual(process.update(), [])
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
        XCTAssertEqual(process.result, 2)
    }
}
