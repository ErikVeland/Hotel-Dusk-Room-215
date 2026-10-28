import XCTest
@testable import HotelDuskDuoKit

final class OriginalSearchShedProcessTests: XCTestCase {
    func testEntryAndDragPreserveTheGrabOffsetAndVerticalPosition() {
        var process = OriginalSearchShedProcess()
        XCTAssertEqual(process.objects.count, 26)
        XCTAssertEqual(process.update(), [.fadeIn(60)])
        XCTAssertEqual(process.phase, .arranging)

        let original = process.objects[0].position
        process.beginDrag(object: 0, at: .init(original.x - 0.25, original.z + 0.5))
        process.drag(to: .init(2, -4))
        process.endDrag()

        XCTAssertEqual(process.objects[0].position.x, 2.25, accuracy: 0.0001)
        XCTAssertEqual(process.objects[0].position.y, original.y, accuracy: 0.0001)
        XCTAssertEqual(process.objects[0].position.z, -4.5, accuracy: 0.0001)
        XCTAssertNil(process.draggedObject)
    }

    func testTreeBoxRequiresAnUnobstructedSourceHit() {
        var process = OriginalSearchShedProcess()
        _ = process.update()

        XCTAssertTrue(process.select(object: 8, targetIsUnobstructed: true).isEmpty)
        XCTAssertTrue(process.select(object: 9, targetIsUnobstructed: false).isEmpty)
        process.beginDrag(object: 9, at: .init(0, 0))
        XCTAssertTrue(process.select(object: 9, targetIsUnobstructed: true).isEmpty)
        process.endDrag()

        XCTAssertEqual(process.select(object: 9, targetIsUnobstructed: true), [.foundTreeBox])
        XCTAssertEqual(process.phase, .found)
    }

    func testOpeningTheFoundTreeBoxReturnsTheOnlyStoryTransitionResult() {
        var process = OriginalSearchShedProcess()
        _ = process.update()

        XCTAssertFalse(process.canOpenFoundBox)
        XCTAssertTrue(process.openFoundBox().isEmpty)
        _ = process.select(object: 9, targetIsUnobstructed: true)
        XCTAssertTrue(process.canOpenFoundBox)

        XCTAssertEqual(process.openFoundBox(), [.completed(0)])
        XCTAssertEqual(process.result, 0)
        XCTAssertFalse(process.canOpenFoundBox)
        XCTAssertTrue(process.openFoundBox().isEmpty)
    }

    func testMenuExitReturnsTheOnlyStoryTransitionResult() {
        var process = OriginalSearchShedProcess()
        _ = process.update()
        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertTrue(process.update().isEmpty)
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(0)])
        XCTAssertEqual(process.result, 0)
    }
}
