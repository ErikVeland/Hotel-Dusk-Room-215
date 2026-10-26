import Foundation

/// Overlay 15, process 41. Input rectangles come from 0x021FE1A0;
/// the switch and connecting-bar state machine comes from 0x021FD0DC.
public struct OriginalSwitchboardProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case sound(archive: Int, entry: Int)
        case hint(pairA: Int16, pairB: Int16)
        case completed(Int16)
    }

    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var leftOn = false
    public private(set) var rightOn = false
    public private(set) var lightOn = false
    public private(set) var awaitingHint = false
    public private(set) var result: Int16?
    private var previousTouch: SIMD2<Int>?
    private var failures = 0
    private var timer = 0
    private var quitting = false

    public init() {}
    public var canQuit: Bool { phase == 1 && !awaitingHint && !quitting && result == nil }
    public mutating func quit() { if canQuit { quitting = true; stage = 0 } }
    public mutating func finishHint() { awaitingHint = false; previousTouch = nil }

    private static func inside(_ point: SIMD2<Int>?, x: ClosedRange<Int>, y: ClosedRange<Int>) -> Bool {
        guard let point else { return false }
        return x.contains(point.x) && y.contains(point.y)
    }
    private static func left(_ p: SIMD2<Int>?) -> Bool { inside(p, x: 32...64, y: 112...216) }
    private static func right(_ p: SIMD2<Int>?) -> Bool { inside(p, x: 128...160, y: 112...216) }
    private static func bar(_ p: SIMD2<Int>?) -> Bool { inside(p, x: 80...112, y: 104...184) }

    public mutating func update(pageTouch: SIMD2<Int>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil, !awaitingHint else { return [] }
        let touch = pageTouch.flatMap { (0..<192).contains($0.x) && (0..<256).contains($0.y) ? $0 : nil }
        if quitting {
            if stage == 0 { stage = 1; return [.fadeOut(60)] }
            if fadeComplete { result = 1; return [.completed(1)] }
            return []
        }
        switch phase {
        case 0:
            phase = 1
            return [.fadeIn(60)]
        case 1:
            previousTouch = touch
            if Self.left(touch) || Self.right(touch) { phase = 2 }
        case 2:
            var effects: [Effect] = []
            let delta = (previousTouch?.y ?? 0) - (touch?.y ?? 0)
            if Self.left(previousTouch), Self.left(touch), abs(delta) > 2 {
                let on = delta > 0
                if leftOn != on { effects.append(.sound(archive: on ? 2 : 3, entry: 40)) }
                leftOn = on
            }
            if Self.right(previousTouch), Self.right(touch), abs(delta) > 2 {
                let on = delta > 0
                if rightOn != on { effects.append(.sound(archive: on ? 2 : 3, entry: 40)) }
                rightOn = on
            }
            if (Self.left(previousTouch) || Self.right(previousTouch)), Self.bar(touch) {
                previousTouch = touch
                phase = 3
                return effects
            }
            if Self.left(touch) || Self.right(touch) { previousTouch = touch }
            else {
                for on in [leftOn, rightOn] where on {
                    failures += 1
                    effects.append(.sound(archive: 3, entry: 40))
                }
                let failed = leftOn || rightOn
                leftOn = false; rightOn = false
                phase = 1; previousTouch = nil
                if failed {
                    awaitingHint = true
                    effects.append(.hint(pairA: 18, pairB: failures < 4 ? 1 : 2))
                }
            }
            return effects
        case 3:
            if !Self.bar(touch) {
                if touch == nil {
                    lightOn = false; leftOn = false; rightOn = false
                    phase = 1; previousTouch = nil
                } else { phase = 2 }
            } else if let touch, let previousTouch, previousTouch.y - touch.y > 2 {
                var effects: [Effect] = [.sound(archive: 0, entry: 40)]
                if !leftOn { effects.append(.sound(archive: 2, entry: 40)) }
                if !rightOn { effects.append(.sound(archive: 2, entry: 40)) }
                leftOn = true; rightOn = true; lightOn = true
                phase = 5
                return effects
            }
        case 5: phase = 6; stage = 0
        case 6:
            switch stage {
            case 0:
                if fadeComplete { stage = 1; timer = 0; return [.completionFade(60)] }
            case 1:
                timer += 1; stage = 2
                return [.sound(archive: 0, entry: 1)]
            case 2:
                timer += 1
                if timer > 120 { stage = 3; timer = 0 }
            case 3:
                timer += 1
                if timer == 40 { stage = 4; return [.fadeOut(60)] }
            case 4:
                if fadeComplete { result = 0; return [.completed(0)] }
            default: break
            }
        default: break
        }
        return []
    }
}
