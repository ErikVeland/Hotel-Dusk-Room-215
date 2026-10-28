import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingTurnProcessTests: XCTestCase {
    private struct DragUpdateTrace: Decodable {
        struct Sample: Decodable {
            let touchPointFixed20_12: [Int32]
            let ballTransformBeforeFixed20_12: [Int32]
        }

        let initialBallTransformFixed20_12: [Int32]
        let initialPositionTargetFixed20_12: [Int32]
        let samples: [Sample]
    }

    func testHeldDragStartsTheSourceRollAtTheCapturedAutomaticLimit() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(DragUpdateTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/drag-update-probe.json")))
        var process = OriginalBowlingTurnProcess(
            ballPositionFixed20_12: Self.vector(trace.initialBallTransformFixed20_12))

        XCTAssertFalse(process.beginDrag(at: Self.vector(trace.initialPositionTargetFixed20_12), ballWasHit: false))
        XCTAssertTrue(process.beginDrag(at: Self.vector(trace.initialPositionTargetFixed20_12), ballWasHit: true))

        for (index, sample) in trace.samples.enumerated() {
            XCTAssertEqual(process.ballPositionFixed20_12, Self.vector(sample.ballTransformBeforeFixed20_12),
                           "ball before source update \(index)")
            process.updateDrag(to: Self.vector(sample.touchPointFixed20_12))
        }

        XCTAssertEqual(process.phase, .rolling)
        XCTAssertEqual(process.simulation.ballMotion.state.velocityFixed20_12, SIMD3(-71, 0, -819))
    }

    func testReleaseBelowTheLaunchThresholdDoesNotStartARoll() {
        var process = OriginalBowlingTurnProcess(ballPositionFixed20_12: SIMD3(0, 1_556, 10_240))
        XCTAssertTrue(process.beginDrag(at: SIMD3(0, 1_556, 10_240), ballWasHit: true))
        process.updateDrag(to: SIMD3(0, 1_556, 10_000))

        XCTAssertFalse(process.endDrag())
        XCTAssertEqual(process.phase, .ready)
    }

    private static func vector(_ values: [Int32]) -> SIMD3<Int32> {
        SIMD3(values[0], values[1], values[2])
    }
}
