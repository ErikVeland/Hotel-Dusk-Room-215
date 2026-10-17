import Foundation
import simd

/**
 * Process 37, overlay 12, variant 2. Positions use original 20.12 coordinates.
 * The key must enter the lock before repeated turns can break it.
 */
public struct OriginalSuitcaseKeyProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int)
        case fadeOut(Int)
        case completionFade(Int)
        case sound(Int)
        case stopSound(Int)
        case caption(Int)
        case completed(Int16)
    }

    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var key = SIMD3<Int32>(0, 393, 12288)
    public private(set) var drawnKey = SIMD3<Int32>(0, 393, 12288)
    public private(set) var keyRoll: Float = 1
    public private(set) var keyTurn: Float = 0
    public private(set) var keyScale: Float = 0.02
    public private(set) var bag = SIMD3<Int32>(-614, 984, -2009)
    public private(set) var eye = SIMD3<Int32>(-655, 8192, 8192)
    public private(set) var target = SIMD3<Int32>(-655, 393, 7373)
    public private(set) var holding = false
    public private(set) var turns = 0
    public private(set) var result: Int16?
    public private(set) var returnValue: Int16 = 2
    private var upperEndpoint = false
    private var wasDown = false
    private var timer = 0
    private var cameraStart = SIMD3<Int32>(-655, 8192, 8192)
    private var targetStart = SIMD3<Int32>(-655, 393, 7373)

    public init() {}

    public var acceptsInput: Bool { (phase == 1 && stage == 1) || (phase == 5 && stage == 5) }
    public var canQuit: Bool { result == nil && (phase == 1 || (phase == 5 && stage <= 5)) }
    public var isBroken: Bool { turns >= 22 }

    public mutating func quit() {
        guard canQuit else { return }
        phase = 6
        stage = 0
        holding = false
    }

    /**
     * One original update. The projection retains the DS segment-intersection quantisation.
     */
    @discardableResult
    public mutating func update(pageTouch: SIMD2<Float>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let pressed = pageTouch != nil && !wasDown
        wasDown = pageTouch != nil
        var effects: [Effect] = []
        switch phase {
        case 0:
            phase = 1
            effects = [.fadeIn(60), .caption(2)]
        case 1:
            drawnKey = key
            if stage == 0 { stage = 1 }
            else if !holding {
                if pressed, let pageTouch, hit(pageTouch, radius: 2048) != nil { holding = true }
            } else if let pageTouch {
                if let point = hit(pageTouch, radius: 40960) {
                    key.x += (point.x - key.x) >> 2
                    key.z = max(8192, key.z + ((point.z - key.z) >> 2))
                    let delta = SIMD3<Float>(key) / 4096 - SIMD3<Float>(-0.16, 0.096, 1.8)
                    if simd_length_squared(delta) <= 0.25 {
                        phase = 5
                        stage = 0
                        holding = false
                        returnValue = 1
                    }
                }
            } else { holding = false }
        case 5:
            if stage < 6 { drawnKey = key }
            switch stage {
            case 0:
                keyTurn += 0.2 * (0.5 - keyTurn)
                if Float(key.x) / 4096 > -0.15 { key.x = Int32(Float(key.x) - 40.96) }
                else if Float(key.x) / 4096 < -0.17 { key.x = Int32(Float(key.x) + 40.96) }
                else {
                    key.x = -655
                    if (keyTurn - 0.5) * (keyTurn - 0.5) < 0.01 {
                        keyTurn = 0.5
                        stage = 1
                        effects.append(.caption(19))
                    }
                }
            case 1:
                if Float(key.z) / 4096 > 1.71 { key.z = Int32(Float(key.z) - 40.96) }
                else if Float(key.z) / 4096 < 1.69 { key.z = Int32(Float(key.z) + 40.96) }
                else { key.z = 6963; stage = 2; effects.append(.sound(31)) }
            case 2:
                cameraStart = eye
                targetStart = target
                timer = 0
                stage = 3
            case 3:
                // 0x021FE6F8: knots at 0, 45 and 60 updates, with the last two positions equal.
                let amount = min(Float(timer) / 45, 1)
                eye = Self.interpolate(cameraStart, SIMD3(-2703, 3604, 10240), amount)
                target = Self.interpolate(targetStart, targetStart &+ SIMD3(0, 410, 0), amount)
                timer += 1
                if timer > 60 { timer = 0; stage = 4 }
            case 4: stage = 5
            case 5:
                // 0x021FE6F8 ignores the right half of the page during key turning.
                guard (pageTouch?.x ?? 0) < 128 else { break }
                if turns == 11 { turns += 1; effects.append(.caption(20)) }
                if !holding {
                    if pressed, let pageTouch, hit(pageTouch, radius: 614) != nil {
                        holding = true
                        keyTurn = keyTurn > 0.5 ? 0.4 : 0.6
                        turns += 1
                        effects.append(.sound(31))
                    }
                } else if let pageTouch {
                    let point = hit(pageTouch, radius: 614)
                    // The original clamps even a failed hit before it releases the drag.
                    let value = point ?? .zero
                    key.y = min(434, max(352, value.y))
                    let z = 1.7 + 0.02 * (Float(value.z) / 4096 - 1.7)
                    key.z = min(7004, max(6922, Self.fixed(z)))
                    if key.y == 352 {
                        if upperEndpoint { turns += 1; effects.append(.sound(31)) }
                        upperEndpoint = false
                    }
                    if key.y == 434 {
                        if !upperEndpoint { turns += 1; effects.append(.sound(31)) }
                        upperEndpoint = true
                    }
                    if turns > 21 {
                        stage = 6
                        timer = 0
                        returnValue = 0
                        effects.append(.completionFade(60))
                        effects.append(.stopSound(33))
                    }
                    if point == nil { holding = false; effects.append(.stopSound(33)) }
                } else { holding = false; effects.append(.stopSound(33)) }
            case 6:
                for axis in 0..<3 { bag[axis] -= (eye[axis] - target[axis]) >> 1 }
                easeBrokenKey()
                stage = 7
                timer = 0
                keyRoll = 0.5
                keyTurn = 0
                keyScale = 0
                effects += [.caption(29), .sound(6)]
            case 7:
                timer += 1
                easeBrokenKey()
                keyRoll += 0.05 * (0.5 - keyRoll)
                keyTurn += 0.05 * -keyTurn
                keyScale += 0.05 * (0.05 - keyScale)
                if timer > 210 { phase = 6; stage = 0; timer = 0 }
            default: break
            }
        case 6:
            if stage == 0 { stage = 1; effects.append(.fadeOut(60)) }
            else if fadeComplete { result = returnValue; effects.append(.completed(returnValue)) }
        default: break
        }
        return effects
    }

    private mutating func easeBrokenKey() {
        let destination = SIMD3<Int32>(-205, -942, 6963)
        for axis in 0..<3 {
            drawnKey[axis] = Int32(Float(drawnKey[axis]) + 0.1 * Float(destination[axis] - drawnKey[axis]))
        }
    }

    private func hit(_ page: SIMD2<Float>, radius: Int32) -> SIMD3<Int32>? {
        OriginalSuitcaseProjection.hit(page: page, eye: eye, target: target, centre: key, radius: radius)
    }

    private static func interpolate(_ start: SIMD3<Int32>, _ end: SIMD3<Int32>, _ amount: Float) -> SIMD3<Int32> {
        let value = SIMD3<Float>(start) / 4096 + amount * (SIMD3<Float>(end &- start) / 4096)
        return SIMD3(fixed(value.x), fixed(value.y), fixed(value.z))
    }

    private static func fixed(_ value: Float) -> Int32 {
        Int32(value * 4096 + (value > 0 ? 0.5 : -0.5))
    }
}
