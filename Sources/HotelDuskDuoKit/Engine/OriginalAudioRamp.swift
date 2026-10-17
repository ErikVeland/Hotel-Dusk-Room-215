import Foundation

/// Fixed-point player-volume interpolation from ARM9 020BBC9C/020BBCD0.
struct OriginalAudioRamp: Codable, Sendable, Equatable {
    let start: Int
    let target: Int
    let frames: Int
    private(set) var elapsed = 0
    let stopsAtEnd: Bool

    var value: Int {
        guard frames > 0, elapsed < frames else { return target }
        return start + elapsed * (target - start) / frames
    }
    var isComplete: Bool { elapsed >= max(0, frames) }
    mutating func advance() { elapsed += 1 }
}
