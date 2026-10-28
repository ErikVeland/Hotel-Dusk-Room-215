import Foundation

/**
 * Models the original typewriter's key hit regions and two-line text entry.
 */
public struct OriginalTypewriterKeyboard: Equatable, Sendable {
    public struct Key: Equatable, Sendable {
        public let value: Character
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int

        public func contains(_ point: SIMD2<Int>) -> Bool {
            point.x >= x && point.x <= x + width &&
                point.y >= y && point.y <= y + height
        }
    }

    public enum Input: Equatable, Sendable {
        case inserted(Character, line: Int)
        case backspaced(line: Int)
        case advancedToSecondLine
        case submit
        case ignored
    }

    public static let keys: [Key] = {
        let values = Array("ABCDEFGHbIJKLMNOPQRSTUVWXYZ")
        let letters = values.enumerated().map { index, value in
            let column = index % 9
            let row = index / 9
            return Key(value: value, x: 136 + row * 20, y: 6 + column * 20,
                       width: 20, height: 20)
        }
        return letters + [
            Key(value: "e", x: 199, y: 141, width: 20, height: 44),
            Key(value: "s", x: 199, y: 19, width: 20, height: 109),
        ]
    }()

    private(set) var lines = [Array<Character>(), Array<Character>()]
    private(set) var activeLine = 0

    public init() {}

    public func text(on line: Int) -> String {
        guard lines.indices.contains(line) else { return "" }
        return String(lines[line])
    }

    /**
     * Applies the first source key region containing the stylus point.
     */
    @discardableResult
    public mutating func tap(at point: SIMD2<Int>) -> Input {
        guard let key = Self.keys.first(where: { $0.contains(point) }) else { return .ignored }
        switch key.value {
        case "b":
            if activeLine == 1 && lines[1].isEmpty {
                activeLine = 0
            }
            guard !lines[activeLine].isEmpty else { return .ignored }
            lines[activeLine].removeLast()
            return .backspaced(line: activeLine)
        case "e":
            guard activeLine == 0 else { return .submit }
            activeLine = 1
            return .advancedToSecondLine
        case "s":
            return insert(" ")
        default:
            return insert(key.value)
        }
    }

    private mutating func insert(_ character: Character) -> Input {
        if lines[activeLine].count > 14 {
            guard activeLine == 0 else { return .ignored }
            activeLine = 1
        }
        lines[activeLine].append(character)
        return .inserted(character, line: activeLine)
    }
}

/**
 * Applies the original shift cipher and answer checks recovered from overlay 41.
 */
public struct OriginalTypewriterCipher: Equatable, Sendable {
    public enum Variant: UInt8, Sendable {
        case first = 0
        case opening = 1
        case memento = 2
        case final = 3
    }

    public let variant: Variant
    public let expectedShift: Int

    public init(variant: Variant, randomInfo: UInt16) {
        self.variant = variant
        expectedShift = Int(UInt8(truncatingIfNeeded: randomInfo) % 10) + 10
    }

    public func decode(_ text: String, shift: Int) -> String {
        let decoded = text.unicodeScalars.map { scalar in
            let value = Int(scalar.value)
            let range: ClosedRange<Int>
            if (65...90).contains(value) {
                range = 65...90
            } else if (97...122).contains(value) {
                range = 97...122
            } else if value == 32 {
                return scalar
            } else {
                return Unicode.Scalar(0) ?? scalar
            }
            let decoded = (value - range.lowerBound - shift + 26 * 2) % 26
            return Unicode.Scalar(range.lowerBound + decoded) ?? scalar
        }
        return String(String.UnicodeScalarView(decoded))
    }

    public func matchesDecodedLines(_ lines: [String], shift: Int) -> Bool {
        guard shift == expectedShift else { return false }
        let accepted: [[String]]
        switch variant {
        case .first, .final:
            accepted = [
                ["OSTERZONE IS", "DUNNING SMITH"],
                ["OSTERZONE IS   ", "DUNNING SMITH"],
                ["OSTERZONE IS DU", "NNING SMITH"],
            ]
        case .memento:
            accepted = [
                ["A MEMENTO IN", "A ROOM OF LOVE"],
                ["A MEMENTO IN   ", "A ROOM OF LOVE"],
                ["A MEMENTO IN A ", "ROOM OF LOVE"],
            ]
        case .opening:
            return false
        }
        return accepted.contains(lines)
    }
}
