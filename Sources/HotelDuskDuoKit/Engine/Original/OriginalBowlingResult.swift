import Foundation

/**
 * Stores the six bowling results in the order used by overlay 11.
 */
public struct OriginalBowlingResult: Equatable, Sendable {
    public static let playerCount = 2
    public static let roundCount = 3
    public static let throwCount = playerCount * roundCount
    public static let maximumScore: Int32 = 10

    public struct ThrowSlot: Equatable, Sendable {
        public let player: Int
        public let round: Int
        public let scoreOffset: Int
    }

    public private(set) var throwScores: [Int32?] = Array(repeating: nil, count: throwCount)

    public init() {}

    public var nextThrow: Int? {
        throwScores.firstIndex(where: { $0 == nil })
    }

    /**
     * Returns each round's result once both player scores are available.
     * Status 1 means player zero wins, 2 means player one wins, and 3 means a tie.
     */
    public var roundStatuses: [Int16?] {
        (0..<Self.roundCount).map { round in
            guard let playerZero = throwScores[round * Self.playerCount],
                  let playerOne = throwScores[round * Self.playerCount + 1],
                  playerZero != -1, playerOne != -1 else { return nil }
            if playerOne < playerZero { return 1 }
            if playerZero < playerOne { return 2 }
            return 3
        }
    }

    /**
     * Mirrors the original result check after player zero records three scores.
     */
    public var shouldFinish: Bool {
        let playerZeroScores = (0..<Self.roundCount).compactMap { throwScores[$0 * Self.playerCount] }
        guard playerZeroScores.count == Self.roundCount else { return false }
        return Self.shouldFinish(
            playerZeroScores: playerZeroScores,
            roundStatuses: roundStatuses.map { $0 ?? 0 })
    }

    /**
     * Returns the row, round and byte offset for a zero-based throw index.
     */
    public static func slot(for throwIndex: Int) -> ThrowSlot? {
        guard (0..<throwCount).contains(throwIndex) else { return nil }
        let player = throwIndex % playerCount
        let round = throwIndex / playerCount
        return ThrowSlot(player: player, round: round, scoreOffset: player * roundCount * 4 + round * 4)
    }

    /**
     * Records one result in source order: players alternate once per round.
     */
    @discardableResult
    public mutating func record(_ score: Int32) -> ThrowSlot? {
        guard (0...Self.maximumScore).contains(score),
              let index = nextThrow, let slot = Self.slot(for: index) else { return nil }
        throwScores[index] = score
        return slot
    }

    /**
     * Mirrors overlay 11's final score check at 0x021FEA90.
     */
    public static func shouldFinish(playerZeroScores: [Int32], roundStatuses: [Int16]) -> Bool {
        guard playerZeroScores.count == roundCount, roundStatuses.count == roundCount,
              playerZeroScores.allSatisfy({ $0 != -1 }) else { return false }
        return roundStatuses.filter { $0 == 2 }.count < 2
    }
}
