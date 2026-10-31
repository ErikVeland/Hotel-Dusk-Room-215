import Foundation
import simd

/**
 * Tracks the five valid searches in overlay 40's mode-one board.
 */
public struct OriginalSearchShedProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int)
        case fadeOut(Int)
        case successReady
        case completed(Int16)
    }

    public enum Phase: Equatable, Sendable {
        case entering
        case searching
        case responding
        case found
        case exiting
    }

    public struct Object: Equatable, Sendable {
        public let position: SIMD3<Float>
        public let scale: SIMD3<Float>
    }

    public private(set) var objects: [Object]
    public private(set) var phase: Phase = .entering
    public private(set) var result: Int16?
    public private(set) var hitCount = 0
    private var responseFrames = 0
    private var menuExitPending = false
    private var fadeOutStarted = false

    public static let requiredHitCount = 5
    private static let successDelayFrames = 30

    public init(seed: UInt32 = 0x0F2B89E1) {
        objects = OriginalBrickWallLayout.objects(seed: seed).map {
            Object(position: $0.position, scale: $0.scale)
        }
    }

    public var canOpenMenu: Bool {
        (phase == .searching || phase == .responding || phase == .found) && result == nil
    }
    public var canConfirmFoundSearch: Bool { phase == .found && result == nil }

    /**
     * Records a hit when the source mode accepts its board index.
     */
    @discardableResult
    public mutating func registerHit(object index: Int) -> Bool {
        guard phase == .searching, result == nil,
              Self.isAcceptedIndex(index), hitCount < Self.requiredHitCount else { return false }
        hitCount += 1
        if hitCount == Self.requiredHitCount {
            phase = .responding
            responseFrames = Self.successDelayFrames
        }
        return true
    }

    /**
     * Returns true for an interior slot in rows zero through twelve.
     */
    public static func isAcceptedIndex(_ index: Int) -> Bool {
        index >= 0 && index < 73 && (1...4).contains(index % 6)
    }

    /**
     * Confirms the source success response and returns process result zero.
     */
    @discardableResult
    public mutating func confirmFoundSearch() -> [Effect] {
        guard canConfirmFoundSearch else { return [] }
        phase = .exiting
        result = 0
        return [.completed(0)]
    }

    public mutating func openMenu() {
        guard canOpenMenu else { return }
        phase = .exiting
        menuExitPending = true
    }

    /**
     * Advances the fade and success response used by the overlay.
     */
    public mutating func update(fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        if menuExitPending {
            if !fadeOutStarted {
                fadeOutStarted = true
                return [.fadeOut(60)]
            }
            if fadeComplete {
                result = 0
                return [.completed(0)]
            }
            return []
        }
        if phase == .entering {
            phase = .searching
            return [.fadeIn(60)]
        }
        if phase == .responding {
            responseFrames -= 1
            if responseFrames <= 0 {
                phase = .found
                return [.successReady]
            }
        }
        return []
    }
}
