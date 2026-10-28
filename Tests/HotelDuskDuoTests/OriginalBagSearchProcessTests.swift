import XCTest
@testable import HotelDuskDuoKit

final class OriginalBagSearchProcessTests: XCTestCase {
    func testOverlayThreeBuildsTheRecoveredTwentyObjectField() {
        let process = OriginalBagSearchProcess()

        XCTAssertEqual(process.objects.count, 20)
        XCTAssertEqual(process.objects.compactMap(\.type), [1, 3, 1, 1, 2, 1, 0, 0, 0, 0])
        XCTAssertEqual(process.objects[1].positionFixed, SIMD3(-2_048, 0, 0))
        XCTAssertEqual(process.objects[1].scale, SIMD3(1, 0.5, 1))
        XCTAssertNil(process.objects[2].type)
        XCTAssertEqual(process.objects[2].positionFixed, SIMD3(-40_960, 0, -40_960))
    }

    func testDraggingTypeThreeToTheSourceTargetRevealsTheTreeBox() throws {
        var process = OriginalBagSearchProcess()
        let object = try XCTUnwrap(process.objects.firstIndex { $0.type == 3 })
        let start = SIMD2(process.objects[object].positionFixed.x, process.objects[object].positionFixed.z)

        process.beginDrag(object: object, at: start)
        process.drag(to: .zero)

        XCTAssertEqual(process.objects[object].positionFixed.x, 0)
        XCTAssertEqual(process.objects[object].positionFixed.z, 0)
        XCTAssertTrue(process.endDrag())
        XCTAssertEqual(process.phase, .found)
        XCTAssertTrue(process.canOpenMenu)
    }

    func testOtherObjectTypesAndNearMissesDoNotCompleteThePuzzle() throws {
        var process = OriginalBagSearchProcess()
        process.beginDrag(object: 0, at: SIMD2(-4_096, 0))
        process.drag(to: .zero)
        XCTAssertFalse(process.endDrag())

        let target = try XCTUnwrap(process.objects.firstIndex { $0.type == 3 })
        let start = SIMD2(process.objects[target].positionFixed.x, process.objects[target].positionFixed.z)
        process.beginDrag(object: target, at: start)
        process.drag(to: SIMD2(1, 0))
        XCTAssertFalse(process.endDrag())
        XCTAssertEqual(process.phase, .arranging)
    }

    func testMenuReturnsTheRecoveredOverlayResultTwo() {
        var process = OriginalBagSearchProcess()
        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertNil(process.result)
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
        XCTAssertEqual(process.result, 2)
        XCTAssertEqual(process.phase, .exiting)
    }
}
