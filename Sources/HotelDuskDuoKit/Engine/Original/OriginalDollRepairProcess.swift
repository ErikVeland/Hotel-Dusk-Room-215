import Foundation

/// Overlay 16: original stitch capture, seam recognition, and wing-drop result.
public struct OriginalDollRepairProcess: Equatable, Sendable {
    public struct Stitch: Equatable, Sendable {
        public let start: SIMD2<Int>
        public let end: SIMD2<Int>
        public var crossesSeam: Bool {
            (125..<206).contains(start.y) && (125..<206).contains(end.y)
                && ((start.x < 170 && end.x > 160) || (end.x < 170 && start.x > 160))
        }
    }
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case sound(archive: Int, entry: Int)
        case completed(Int16)
    }
    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var stitches: [Stitch] = []
    public private(set) var trail: [SIMD2<Int>] = []
    public private(set) var wingAngle: Float = 0
    public private(set) var wingY = 110
    public private(set) var result: Int16?
    private var start: SIMD2<Int>?
    private var end: SIMD2<Int>?
    private var timer = 0
    private var rotationFrame = 0
    private var fallingFrame = 0
    private var quitting = false
    private var returnValue: Int16 = 2
    public init() {}
    public var canQuit: Bool { phase == 1 && stage == 0 && !quitting && result == nil }
    public var repaired: Bool { returnValue == 0 }
    public var showsWholeDoll: Bool { phase == 3 && stage >= 2 }
    public var showsFallingWing: Bool { phase == 3 && stage >= 3 }
    public mutating func quit() { if canQuit { quitting = true; stage = 0 } }
    public var seamMask: UInt8 {
        var mask: UInt8 = 0
        for stitch in stitches where stitch.crossesSeam {
            for (index, range) in [(0, 125..<152), (1, 151..<178), (2, 177..<206)] {
                if range.contains(stitch.start.y) { mask |= 1 << index }
                if range.contains(stitch.end.y) { mask |= 1 << (index + 3) }
            }
        }
        return mask
    }
    private mutating func record(_ first: SIMD2<Int>, _ last: SIMD2<Int>) -> [Effect] {
        let dx = Int32(last.x - first.x), dy = Int32(last.y - first.y)
        guard stitches.count < 15, dx &* dx &* dy &* dy > 143 else { return [] }
        stitches.append(.init(start: first, end: last))
        return [.sound(archive: 35, entry: 0)]
    }
    public mutating func update(pageTouch: SIMD2<Int>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        if quitting {
            if stage == 0 { stage = 1; return [.fadeOut(60)] }
            if fadeComplete { result = returnValue; return [.completed(returnValue)] }
            return []
        }
        let touch = pageTouch.flatMap { (0..<192).contains($0.x) && (0..<256).contains($0.y) ? $0 : nil }
        switch phase {
        case 0: phase = 1; return [.fadeIn(60)]
        case 1:
            if stage == 0 {
                // Recognition is drawn after the source update, so a newly
                // recorded stitch affects the following update's decision.
                let successful = stitches.filter(\.crossesSeam).count > 9 && seamMask == 0x3F
                var effects: [Effect] = []
                if let touch {
                    trail.append(touch)
                    if trail.count > 16 { trail.removeFirst() }
                    if let first = start, let last = end {
                        let a = last &- first, b = touch &- last
                        let dot = Int16(truncatingIfNeeded: a.x * b.x + a.y * b.y)
                        if dot < 0 {
                            effects = record(first, last)
                            if !effects.isEmpty { start = last }
                        }
                        end = touch
                    } else if start == nil { start = touch }
                    else { end = touch }
                } else {
                    if !trail.isEmpty { trail.removeFirst() }
                    if let first = start, let last = end { effects = record(first, last) }
                    start = nil; end = nil
                }
                if stitches.count >= 15 { returnValue = 1; phase = 3; stage = 0 }
                else if successful { stage = 1 }
                return effects
            }
            if stage == 1 { stage = 2; return [.completionFade(60)] }
            if stage == 2 {
                stage = 3; timer = 0; returnValue = 0
                return [.sound(archive: 1, entry: 0)]
            }
            if stage == 3 {
                timer += 1
                if timer > 120 { stage = 4; return [.fadeOut(60)] }
            } else if stage == 4 && fadeComplete { result = 0; return [.completed(0)] }
        case 3:
            switch stage {
            case 0: stage = 1; return [.fadeOut(60)]
            case 1:
                if fadeComplete { stage = 2; return [.fadeIn(60)] }
            case 2:
                if fadeComplete { stage = 3; timer = 45 }
            case 3:
                if timer > 0 { timer -= 1 }
                else if wingAngle < 90 {
                    rotationFrame += 1
                    wingAngle += sin(Float(rotationFrame) * Float(bitPattern: 0x40490FD9) / 180)
                    if wingAngle >= 90 { timer = 15 }
                } else {
                    fallingFrame += 1; wingY += fallingFrame >> 2
                    if fallingFrame > 60 { stage = 4; return [.fadeOut(60)] }
                }
            case 4:
                if fadeComplete { result = 1; return [.completed(1)] }
            default: break
            }
        default: break
        }
        return []
    }
}
