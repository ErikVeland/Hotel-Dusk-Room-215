import Foundation

/**
 * Process 27, overlay 6. Pulling the trapped memo tears it after the original movement threshold.
 */
public struct OriginalMemoPullProcess: Equatable, Sendable {
    public struct Touch: Equatable, Sendable {
        public var paper: SIMD3<Int32>?
        public var plane: SIMD3<Int32>?

        public init(paper: SIMD3<Int32>?, plane: SIMD3<Int32>?) {
            self.paper = paper
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
        case torn
        case completed(Int16)
    }

    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var holding = false
    public private(set) var position = SIMD3<Int32>(-221, 2048, -82)
    public private(set) var angle = Float(bitPattern: 0x4020D97C)
    public private(set) var remainingAngle = Float(bitPattern: 0x40490FDB)
    public private(set) var grabOffset = SIMD3<Int32>.zero
    public private(set) var grabAngle: Float = 0
    public private(set) var pull: Float = 0.15
    public private(set) var soundStage = 0
    public private(set) var tearSpeed: Float = 0
    public private(set) var timer = 0
    public private(set) var result: Int16?

    public init() {}

    public var canQuit: Bool { result == nil && phase == 1 }
    public var returnValue: Int16 { pull > 0.35 ? 0 : pull > 0.15 ? 1 : 2 }

    public mutating func quit() {
        guard canQuit else { return }
        phase = 3
        stage = 0
        holding = false
    }

    /**
     * The host supplies touch intersections, fade completion and one original controller update per call.
     */
    @discardableResult
    public mutating func update(touch: Touch? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        switch phase {
        case 0:
            phase = 1
            return [.caption, .fadeIn(60)]
        case 1:
            if stage == 0 { stage = 1; return [] }
            guard let touch else { holding = false; return [] }
            if !holding {
                if let hit = touch.paper {
                    holding = true
                    grabOffset = hit &- position
                    grabAngle = angle
                }
                return []
            }
            let effects = drag(plane: touch.plane ?? .zero)
            if touch.paper == nil { holding = false }
            return effects
        case 2:
            switch stage {
            case 0:
                tearSpeed = 0.06
                soundStage = 3
                stage = 1
                return [.sound(archive: 2, entry: 29)]
            case 1:
                /**
                 * 0x021FDA1C compares the incremented animation counter with zero.
                 */
                angle -= Float(0.3) * (Float(bitPattern: 0x40490FDB) * tearSpeed)
                tearSpeed -= 0.005
                position.x += Int32((tearSpeed * 4096).rounded(.toNearestOrAwayFromZero))
                stage = 2
                return [.torn, .sound(archive: 0, entry: 6)]
            case 2:
                timer += 1
                if timer > 120 { timer = 0; phase = 3; stage = 0 }
            default: break
            }
        case 3:
            if stage == 0 { stage = 1; return [.hideCaption, .fadeOut(60)] }
            if fadeComplete { result = returnValue; return [.completed(returnValue)] }
        default: break
        }
        return []
    }

    private mutating func drag(plane: SIMD3<Int32>) -> [Effect] {
        var point = plane &- grabOffset
        point.x += 4096
        var next = grabAngle - Self.measuredAngle(point) - Float(0.1)
        let turn = Float(bitPattern: 0x40C90FDB)
        while next < 0 { next += turn }
        while next >= turn { next -= turn }
        if next > Float(bitPattern: 0x4030EF3C) {
            pull += 0.001
            next = Float(bitPattern: 0x402F5376)
        } else if next < Float(bitPattern: 0x4010C3BC) {
            pull += 0.001
            next = Float(bitPattern: 0x40125F83)
        }
        let change = next - angle
        if change * change > 0, point.x > position.x { pull += 0.015 }
        angle = next
        remainingAngle = next
        var effects: [Effect] = []
        if pull > 0.35 {
            phase = 2
            stage = 0
            effects += [.hideCaption, .completionFade(60), .sound(archive: 1, entry: 29)]
        } else if pull <= 0.34, pull > 0.30 {
            if soundStage == 1 { effects.append(.sound(archive: 0, entry: 29)) }
            soundStage = 2
        }
        if soundStage == 0 {
            soundStage = 1
            effects.append(.sound(archive: 0, entry: 29))
        }
        return effects
    }

    /**
     * 0x020254C8 measures the XZ angle around (0, 0, 4096), with Float32 vector arithmetic.
     */
    private static func measuredAngle(_ point: SIMD3<Int32>) -> Float {
        let x = Float(point.x * 2) / 4096
        let z = Float(point.y * 2) / 4096 - 1
        let magnitude = sqrt(x * x + z * z)
        guard magnitude > 0 else { return 0 }
        let nx = x / magnitude, nz = z / magnitude
        let angle = Float(acos(Double(min(1, max(-1, nx)))))
        if asin(Double(nz)) < 0 {
            let pi = Float(bitPattern: 0x40490FD9)
            return pi + (pi - angle)
        }
        return angle
    }
}
