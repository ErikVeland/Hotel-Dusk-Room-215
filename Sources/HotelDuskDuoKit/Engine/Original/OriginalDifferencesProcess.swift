import Foundation

/// Overlay 39, process 73. Circles are recognized by 0x021FE324 against the
/// two rectangles initialized by 0x021FE834. Drawing uses the original clipped ink rules.
public struct OriginalDifferencesProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case startSound, soundVolume(Int), stopSound, victory
        case hint(pairA: Int16, pairB: Int16)
        case completed(Int16)
    }
    public private(set) var drawing: OriginalMemoDrawing
    public private(set) var phase = 1
    public private(set) var stage = 0
    public private(set) var found: UInt16 = 0
    public private(set) var awaitingHint = false
    public private(set) var result: Int16?
    public private(set) var revision = 0
    private var processReturn: Int16 = 2
    private var started = false
    private var strokes: [[SIMD2<Int>]] = [[]]
    private var releasePending = false
    private var attempts = 0
    private var hintCountdown: Int?
    private var rejectedSinceClear = false
    private var timer = 0
    private var trailingTouch = SIMD2<Int>.zero
    public static let targets: [SIMD4<Int>] = [.init(144, 104, 152, 112), .init(136, 192, 152, 200)]

    public init(mask: [UInt8]) throws {
        drawing = try OriginalMemoDrawing(paper: .whole, randomInfo: 1, mask: mask)
    }
    public var canQuit: Bool { phase == 1 && !awaitingHint && hintCountdown == nil && result == nil }
    public mutating func clear() {
        guard canQuit else { return }
        drawing.clear(); drawing.release(); revision += 1
        found = 0; attempts = 0; rejectedSinceClear = false; strokes = [[]]; releasePending = false
    }
    public mutating func quit() {
        guard canQuit else { return }
        phase = 3; stage = 0; drawing.release()
    }
    public mutating func finishHint() {
        awaitingHint = false; hintCountdown = 30; drawing.release()
    }
    private static func encloses(_ points: [SIMD2<Int>], target: SIMD4<Int>) -> Bool {
        guard let first = points.first else { return false }
        var lo = first, hi = first
        for point in points { lo = SIMD2(min(lo.x, point.x), min(lo.y, point.y)); hi = SIMD2(max(hi.x, point.x), max(hi.y, point.y)) }
        guard lo.x >= target.x - 40, lo.y >= target.y - 40,
              hi.x <= target.z + 40, hi.y <= target.w + 40,
              lo.x < target.x, lo.y < target.y, hi.x > target.z, hi.y > target.w else { return false }
        return !points.contains { (target.x...target.z).contains($0.x) && (target.y...target.w).contains($0.y) }
    }
    public mutating func update(touch: SIMD2<Int>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil, !awaitingHint else { return [] }
        if !started { started = true; return [.fadeIn(60)] }
        if phase == 3 {
            if stage == 0 { stage = 1; return [.stopSound, .fadeOut(60)] }
            if fadeComplete { result = processReturn; return [.completed(processReturn)] }
            return []
        }
        if phase == 2 {
            switch stage {
            case 0: stage = 1; return [.completionFade(60)]
            case 1: stage = 2; timer = 120; return [.victory]
            case 2:
                timer -= 1
                if timer <= 0 { stage = 3; return [.fadeOut(60)] }
            case 3: if fadeComplete { result = 0; return [.completed(0)] }
            default: break
            }
            return []
        }
        if let remaining = hintCountdown {
            hintCountdown = remaining - 1
            if remaining <= 1 { hintCountdown = nil }
            return []
        }
        if attempts > 1 {
            attempts = 0; rejectedSinceClear = true; hintCountdown = 30; stage = 1
        }
        if stage == 1 && hintCountdown == nil {
            stage = 0; awaitingHint = true
            return [.hint(pairA: 50, pairB: 1)]
        }
        guard let point = touch, (0..<192).contains(point.x), (0..<256).contains(point.y) else {
            if drawing.previousTouch != nil {
                drawing.release(); releasePending = true
                if strokes.count < 8 { strokes.append([]) }
                return [.stopSound]
            }
            if releasePending {
                releasePending = false
                let matches = Self.targets.indices.filter { Self.encloses(strokes[0], target: Self.targets[$0]) }
                if matches.count == 1 { found |= 1 << matches[0] }
                strokes = [[]]; attempts += 1; processReturn = 1
                if found == 3 && !rejectedSinceClear { phase = 2; stage = 0 }
            }
            return []
        }
        releasePending = false
        var effects: [Effect] = []
        if drawing.previousTouch == nil { effects.append(.startSound) }
        let previous = drawing.previousTouch ?? point
        let delta = previous &- trailingTouch
        trailingTouch = previous
        effects.append(.soundVolume(delta.x * delta.x + delta.y * delta.y < 10 ? 0 : 127))
        if strokes[strokes.count - 1].last != point && strokes[strokes.count - 1].count < 256 {
            strokes[strokes.count - 1].append(point)
        }
        drawing.touch(x: point.x, y: point.y); revision += 1
        return effects
    }
}
