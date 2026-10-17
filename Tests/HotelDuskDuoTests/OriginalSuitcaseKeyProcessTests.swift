import XCTest
@testable import HotelDuskDuoKit

final class OriginalSuitcaseKeyProcessTests: XCTestCase {
    private func insertKey() -> OriginalSuitcaseKeyProcess {
        var puzzle = OriginalSuitcaseKeyProcess()
        puzzle.update()
        puzzle.update()
        for _ in 0..<3 { puzzle.update(pageTouch: .init(110, 240)) }
        for y in stride(from: 225, through: 95, by: -10) {
            for _ in 0..<8 { puzzle.update(pageTouch: .init(100, Float(y))) }
        }
        for _ in 0..<180 { puzzle.update(pageTouch: .init(100, 95)) }
        puzzle.update()
        return puzzle
    }

    func testReferenceInsertionAndTurns() throws {
        var puzzle = insertKey()
        XCTAssertEqual(puzzle.phase, 5)
        XCTAssertEqual(puzzle.stage, 5)
        XCTAssertEqual(puzzle.key, .init(-655, 393, 6963))
        XCTAssertEqual(puzzle.eye, .init(-2703, 3604, 10240))
        XCTAssertEqual(puzzle.target, .init(-655, 803, 7373))
        XCTAssertEqual(puzzle.returnValue, 1)
        XCTAssertEqual(puzzle.keyTurn, 0.5)
        for turn in 1...21 {
            for _ in 0..<3 { puzzle.update(pageTouch: .init(86, 130)) }
            for _ in 0..<8 { puzzle.update() }
            if turn == 1 {
                XCTAssertEqual(puzzle.turns, 2)
                XCTAssertEqual(puzzle.key, .init(-655, 434, 6962))
            }
            if turn == 10 { XCTAssertEqual(puzzle.turns, 12) }
        }
        XCTAssertEqual(puzzle.turns, 22)
        XCTAssertTrue(puzzle.isBroken)
        XCTAssertEqual(puzzle.returnValue, 0)
        for _ in 0..<600 { puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
    }

    func testQuitKeepsInsertionProgressResult() {
        var untouched = OriginalSuitcaseKeyProcess()
        untouched.update()
        untouched.quit()
        untouched.update()
        XCTAssertNil(untouched.result)
        untouched.update(fadeComplete: true)
        XCTAssertEqual(untouched.result, 2)
        var inserted = insertKey()
        inserted.quit()
        inserted.update()
        inserted.update(fadeComplete: true)
        XCTAssertEqual(inserted.result, 1)
    }

    func testTouchesOutsideKeyDoNotAdvance() {
        var puzzle = OriginalSuitcaseKeyProcess()
        for _ in 0..<100 { puzzle.update(pageTouch: .init(10, 10)) }
        XCTAssertFalse(puzzle.holding)
        XCTAssertEqual(puzzle.key, .init(0, 393, 12288))
        XCTAssertEqual(puzzle.returnValue, 2)
        XCTAssertNil(OriginalSuitcaseProjection.hit(page: .init(.nan, 0), eye: puzzle.eye,
            target: puzzle.target, centre: puzzle.key, radius: 2048))
    }

    func testTurnReleaseStopsTheOriginalEffectPlayer() {
        var puzzle = insertKey()
        puzzle.update(pageTouch: .init(86, 130))
        XCTAssertTrue(puzzle.holding)
        XCTAssertTrue(puzzle.update().contains(.stopSound(33)))
        XCTAssertFalse(puzzle.holding)
    }
}
