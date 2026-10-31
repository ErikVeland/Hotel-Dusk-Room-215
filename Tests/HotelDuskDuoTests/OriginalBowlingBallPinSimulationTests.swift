import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingBallPinSimulationTests: XCTestCase {
    private struct CameraTrace: Decodable {
        struct PinState: Decodable {
            let positionFixed20_12: [Int32]
            let motionFixed20_12: [Int32]
            let rotationFloat: Float
            let directionAngleFloat: Float
            let angularVelocityFloat: Float
            let needsUpdate: Bool
            let active: Bool
        }

        struct State: Decodable {
            let ballHitTranslation20_12: [Int32]
            let launchVelocity20_12: [Int32]
            let pinStates: [PinState]
        }

        let states: [String: State]
    }

    private struct Trace: Decodable {
        struct Case: Decodable {
            struct PinState: Decodable {
                let positionFixed20_12: [Int32]
                let motionFixed20_12: [Int32]
                let rotationFloat: Float
                let angularVelocityFloat: Float
                let needsUpdate: Bool
                let active: Bool
            }
            struct Snapshot: Decodable {
                let ballPositionFixed20_12: [Int32]
                let ballVelocityFixed20_12: [Int32]
                let pinStates: [PinState]
            }
            struct Input: Decodable {
                let ballPositionFixed20_12: [Int32]
                let ballVelocityFixed20_12: [Int32]
            }
            let input: Input
            let states: States
            struct States: Decodable {
                let before: Snapshot
                let after: Snapshot
            }
        }
        let cases: [String: Case]
    }

    func testBallAndPinStateMatchesEveryIsolatedSourceCollisionCapture() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(Trace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/ball-pin-collisions.json")))

        for name in trace.cases.keys.sorted() {
            let capture = try XCTUnwrap(trace.cases[name])
            var pins = OriginalBowlingPinField()
            for index in capture.states.before.pinStates.indices {
                let state = capture.states.before.pinStates[index]
                _ = pins.setPin(.init(
                    positionFixed20_12: try vector(state.positionFixed20_12),
                    motionFixed20_12: try vector(state.motionFixed20_12),
                    rotation: state.rotationFloat,
                    angularVelocity: state.angularVelocityFloat,
                    isActive: state.active,
                    needsUpdate: state.needsUpdate), at: index)
            }
            if name == "head-on" {
                XCTAssertEqual(pins.ballContactCandidates(at: SIMD3(0, 0, 1_980)), [0])
                var collisionProbePins = pins
                var velocity = SIMD3<Int32>(0, 0, -200)
                XCTAssertEqual(collisionProbePins.resolveBallContacts(at: SIMD3(0, 0, 1_980),
                    ballVelocityFixed20_12: &velocity), [0])
                XCTAssertEqual(velocity.z, -170)
            }
            var simulation = OriginalBowlingBallPinSimulation(
                ballState: .init(
                    positionFixed20_12: try vector(capture.input.ballPositionFixed20_12),
                    velocityFixed20_12: try vector(capture.input.ballVelocityFixed20_12)),
                pins: pins)

            simulation.advanceOneUpdate()
            if name == "head-on" {
                XCTAssertEqual(simulation.resolvedContactsThisUpdate, [0])
            }

            XCTAssertEqual(simulation.ballMotion.state.positionFixed20_12,
                           try vector(capture.states.after.ballPositionFixed20_12), name)
            XCTAssertEqual(simulation.ballMotion.state.velocityFixed20_12,
                           try vector(capture.states.after.ballVelocityFixed20_12), name)
            XCTAssertEqual(simulation.pins.pins[0].positionFixed20_12,
                           try vector(capture.states.after.pinStates[0].positionFixed20_12), name)
            XCTAssertEqual(simulation.pins.pins[0].motionFixed20_12,
                           try vector(capture.states.after.pinStates[0].motionFixed20_12), name)
            XCTAssertEqual(simulation.pins.pins[0].rotation,
                           capture.states.after.pinStates[0].rotationFloat, accuracy: 0.000001, name)
            XCTAssertEqual(simulation.pins.pins[0].angularVelocity,
                           capture.states.after.pinStates[0].angularVelocityFloat, accuracy: 0.000001, name)
            XCTAssertEqual(simulation.pins.pins[0].needsUpdate,
                           capture.states.after.pinStates[0].needsUpdate, name)
        }
    }

    func testCapturedRoll24ContactAngleAndRoll27And36PinStatesMatch() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(CameraTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/camera-input-trace.json")))
        let roll23 = try XCTUnwrap(trace.states["roll-23"])
        let roll24 = try XCTUnwrap(trace.states["roll-24"])
        let roll27 = try XCTUnwrap(trace.states["roll-27"])
        let roll36 = try XCTUnwrap(trace.states["roll-36"])

        var pins = OriginalBowlingPinField()
        for (index, sourcePin) in roll23.pinStates.enumerated() {
            _ = pins.setPin(.init(
                positionFixed20_12: try vector(sourcePin.positionFixed20_12),
                motionFixed20_12: try vector(sourcePin.motionFixed20_12),
                rotation: sourcePin.rotationFloat,
                angularVelocity: sourcePin.angularVelocityFloat,
                directionAngle: sourcePin.directionAngleFloat,
                isActive: sourcePin.active,
                needsUpdate: sourcePin.needsUpdate), at: index)
        }

        var simulation = OriginalBowlingBallPinSimulation(
            ballState: .init(
                positionFixed20_12: try vector(roll23.ballHitTranslation20_12),
                velocityFixed20_12: try vector(roll23.launchVelocity20_12)),
            pins: pins)
        simulation.advanceOneUpdate()

        XCTAssertEqual(simulation.ballMotion.state.positionFixed20_12,
                       try vector(roll24.ballHitTranslation20_12))
        XCTAssertEqual(simulation.pins.pins[0].directionAngle,
                       roll24.pinStates[0].directionAngleFloat, accuracy: 0.000001)
        XCTAssertEqual(simulation.pins.pins[0].positionFixed20_12,
                       try vector(roll24.pinStates[0].positionFixed20_12))

        simulation.advanceOneUpdate()
        XCTAssertEqual(simulation.ballMotion.state.positionFixed20_12,
                       try vector(roll27.ballHitTranslation20_12))
        XCTAssertEqual(simulation.pins.pins[0].positionFixed20_12,
                       try vector(roll27.pinStates[0].positionFixed20_12))
        XCTAssertEqual(simulation.pins.pins[2].positionFixed20_12,
                       try vector(roll27.pinStates[2].positionFixed20_12))

        for _ in 0..<3 { simulation.advanceOneUpdate() }
        XCTAssertEqual(simulation.ballMotion.state.positionFixed20_12,
                       try vector(roll36.ballHitTranslation20_12))
        for (index, sourcePin) in roll36.pinStates.enumerated() {
            let nativePin = simulation.pins.pins[index]
            XCTAssertEqual(nativePin.positionFixed20_12,
                           try vector(sourcePin.positionFixed20_12), "pin \(index) position")
            XCTAssertEqual(nativePin.motionFixed20_12,
                           try vector(sourcePin.motionFixed20_12), "pin \(index) motion")
            XCTAssertEqual(nativePin.rotation, sourcePin.rotationFloat,
                           accuracy: 0.000001, "pin \(index) rotation")
            XCTAssertEqual(nativePin.directionAngle, sourcePin.directionAngleFloat,
                           accuracy: 0.000001, "pin \(index) direction")
            XCTAssertEqual(nativePin.angularVelocity, sourcePin.angularVelocityFloat,
                           accuracy: 0.000001, "pin \(index) angular velocity")
            XCTAssertEqual(nativePin.needsUpdate, sourcePin.needsUpdate,
                           "pin \(index) update flag")
        }
    }

    private func vector(_ values: [Int32]) throws -> SIMD3<Int32> {
        guard values.count == 3 else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Expected three fixed-point coordinates"))
        }
        return SIMD3(values[0], values[1], values[2])
    }
}
