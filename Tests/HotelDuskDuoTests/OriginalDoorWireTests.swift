import XCTest
import simd
@testable import HotelDuskDuoKit

final class OriginalDoorWireTests: XCTestCase {
    private func ready(_ variant: OriginalThinWireProcess.Variant = .door) -> OriginalThinWireProcess {
        var puzzle = OriginalThinWireProcess(variant: variant)
        _ = puzzle.update()
        _ = puzzle.update()
        return puzzle
    }

    private func latch(_ index: Int, puzzle: inout OriginalThinWireProcess) throws {
        _ = puzzle.update()
        let paths: [[SIMD2<Float>]] = [
            [.init(88, 121), .init(84, 121), .init(84, 86)],
            [.init(88, 106), .init(84, 118), .init(124, 118)],
            [.init(104, 88), .init(155, 98), .init(155, 138), .init(108, 138), .init(108, 180)],
            [.init(88, 154), .init(110, 154), .init(110, 138), .init(70, 138)]
        ]
        let frames = [[4, 4, 40], [4, 4, 40], [1, 24, 16, 18, 40], [1, 12, 8, 40]]
        for (step, point) in paths[index].enumerated() {
            for _ in 0..<frames[index][step] where !puzzle.pins[index].reached {
                _ = puzzle.update(pageTouch: point)
            }
        }
        XCTAssertTrue(puzzle.pins[index].reached, "Pin \(index) must latch through cursor input: \(puzzle.pins), cursor \(puzzle.cursor), holding \(puzzle.holding)")
    }

    func testDoorStartsAtItsFourPinLockWithoutSuitcaseInsertion() {
        let puzzle = ready()
        XCTAssertEqual(puzzle.phase, 3)
        XCTAssertEqual(puzzle.stage, 1)
        XCTAssertEqual(puzzle.processID, 77)
        XCTAssertEqual(puzzle.pins.map(\.position), [.init(-410, 1352), .init(410, 410), .init(410, -1352), .init(-410, -410)])
        XCTAssertTrue(puzzle.showsLock)
        var untouched = puzzle
        untouched.quit()
        _ = untouched.update()
        _ = untouched.update(fadeComplete: true)
        XCTAssertEqual(untouched.result, 2)
    }

    func testFourPinsCompleteThroughInputAndTheDoorReturnsWithoutOpeningASuitcase() throws {
        var puzzle = ready()
        for index in [0, 1, 2, 3] { try latch(index, puzzle: &puzzle) }
        XCTAssertEqual(puzzle.returnValue, 0)
        XCTAssertEqual(puzzle.stage, 2)
        for _ in 0..<400 where puzzle.result == nil { _ = puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
        XCTAssertEqual(puzzle.lidRotation, 0)
    }

    func testDoorPinsExpireAfterFourSeconds() throws {
        var puzzle = ready()
        try latch(0, puzzle: &puzzle)
        _ = puzzle.update(elapsedSeconds: 3.8)
        XCTAssertTrue(puzzle.pins[0].reached)
        _ = puzzle.update(elapsedSeconds: 0.21)
        XCTAssertFalse(puzzle.pins[0].reached)
    }

    @MainActor func testOriginalDoorArtLoadsAndRenders() throws {
        for variant: OriginalThinWireProcess.Variant in [.door, .orderedDoor] {
            let image = try OriginalThinWireRenderer(variant: variant).render(ready(variant))
            XCTAssertEqual(image.width, 768)
            XCTAssertEqual(image.height, 1024)
        }
    }
}
