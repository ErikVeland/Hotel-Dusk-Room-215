import Foundation

/**
 * Records the ballpoint attempt from overlay 25 process 76 and its shared slot 5 return.
 */
public struct OriginalCassetteBallpointProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case waiting
        case quitDelay
        case fading
        case complete
    }

    public static let quitDelayUpdates = 10
    public static let quitFadeUpdates = 60

    public private(set) var phase: Phase = .waiting
    public private(set) var fadeUpdates = 0
    public private(set) var returnedProcessValue: Int16?

    private var quitDelay = 0

    public init() {}

    /**
     * Advances one source update from a new raw touch or the screen fade state.
     */
    public mutating func update(newRawTouch: SIMD2<Int>?, screen0FadeComplete: Bool = false) {
        switch phase {
        case .waiting:
            guard let newRawTouch,
                  OriginalBellProcess.hitsQuit(
                    OriginalBellProcess.Touch(x: newRawTouch.x, y: newRawTouch.y),
                    leftHanded: false
                  ) else { return }
            phase = .quitDelay
            quitDelay = Self.quitDelayUpdates
        case .quitDelay:
            quitDelay -= 1
            if quitDelay <= 0 { phase = .fading }
        case .fading:
            fadeUpdates += 1
            if screen0FadeComplete || fadeUpdates >= Self.quitFadeUpdates {
                returnedProcessValue = 2
                phase = .complete
            }
        case .complete:
            break
        }
    }
}
