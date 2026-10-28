import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingPinFieldTests: XCTestCase {
    private struct BallContactTrace: Decodable {
        struct Capture: Decodable {
            let sourceBallPinRadiusComponents: [Float]
        }

        let cases: [String: Capture]
    }

    private struct IsolatedInteractions: Decodable {
        struct Capture: Decodable {
            struct State: Decodable {
                struct Pin: Decodable {
                    let positionFixed20_12: [Int32]
                    let motionFixed20_12: [Int32]
                    let rotationFloat: Float
                    let angularVelocityFloat: Float
                    let needsUpdate: Bool
                    let active: Bool
                }
                let pinStates: [Pin]
            }
            let states: [String: State]
        }
        let cases: [String: Capture]
    }

    private struct PinBoundaryTrace: Decodable {
        struct Capture: Decodable {
            struct State: Decodable {
                let positionFixed20_12: [Int32]
            }
            let states: States
            struct States: Decodable {
                let before: State
                let after: State
            }
        }
        let cases: [String: Capture]
    }

    private struct PinPairTrace: Decodable {
        struct Capture: Decodable {
            struct Pin: Decodable {
                let positionFixed20_12: [Int32]
                let motionFixed20_12: [Int32]
                let rotationFloat: Float
                let directionAngleFloat: Float?
                let angularVelocityFloat: Float
                let needsUpdate: Bool
                let active: Bool
            }
            struct State: Decodable { let before: [Pin]; let after: [Pin] }
            let states: State
        }
        let cases: [String: Capture]
    }

    func testPinCentresFollowTheRecoveredFourRowFormation() {
        let positions = OriginalBowlingPinField.initialPositions
        XCTAssertEqual(positions.count, 10)
        for (index, expected) in [
            SIMD2<Float>(0, -5.5), SIMD2(-0.3999, -6.1929), SIMD2(0.3999, -6.1929),
            SIMD2(-0.8, -6.8855), SIMD2(0, -6.8855), SIMD2(0.8, -6.8855),
            SIMD2(-1.2, -7.5784), SIMD2(-0.3999, -7.5784), SIMD2(0.3999, -7.5784),
            SIMD2(1.2, -7.5784)
        ].enumerated() {
            XCTAssertEqual(positions[index].x, expected.x, accuracy: 0.001)
            XCTAssertEqual(positions[index].y, expected.y, accuracy: 0.001)
        }
    }

    func testScoreCountsPinsWithNonZeroRotation() {
        var pins = OriginalBowlingPinField()

        XCTAssertEqual(pins.score, 0)
        XCTAssertTrue(pins.setRotation(Float(bitPattern: 0x3fc90fdb), forPin: 0))
        XCTAssertTrue(pins.setRotation(-0.25, forPin: 4))
        XCTAssertEqual(pins.score, 2)
    }

    func testPinStatePreservesCapturedFixedPointMotionAndFloatAngles() {
        var pins = OriginalBowlingPinField()
        let rotation = Float(bitPattern: 0x3fc90fdb)
        let pin = OriginalBowlingPinField.Pin(
            positionFixed20_12: SIMD3(-2_825, 0, -22_521),
            motionFixed20_12: SIMD3(0, 0, -168),
            rotation: rotation,
            angularVelocity: 0.05,
            isActive: true,
            needsUpdate: true)

        XCTAssertTrue(pins.setPin(pin, at: 0))
        XCTAssertEqual(pins.pins[0], pin)
        XCTAssertEqual(pins.rotations[0], rotation)
        XCTAssertEqual(pins.score, 1)
    }

    func testLinearMotionAdvancesBeforeApplyingSourceDamping() {
        var pins = OriginalBowlingPinField()
        let movingPin = OriginalBowlingPinField.Pin(
            positionFixed20_12: SIMD3(100, 200, -300),
            motionFixed20_12: SIMD3(50, 900, -543),
            needsUpdate: true)
        _ = pins.setPin(movingPin, at: 0)

        pins.advanceMotion()

        XCTAssertEqual(pins.pins[0].positionFixed20_12, SIMD3(150, 200, -843))
        XCTAssertEqual(pins.pins[0].motionFixed20_12, SIMD3(45, 0, -488))
        XCTAssertTrue(pins.pins[0].needsUpdate)
    }

    func testIsolatedPinMotionMatchesTheSourceCaptureFromRest() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(IsolatedInteractions.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/isolated-pin-interactions.json")))
        let capture = try XCTUnwrap(trace.cases["separated-x-motion"])
        let input = try XCTUnwrap(capture.states["before"])
        let expected = try XCTUnwrap(capture.states["after"])
        var pins = OriginalBowlingPinField()

        for index in 0..<OriginalBowlingPinField.pinCount {
            let source = input.pinStates[index]
            XCTAssertTrue(pins.setPin(.init(
                positionFixed20_12: try vector(source.positionFixed20_12),
                motionFixed20_12: try vector(source.motionFixed20_12),
                rotation: source.rotationFloat,
                angularVelocity: source.angularVelocityFloat,
                isActive: source.active,
                needsUpdate: source.needsUpdate), at: index))
        }

        pins.advanceMotion()

        for index in 0..<2 {
            let actual = pins.pins[index]
            let reference = expected.pinStates[index]
            XCTAssertEqual(actual.positionFixed20_12, try vector(reference.positionFixed20_12), "pin \(index)")
            XCTAssertEqual(actual.motionFixed20_12, try vector(reference.motionFixed20_12), "pin \(index)")
            XCTAssertEqual(actual.rotation, reference.rotationFloat, accuracy: 0.000001, "pin \(index)")
            XCTAssertEqual(actual.angularVelocity, reference.angularVelocityFloat, accuracy: 0.000001, "pin \(index)")
        }
    }

    func testLaneBoundaryCorrectionMatchesIsolatedSourceCaptures() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(PinBoundaryTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/pin-boundary-trace.json")))

        for name in trace.cases.keys.sorted() {
            let capture = try XCTUnwrap(trace.cases[name])
            var pins = OriginalBowlingPinField()
            var state = capture.states.before.positionFixed20_12
            XCTAssertEqual(state.count, 3)
            XCTAssertTrue(pins.setPin(.init(positionFixed20_12: SIMD3(state[0], state[1], state[2])), at: 0))

            pins.resolveLaneBoundary()

            state = capture.states.after.positionFixed20_12
            XCTAssertEqual(pins.pins[0].positionFixed20_12.x, state[0], name)
        }
    }

    func testAngularMotionAdvancesByVelocityThenAddsSourceStep() {
        var pins = OriginalBowlingPinField()
        let pin = OriginalBowlingPinField.Pin(
            positionFixed20_12: .zero,
            rotation: 0.0628165156,
            angularVelocity: 0.1128165126,
            needsUpdate: true)
        _ = pins.setPin(pin, at: 0)

        pins.advanceMotion()

        XCTAssertEqual(pins.pins[0].rotation, 0.1756330282, accuracy: 0.000001)
        XCTAssertEqual(pins.pins[0].angularVelocity, 0.1628165126, accuracy: 0.000001)
    }

    func testAngularMotionStopsAtEitherSourceRotationLimit() {
        var pins = OriginalBowlingPinField()
        _ = pins.setPin(.init(positionFixed20_12: .zero, rotation: 1.53,
                              angularVelocity: 0.1, needsUpdate: true), at: 0)
        _ = pins.setPin(.init(positionFixed20_12: .zero, rotation: 4.75,
                              angularVelocity: -0.1, needsUpdate: true), at: 1)

        pins.advanceMotion()

        XCTAssertEqual(pins.pins[0].rotation, .pi / 2, accuracy: 0.000001)
        XCTAssertEqual(pins.pins[0].angularVelocity, 0)
        XCTAssertEqual(pins.pins[1].rotation, 3 * .pi / 2, accuracy: 0.000001)
        XCTAssertEqual(pins.pins[1].angularVelocity, 0)
    }

    func testLinearMotionStopsDampedComponentsBelowSourceThreshold() {
        var pins = OriginalBowlingPinField()
        let movingPin = OriginalBowlingPinField.Pin(
            positionFixed20_12: .zero,
            motionFixed20_12: SIMD3(1, 0, -40),
            needsUpdate: true)
        _ = pins.setPin(movingPin, at: 0)
        _ = pins.setPin(.init(positionFixed20_12: SIMD3(2, 0, 3),
                               motionFixed20_12: SIMD3(5, 0, 6)), at: 1)

        pins.advanceMotion()

        XCTAssertEqual(pins.pins[0].motionFixed20_12, .zero)
        XCTAssertEqual(pins.pins[1].positionFixed20_12, SIMD3(2, 0, 3))
        XCTAssertEqual(pins.pins[1].motionFixed20_12, SIMD3(5, 0, 6))
    }

    func testCollisionGateUsesRuntimeRadiusAndRequiresMotion() {
        var pins = OriginalBowlingPinField()
        let first = OriginalBowlingPinField.Pin(
            positionFixed20_12: SIMD3(0, 0, 0),
            motionFixed20_12: SIMD3(10, 0, 0))
        let second = OriginalBowlingPinField.Pin(
            positionFixed20_12: SIMD3(1_638, 0, 0))
        _ = pins.setPin(first, at: 0)
        _ = pins.setPin(second, at: 1)

        XCTAssertEqual(OriginalBowlingPinField.pinCollisionRadius, 0.48484844, accuracy: 0.000001)
        XCTAssertEqual(pins.overlappingMovingPinPairs.map { [$0.0, $0.1] }, [[0, 1]])

        _ = pins.setPin(.init(positionFixed20_12: SIMD3(0, 0, 0)), at: 0)
        XCTAssertTrue(pins.overlappingMovingPinPairs.isEmpty)
    }

    func testCollisionGateRejectsInactiveAndDistantPins() {
        var pins = OriginalBowlingPinField()
        _ = pins.setPin(.init(positionFixed20_12: .zero, motionFixed20_12: SIMD3(1, 0, 0)), at: 0)
        _ = pins.setPin(.init(positionFixed20_12: SIMD3(1_638, 0, 0), isActive: false), at: 1)
        _ = pins.setPin(.init(positionFixed20_12: SIMD3(10_000, 0, 0)), at: 2)

        XCTAssertTrue(pins.overlappingMovingPinPairs.isEmpty)
    }

    func testPinPairResponseMatchesIsolatedSourceCaptures() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(PinPairTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/pin-pair-sweep.json")))

        for name in trace.cases.keys.sorted() {
            let capture = try XCTUnwrap(trace.cases[name])
            var pins = OriginalBowlingPinField()
            for index in capture.states.before.indices {
                let state = capture.states.before[index]
                XCTAssertTrue(pins.setPin(.init(
                    positionFixed20_12: try vector(state.positionFixed20_12),
                    motionFixed20_12: try vector(state.motionFixed20_12),
                    rotation: state.rotationFloat,
                    angularVelocity: state.angularVelocityFloat,
                    directionAngle: state.directionAngleFloat ?? 0,
                    isActive: state.active,
                    needsUpdate: state.needsUpdate), at: index))
            }

            pins.resolvePinContacts()
            pins.advanceMotion()
            pins.resolveLaneBoundary()
            pins.resolvePinPositionalContacts()

            for index in capture.states.after.indices {
                let actual = pins.pins[index]
                let expected = capture.states.after[index]
                XCTAssertEqual(actual.positionFixed20_12, try vector(expected.positionFixed20_12), "\(name), pin \(index)")
                XCTAssertEqual(actual.motionFixed20_12, try vector(expected.motionFixed20_12), "\(name), pin \(index)")
                XCTAssertEqual(actual.rotation, expected.rotationFloat, accuracy: 0.000001, "\(name), pin \(index)")
                if let expectedDirection = expected.directionAngleFloat {
                    XCTAssertEqual(actual.directionAngle, expectedDirection, accuracy: 0.000001,
                                   "\(name), pin \(index) direction")
                }
                XCTAssertEqual(actual.angularVelocity, expected.angularVelocityFloat, accuracy: 0.000001, "\(name), pin \(index)")
                XCTAssertEqual(actual.needsUpdate, expected.needsUpdate, "\(name), pin \(index)")
            }
        }
    }

    func testPinPositionCorrectionMatchesIsolatedSourceSeparationCaptures() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(PinPairTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/pin-separation-sweep.json")))

        for name in trace.cases.keys.sorted() {
            let capture = try XCTUnwrap(trace.cases[name])
            var pins = OriginalBowlingPinField()
            for index in 0..<OriginalBowlingPinField.pinCount {
                _ = pins.setPin(.init(positionFixed20_12: SIMD3(1_000_000 + Int32(index) * 100_000,
                                                                0, 1_000_000),
                                      isActive: false), at: index)
            }
            for index in capture.states.before.indices {
                let state = capture.states.before[index]
                XCTAssertTrue(pins.setPin(.init(
                    positionFixed20_12: try vector(state.positionFixed20_12),
                    motionFixed20_12: try vector(state.motionFixed20_12),
                    rotation: state.rotationFloat,
                    angularVelocity: state.angularVelocityFloat,
                    directionAngle: state.directionAngleFloat ?? 0,
                    isActive: state.active,
                    needsUpdate: state.needsUpdate), at: index))
            }

            pins.resolvePinContacts()
            pins.advanceMotion()
            pins.resolveLaneBoundary()
            pins.resolvePinPositionalContacts()

            for index in capture.states.after.indices {
                let actual = pins.pins[index]
                let expected = capture.states.after[index]
                XCTAssertEqual(actual.positionFixed20_12, try vector(expected.positionFixed20_12), "\(name), pin \(index)")
                XCTAssertEqual(actual.motionFixed20_12, try vector(expected.motionFixed20_12), "\(name), pin \(index)")
                XCTAssertEqual(actual.rotation, expected.rotationFloat, accuracy: 0.000001, "\(name), pin \(index)")
                if let expectedDirection = expected.directionAngleFloat {
                    XCTAssertEqual(actual.directionAngle, expectedDirection, accuracy: 0.000001,
                                   "\(name), pin \(index) direction")
                }
                XCTAssertEqual(actual.angularVelocity, expected.angularVelocityFloat, accuracy: 0.000001, "\(name), pin \(index)")
            }
        }
    }

    func testBallContactGateUsesCapturedSourceRadiusAndIgnoresVerticalDistance() throws {
        var pins = OriginalBowlingPinField()
        _ = pins.setPin(.init(positionFixed20_12: .zero), at: 0)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(BallContactTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/ball-pin-collisions.json")))
        let capture = try XCTUnwrap(trace.cases["head-on"])
        let sourceRadius = try XCTUnwrap(capture.sourceBallPinRadiusComponents.first)
            + XCTUnwrap(capture.sourceBallPinRadiusComponents.dropFirst().first)

        XCTAssertEqual(sourceRadius, OriginalBowlingPinField.ballPinCollisionRadius, accuracy: 0.000001)
        XCTAssertEqual(pins.ballContactCandidates(at: SIMD3(0, 40_000, 3_971)), [0])
        XCTAssertTrue(pins.ballContactCandidates(at: SIMD3(0, 0, 3_972)).isEmpty)
    }

    func testBallContactGateSkipsInactiveOrUpdatingPins() {
        var pins = OriginalBowlingPinField()
        _ = pins.setPin(.init(positionFixed20_12: .zero, isActive: false), at: 0)
        _ = pins.setPin(.init(positionFixed20_12: .zero, needsUpdate: true), at: 1)

        XCTAssertTrue(pins.ballContactCandidates(at: .zero).isEmpty)
    }

    func testZeroRotationLeavesPinStandingAndCanClearPriorRotation() {
        var pins = OriginalBowlingPinField()
        _ = pins.setRotation(.pi / 2, forPin: 3)
        _ = pins.setRotation(0, forPin: 3)

        XCTAssertEqual(pins.score, 0)
    }

    func testRejectsPinIndicesOutsideTheOriginalTenPinField() {
        var pins = OriginalBowlingPinField()

        XCTAssertFalse(pins.setRotation(1, forPin: -1))
        XCTAssertFalse(pins.setRotation(1, forPin: OriginalBowlingPinField.pinCount))
        XCTAssertEqual(pins.score, 0)
    }

    private func vector(_ values: [Int32]) throws -> SIMD3<Int32> {
        guard values.count == 3 else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Expected three coordinates"))
        }
        return SIMD3(values[0], values[1], values[2])
    }
}
