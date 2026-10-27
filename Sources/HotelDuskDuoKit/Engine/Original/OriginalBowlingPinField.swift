import Foundation

/**
 * Records the initial pin positions and rotation values used by overlay 11.
 */
public struct OriginalBowlingPinField: Equatable, Sendable {
    public static let pinCount = 10
    public static let pinSpacing: Float = 0.8
    public static let halfPinRowDepth: Float = 0.69275
    public static let linearMotionDamping: Float = 0.9
    public static let stationaryVelocitySquaredThreshold: Float = 0.0001
    public static let angularMotionStep: Float = 0.05
    public static let positiveRotationLimit: Float = .pi / 2
    public static let negativeRotationLimit: Float = 3 * .pi / 2
    public static let pinCollisionRadius = Float(bitPattern: 0x3ef83e0e)
    public static let ballPinCollisionRadius = Float(bitPattern: 0x3f783e0e)
    private static let fixedPointScale: Float = 4_096
    private static let laneHalfWidth = Float(bitPattern: 0x40466666)
    private static let laneBoundaryCorrection: Int32 = 410
    private static let pinLateralVelocityScale: Float = 0.1
    private static let ballVelocityResponse: Float = 0.15

    /**
     * Stores one pin's simulation fields from overlay 11's 0x60-byte record.
     */
    public struct Pin: Equatable, Sendable {
        public var positionFixed20_12: SIMD3<Int32>
        public var motionFixed20_12: SIMD3<Int32>
        public var rotation: Float
        public var angularVelocity: Float
        public var isActive: Bool
        public var needsUpdate: Bool

        /**
         * Creates a pin state with the source record's initial values.
         */
        public init(positionFixed20_12: SIMD3<Int32>, motionFixed20_12: SIMD3<Int32> = .zero,
                    rotation: Float = 0, angularVelocity: Float = 0,
                    isActive: Bool = true, needsUpdate: Bool = false) {
            self.positionFixed20_12 = positionFixed20_12
            self.motionFixed20_12 = motionFixed20_12
            self.rotation = rotation
            self.angularVelocity = angularVelocity
            self.isActive = isActive
            self.needsUpdate = needsUpdate
        }
    }

    private static let initialPinStates: [Pin] = [
        Pin(positionFixed20_12: SIMD3(0, 0, -22_528)),
        Pin(positionFixed20_12: SIMD3(-1_638, 0, -25_366)),
        Pin(positionFixed20_12: SIMD3(1_638, 0, -25_366)),
        Pin(positionFixed20_12: SIMD3(-3_277, 0, -28_203)),
        Pin(positionFixed20_12: SIMD3(0, 0, -28_203)),
        Pin(positionFixed20_12: SIMD3(3_277, 0, -28_203)),
        Pin(positionFixed20_12: SIMD3(-4_915, 0, -31_041)),
        Pin(positionFixed20_12: SIMD3(-1_638, 0, -31_041)),
        Pin(positionFixed20_12: SIMD3(1_638, 0, -31_041)),
        Pin(positionFixed20_12: SIMD3(4_915, 0, -31_041))
    ]

    /**
     * Returns the pin centres from overlay 11's initialiser at 0x021FFDFC.
     */
    public static let initialPositions: [SIMD2<Float>] = initialPinStates.map {
        SIMD2(Float($0.positionFixed20_12.x) / 4_096,
              Float($0.positionFixed20_12.z) / 4_096)
    }

    public private(set) var pins = initialPinStates

    public var rotations: [Float] { pins.map(\.rotation) }

    public init() {}

    /**
     * Returns the number of pins with a non-zero rotation, as counted by 0x021FE9D4.
     */
    public var score: Int32 {
        Int32(pins.reduce(into: 0) { count, pin in
            if pin.rotation != 0 { count += 1 }
        })
    }

    /**
     * Stores a source pin state by its index in the ten-pin array.
     */
    @discardableResult
    public mutating func setPin(_ pin: Pin, at index: Int) -> Bool {
        guard pins.indices.contains(index) else { return false }
        pins[index] = pin
        return true
    }

    /**
     * Applies the per-pin angular and linear movement from overlay 11's 0x021FEF34.
     */
    public mutating func advanceMotion() {
        for index in pins.indices where pins[index].needsUpdate {
            var pin = pins[index]
            Self.advanceAngularMotion(&pin)
            pin.positionFixed20_12.x &+= pin.motionFixed20_12.x
            pin.positionFixed20_12.z &+= pin.motionFixed20_12.z
            pin.motionFixed20_12.y = 0
            pin.motionFixed20_12.x = Self.dampedMotion(pin.motionFixed20_12.x)
            pin.motionFixed20_12.z = Self.dampedMotion(pin.motionFixed20_12.z)
            if Self.velocitySquared(pin.motionFixed20_12.x) < Self.stationaryVelocitySquaredThreshold {
                pin.motionFixed20_12.x = 0
            }
            if Self.velocitySquared(pin.motionFixed20_12.z) < Self.stationaryVelocitySquaredThreshold {
                pin.motionFixed20_12.z = 0
            }
            pins[index] = pin
        }
    }

    /**
     * Applies overlay 11's one-step lane-edge correction from 0x022043c0.
     */
    public mutating func resolveLaneBoundary() {
        for index in pins.indices {
            let x = Float(pins[index].positionFixed20_12.x) / Self.fixedPointScale
            if x < -Self.laneHalfWidth {
                pins[index].positionFixed20_12.x &+= Self.laneBoundaryCorrection
            } else if x > Self.laneHalfWidth {
                pins[index].positionFixed20_12.x &-= Self.laneBoundaryCorrection
            }
        }
    }

    /**
     * Returns moving, active pin pairs inside overlay 11's collision radius.
     */
    public var overlappingMovingPinPairs: [(Int, Int)] {
        var pairs = [(Int, Int)]()
        for first in pins.indices where pins[first].isActive {
            for second in pins.index(after: first)..<pins.endIndex where pins[second].isActive {
                let firstPin = pins[first]
                let secondPin = pins[second]
                guard firstPin.motionFixed20_12.x != 0 || firstPin.motionFixed20_12.z != 0 ||
                      secondPin.motionFixed20_12.x != 0 || secondPin.motionFixed20_12.z != 0 else { continue }
                let deltaX = Float(firstPin.positionFixed20_12.x &- secondPin.positionFixed20_12.x) / 4_096
                let deltaZ = Float(firstPin.positionFixed20_12.z &- secondPin.positionFixed20_12.z) / 4_096
                let distanceSquared = deltaX * deltaX + deltaZ * deltaZ
                if distanceSquared < Self.pinCollisionRadius * Self.pinCollisionRadius {
                    pairs.append((first, second))
                }
            }
        }
        return pairs
    }

    /**
     * Returns active pins inside the source ball-contact radius.
     */
    public func ballContactCandidates(at ballPositionFixed20_12: SIMD3<Int32>) -> [Int] {
        pins.indices.filter { index in
            let pin = pins[index]
            guard pin.isActive, !pin.needsUpdate else { return false }
            let deltaX = Float(ballPositionFixed20_12.x &- pin.positionFixed20_12.x) / 4_096
            let deltaZ = Float(ballPositionFixed20_12.z &- pin.positionFixed20_12.z) / 4_096
            return deltaX * deltaX + deltaZ * deltaZ
                < Self.ballPinCollisionRadius * Self.ballPinCollisionRadius
        }
    }

    /**
     * Applies overlay 11's ball-to-pin impulses and returns the struck pin indices.
     */
    public mutating func resolveBallContacts(at ballPositionFixed20_12: SIMD3<Int32>,
                                             ballVelocityFixed20_12: inout SIMD3<Int32>) -> [Int] {
        var contacts = [Int]()
        for index in pins.indices {
            var pin = pins[index]
            guard pin.isActive, !pin.needsUpdate else { continue }
            let deltaX = Float(pin.positionFixed20_12.x &- ballPositionFixed20_12.x) / Self.fixedPointScale
            let deltaZ = Float(pin.positionFixed20_12.z &- ballPositionFixed20_12.z) / Self.fixedPointScale
            let distanceSquared = deltaX * deltaX + deltaZ * deltaZ
            guard distanceSquared < Self.ballPinCollisionRadius * Self.ballPinCollisionRadius else { continue }

            let distance = max(distanceSquared.squareRoot(), 0.1)
            let normalX = deltaX / distance
            let normalZ = deltaZ / distance
            let velocityX = Float(ballVelocityFixed20_12.x) / Self.fixedPointScale
            let velocityZ = Float(ballVelocityFixed20_12.z) / Self.fixedPointScale
            let speed = (velocityX * velocityX + velocityZ * velocityZ).squareRoot()
            pin.motionFixed20_12.x = Self.fixedValue(normalX * speed * Self.pinLateralVelocityScale)
            pin.motionFixed20_12.y = 0
            pin.motionFixed20_12.z = min(Self.fixedValue(normalZ * speed), 0)
            pin.angularVelocity = -velocityZ * Float.pi * Self.pinLateralVelocityScale
            pin.needsUpdate = true
            pins[index] = pin

            let impulseX = Self.fixedValue(normalX * speed * Self.ballVelocityResponse)
            let impulseZ = Self.fixedValue(normalZ * speed * Self.ballVelocityResponse)
            ballVelocityFixed20_12.x &-= impulseX
            ballVelocityFixed20_12.z &-= impulseZ
            contacts.append(index)
        }
        return contacts
    }

    /**
     * Stores the rotation state produced by the pin simulation.
     */
    @discardableResult
    public mutating func setRotation(_ rotation: Float, forPin pin: Int) -> Bool {
        guard pins.indices.contains(pin) else { return false }
        pins[pin].rotation = rotation
        return true
    }

    private static func dampedMotion(_ fixedValue: Int32) -> Int32 {
        Int32(Float(fixedValue) * linearMotionDamping)
    }

    private static func fixedValue(_ value: Float) -> Int32 {
        let fixedValue = value * fixedPointScale
        let roundingTolerance = fixedValue.ulp * 4
        let adjustedValue = fixedValue + (fixedValue < 0 ? -roundingTolerance : roundingTolerance)
        return Int32(clamping: Int64(adjustedValue.rounded(.toNearestOrAwayFromZero)))
    }

    private static func velocitySquared(_ fixedValue: Int32) -> Float {
        let velocity = Float(fixedValue) / 4_096
        return velocity * velocity
    }

    private static func advanceAngularMotion(_ pin: inout Pin) {
        let twoPi = 2 * Float.pi
        var rotation = (pin.rotation + pin.angularVelocity).truncatingRemainder(dividingBy: twoPi)
        if rotation < 0 { rotation += twoPi }

        if pin.angularVelocity > 0, rotation > positiveRotationLimit {
            pin.rotation = positiveRotationLimit
            pin.angularVelocity = 0
        } else if pin.angularVelocity < 0, rotation < negativeRotationLimit {
            pin.rotation = negativeRotationLimit
            pin.angularVelocity = 0
        } else {
            pin.rotation = rotation
            pin.angularVelocity += angularMotionStep
        }
    }
}
