import XCTest
@testable import HotelDuskDuoKit

final class OriginalBagSearchProcessTests: XCTestCase {
    func testOverlayThirtyBuildsItsRecoveredTwentySixObjectField() {
        let process = OriginalBagSearchProcess()

        XCTAssertEqual(process.objects.count, 26)
        XCTAssertEqual(process.objects[0].positionFixed, SIMD3(4_096, 6_144, -2_048))
        XCTAssertEqual(process.objects[2].scale, SIMD3(1, 1, 2))
        XCTAssertEqual(process.objects[7].scale, SIMD3(1, 2, 1))
        XCTAssertEqual(process.objects[9].positionFixed, SIMD3(-4_096, 2_048, -14_336))
        XCTAssertEqual(process.objects[9].scale, SIMD3(1, 3, 1))
        XCTAssertEqual(process.objects[15].scale, SIMD3(1, 1, 2))
    }

    func testTreeBoxTapIsBlockedUntilTheOverlappingObjectMoves() {
        var process = OriginalBagSearchProcess()
        let treeBox = process.objects[9]
        let treePoint = SIMD2(treeBox.positionFixed.x, treeBox.positionFixed.z)

        process.beginDrag(object: 9, at: treePoint)
        XCTAssertFalse(process.endDrag())
        XCTAssertEqual(process.phase, .arranging)

        let blocker = process.objects[5]
        let blockerPoint = SIMD2(blocker.positionFixed.x, blocker.positionFixed.z)
        process.beginDrag(object: 5, at: blockerPoint)
        process.drag(to: SIMD2(blockerPoint.x + 4_096, blockerPoint.y))
        XCTAssertFalse(process.endDrag())

        process.beginDrag(object: 9, at: treePoint)
        XCTAssertTrue(process.endDrag())
        XCTAssertEqual(process.phase, .found)
        XCTAssertTrue(process.canOpenMenu)
    }

    func testObjectsAfterTheTargetIndexCanAlsoBlockIt() {
        var process = OriginalBagSearchProcess()
        let laterObject = process.objects[18]
        let laterPoint = SIMD2(laterObject.positionFixed.x, laterObject.positionFixed.z)
        process.beginDrag(object: 18, at: laterPoint)
        process.drag(to: SIMD2(process.objects[9].positionFixed.x, laterPoint.y))
        XCTAssertFalse(process.endDrag())

        let treeBox = process.objects[9]
        process.beginDrag(object: 9,
            at: SIMD2(treeBox.positionFixed.x, treeBox.positionFixed.z))
        XCTAssertFalse(process.endDrag())
        XCTAssertEqual(process.phase, .arranging)
    }

    func testOtherObjectTapDoesNotCompleteTheSearch() {
        var process = OriginalBagSearchProcess()
        let object = process.objects[0]
        process.beginDrag(object: 0,
            at: SIMD2(object.positionFixed.x, object.positionFixed.z))

        XCTAssertFalse(process.endDrag())
        XCTAssertEqual(process.phase, .arranging)
    }

    func testMenuReturnsFailureWhenTreeBoxRemainsBlocked() {
        var process = OriginalBagSearchProcess()
        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertNil(process.result)
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
        XCTAssertEqual(process.result, 2)
        XCTAssertEqual(process.phase, .exiting)
    }

    func testFoundTreeBoxReturnsSuccessFromTheMenu() {
        var process = OriginalBagSearchProcess()
        let blocker = process.objects[5]
        let blockerPoint = SIMD2(blocker.positionFixed.x, blocker.positionFixed.z)
        process.beginDrag(object: 5, at: blockerPoint)
        process.drag(to: SIMD2(blockerPoint.x + 4_096, blockerPoint.y))
        XCTAssertFalse(process.endDrag())

        let treeBox = process.objects[9]
        process.beginDrag(object: 9,
            at: SIMD2(treeBox.positionFixed.x, treeBox.positionFixed.z))
        XCTAssertTrue(process.endDrag())
        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(0)])
        XCTAssertEqual(process.result, 0)
    }
}
