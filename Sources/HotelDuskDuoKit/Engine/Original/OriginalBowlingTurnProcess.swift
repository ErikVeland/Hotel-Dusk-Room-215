import Foundation

/**
 * Advances one source bowling throw from a selected ball through its roll.
 */
public struct OriginalBowlingTurnProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case ready
        case dragging
        case rolling
        case complete
    }

    public static let automaticRollPositionZ: Int32 = 0x0c7b
    public private(set) var simulation: OriginalBowlingBallPinSimulation
    public private(set) var phase = Phase.ready
    public private(set) var score: Int32?

    private var drag: OriginalBowlingDrag

    public var ballPositionFixed20_12: SIMD3<Int32> {
        drag.ballTransformFixed20_12
    }

    public init(ballPositionFixed20_12: SIMD3<Int32>, pins: OriginalBowlingPinField = .init()) {
        drag = OriginalBowlingDrag(ballTransformFixed20_12: ballPositionFixed20_12)
        simulation = OriginalBowlingBallPinSimulation(
            ballState: .init(positionFixed20_12: ballPositionFixed20_12, velocityFixed20_12: .zero),
            pins: pins)
    }

    /**
     * Starts the held drag after the caller confirms the ball mask was hit.
     */
    @discardableResult
    public mutating func beginDrag(at lanePointFixed20_12: SIMD3<Int32>, ballWasHit: Bool) -> Bool {
        guard phase == .ready, ballWasHit else { return false }
        drag.begin(at: lanePointFixed20_12)
        phase = .dragging
        return true
    }

    /**
     * Applies one source held update and starts the roll at the automatic forward limit.
     */
    public mutating func updateDrag(to lanePointFixed20_12: SIMD3<Int32>) {
        guard phase == .dragging else { return }
        drag.update(touchPointFixed20_12: lanePointFixed20_12)
        guard drag.ballTransformFixed20_12.z < Self.automaticRollPositionZ else { return }
        startRoll(velocity: drag.end() ?? SIMD3(0, 0, OriginalBowlingLaunch.minimumForwardDelta))
    }

    /**
     * Starts a roll when the final two drag deltas pass the source launch threshold.
     */
    @discardableResult
    public mutating func endDrag() -> Bool {
        guard phase == .dragging else { return false }
        guard let velocity = drag.end() else {
            phase = .ready
            return false
        }
        startRoll(velocity: velocity)
        return true
    }

    /**
     * Advances the source roll and records the pin count after all motion stops.
     */
    public mutating func advanceOneUpdate() {
        guard phase == .rolling else { return }
        simulation.advanceOneUpdate()
        let ballStopped = simulation.ballMotion.state.velocityFixed20_12.x == 0
            && simulation.ballMotion.state.velocityFixed20_12.z == 0
        let pinsStopped = simulation.pins.pins.allSatisfy {
            $0.motionFixed20_12.x == 0 && $0.motionFixed20_12.z == 0
        }
        guard ballStopped && pinsStopped else { return }
        score = simulation.pins.score
        phase = .complete
    }

    private mutating func startRoll(velocity: SIMD3<Int32>) {
        simulation = OriginalBowlingBallPinSimulation(
            ballState: .init(positionFixed20_12: drag.ballTransformFixed20_12,
                             velocityFixed20_12: velocity),
            pins: simulation.pins)
        phase = .rolling
    }
}
