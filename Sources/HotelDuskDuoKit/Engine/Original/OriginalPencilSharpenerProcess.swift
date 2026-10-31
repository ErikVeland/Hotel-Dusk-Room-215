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
    private static let pencilAxisMinimum = 38.0
    private static let pencilAxisMaximum = 130.0
    private static let pencilHalfWidth = 26.0
    private static let powderProgressRequired = 500.0

    public private(set) var phase: Phase = .sharpening
    public private(set) var powderProgress = 0.0
    private var remainingExitFrames = 0
    private var touchIsHeld = false
    private var previousTouch: SIMD2<Double>?
    private var processReturnValue: Int16?

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
        releaseTouch()
        phase = .exitAnimation
        remainingExitFrames = Self.exitAnimationFrames
        processReturnValue = 2
        return true
    }

    /**
     * Holds the pencil and records movement across its lead.
     */
    public mutating func holdTouch(pageX: Int, pageY: Int) {
        guard phase == .sharpening,
              (0..<192).contains(pageX), (0..<256).contains(pageY) else { return }
        let point = SIMD2(Double(pageX), Double(pageY))
        guard touchIsHeld else {
            guard Self.containsPencilMask(pageX: pageX, pageY: pageY) else { return }
            touchIsHeld = true
            previousTouch = point
            return
        }
        if let previousTouch {
            let delta = point - previousTouch
            powderProgress += abs(delta.x - delta.y) / sqrt(2)
            if powderProgress >= Self.powderProgressRequired {
                powderProgress = Self.powderProgressRequired
                phase = .complete
                processReturnValue = 0
                self.previousTouch = point
                return
            }
        }
        previousTouch = point
    }

    /**
     * Releases the held pencil.
     */
    public mutating func releaseTouch() {
        touchIsHeld = false
        previousTouch = nil
    }

    /**
     * Advances the source exit delay by one process update.
     */
    public mutating func updateOneFrame() {
        guard phase == .exitAnimation else { return }
        remainingExitFrames -= 1
        if remainingExitFrames == 0 { phase = .complete }
    }

    public var returnedProcessValue: Int16? { processReturnValue }

    /**
     * Tests the diagonal pencil mask measured from the source hit region.
     */
    public static func containsPencilMask(pageX: Int, pageY: Int) -> Bool {
        guard (0..<192).contains(pageX), (0..<256).contains(pageY) else { return false }
        let axisPosition = (Double(pageX) + Double(pageY) + 1) / 2
        let distanceFromAxis = abs(Double(pageY - pageX + 1)) / sqrt(2)
        return (pencilAxisMinimum...pencilAxisMaximum).contains(axisPosition)
            && distanceFromAxis <= pencilHalfWidth
    }

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
