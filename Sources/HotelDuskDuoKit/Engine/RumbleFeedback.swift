import Foundation
#if os(iOS)
import CoreHaptics
#endif

enum RumbleTiming {
    static let minimumDuration = 0.08
    static let maximumDuration = 30.0

    static func durationSeconds(frameCount: Int?, updatesPerSecond: Double) -> Double {
        let frames = max(0, frameCount ?? 8)
        return min(max(Double(frames) / updatesPerSecond, minimumDuration), maximumDuration)
    }
}

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
        let hapticEngine = try? CHHapticEngine()
        hapticEngine?.resetHandler = { [weak self] in
            Task { @MainActor [weak self] in self?.player = nil }
        }
        hapticEngine?.stoppedHandler = { [weak self] _ in
            Task { @MainActor [weak self] in self?.player = nil }
        }
        engine = hapticEngine
        #endif
    }

    public func playRumble(durationFrames: Int?) {
        #if os(iOS)
        guard let engine else { return }
        let duration = RumbleTiming.durationSeconds(frameCount: durationFrames,
                                                    updatesPerSecond: OriginalPlaySession.updatesPerSecond)
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
