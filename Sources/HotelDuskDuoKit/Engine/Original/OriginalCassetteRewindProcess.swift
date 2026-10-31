import Foundation

/**
 * Records the pencil rewind interaction from overlay 25 process 45.
 */
public struct OriginalCassetteRewindProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case ready
        case tracking
        case rewindAnimation
        case quitFade
        case returnPending
        case complete
    }

    public static let rewindStartX = 120
    public static let rewindTargetY = 100
    public static let completionCounter = 6
    public static let animationWaitUpdates = 20
    public static let quitFadeUpdates = 60

    public private(set) var phase: Phase = .ready
    public private(set) var dragProgress = 100
    public private(set) var qualifyingTouchFrames = 0
    public private(set) var quitFadeProgress = 0
    public private(set) var returnedProcessValue: Int16?

    private var lastPoint: SIMD2<Int>?
    private var reachedRewindEdge = false
    private var animationUpdates = 0
    private var returnUpdates = 0

    public init() {}

    public var opacity: Double {
        phase == .quitFade ? max(0, 1 - Double(quitFadeProgress) / Double(Self.quitFadeUpdates)) : 1
    }

    /**
     * Advances one source update from held input and an optional new raw DS press.
     */
    public mutating func update(rawTouch: SIMD2<Int>?, pressedTouch: SIMD2<Int>? = nil) {
        if phase != .quitFade, phase != .complete,
           let pressedTouch,
           OriginalBellProcess.hitsQuit(
            OriginalBellProcess.Touch(x: pressedTouch.x, y: pressedTouch.y), leftHanded: false
           ) {
            phase = .quitFade
            quitFadeProgress = 0
            return
        }

        switch phase {
        case .ready:
            guard let rawTouch,
                  OriginalCassetteTouchRegion.containsStartTap(rawTouch, rotated: false) else { return }
            lastPoint = rawTouch
            phase = .tracking
        case .tracking:
            guard let rawTouch else {
                lastPoint = nil
                phase = .ready
                reachedRewindEdge = false
                return
            }
            track(rawTouch)
        case .rewindAnimation:
            animationUpdates += 1
            if animationUpdates >= Self.animationWaitUpdates {
                phase = .returnPending
            }
        case .quitFade:
            quitFadeProgress += 1
            if quitFadeProgress >= Self.quitFadeUpdates {
                returnedProcessValue = 2
                phase = .complete
            }
        case .returnPending:
            returnUpdates += 1
            if returnUpdates >= 2 {
                returnedProcessValue = 0
                phase = .complete
            }
        case .complete:
            break
        }
    }

    private mutating func track(_ rawTouch: SIMD2<Int>) {
        guard (0..<256).contains(rawTouch.x), (0..<192).contains(rawTouch.y),
              let previous = lastPoint,
              let previousPoint = OriginalCassetteTouchRegion.processPoint(rawTouch: previous, rotated: false),
              let point = OriginalCassetteTouchRegion.processPoint(rawTouch: rawTouch, rotated: false) else {
            lastPoint = rawTouch
            return
        }

        lastPoint = rawTouch
        if !reachedRewindEdge {
            guard abs(point.y - previousPoint.y) <= 2,
                  point.x >= Self.rewindStartX else { return }
            reachedRewindEdge = true
        }

        guard reachedRewindEdge, point.y <= Self.rewindTargetY else { return }
        dragProgress = 85
        if qualifyingTouchFrames == 0 {
            qualifyingTouchFrames = 1
        } else {
            qualifyingTouchFrames += 1
        }
        if qualifyingTouchFrames >= Self.completionCounter {
            phase = .rewindAnimation
            lastPoint = nil
        }
    }
}
