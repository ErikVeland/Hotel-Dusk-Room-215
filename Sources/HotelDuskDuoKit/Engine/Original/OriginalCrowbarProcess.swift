import Foundation

/**
 * Process 30 placement, lifting and cabinet-drop state from overlay 5.
 */
public struct OriginalCrowbarProcess: Equatable, Sendable {
    public struct Touch: Equatable, Sendable {
        public let handle: SIMD3<Int32>?
        public let plane: SIMD3<Int32>?

        public init(handle: SIMD3<Int32>?, plane: SIMD3<Int32>?) {
            self.handle = handle
            self.plane = plane
        }
    }

    public enum Effect: Equatable, Sendable {
        case caption
        case hideCaption
        case fadeIn(Int)
        case completionFade(Int)
        case fadeOut(Int)
        case sound(archive: Int, entry: Int)
        case stopLiftSound
        case soundVolume(Int)
        case rumble(Int)
        case stopRumble
        case completed(Int16)
    }

    public static let restingAngle = Float(bitPattern: 0x3E20D97C)
    public static let maximumAngle = Float(bitPattern: 0x3F490FDB)
    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var position = SIMD3<Int32>(819, 532, -4096)
    public private(set) var handle = SIMD3<Int32>(819, 532, -4096)
    public private(set) var grabOffset = SIMD3<Int32>.zero
    public private(set) var angle = restingAngle
    public private(set) var cabinetAngle: Float = 0
    public private(set) var dropSeverity: Float = 0
    public private(set) var speed: Float = 0
    public private(set) var paperY: Int32 = 2048
    public private(set) var paperSpeed: Float = 0
    public private(set) var holding = false
    public private(set) var lifting = false
    public private(set) var moved = false
    public private(set) var markerVisible = false
    public private(set) var marker = SIMD2<Int>(115, 93)
    public private(set) var timer = 0
    public private(set) var animationFrame = 0
    public private(set) var soundTimer = 0
    public private(set) var rumbleTimer = 0
    public private(set) var returnValue: Int16 = 2
    public private(set) var result: Int16?
    private var wasTouching = false

    public init() {}
    public var canQuit: Bool { result == nil && phase != 3 }
    public var placed: Bool { stage != 0 && stage != 1 && stage != 10 || phase == 2 }
    public var cameraShake: Int32 {
        guard phase == 1, stage == 8 else { return 0 }
        let amount = Self.fixed(Float(0.01) * dropSeverity)
        return timer % 4 < 2 ? -amount : amount
    }

    public mutating func quit() {
        guard canQuit else { return }
        phase = 3
        stage = 0
    }

    /**
     * The host supplies one controller update, projected touch intersections and fade completion.
     */
    @discardableResult
    public mutating func update(touch: Touch? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let pressed = touch != nil && !wasTouching
        defer { wasTouching = touch != nil }
        var effects: [Effect] = []
        switch phase {
        case 0:
            phase = 1
            markerVisible = true
            effects = [.caption, .fadeIn(60)]
        case 1:
            effects = interact(touch: touch, pressed: pressed)
        case 2:
            switch stage {
            case 0: stage = 1
            case 1:
                animationFrame += 1
                if animationFrame > 60 { animationFrame = 0; stage = 2 }
            case 2: stage = 3
            case 3:
                if animationFrame < 20 { paperSpeed += 0.002 }
                else if paperSpeed > 0 { paperSpeed -= 0.002 }
                else { paperSpeed = 0 }
                paperY += Self.fixed(paperSpeed)
                animationFrame += 1
                if animationFrame > 150 { animationFrame = 0; paperSpeed = 0; phase = 3; stage = 0 }
            default: break
            }
        case 3:
            switch stage {
            case 0: stage = 1
            case 1: stage = 2
            case 2: stage = 3; effects = [.fadeOut(60)]
            default:
                if fadeComplete { result = returnValue; effects = [.completed(returnValue)] }
            }
        default: break
        }
        if rumbleTimer > 0 {
            rumbleTimer -= 1
            if rumbleTimer == 0 { effects.append(.stopRumble) }
        }
        return effects
    }

    private mutating func interact(touch: Touch?, pressed: Bool) -> [Effect] {
        switch stage {
        case 0:
            stage = 10
            markerVisible = true
        case 10:
            if pressed { markerVisible = false }
            if pressed, let hit = touch?.handle {
                holding = true
                grabOffset = hit &- handle
                stage = 1
            }
        case 1:
            if !holding {
                if pressed, let hit = touch?.handle {
                    returnValue = 1
                    holding = true
                    grabOffset = hit &- handle
                }
            } else if touch == nil { holding = false }
            else {
                guard let point = touch?.plane else { return [] }
                handle = point &- grabOffset
                handle.z = min(0, handle.z)
                handle.x = max(819, handle.x)
                position.x += (handle.x - position.x) >> 3
                position.z += (handle.z - position.z) >> 3
            }
            let dx = Float(position.x) / 4096 - Float(0.2)
            let squareZ = (Int64(position.z) * Int64(position.z) + 2048) >> 12
            if dx * dx < 0.1, squareZ == 0 {
                handle.x = 0
                handle.z = -4096
                holding = false
                stage = 2
                return [.sound(archive: 0, entry: 30)]
            }
        case 2:
            position.x = Self.approachZero(position.x)
            position.z = Self.approachZero(position.z)
            if angle >= 0 { angle -= 0.01 }
            if angle <= 0, position.x == 0, position.z == 0 {
                angle = 0
                stage = 5
                markerVisible = true
                marker = SIMD2(112, 88)
            }
        case 5:
            speed += 0.01
            angle += speed
            updateHandle()
            if angle > Self.restingAngle { speed = 0; angle = Self.restingAngle; stage = 3 }
        case 3:
            var effects: [Effect] = []
            if !lifting {
                if pressed { markerVisible = false }
                if pressed, let hit = touch?.handle {
                    lifting = true
                    grabOffset = hit &- handle
                    soundTimer = 0
                }
            } else if let touch {
                let point = touch.plane ?? .zero
                if point != .zero { handle = point &- grabOffset }
                var length = Self.length(point)
                if length == 0 { length = 4096 }
                let radius = Float(length) / 4096
                if radius < 1.1, radius > 0.7 {
                    holding = true
                    let next = Self.measuredAngle(handle)
                    let delta = next - angle
                    moved = delta * delta > 0.001
                    angle = next
                    updateHandle()
                    let volume = dropSeverity > 0 ? Int(Float(32) + Float(95) * dropSeverity) : 0
                    if volume > 0 {
                        effects.append(.soundVolume(volume))
                        if soundTimer < 1 { effects.append(.sound(archive: 1, entry: 30)); soundTimer = 60 }
                    }
                } else { drop(); effects.append(.stopLiftSound) }
            } else { drop(); effects.append(.stopLiftSound) }
            if angle > Float(bitPattern: 0x40490FDB) || angle < Self.restingAngle { angle = Self.restingAngle }
            else if angle > Self.maximumAngle { angle = Self.maximumAngle }
            cabinetAngle = Float(0.2) * (angle - Self.restingAngle) * Float(0.5)
            dropSeverity = Float(200) * min(Float(0.005), max(0, cabinetAngle - Float(0.01)))
            if angle == Self.maximumAngle {
                stage = 6
                effects += [.completionFade(60), .hideCaption]
            }
            return effects
        case 4:
            speed += 0.01
            angle -= speed
            cabinetAngle = Float(0.2) * (angle - Self.restingAngle)
            updateHandle()
            if angle < Self.restingAngle {
                speed = 0
                angle = Self.restingAngle
                stage = 8
                timer = 0
                cabinetAngle = 0
                var effects: [Effect] = [.sound(archive: 2, entry: 30), .soundVolume(Int(Float(127) * dropSeverity))]
                if dropSeverity > 0.8 { rumbleTimer = 20; effects.append(.rumble(20)) }
                return effects
            }
        case 6:
            timer = 0
            returnValue = 0
            stage = 7
            return [.sound(archive: 0, entry: 6)]
        case 7:
            timer += 1
            if timer > 120 { timer = 0; phase = 2; stage = 0 }
        case 8:
            timer += 1
            if timer > 16 { timer = 0; stage = dropSeverity >= 0.8 ? 9 : 3 }
        case 9:
            returnValue = 3
            phase = 3
            stage = 0
        default: break
        }
        return []
    }

    private mutating func drop() {
        updateHandle()
        holding = false
        lifting = false
        moved = false
        soundTimer = 0
        stage = 4
    }

    private mutating func updateHandle() {
        handle = SIMD3(Self.fixed(Float(sin(Double(angle)))), 0, -Self.fixed(Float(cos(Double(angle)))))
    }

    private static func measuredAngle(_ point: SIMD3<Int32>) -> Float {
        let x = Float(point.x * 2) / 4096, z = Float(point.z * 2) / 4096
        let magnitude = sqrt(x * x + z * z)
        guard magnitude > 0 else { return 0 }
        let angle = Float(acos(Double(min(1, max(-1, -z / magnitude)))))
        guard asin(Double(x / magnitude)) < 0 else { return angle }
        let pi = Float(bitPattern: 0x40490FD9)
        return pi + (pi - angle)
    }

    private static func approachZero(_ value: Int32) -> Int32 {
        value > 41 ? value - 41 : value < -41 ? value + 41 : 0
    }

    private static func length(_ point: SIMD3<Int32>) -> Int32 {
        let square = (0..<3).reduce(Int64(0)) { $0 + Int64(point[$1]) * Int64(point[$1]) }
        return Int32((Int64(Double(square * 4).squareRoot()) + 1) >> 1)
    }

    private static func fixed(_ value: Float) -> Int32 {
        Int32((value * 4096).rounded(.toNearestOrAwayFromZero))
    }
}
