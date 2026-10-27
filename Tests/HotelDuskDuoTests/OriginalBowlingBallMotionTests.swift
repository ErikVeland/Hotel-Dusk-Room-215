import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingBallMotionTests: XCTestCase {
    private struct BoundaryTrace: Decodable {
        struct Case: Decodable {
            struct Output: Decodable { let positionFixed20_12: [Int32]; let velocityFixed20_12: [Int32] }
            let input: [Int32]
            let output: Output
        }
        let cases: [String: Case]
    }

    private struct Trace: Decodable {
        struct State: Decodable {
            let positionFixed20_12: [Int32]
            let velocityFixed20_12: [Int32]
        }

        let initial: State
        let afterOneUpdate: State
    }

    private struct BallPinCollisionTrace: Decodable {
        struct Case: Decodable {
            struct Input: Decodable {
                let ballPositionFixed20_12: [Int32]
                let ballVelocityFixed20_12: [Int32]
            }
            struct States: Decodable {
                struct Snapshot: Decodable { let ballVelocityFixed20_12: [Int32] }
                let before: Snapshot
                let after: Snapshot
            }
            let input: Input
            let states: States
        }
        let cases: [String: Case]
    }

    private func vector(_ values: [Int32]) throws -> SIMD3<Int32> {
        guard values.count == 3 else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Expected three fixed-point coordinates"))
        }
        return SIMD3(values[0], values[1], values[2])
    }

    func testBallSubstepsMatchTheIsolatedOriginalRunnerCapture() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(Trace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/ball-substep-trace.json")))
        var motion = OriginalBowlingBallMotion(state: .init(
            positionFixed20_12: try vector(trace.initial.positionFixed20_12),
            velocityFixed20_12: try vector(trace.initial.velocityFixed20_12)))

        motion.advance { _ in }

        XCTAssertEqual(motion.state.positionFixed20_12, try vector(trace.afterOneUpdate.positionFixed20_12))
        XCTAssertEqual(motion.state.velocityFixed20_12, try vector(trace.afterOneUpdate.velocityFixed20_12))
    }

    func testLateralBoundaryMatchesTheIsolatedOriginalRunnerCapture() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(BoundaryTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/ball-boundary-trace.json")))

        for name in ["lateral-boundary", "longitudinal-free"] {
            let capture = try XCTUnwrap(trace.cases[name])
            XCTAssertEqual(capture.input.count, 6, name)
            var motion = OriginalBowlingBallMotion(state: .init(
                positionFixed20_12: try vector(Array(capture.input.prefix(3))),
                velocityFixed20_12: try vector(Array(capture.input.suffix(3)))))
            motion.advance { _ in }

            XCTAssertEqual(motion.state.positionFixed20_12, try vector(capture.output.positionFixed20_12), name)
            XCTAssertEqual(motion.state.velocityFixed20_12, try vector(capture.output.velocityFixed20_12), name)
        }
    }

    func testBallPinContactGateMatchesAxialSourceSweep() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(BallPinCollisionTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/ball-pin-collisions.json")))

        for (name, expectedContactStep) in [("axial-edge", 7), ("axial-clear", 0)] {
            let capture = try XCTUnwrap(trace.cases[name])
            let sourceHit = capture.states.before.ballVelocityFixed20_12
                != capture.states.after.ballVelocityFixed20_12
            XCTAssertEqual(sourceHit, expectedContactStep != 0, name)

            var pins = OriginalBowlingPinField()
            _ = pins.setPin(.init(positionFixed20_12: .zero), at: 0)
            var motion = OriginalBowlingBallMotion(state: .init(
                positionFixed20_12: try vector(capture.input.ballPositionFixed20_12),
                velocityFixed20_12: try vector(capture.input.ballVelocityFixed20_12)))
            var step = 0
            var firstContactStep: Int?

            motion.advance { state in
                step += 1
                if firstContactStep == nil,
                   !pins.ballContactCandidates(at: state.positionFixed20_12).isEmpty {
                    firstContactStep = step
                }
            }

            XCTAssertEqual(firstContactStep, expectedContactStep == 0 ? nil : expectedContactStep, name)
        }
    }

    func testOneUpdateRunsTenSubstepsAndPreservesTheVerticalCoordinate() {
        var motion = OriginalBowlingBallMotion(state: .init(
            positionFixed20_12: SIMD3(0, 77, 0),
            velocityFixed20_12: SIMD3(4096, 900, -819)))
        var collisions = 0

        motion.advance { _ in collisions += 1 }

        XCTAssertEqual(collisions, OriginalBowlingBallMotion.substepCount)
        XCTAssertEqual(motion.state.positionFixed20_12.y, 77)
        XCTAssertEqual(motion.state.velocityFixed20_12.y, 0)
        XCTAssertEqual(motion.state.positionFixed20_12.x, 4090)
        XCTAssertEqual(motion.state.positionFixed20_12.z, -810)
    }

    func testSubstepCollisionCanStopFurtherTravelInTheSameUpdate() {
        var motion = OriginalBowlingBallMotion(state: .init(
            positionFixed20_12: .zero,
            velocityFixed20_12: SIMD3(4096, 0, 0)))
        var collisions = 0

        motion.advance { state in
            collisions += 1
            if collisions == 4 { state.velocityFixed20_12.x = 0 }
        }

        XCTAssertEqual(collisions, OriginalBowlingBallMotion.substepCount)
        XCTAssertEqual(motion.state.positionFixed20_12.x, 4 * 409)
        XCTAssertEqual(motion.state.velocityFixed20_12.x, 0)
    }
}
