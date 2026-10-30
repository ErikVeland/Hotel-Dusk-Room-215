import Foundation

public struct OriginalNumberSealProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case fadingIn(remaining: Int)
        case awaitingExit
        case fadingOut(remaining: Int)
        case complete
    }

    public let number: Int
    public private(set) var phase: Phase = .fadingIn(remaining: 60)
    public var result: Int16? { phase == .complete ? 2 : nil }
    public var opacity: Double {
        switch phase {
        case .fadingIn(let remaining): return Double(60 - remaining) / 60
        case .fadingOut(let remaining): return Double(remaining) / 60
        case .awaitingExit: return 1
        case .complete: return 0
        }
    }

    public init(mapID: Int16, randomInfo: UInt16, shifted: Bool) {
        let column: Int
        switch mapID {
        case 2: column = 0
        case 3: column = 1
        case 17: column = 2
        case 26: column = 3
        case 4: column = 4
        case 5: column = 5
        default: column = 6
        }
        let row = (Int(randomInfo % 10) + (shifted ? 1 : 0)) % 10
        number = Self.numbers[row * 7 + column]
    }

    public mutating func update(touch: SIMD2<Int>? = nil) {
        switch phase {
        case .fadingIn(let remaining):
            phase = remaining <= 1 ? .awaitingExit : .fadingIn(remaining: remaining - 1)
        case .awaitingExit:
            if let touch, (152...191).contains(touch.x), (224...255).contains(touch.y) {
                phase = .fadingOut(remaining: 60)
            }
        case .fadingOut(let remaining):
            phase = remaining <= 1 ? .complete : .fadingOut(remaining: remaining - 1)
        case .complete:
            break
        }
    }

    private static let numbers = [
        10, 14, -43, 25, 23, 34, -12,
        11, -40, 26, -49, 33, 22, 34,
        12, 59, -65, 29, 72, -73, 35,
        13, -27, 22, -36, 54, 76, -22,
        14, 11, -10, 78, -17, 22, -38,
        15, 36, 81, -61, -48, -37, 46,
        16, -39, 48, 53, -54, 47, -28,
        17, -34, 28, -15, 94, -20, -15,
        18, 37, 36, -15, -14, 80, -52,
        19, 25, -21, -11, 77, -91, 30
    ]
}
