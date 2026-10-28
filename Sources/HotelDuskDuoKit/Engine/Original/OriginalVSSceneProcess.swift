import Foundation

/**
 * Runs the captured Process 88 interaction and its source return delay.
 */
public struct OriginalVSSceneProcess: Equatable, Sendable {
    /// The normal custom-interaction path returns zero from the overlay handler.
    public static let result: Int16 = 0
    public static let fadeStartFrame = 100
    public static let fadeFrameCount = 60
    public static let completionFrameCount = 241

    public private(set) var frameAfterTouch = 0
    public private(set) var didTouch = false
    public private(set) var resultValue: Int16?

    public var opacity: Double {
        guard didTouch else { return 1 }
        guard frameAfterTouch > Self.fadeStartFrame else { return 1 }
        return max(0, 1 - Double(frameAfterTouch - Self.fadeStartFrame) / Double(Self.fadeFrameCount))
    }

    public mutating func touch() {
        guard !didTouch, resultValue == nil else { return }
        didTouch = true
    }

    @discardableResult
    public mutating func update() -> Bool {
        guard didTouch, resultValue == nil else { return false }
        frameAfterTouch += 1
        guard frameAfterTouch >= Self.completionFrameCount else { return false }
        resultValue = Self.result
        return true
    }
}
