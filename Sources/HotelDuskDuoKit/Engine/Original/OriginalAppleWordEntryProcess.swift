import Foundation

/**
 * Records the five source letter taps used to enter the Chapter 9 answer.
 */
public struct OriginalAppleWordEntryProcess: Equatable, Sendable {
    public static let letters = Array("JENNY")

    public private(set) var selectedLetters: [Character] = []
    public private(set) var isComplete = false

    public init?(foundMask: UInt16) {
        guard foundMask & 0x1f == 0x1f else { return nil }
    }

    /**
     * Adds a player-selected letter and returns zero when the source answer is complete.
     */
    @discardableResult
    public mutating func selectLetter(at index: Int) -> Int16? {
        guard !isComplete, Self.letters.indices.contains(index) else { return nil }
        let expectedIndex = selectedLetters.count
        guard index == expectedIndex else {
            selectedLetters.removeAll()
            return nil
        }

        selectedLetters.append(Self.letters[index])
        guard selectedLetters.count == Self.letters.count else { return nil }
        isComplete = true
        return 0
    }
}
