import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingDragTests: XCTestCase {
    private struct DragUpdateTrace: Decodable {
        struct Sample: Decodable {
            let touchPointFixed20_12: [Int32]
            let ballTransformBeforeFixed20_12: [Int32]
            let sourceDeltaFixed20_12: [Int32]
        }

        let initialBallTransformFixed20_12: [Int32]
        let initialPositionTargetFixed20_12: [Int32]
        let samples: [Sample]
    }

    func testUpdateSubtractsBeforeEasingTowardThePreviousTouchPoint() {
        var drag = OriginalBowlingDrag(ballTransformFixed20_12: SIMD3(0, 1_556, 10_240))
        drag.begin(at: SIMD3(100, 1_556, 10_000))

        drag.update(touchPointFixed20_12: SIMD3(300, 3_145, 15_000))

        XCTAssertEqual(drag.currentDeltaFixed20_12, SIMD3(300, 1_589, 4_760))
        XCTAssertEqual(drag.ballTransformFixed20_12, SIMD3(25, 1_556, 10_180))
        XCTAssertEqual(drag.previousTouchPointFixed20_12, SIMD3(100, 1_556, 10_000))
        XCTAssertEqual(drag.currentTouchPointFixed20_12, SIMD3(300, 1_556, 15_000))
    }

    func testBallForwardPositionClampsAtTheSourceLimit() {
        var drag = OriginalBowlingDrag(ballTransformFixed20_12: SIMD3(0, 1_556, 11_800))
        drag.begin(at: SIMD3(0, 1_556, 20_000))

        drag.update(touchPointFixed20_12: SIMD3(0, 1_556, 20_000))

        XCTAssertEqual(drag.ballTransformFixed20_12.z, 0x2e66)
    }

    func testReleaseUsesTheTwoMostRecentSourceDeltas() {
        var drag = OriginalBowlingDrag(ballTransformFixed20_12: SIMD3(0, 1_556, 10_000))
        drag.begin(at: SIMD3(0, 1_556, 10_000))
        drag.update(touchPointFixed20_12: SIMD3(30, 1_556, 9_000))
        drag.update(touchPointFixed20_12: SIMD3(50, 1_556, 9_000))

        XCTAssertEqual(drag.previousDeltaFixed20_12, SIMD3(30, 0, -1_000))
        XCTAssertEqual(drag.currentDeltaFixed20_12, SIMD3(50, 0, -1_000))
        XCTAssertEqual(drag.end(), SIMD3(40, 0, -819))
        XCTAssertFalse(drag.isHolding)
    }

    func testHeldDragReplaysEveryCapturedSourceHelperUpdate() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(DragUpdateTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/drag-update-probe.json")))
        var drag = OriginalBowlingDrag(ballTransformFixed20_12: Self.vector(trace.initialBallTransformFixed20_12))
        drag.begin(at: Self.vector(trace.initialPositionTargetFixed20_12))

        for (index, sample) in trace.samples.enumerated() {
            XCTAssertEqual(drag.ballTransformFixed20_12,
                           Self.vector(sample.ballTransformBeforeFixed20_12), "ball before sample \(index)")
            drag.update(touchPointFixed20_12: Self.vector(sample.touchPointFixed20_12))
            XCTAssertEqual(drag.currentDeltaFixed20_12,
                           Self.vector(sample.sourceDeltaFixed20_12), "drag delta at sample \(index)")
            if index + 1 < trace.samples.count {
                XCTAssertEqual(drag.ballTransformFixed20_12,
                               Self.vector(trace.samples[index + 1].ballTransformBeforeFixed20_12),
                               "ball after sample \(index)")
            }
        }

        XCTAssertEqual(drag.end(), SIMD3(-71, 0, -819))
    }

    private static func vector(_ values: [Int32]) -> SIMD3<Int32> {
        SIMD3(values[0], values[1], values[2])
    }
}
