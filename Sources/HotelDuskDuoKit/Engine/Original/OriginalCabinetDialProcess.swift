import Foundation

/**
 * Cabinet mode of process 31, recovered from overlay 10.
 */
public struct OriginalCabinetDialProcess: Equatable, Sendable {
    public struct Touch: Equatable, Sendable {
        public let hits: [SIMD3<Int32>?]
        public let plane: SIMD3<Int32>?

        public init(hits: [SIMD3<Int32>?], plane: SIMD3<Int32>?) {
            self.hits = hits
            self.plane = plane
        }
    }

    public enum Effect: Equatable, Sendable {
        case caption
        case hideCaption
        case fadeIn(Int)
        case fadeOut(Int)
        case completionFade(Int)
        case sound(archive: Int, entry: Int)
        case rumble
        case completed(Int16)
    }

    public let target: [Int]
    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var nextPhase = -1
    public private(set) var angles: [Float]
    public private(set) var holding = false
    public private(set) var selected = 0
    public private(set) var wheelY: [Int32] = [-483, -483, -483]
    public private(set) var grabOffsets = [SIMD3<Int32>](repeating: .zero, count: 3)
    public private(set) var timer = 0
    public private(set) var drawerOpening: Float = 0
    public private(set) var returnValue: Int16 = 2
    public private(set) var result: Int16?

    public init(randomValue: UInt16, retainedValue: UInt16) {
        let code = Int(randomValue % 10) + 127
        target = [code / 100, code / 10 % 10, code % 10]
        let initial = min(999, Int(UInt16(999) &- retainedValue))
        let digits = [initial / 100, initial / 10 % 10, initial % 10]
        angles = digits.map { Float((6 - $0 + 10) % 10 + 1) * Float(0.2) }
    }

    public var canQuit: Bool { phase == 1 && result == nil }
    public var digits: [Int] { angles.map(Self.digit) }
    public var retainedValue: UInt16 {
        returnValue == 0 ? 0 : UInt16(999 - (digits[0] * 100 + digits[1] * 10 + digits[2]))
    }
    public var showsDrawer: Bool { phase == 2 || phase == 4 }

    public mutating func quit() {
        guard canQuit else { return }
        phase = 3
        stage = 0
        nextPhase = -1
    }

    /**
     * Advances one original controller update using projected touch intersections.
     */
    @discardableResult
    public mutating func update(touch: Touch? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        switch phase {
        case 0:
            phase = 1
            return [.caption, .fadeIn(60)]
        case 1: return updateWheels(touch: touch)
        case 2:
            switch stage {
            case 0: stage = 1
            case 1:
                drawerOpening += 0.001
                if drawerOpening > 0.05 { drawerOpening = 0.05; stage = 3 }
            case 3:
                timer += 1
                if timer > 60 { timer = 0; stage = 4; return [.fadeOut(60)] }
            case 4:
                timer += 1
                if timer > 60 { timer = 0; result = returnValue; return [.completed(returnValue)] }
            default: break
            }
        case 3, 4:
            if stage == 0 { stage = 1; return [.hideCaption, .fadeOut(60)] }
            if stage == 1 && fadeComplete {
                if nextPhase == -1 { result = returnValue; return [.completed(returnValue)] }
                phase = nextPhase
                stage = 0
                return [.fadeIn(60)]
            }
        default: break
        }
        return []
    }

    private mutating func updateWheels(touch: Touch?) -> [Effect] {
        switch stage {
        case 0: stage = 1
        case 1:
            if !holding {
                if let touch {
                    for index in 0..<min(3, touch.hits.count) {
                        guard let point = touch.hits[index] else { continue }
                        returnValue = 1
                        holding = true
                        selected = index
                        grabOffsets[index] = point &- SIMD3(Self.wheelX[index], wheelY[index], 4751)
                        break
                    }
                }
            } else if let touch {
                let y = min(4096, max(-4096, touch.plane?.y ?? 0))
                let displacement = y - grabOffsets[selected].y
                let delta = Float(wheelY[selected] - displacement) / 4096
                angles[selected] -= Float(0.16) * delta
                wheelY[selected] = displacement
            } else {
                wheelY[selected] = 0
                angles[selected] = Self.wrap(angles[selected])
                stage = 2
                holding = false
                return [.sound(archive: 0, entry: 31)]
            }
        case 2:
            for index in -1...10 {
                let difference = Float(0.2) * Float(index) - angles[selected]
                if difference * difference <= Float(bitPattern: 0x3C23D70B) {
                    angles[selected] += difference > 0 ? Float(0.01) : -Float(0.01)
                    break
                }
            }
            for index in -1...10 {
                let difference = Float(0.2) * Float(index) - angles[selected]
                if difference * difference <= Float(0.0001) {
                    angles[selected] = Self.wrap(angles[selected])
                    stage = 1
                    if digits == target {
                        returnValue = 0
                        stage = 3
                        return [.completionFade(60), .sound(archive: 1, entry: 31), .hideCaption, .rumble]
                    }
                }
            }
        case 3:
            timer += 1
            if timer > 0 { timer = 0; stage = 4; return [.sound(archive: 0, entry: 6)] }
        case 4:
            timer += 1
            if timer > 120 { timer = 0; phase = 3; stage = 0; nextPhase = 2 }
        default: break
        }
        return []
    }

    static let wheelX: [Int32] = [-4608, -205, 4198]

    private static func wrap(_ value: Float) -> Float {
        var value = value
        while value < 0 { value += 2 }
        while value >= 2 { value -= 2 }
        return value
    }

    private static func digit(_ angle: Float) -> Int {
        for index in 0..<9 {
            let start = Float(0.1) + Float(0.2) * Float(index)
            let end = Float(0.3) + Float(0.2) * Float(index)
            if angle > start && angle <= end { return (6 - index + 10) % 10 }
        }
        return 7
    }
}
