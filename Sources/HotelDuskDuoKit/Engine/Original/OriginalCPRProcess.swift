import Foundation

/**
 * Tracks the close-and-reopen input used by Chapter 9's CPR interaction.
 */
public struct OriginalCPRProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case awaitingClose
        case awaitingReopen
        case complete
    }

    public private(set) var phase: Phase = .awaitingClose

    /**
     * Returns the original success result after a full close and reopen.
     */
    public mutating func receiveFold(isClosed: Bool, isFullyOpen: Bool) -> Int16? {
        switch phase {
        case .awaitingClose where isClosed:
            phase = .awaitingReopen
        case .awaitingReopen where isFullyOpen:
            phase = .complete
            return 0
        case .awaitingClose, .awaitingReopen, .complete:
            break
        }
        return nil
    }
}
