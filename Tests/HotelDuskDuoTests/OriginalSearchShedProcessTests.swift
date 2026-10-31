import XCTest
@testable import HotelDuskDuoKit

final class OriginalSearchShedProcessTests: XCTestCase {
    func testModeOneUsesNinetyRecoveredOverlayFortyTransforms() {
        let seed: UInt32 = 0x0F2B89E1
        let expected = OriginalBrickWallLayout.objects(seed: seed)
        let process = OriginalSearchShedProcess(seed: seed)

        XCTAssertEqual(process.objects.count, 90)
        XCTAssertEqual(process.objects.map(\.position), expected.map(\.position))
        XCTAssertEqual(process.objects.map(\.scale), expected.map(\.scale))
        XCTAssertEqual(process.objects[32].position.y, Float(bitPattern: 0xBF8CCCCD))
        XCTAssertEqual(process.objects[43].position.z, Float(bitPattern: 0x3F8CCCCD))
    }

    func testModeOneOnlyCountsAcceptedInteriorHits() {
        XCTAssertFalse(OriginalSearchShedProcess.isAcceptedIndex(-1))
        XCTAssertFalse(OriginalSearchShedProcess.isAcceptedIndex(0))
        XCTAssertTrue(OriginalSearchShedProcess.isAcceptedIndex(1))
        XCTAssertTrue(OriginalSearchShedProcess.isAcceptedIndex(70))
        XCTAssertFalse(OriginalSearchShedProcess.isAcceptedIndex(72))
        XCTAssertFalse(OriginalSearchShedProcess.isAcceptedIndex(73))

        var process = OriginalSearchShedProcess()
        XCTAssertEqual(process.update(), [.fadeIn(60)])
        XCTAssertEqual(process.phase, .searching)
        XCTAssertFalse(process.registerHit(object: 0))
        for _ in 0..<4 { XCTAssertTrue(process.registerHit(object: 1)) }
        XCTAssertEqual(process.hitCount, 4)
        XCTAssertEqual(process.phase, .searching)
        XCTAssertTrue(process.registerHit(object: 2))
        XCTAssertEqual(process.phase, .responding)
        XCTAssertFalse(process.registerHit(object: 3))
        XCTAssertEqual(process.hitCount, 5)

        for _ in 0..<29 { XCTAssertTrue(process.update().isEmpty) }
        XCTAssertEqual(process.update(), [.successReady])
        XCTAssertTrue(process.canConfirmFoundSearch)
        XCTAssertEqual(process.confirmFoundSearch(), [.completed(0)])
        XCTAssertEqual(process.result, 0)
    }

    func testMenuExitRemainsAvailableBeforeTheSearchIsComplete() {
        var process = OriginalSearchShedProcess()
        _ = process.update()
        XCTAssertTrue(process.canOpenMenu)
        process.openMenu()

        XCTAssertEqual(process.update(), [.fadeOut(60)])
        XCTAssertTrue(process.update().isEmpty)
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(0)])
        XCTAssertEqual(process.result, 0)
    }
}
