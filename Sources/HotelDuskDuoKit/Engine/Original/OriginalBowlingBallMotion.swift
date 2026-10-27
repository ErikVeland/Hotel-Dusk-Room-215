import Foundation

/**
 * Advances the bowling ball through the source's ten collision substeps.
 */
public struct OriginalBowlingBallMotion: Equatable, Sendable {
    public static let substepCount = 10
    public static let substepFraction = Float(bitPattern: 0x3dcccccd)
    private static let fixedPointScale: Float = 4_096
    private static let laneHalfWidth = Float(bitPattern: 0x40466666)
    private static let laneOffset = Float(bitPattern: 0x3f3a2e8b)
    private static let lateralLimit = laneHalfWidth - laneOffset
    private static let reverseBoundaryFixed20_12: Int32 = -54_067
    private static let positiveZDeceleration: Int32 = 41

    public struct State: Equatable, Sendable {
        public var positionFixed20_12: SIMD3<Int32>
        public var velocityFixed20_12: SIMD3<Int32>

        public init(positionFixed20_12: SIMD3<Int32>, velocityFixed20_12: SIMD3<Int32>) {
            self.positionFixed20_12 = positionFixed20_12
            self.velocityFixed20_12 = velocityFixed20_12
        }
    }

    public private(set) var state: State

    public init(state: State) {
        self.state = state
    }

    /**
     * Advances one source update and resolves collisions after each substep.
     */
    public mutating func advance(resolveSubstep: (inout State) -> Void) {
        for _ in 0..<Self.substepCount {
            guard advanceOneSubstep() else { break }
            resolveSubstep(&state)
        }
    }

    /**
     * Advances one ball substep. Returns false when the source lateral stop prevents movement.
     */
    @discardableResult
    public mutating func advanceOneSubstep() -> Bool {
        let nextX = Self.nextFixedValue(state.positionFixed20_12.x,
                                        velocity: state.velocityFixed20_12.x)
        let nextXWorld = nextX / Self.fixedPointScale
        let crossesLateralBoundary = (state.velocityFixed20_12.x < 0
            && abs(nextXWorld) >= Self.lateralLimit)
            || (state.velocityFixed20_12.x > 0 && abs(nextXWorld) > Self.lateralLimit)
        if crossesLateralBoundary {
            state.velocityFixed20_12.x = 0
            return false
        }

        state.velocityFixed20_12.y = 0
        state.positionFixed20_12.x = Self.truncatedFixedValue(nextX)
        state.positionFixed20_12.z = Self.truncatedFixedValue(Self.nextFixedValue(
            state.positionFixed20_12.z, velocity: state.velocityFixed20_12.z))
        return true
    }

    /**
     * Stores the velocity after the source collision resolver updates it.
     */
    public mutating func setVelocityFixed20_12(_ velocity: SIMD3<Int32>) {
        state.velocityFixed20_12 = velocity
    }

    /**
     * Applies the positive-Z speed change from overlay 11's outer process update.
     */
    public mutating func applySourceFrameVelocityResponse() {
        if state.positionFixed20_12.z < Self.reverseBoundaryFixed20_12 {
            state.velocityFixed20_12.z = 0 &- state.velocityFixed20_12.z
        } else if state.velocityFixed20_12.z > 0 {
            state.velocityFixed20_12.z = max(0, state.velocityFixed20_12.z - Self.positiveZDeceleration)
        }
    }

    private static func nextFixedValue(_ position: Int32, velocity: Int32) -> Float {
        Float(position) + Float(velocity) * substepFraction
    }

    private static func truncatedFixedValue(_ value: Float) -> Int32 {
        Int32(clamping: Int64(value.rounded(.towardZero)))
    }
}
