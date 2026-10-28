import Foundation

/**
 * Advances the source AfterConfess sequence through its three timed image groups.
 */
public struct OriginalAfterConfessProcess: Equatable, Sendable {
    public enum Phase: Int, Equatable, Sendable {
        case firstScene
        case secondScene
        case finalScene
        case complete
    }

    public static let result: Int16 = 2
    public static let frameCounts = [60, 100, 120]

    public private(set) var phase: Phase = .firstScene
    public private(set) var frameInPhase = 0
    public private(set) var resultValue: Int16?

    @discardableResult
    public mutating func update() -> Bool {
        guard resultValue == nil else { return false }
        frameInPhase += 1
        guard frameInPhase >= Self.frameCounts[phase.rawValue] else { return false }

        frameInPhase = 0
        if phase == .finalScene {
            phase = .complete
            resultValue = Self.result
            return true
        }
        phase = Phase(rawValue: phase.rawValue + 1)!
        return false
    }
}
