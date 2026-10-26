import Foundation

/// Overlay 17. The original tiled scratch buffer, touch polygons, random dust
/// removal and completion tests are retained from 0x021FD488 and 0x021FDA38.
public struct OriginalFountainPenProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeFromWhite(Int), fadeOut(Int), reveal(Int), sound(archive: Int, entry: Int), ensureSound(archive: Int, entry: Int)
        case completed(Int16)
    }
    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var rubbing = false
    public private(set) var mask: [UInt8]
    public private(set) var revision = 0
    public private(set) var inscriptionVisible = false
    public private(set) var returnValue: Int16 = 2
    public private(set) var result: Int16?
    private let dust: [UInt8]
    private var seed: UInt32
    private var timer = 0
    private var wasDown = false
    private var quitting = false
    private var microphoneWarmup = 60

    public init(surface: [UInt8], dust: [UInt8], seed: UInt32) throws {
        guard surface.count == 0xC000, dust.count == 0xC000 else {
            throw OriginalDataError.invalid("Fountain pen scratch buffers")
        }
        mask = surface; self.dust = dust; self.seed = seed
    }
    public var canQuit: Bool { phase > 0 && phase < 3 && returnValue != 0 && !quitting && result == nil }
    public mutating func quit() { if canQuit { quitting = true; timer = 0; rubbing = false } }

    private static let grab: [SIMD2<Int>] = [.init(104,96), .init(120,112), .init(64,208), .init(48,192)]
    private static let rub: [SIMD2<Int>] = [.init(100,72), .init(148,96), .init(69,216), .init(40,200)]
    private static let inspect: [SIMD2<Int>] = [.init(120,22), .init(182,58), .init(65,256), .init(0,256)]
    static func contains(_ point: SIMD2<Int>, polygon: [SIMD2<Int>]) -> Bool {
        for index in polygon.indices {
            let a = polygon[index] &- point, b = polygon[(index + 1) % polygon.count] &- point
            if Int16(truncatingIfNeeded: a.x * b.y - b.x * a.y) < 0 { return false }
        }
        return true
    }
    // These offsets deliberately preserve the source's tile-edge rounding.
    private static func scratchOffset(x: Int, y: Int) -> Int {
        8 + (x % 8) * 8 + (x / 8) * 0x800 - (y % 8) + ((256 - y) / 8) * 64
    }
    private func clearedCount(xRange: Range<Int>, halfWidth: Int, slope: Double, intercept: Double) -> Int {
        var count = 0
        for x in xRange {
            let centre = Int(intercept + slope * Double(x))
            for offset in -halfWidth..<halfWidth {
                let address = 8 + (x % 8) * 8 + (x / 8) * 0x800 - (centre + offset % 8)
                    + ((256 - centre + offset) / 8) * 64
                if mask.indices.contains(address), mask[address] == 0 { count += 1 }
            }
        }
        return count
    }
    public var rubbingComplete: Bool {
        guard clearedCount(xRange: 70..<120, halfWidth: 15, slope: -1.67, intercept: 298) > 1200 else { return false }
        return [(13,11), (14,12), (15,12), (16,13)].allSatisfy { x, y in
            let start = (x + y * 32) * 64
            return mask[start..<(start + 64)].allSatisfy { $0 == 0 }
        }
    }
    public var dustComplete: Bool { clearedCount(xRange: 70..<155, halfWidth: 20, slope: -1.7, intercept: 336) > 3000 }

    private mutating func erase(at point: SIMD2<Int>) {
        for x in max(0, point.x - 8)...min(191, point.x + 8) {
            for y in max(0, point.y - 8)...min(255, point.y + 8) where (x - point.x) * (x - point.x) + (y - point.y) * (y - point.y) < 65 {
                let offset = Self.scratchOffset(x: x, y: y)
                if mask.indices.contains(offset) { mask[offset] = 0 }
            }
        }
        revision += 1
    }
    private mutating func clearDust() {
        for x in 0..<192 {
            for y in 0..<256 {
                seed = seed &* 0x5D588B65 &+ 0x269EC3
                let distance = Int(Int16(truncatingIfNeeded: (128-y)*(128-y) + (96-x)*(96-x)))
                if distance + 14000 < Int((UInt64(seed >> 16) * 25600) >> 16) {
                    let offset = Self.scratchOffset(x: x, y: y)
                    if mask.indices.contains(offset) { mask[offset] = 0 }
                }
            }
        }
        revision += 1
    }

    public mutating func update(pageTouch: SIMD2<Int>? = nil, microphoneEnergy: UInt32 = 0, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let touch = pageTouch.flatMap { (0..<192).contains($0.x) && (0..<256).contains($0.y) ? $0 : nil }
        let pressed = touch != nil && !wasDown
        wasDown = touch != nil
        if quitting {
            if timer == 0 { timer = 1; return [.fadeOut(30)] }
            if fadeComplete { result = returnValue; return [.completed(returnValue)] }
            return []
        }
        if microphoneWarmup > 0, phase == 2, stage >= 2 { microphoneWarmup -= 1 }
        switch phase {
        case 0: phase = 1; return [.fadeIn(60)]
        case 1:
            if stage == 0, fadeComplete {
                var effects: [Effect] = []
                if pressed, let touch {
                    if Self.contains(touch, polygon: Self.grab) {
                        rubbing = true
                        effects.append(.sound(archive: 0, entry: 50))
                    }
                } else if rubbing, let touch, Self.contains(touch, polygon: Self.rub) { erase(at: touch) }
                else { rubbing = false }
                if rubbingComplete { stage = 1; timer = 90; rubbing = false }
                return effects
            } else if stage == 1 {
                timer -= 1
                if timer == 0 { stage = 2; return [.fadeOut(30)] }
            } else if stage == 2, fadeComplete {
                phase = 2; stage = 0; mask = dust; revision += 1
            }
        case 2:
            switch stage {
            case 0: stage = 1; return [.fadeIn(30)]
            case 1: if fadeComplete { stage = 2 }
            case 2:
                if pressed, let touch, Self.contains(touch, polygon: Self.inspect) {
                    clearDust()
                    if dustComplete { returnValue = 0; stage = 3; return [.sound(archive: 0, entry: 38), .reveal(30)] }
                    return [.sound(archive: 0, entry: 38)]
                } else if touch == nil, microphoneWarmup == 0, microphoneEnergy > 30000 {
                    clearDust(); stage = 10
                }
            case 3:
                if fadeComplete {
                    inscriptionVisible = true
                    mask = Array(repeating: 0, count: 0xC000); revision += 1
                    stage = 4
                    return [.fadeFromWhite(30)]
                }
            case 4:
                if fadeComplete { stage = 5; timer = 120 }
            case 5:
                timer -= 1
                if timer == 0 { phase = 3; return [.fadeOut(30)] }
            case 10:
                clearDust()
                if dustComplete { returnValue = 1; stage = 5; timer = 120 }
                return [.ensureSound(archive: 1, entry: 50)]
            default: break
            }
        case 3:
            if fadeComplete { result = returnValue; return [.completed(returnValue)] }
        default: break
        }
        return []
    }
}
