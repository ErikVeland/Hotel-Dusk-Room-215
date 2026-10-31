import Foundation

/**
 * Player actions exposed by the recovered Lounge TV callbacks.
 */
public struct OriginalLoungeTVProcess: Equatable, Sendable {
    public enum Action: String, CaseIterable, Codable, Sendable {
        case cartoon
        case news
        case leave
    }

    public enum Effect: Equatable, Sendable {
        case systemResponse(pairB: Int16)
    }

    public private(set) var isWaitingForResponse = false

    public init() {}

    /**
     * Maps the three overlay callbacks to their System mode-20 response values.
     */
    public mutating func apply(_ action: Action) -> Effect? {
        guard !isWaitingForResponse else { return nil }
        isWaitingForResponse = action != .leave
        switch action {
        case .cartoon: return .systemResponse(pairB: 1)
        case .news: return .systemResponse(pairB: 2)
        case .leave: return .systemResponse(pairB: 0)
        }
    }

    /**
     * Enables another TV choice after its child System dialogue returns.
     */
    public mutating func finishResponse() {
        isWaitingForResponse = false
    }
}
