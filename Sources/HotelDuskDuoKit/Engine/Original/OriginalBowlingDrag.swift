import Foundation

/**
 * Applies overlay 11's held-drag updates to the ball transform.
 */
public struct OriginalBowlingDrag: Equatable, Sendable {
    private static let maximumBallZ: Int32 = 0x2e66

    public private(set) var ballTransformFixed20_12: SIMD3<Int32>
    public private(set) var isHolding = false
    public private(set) var previousTouchPointFixed20_12: SIMD3<Int32>?
    public private(set) var currentTouchPointFixed20_12: SIMD3<Int32>?
    public private(set) var previousDeltaFixed20_12 = SIMD3<Int32>.zero
    public private(set) var currentDeltaFixed20_12 = SIMD3<Int32>.zero

    public init(ballTransformFixed20_12: SIMD3<Int32>) {
        self.ballTransformFixed20_12 = ballTransformFixed20_12
    }

    /**
     * Starts a drag after the source has accepted ball-plane and lane-plane hits.
     */
    public mutating func begin(at touchPointFixed20_12: SIMD3<Int32>) {
        isHolding = true
        let positionTarget = Self.positionTarget(touchPointFixed20_12, ballY: ballTransformFixed20_12.y)
        previousTouchPointFixed20_12 = positionTarget
        currentTouchPointFixed20_12 = positionTarget
        previousDeltaFixed20_12 = .zero
        currentDeltaFixed20_12 = .zero
    }

    /**
     * Applies one held update using the already projected and clamped lane point.
     */
    public mutating func update(touchPointFixed20_12: SIMD3<Int32>) {
        guard isHolding, let previousTouchPointFixed20_12,
              let currentTouchPointFixed20_12 else { return }

        let delta = OriginalBowlingTouchRay.sourceDragDelta20_12(
            touchPoint: touchPointFixed20_12, ballTransform: ballTransformFixed20_12)
        previousDeltaFixed20_12 = currentDeltaFixed20_12
        currentDeltaFixed20_12 = delta

        ballTransformFixed20_12.x = Self.approach(
            ballTransformFixed20_12.x, target: previousTouchPointFixed20_12.x)
        ballTransformFixed20_12.z = min(Self.approach(
            ballTransformFixed20_12.z, target: previousTouchPointFixed20_12.z), Self.maximumBallZ)

        self.previousTouchPointFixed20_12 = currentTouchPointFixed20_12
        self.currentTouchPointFixed20_12 = Self.positionTarget(
            touchPointFixed20_12, ballY: ballTransformFixed20_12.y)
    }

    /**
     * Releases the drag and returns a source launch velocity when its threshold passes.
     */
    public mutating func end() -> SIMD3<Int32>? {
        guard isHolding else { return nil }
        isHolding = false
        return OriginalBowlingLaunch.velocity(
            currentDelta: currentDeltaFixed20_12, previousDelta: previousDeltaFixed20_12)
    }

    private static func approach(_ value: Int32, target: Int32) -> Int32 {
        value &+ ((target &- value) >> 2)
    }

    private static func positionTarget(_ point: SIMD3<Int32>, ballY: Int32) -> SIMD3<Int32> {
        SIMD3(point.x, ballY, point.z)
    }
}
