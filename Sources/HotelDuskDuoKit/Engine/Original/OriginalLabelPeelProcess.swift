import Foundation

/// Overlay 22, process 46. The source erases a 128 × 160 label mask and
/// accepts the peel when at least 99.5% of its pixels are clear.
public struct OriginalLabelPeelProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int)
        case dragging(Bool)
        case followupInteractionRequired
        case completed(Int16)
    }

    public static let width = 128
    public static let height = 160
    public static let completionFraction = 0.995
    public static let brushRadius = 10
    private static let strokeSampleCount = 3

    public private(set) var phase = 0
    public private(set) var mask: [UInt8]
    public private(set) var result: Int16?
    private var previousTouch: SIMD2<Int>?
    private var finishing = false
    private var followupInteractionReported = false

    public init(mask: [UInt8]) {
        self.mask = Array(mask.prefix(Self.width * Self.height))
        if self.mask.count < Self.width * Self.height {
            self.mask.append(contentsOf: repeatElement(0, count: Self.width * Self.height - self.mask.count))
        }
    }

    public var clearedPixelCount: Int { mask.reduce(into: 0) { if $1 == 0 || $1 >= 128 { $0 += 1 } } }
    public var completionThreshold: Int { Int((Double(mask.count) * Self.completionFraction).rounded(.up)) }
    public var isComplete: Bool { clearedPixelCount >= completionThreshold }

    public mutating func update(pageTouch: SIMD2<Int>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        if finishing {
            if fadeComplete && !followupInteractionReported {
                followupInteractionReported = true
                return [.followupInteractionRequired]
            }
            return []
        }
        if phase == 0 {
            phase = 1
            return [.fadeIn(60)]
        }

        let touch = pageTouch.flatMap {
            (32..<160).contains($0.x) && (48..<208).contains($0.y) ? $0 : nil
        }
        var effects: [Effect] = []
        if let point = touch {
            if let previousTouch {
                for sample in 0..<Self.strokeSampleCount {
                    let x = point.x + (previousTouch.x - point.x) * sample / Self.strokeSampleCount
                    let y = point.y + (previousTouch.y - point.y) * sample / Self.strokeSampleCount
                    erase(at: SIMD2(x - 32, y - 48))
                }
            }
            if previousTouch == nil { effects.append(.dragging(true)) }
        } else if previousTouch != nil {
            effects.append(.dragging(false))
        }
        previousTouch = touch

        if touch == nil && isComplete {
            finishing = true
            previousTouch = nil
            effects.append(.fadeOut(60))
        }
        return effects
    }

    private mutating func erase(at point: SIMD2<Int>) {
        let radius = Self.brushRadius
        for y in max(0, point.y - radius)...min(Self.height - 1, point.y + radius) {
            for x in max(0, point.x - radius)...min(Self.width - 1, point.x + radius) {
                let dx = x - point.x, dy = y - point.y
                guard dx * dx + dy * dy <= radius * radius else { continue }
                let index = y * Self.width + x
                if mask[index] > 0 && mask[index] < 128 { mask[index] += 128 }
            }
        }
    }
}
