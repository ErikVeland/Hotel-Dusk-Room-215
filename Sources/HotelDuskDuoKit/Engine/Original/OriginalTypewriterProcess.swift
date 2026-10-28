import Foundation
import simd

/**
 * Owns the typewriter input, shift dial, and recovered answer checks.
 */
public struct OriginalTypewriterProcess: Equatable, Sendable {
    public enum Submission: Equatable, Sendable {
        case key(OriginalTypewriterKeyboard.Input)
        case rejected(decodedLines: [String])
        case accepted
        case unresolvedVariant
    }

    public let cipher: OriginalTypewriterCipher
    public private(set) var keyboard = OriginalTypewriterKeyboard()
    public private(set) var shift = 0
    public private(set) var result: Int16?

    public init(cipher: OriginalTypewriterCipher) {
        self.cipher = cipher
    }

    public mutating func adjustShift(by amount: Int) {
        guard result == nil, amount != 0 else { return }
        shift = (shift + amount % 30 + 30) % 30
    }

    /**
     * Applies one source keyboard hit and checks the submitted cipher answer.
     */
    @discardableResult
    public mutating func tap(at point: SIMD2<Int>) -> Submission {
        guard result == nil else { return .key(.ignored) }
        let input = keyboard.tap(at: point)
        guard input == .submit else { return .key(input) }
        guard cipher.variant != .opening else { return .unresolvedVariant }
        let decodedLines = (0..<2).map { cipher.decode(keyboard.text(on: $0), shift: shift) }
        guard cipher.matchesDecodedLines(decodedLines, shift: shift) else {
            return .rejected(decodedLines: decodedLines)
        }
        result = 0
        return .accepted
    }

    /**
     * Returns the source exit value when the player leaves the typewriter.
     */
    public mutating func requestExit() -> Int16? {
        guard result == nil else { return nil }
        result = 2
        return result
    }
}
