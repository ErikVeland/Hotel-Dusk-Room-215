import Foundation

/// Overlay 26, process 48: slide the tank lid, or operate the flush handle.
/// Hit rectangles and frame deltas follow 0x021FEBE0 and 0x021FE910.
public struct OriginalToiletTankProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case sound(archive: Int, entry: Int)
        case slideSound(moving: Bool), stopSlideSound
        case hint(pairA: Int16, pairB: Int16)
        case completed(Int16)
    }
    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var lidAngle: Float = 0
    public private(set) var flushAngle: Float = 0
    public private(set) var awaitingHint = false
    public private(set) var result: Int16?
    private var previousTouch: SIMD2<Int>?
    private var delta = SIMD2<Int>.zero
    private var lidHeld = false
    private var flushHeld = false
    private var timer = 0
    private var quitting = false
    private var returnValue: Int16 = 1

    public init() {}
    public var canQuit: Bool {
        let backEnabled = (phase == 1 && stage <= 1) || (phase == 2 && stage <= 503) || phase == 4
        return backEnabled && !awaitingHint && !quitting && result == nil
    }
    public mutating func quit() { if canQuit { quitting = true; stage = 0 } }
    public mutating func finishHint() { awaitingHint = false; previousTouch = nil; delta = .zero; timer = 50 }
    public var lidRectangle: SIMD4<Int> {
        let ratio = lidAngle / -33
        return SIMD4(43 + Int(-43 * ratio), 64, 190 + Int(-102 * ratio), 88 + Int(24 * ratio))
    }
    private func contains(_ point: SIMD2<Int>?, _ rect: SIMD4<Int>) -> Bool {
        guard let point else { return false }
        return point.x >= rect.x && point.x <= rect.z && point.y >= rect.y && point.y <= rect.w
    }
    private mutating func cache(_ touch: SIMD2<Int>?) {
        if let touch, let previousTouch {
            delta = touch &- previousTouch
            let magnitude = delta.x * delta.x + delta.y * delta.y
            if magnitude > 64 { delta = SIMD2(delta.x * 64 / magnitude, delta.y * 64 / magnitude) }
        } else { delta = .zero }
        previousTouch = touch
    }
    public mutating func update(pageTouch: SIMD2<Int>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil, !awaitingHint else { return [] }
        let touch = pageTouch.flatMap { (0..<192).contains($0.x) && (0..<256).contains($0.y) ? $0 : nil }
        if quitting {
            if stage == 0 { stage = 1; return [.stopSlideSound, .fadeOut(60)] }
            if fadeComplete { result = returnValue; return [.completed(returnValue)] }
            return []
        }
        switch phase {
        case 0:
            phase = 1
            return [.fadeIn(60)]
        case 1:
            var effects: [Effect] = []
            let pressed = touch != nil && previousTouch == nil
            if stage == 0 {
                if fadeComplete { stage = 1; lidHeld = false }
            } else if stage == 1 {
                if pressed && contains(touch, lidRectangle) { lidHeld = true }
                if lidHeld && contains(touch, lidRectangle) {
                    if delta.x < 0 { lidAngle -= 0.2 }
                    if delta.x > 0 { lidAngle += 0.2 }
                    lidAngle = min(0, lidAngle)
                    effects.append(.slideSound(moving: delta.x != 0))
                    if lidAngle <= -33 {
                        lidAngle = -33; stage = 2
                        effects.append(.stopSlideSound)
                    }
                } else { lidHeld = false; effects.append(.stopSlideSound) }
            } else if stage == 2 {
                returnValue = 0; stage = 3; timer = 0
                effects.append(.completionFade(60))
            } else if stage == 3 {
                stage = 4; timer = 0
                effects.append(.sound(archive: 0, entry: 1))
            } else if stage == 4 {
                timer += 1
                if timer > 210 { stage = 5; effects.append(.fadeOut(60)) }
            } else if stage == 5 && fadeComplete {
                result = 0; effects.append(.completed(0))
            }
            if stage <= 1 {
                let flushRect = SIMD4(72, 112, 136, 160)
                if pressed && contains(touch, flushRect) { flushHeld = true }
                else if flushHeld && delta.y >= 3 { phase = 2; stage = 0 }
                else if !contains(touch, flushRect) { flushHeld = false }
            }
            cache(touch)
            return effects
        case 2:
            defer { cache(touch) }
            switch stage {
            case 0:
                if touch == nil { phase = 1; stage = 0 }
                else if delta.x > 0 { stage = 500; timer = 15 }
            case 500:
                timer -= 1
                if timer == 0 {
                    flushAngle = -135; timer = 15; stage = 501
                    return [.sound(archive: 0, entry: 45)]
                }
                flushAngle -= 9
            case 501:
                timer -= 1
                if timer == 0 { stage = 502; timer = 120 }
            case 502:
                timer -= 1
                if timer == 0 { flushAngle = 0; stage = 503 }
                else { flushAngle += 1.125 }
            case 503: stage = 504; timer = 30
            case 504:
                timer -= 1
                if timer == 0 {
                    phase = 4; stage = 0; awaitingHint = true
                    return [.hint(pairA: 25, pairB: 1)]
                }
            default: break
            }
        case 4:
            timer -= 1
            if timer <= 0 { phase = 1; stage = 0; lidHeld = false; flushHeld = false }
        default: break
        }
        return []
    }
}
