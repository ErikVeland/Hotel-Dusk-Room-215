import XCTest
import simd
@testable import HotelDuskDuoKit

final class OriginalBrickWallProcessTests: XCTestCase {
    func testHammerGatesAndMovesASelectedBrickThroughItsFullFaceMask() {
        var process = OriginalBrickWallProcess(seed: 0x0F2B89E1)
        let start = SIMD2<Float>(32, 239)

        XCTAssertFalse(process.beginDrag(at: start, hammerAvailable: false))
        XCTAssertTrue(process.beginDrag(at: start, hammerAvailable: true))
        process.drag(to: SIMD2(190, 255))
        _ = process.endDrag()

        XCTAssertLessThan(process.objects[7].position.y, -1)
        XCTAssertNil(process.selectedObject)
        XCTAssertNil(process.result, "An obstructed doorway must stay in the puzzle.")
    }

    func testClearDoorwayReturnsSourceSuccessValueZero() {
        let fixedCells = [UInt8](repeating: 0xff, count: 9)
        var process = OriginalBrickWallProcess(seed: 0x0F2B89E1, modeZeroFixedCells: fixedCells)

        XCTAssertEqual(process.endDrag(), [.completed(0)])
        XCTAssertEqual(process.result, 0)
    }

    func testLeavingTheBoardReturnsTheRecoveredIncompleteBranch() {
        var process = OriginalBrickWallProcess()
        XCTAssertEqual(process.leave(), 2)
        XCTAssertEqual(process.result, 2)
    }
}
