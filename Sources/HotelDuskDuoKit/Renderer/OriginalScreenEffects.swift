import Foundation

/// Source Q20.12 brightness and alpha controllers (020812F0 / 02081C40).
/// Keep internal values unclamped; the DS clamps the final blend coefficients.
public struct OriginalScreenEffects: Equatable, Codable, Sendable {
    public struct Brightness: Equatable, Codable, Sendable {
        public var step: Int32 = 0
        public var value: Int32 = 0
        public var mask: UInt16 = 0
        public var remaining: UInt16 = 0
        public var active = false
        public var mode: UInt8 = 0
        public var firstUpdate = false
        public var coefficient: Int { Int(value / 4096) }
    }
    public struct Alpha: Equatable, Codable, Sendable {
        public var step: Int32 = 0
        public var value: Int32 = 0
        public var firstMask: UInt16 = 0
        public var secondMask: UInt16 = 0
        public var remaining: UInt16 = 0
        public var mode: UInt8 = 0
        public var active = false
        public var firstCoefficient: Int { Int(value / 4096) }
        public var secondCoefficient: Int { 16 - firstCoefficient }
    }
    public private(set) var brightness: [Brightness]
    public private(set) var alpha: [Alpha]

    public init() {
        brightness = Array(repeating: Brightness(), count: 2)
        alpha = Array(repeating: Alpha(), count: 2)
    }

    /// Exact brightness state at the original opening initializer's return.
    public static var opening: Self {
        var result = Self()
        result.brightness = Array(repeating: Brightness(step: 65536, value: -65536,
            mask: 63, remaining: 0, active: false, mode: 2, firstUpdate: false), count: 2)
        return result
    }

    /// The source SDK divides (numerator << 32) and rounds the Q12 result.
    private static func divide(_ numerator: Int32, by denominator: Int32) -> Int32 {
        let quotient = (Int64(numerator) << 32) / Int64(denominator)
        return Int32(truncatingIfNeeded: (quotient + 0x80000) >> 20)
    }

    public mutating func beginBrightness(screen: Int, mask: UInt16, mode: UInt8,
                                         from value: Float, frames: UInt16) throws {
        guard brightness.indices.contains(screen), mode <= 4, frames > 0,
              value.isFinite, abs(value) < 524_000 else {
            throw OriginalDataError.invalid("Original brightness request")
        }
        let fixed = Int32(value * 4096 + (value > 0 ? 0.5 : -0.5))
        let numerator: Int32 = mode == 0 || mode == 4 ? 32768 : 65536
        brightness[screen] = Brightness(step: Self.divide(numerator, by: Int32(frames) * 4096),
            value: fixed, mask: mask, remaining: frames, active: true, mode: mode, firstUpdate: true)
    }

    public mutating func beginAlpha(screen: Int, firstMask: UInt16, secondMask: UInt16,
                                    mode: UInt8, frames: UInt16) throws {
        guard alpha.indices.contains(screen), mode <= 2, frames > 0 else {
            throw OriginalDataError.invalid("Original alpha request")
        }
        let current = alpha[screen].value
        let value: Int32 = mode == 0 ? 0 : mode == 1 ? 65536 : current
        let numerator: Int32 = mode == 2 ? (value == 0 ? 32768 - value : -value) : 65536
        alpha[screen] = Alpha(step: Self.divide(numerator, by: Int32(frames) * 4096), value: value,
            firstMask: firstMask, secondMask: secondMask, remaining: frames, mode: mode, active: true)
    }

    /// Original global screen update runs before the cinematic command queue.
    public mutating func advanceOriginalFrame() {
        for index in brightness.indices where brightness[index].active {
            if brightness[index].firstUpdate {
                brightness[index].firstUpdate = false
                continue
            }
            switch brightness[index].mode {
            case 1: brightness[index].value &+= brightness[index].step
            case 2, 4: brightness[index].value &-= brightness[index].step
            case 3:
                if brightness[index].value > 0 { brightness[index].value &-= brightness[index].step }
                else { brightness[index].value &+= brightness[index].step }
            default: break
            }
            brightness[index].remaining &-= 1
            if brightness[index].remaining == 0 {
                brightness[index].active = false
                switch brightness[index].mode {
                case 1: brightness[index].value = 65536
                case 2: brightness[index].value = -65536
                case 3: brightness[index].value = 0
                case 4: brightness[index].value = -32768
                default: break
                }
            }
        }
        for index in alpha.indices where alpha[index].active {
            if alpha[index].mode == 1 { alpha[index].value &-= alpha[index].step }
            else { alpha[index].value &+= alpha[index].step }
            alpha[index].remaining &-= 1
            if alpha[index].remaining == 0 {
                alpha[index].active = false
                switch alpha[index].mode {
                case 0: alpha[index].value = 65536
                case 1: alpha[index].value = 0
                default: alpha[index].value = alpha[index].step > 0 ? 32768 : 0
                }
            }
        }
    }

    /// Returns nil for a command owned by another native subsystem.
    public mutating func apply(_ record: OriginalCinematicRecord) throws -> OriginalCinematicQueue.Result? {
        guard [0x020A44FC, 0x020A45CC, 0x020A4658, 0x020A4724].contains(record.handlerAddress) else { return nil }
        let screen = Int(try record.byte(4))
        guard screen <= 2 else { throw OriginalDataError.invalid("Original screen selector") }
        let screens = screen == 2 ? [0, 1] : [screen]
        switch record.handlerAddress {
        case 0x020A44FC:
            for index in screens {
                // 02082C90 truncates the current Q12 brightness before restart.
                try beginBrightness(screen: index, mask: UInt16(record.byte(5)), mode: record.byte(6),
                                    from: Float(brightness[index].coefficient), frames: record.unsigned16(8))
            }
            return .complete
        case 0x020A45CC:
            return screens.contains(where: { brightness[$0].active }) ? .waiting : .complete
        case 0x020A4658:
            for index in screens {
                try beginAlpha(screen: index, firstMask: UInt16(record.byte(5)), secondMask: UInt16(record.byte(6)),
                               mode: record.byte(7), frames: record.unsigned16(8))
            }
            return .complete
        default:
            return screens.contains(where: { alpha[$0].active }) ? .waiting : .complete
        }
    }
}
