import Foundation

/**
 * Overlay 36's Chapter 10 code notice fade and exit sequence.
 */
public struct OriginalCodeNoticeProcess: Equatable, Sendable {
    public static let fadeUpdates = 31
    public static let exitControlPageX = 0...39
    public static let exitControlPageY = 224...255

    public enum Phase: Equatable, Sendable {
        case fadingIn(remainingUpdates: Int)
        case awaitingExit
        case waitingForExitControl
        case returned
    }

    public enum Effect: Equatable, Sendable {
        case returned(Int16)
    }

    public let processID: Int
    public private(set) var phase: Phase
    public private(set) var result: Int16?
    public var opacity: Double {
        guard case .fadingIn(let remainingUpdates) = phase else { return 1 }
        return Double(Self.fadeUpdates + 1 - remainingUpdates) / Double(Self.fadeUpdates)
    }

    public init(processID: Int) {
        precondition(processID == 62 || processID == 67)
        self.processID = processID
        phase = .fadingIn(remainingUpdates: Self.fadeUpdates)
        result = nil
    }

    /**
     * Tests the page-space mask for overlay 36's exit control.
     * The source rectangle x 0xE4...0xFC, y 0x9C...0xBC is rotated into
     * portrait page coordinates. The mask adds four pixels where the screen
     * edge permits it.
     */
    public static func hitsExitControl(pageX: Int, pageY: Int) -> Bool {
        exitControlPageX.contains(pageX) && exitControlPageY.contains(pageY)
    }

    /**
     * Advances one overlay update using the recovered exit-control signals.
     */
    public mutating func update(pageTouch: SIMD2<Int>? = nil,
                                exitControlFinished: Bool = false) -> [Effect] {
        var effects: [Effect] = []
        switch phase {
        case .fadingIn(let remainingUpdates):
            phase = remainingUpdates <= 1 ? .awaitingExit
                : .fadingIn(remainingUpdates: remainingUpdates - 1)
        case .awaitingExit:
            if let pageTouch, Self.hitsExitControl(pageX: pageTouch.x, pageY: pageTouch.y) {
                phase = .waitingForExitControl
            }
        case .waitingForExitControl:
            if exitControlFinished {
                result = 2
                phase = .returned
                effects.append(.returned(2))
            }
        case .returned:
            break
        }
        return effects
    }
}
