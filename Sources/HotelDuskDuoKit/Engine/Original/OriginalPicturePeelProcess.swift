import Foundation

/**
 * Overlay 35 picture peel for Chapter 10 process 61.
 */
public struct OriginalPicturePeelProcess: Equatable, Sendable {
    public static let width = 192
    public static let height = 256
    public static let clearedPixelThreshold = 44_237
    public static let brushRadius = 4

    public enum Effect: Equatable, Sendable {
        case dragging(Bool)
        case sound(archive: Int, entry: Int)
        case peelCompleted
        case returned(Int16)
    }

    public private(set) var mask: [UInt8]
    public private(set) var clearedPixelCount: Int
    public private(set) var result: Int16?
    private var previousTouch: SIMD2<Int>?
    private var completionTriggered = false

    public init(mask: [UInt8]) {
        let size = Self.width * Self.height
        var normalisedMask = Array(mask.prefix(size))
        if normalisedMask.count < size {
            normalisedMask.append(contentsOf: repeatElement(1, count: size - normalisedMask.count))
        }
        self.mask = normalisedMask
        clearedPixelCount = normalisedMask.reduce(into: 0) { if $1 == 0 { $0 += 1 } }
    }

    public var isComplete: Bool { clearedPixelCount >= Self.clearedPixelThreshold }

    /**
     * Applies one held-touch sample and tests completion after release.
     */
    public mutating func update(touch: SIMD2<Int>? = nil, eraseSoundPlaying: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let point = touch.flatMap { Self.contains($0) ? $0 : nil }
        var effects: [Effect] = []
        let clearedBeforeTouch = clearedPixelCount
        if let point {
            if let previousTouch {
                let dx = point.x - previousTouch.x
                let dy = point.y - previousTouch.y
                for step in 1...20 {
                    stamp(.init(previousTouch.x + dx * step / 20,
                                previousTouch.y + dy * step / 20))
                }
            } else {
                stamp(point)
                effects.append(.dragging(true))
            }
        } else if previousTouch != nil {
            effects.append(.dragging(false))
            if isComplete && !completionTriggered {
                completionTriggered = true
                effects.append(.peelCompleted)
            }
        }
        if clearedPixelCount > clearedBeforeTouch && !eraseSoundPlaying {
            effects.append(.sound(archive: 50, entry: 0))
        }
        previousTouch = point
        return effects
    }

    /**
     * Returns success after the player clears the cover, or the exit result when it remains.
     */
    public mutating func requestExit() -> Effect? {
        guard result == nil else { return nil }
        let returnValue: Int16 = completionTriggered ? 0 : 2
        result = returnValue
        return .returned(returnValue)
    }

    private static func contains(_ point: SIMD2<Int>) -> Bool {
        (0..<width).contains(point.x) && (0..<height).contains(point.y)
    }

    private mutating func stamp(_ point: SIMD2<Int>) {
        let radius = Self.brushRadius
        for dx in -radius...radius {
            for dy in -radius...radius where dx * dx + dy * dy < 17 {
                let x = point.x + dx
                let y = point.y + dy
                guard Self.contains(.init(x, y)) else { continue }
                let index = x * Self.height + Self.height - 1 - y
                if mask[index] != 0 {
                    mask[index] = 0
                    clearedPixelCount += 1
                }
            }
        }
    }
}
