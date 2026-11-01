import Foundation
#if os(iOS)
import CoreHaptics
#endif

/**
 * Plays recovered rumble effects through the current device.
 */
@MainActor
public protocol RumbleFeedback: AnyObject {
    func playRumble(durationFrames: Int?)
    func stopRumble()
}

@MainActor
public final class NoRumbleFeedback: RumbleFeedback {
    public init() {}

    public func playRumble(durationFrames: Int?) {}

    public func stopRumble() {}
}

@MainActor
public final class SystemRumbleFeedback: RumbleFeedback {
    #if os(iOS)
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    #endif

    public init() {
        #if os(iOS)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        #endif
    }

    public func playRumble(durationFrames: Int?) {
        #if os(iOS)
        guard let engine else { return }
        let frameDuration = 1 / OriginalPlaySession.updatesPerSecond
        let duration = min(max(Double(durationFrames ?? 8) * frameDuration, 0.08), 30)
        let parameters = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.72),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.24)
        ]
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: parameters,
                                  relativeTime: 0, duration: duration)
        do {
            try? player?.stop(atTime: CHHapticTimeImmediate)
            player = nil
            try engine.start()
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let nextPlayer = try engine.makePlayer(with: pattern)
            try nextPlayer.start(atTime: CHHapticTimeImmediate)
            player = nextPlayer
        } catch {
            player = nil
        }
        #endif
    }

    public func stopRumble() {
        #if os(iOS)
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        #endif
    }
}
