import Foundation

/**
 * Handles one bowling drag and roll using overlay 11's captured input path.
 */
public struct OriginalBowlingTurnProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case ready
        case dragging
        case rolling
        case complete
    }

    public private(set) var simulation: OriginalBowlingBallPinSimulation
    public private(set) var phase = Phase.ready
    public private(set) var score: Int32?
    private var previousDragDelta: SIMD3<Int32>?
    private var currentDragDelta: SIMD3<Int32>?

    var latestDragDeltas: [SIMD3<Int32>] {
        [previousDragDelta, currentDragDelta].compactMap { $0 }
    }

    public init(ballPositionFixed20_12: SIMD3<Int32>, pins: OriginalBowlingPinField = .init()) {
        simulation = OriginalBowlingBallPinSimulation(
            ballState: .init(positionFixed20_12: ballPositionFixed20_12, velocityFixed20_12: .zero),
            pins: pins)
    }

    /**
     * Starts a drag only when the rendered ball mask and source drag planes both hit.
     */
    @discardableResult
    public mutating func beginDrag(pagePoint: SIMD2<Float>, camera: OriginalBowlingCameraBasis,
                                   ballHit: Bool) -> Bool {
        guard phase == .ready, ballHit,
              let delta = Self.dragDelta(pagePoint: pagePoint, camera: camera,
                                         ballPositionFixed20_12: simulation.ballMotion.state.positionFixed20_12) else {
            return false
        }
        previousDragDelta = delta
        currentDragDelta = delta
        phase = .dragging
        return true
    }

    /**
     * Moves the live drag across the source lane and ball touch planes.
     */
    public mutating func moveDrag(pagePoint: SIMD2<Float>, camera: OriginalBowlingCameraBasis) {
        guard phase == .dragging,
              let delta = Self.dragDelta(pagePoint: pagePoint, camera: camera,
                                         ballPositionFixed20_12: simulation.ballMotion.state.positionFixed20_12) else { return }
        previousDragDelta = currentDragDelta
        currentDragDelta = delta
    }

    /**
     * Launches when the two latest source drag deltas pass the forward threshold.
     */
    @discardableResult
    public mutating func endDrag() -> Bool {
        guard phase == .dragging, let currentDragDelta, let previousDragDelta,
              let velocity = OriginalBowlingLaunch.velocity(currentDelta: currentDragDelta,
                                                           previousDelta: previousDragDelta) else {
            phase = .ready
            return false
        }
        simulation = OriginalBowlingBallPinSimulation(
            ballState: .init(positionFixed20_12: simulation.ballMotion.state.positionFixed20_12,
                             velocityFixed20_12: velocity),
            pins: simulation.pins)
        phase = .rolling
        return true
    }

    /**
     * Advances one source bowling update and records its toppled-pin score at rest.
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

    private static func dragDelta(pagePoint: SIMD2<Float>, camera: OriginalBowlingCameraBasis,
                                  ballPositionFixed20_12: SIMD3<Int32>) -> SIMD3<Int32>? {
        guard let ray = OriginalBowlingTouchRay.ray(pagePoint: pagePoint, camera: camera) else { return nil }
        let ballPosition = SIMD3(Float(ballPositionFixed20_12.x), Float(ballPositionFixed20_12.y),
                                 Float(ballPositionFixed20_12.z)) / 4_096
        let ballVertices = OriginalBowlingTouchRay.ballPlaneVertices.map { $0 + ballPosition }
        guard let anchor = OriginalBowlingTouchRay.dragAnchor(
            origin: ray.origin, direction: ray.direction,
            laneVertices: OriginalBowlingTouchRay.lanePlaneVertices,
            ballVertices: ballVertices) else { return nil }
        let delta = anchor.lanePoint - anchor.ballPoint
        return SIMD3(Self.fixed(delta.x), Self.fixed(delta.y), Self.fixed(delta.z))
    }

    private static func fixed(_ value: Float) -> Int32 {
        guard value.isFinite else { return 0 }
        return Int32(clamping: Int64((value * 4_096).rounded(.toNearestOrAwayFromZero)))
    }
}
