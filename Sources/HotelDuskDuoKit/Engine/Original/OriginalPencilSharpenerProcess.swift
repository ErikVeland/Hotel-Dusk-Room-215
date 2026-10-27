import Foundation

/**
 * Tracks the quit path for overlay 19, process 59.
 */
public struct OriginalPencilSharpenerProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case sharpening
        case exitAnimation
        case complete
    }

    public static let exitAnimationFrames = 60
    private static let exitMask = CGRect(x: 3, y: 3, width: 33, height: 25)

    public private(set) var phase: Phase = .sharpening
    private var remainingExitFrames = 0

    public init() {}

    /**
     * Rotates a raw 256×192 point into the portrait 192×256 page.
     */
    public static func pagePoint(rawTouch: SIMD2<Int>) -> SIMD2<Int>? {
        guard (0..<256).contains(rawTouch.x), (0..<192).contains(rawTouch.y) else { return nil }
        return SIMD2(191 - rawTouch.y, rawTouch.x)
    }

    /**
     * Starts the original exit animation when the player taps its icon.
     */
    @discardableResult
    public mutating func tap(pageX: Int, pageY: Int) -> Bool {
        guard phase == .sharpening, Self.containsExitMask(pageX: pageX, pageY: pageY) else { return false }
        phase = .exitAnimation
        remainingExitFrames = Self.exitAnimationFrames
        return true
    }

    /**
     * Advances the source exit delay by one process update.
     */
    public mutating func updateOneFrame() {
        guard phase == .exitAnimation else { return }
        remainingExitFrames -= 1
        if remainingExitFrames == 0 { phase = .complete }
    }

    public var returnedProcessValue: Int16? { phase == .complete ? 2 : nil }

    /**
     * Tests the rounded icon mask from the rotated 192×256 scene capture.
     */
    public static func containsExitMask(pageX: Int, pageY: Int) -> Bool {
        guard (0..<192).contains(pageX), (0..<256).contains(pageY),
              exitMask.contains(CGPoint(x: pageX, y: pageY)) else { return false }
        let radius: CGFloat = 4
        let nearestX = min(max(CGFloat(pageX), exitMask.minX + radius), exitMask.maxX - radius)
        let nearestY = min(max(CGFloat(pageY), exitMask.minY + radius), exitMask.maxY - radius)
        let dx = CGFloat(pageX) - nearestX
        let dy = CGFloat(pageY) - nearestY
        return dx * dx + dy * dy <= radius * radius
    }
}
