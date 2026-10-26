import Foundation

/// Overlay 18: six-coin cross, original snapping grid, and explicit answer check.
public struct OriginalCoinProcess: Equatable, Sendable {
    public struct Coin: Equatable, Sendable {
        public fileprivate(set) var position: SIMD2<Int32>
        public fileprivate(set) var depth: Int32 = 18432
    }
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case sound(archive: Int, entry: Int)
        case completed(Int16)
    }
    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var coins: [Coin] = [
        .init(position: .init(0, 3277)), .init(position: .init(0, 1638)),
        .init(position: .zero), .init(position: .init(0, -1638)),
        .init(position: .init(-1638, 0)), .init(position: .init(1638, 0))
    ]
    public private(set) var selected: Int?
    public private(set) var returnValue: Int16 = 2
    public private(set) var result: Int16?
    private var wasDown = false
    private var timer = 0
    private var checkPending = false
    public init() {}
    public var canCheck: Bool { phase == 1 && stage == 1 && result == nil }
    public var canQuit: Bool { result == nil && (phase == 0 || phase == 2 || canCheck) }
    public mutating func check() { if canCheck { checkPending = true } }
    public mutating func quit() {
        guard canQuit else { return }
        selected = nil; phase = 3; stage = 0
    }
    public var isCorrect: Bool {
        let original = Self().coins.map(\.position)
        var lower = original; lower[3] = .zero
        var upper = original; upper[0] = .zero
        return coins.map(\.position) == lower || coins.map(\.position) == upper
    }
    private static func fixed(_ value: Float) -> Int32 {
        Int32((value * 4096).rounded(.toNearestOrAwayFromZero))
    }
    private static func snap(_ value: Float) -> Float {
        var point = Float(-2.4)
        while point <= 2.4 {
            if point - Float(0.05) <= value && value <= point + Float(0.05) { return point }
            point += Float(0.4)
        }
        return value
    }
    /// 020CD2C8 also reorders equal depths. Keeping that order matters when coins overlap.
    private func depthOrder() -> [Int] {
        var order = Array(coins.indices)
        func sort(_ low: Int, _ high: Int) {
            guard high > low else { return }
            if high - low == 1 {
                if coins[order[low]].depth > coins[order[high]].depth { order.swapAt(low, high) }
                return
            }
            order.swapAt(low, low + (high - low) / 2)
            var left = low + 1, right = high
            repeat {
                while left < high && coins[order[left]].depth < coins[order[low]].depth { left += 1 }
                while coins[order[right]].depth > coins[order[low]].depth { right -= 1 }
                if right <= left { break }
                order.swapAt(left, right); left += 1; right -= 1
            } while left <= right
            order.swapAt(low, right)
            sort(low, right - 1); sort(right + 1, high)
        }
        sort(0, order.count - 1)
        return order
    }
    public mutating func update(pageTouch: SIMD2<Float>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let touch = pageTouch.flatMap {
            $0.x.isFinite && $0.y.isFinite && (0..<192).contains($0.x) && (0..<256).contains($0.y) ? $0 : nil
        }
        let pressed = touch != nil && !wasDown
        wasDown = touch != nil
        switch phase {
        case 0:
            if stage == 0 { stage = 1; return [.fadeIn(60)] }
            phase = 2; stage = 0; timer = 0
        case 2:
            timer += 1
            if timer > 30 { phase = 1; stage = 0; timer = 0 }
        case 1:
            switch stage {
            case 0: stage = 1
            case 1:
                var effects: [Effect] = []
                if let touch {
                    let point = SIMD2((touch.x - 96) / 96, (128 - touch.y) / 96)
                    if selected == nil && pressed {
                        for index in coins.indices {
                            let delta = SIMD2(Float(coins[index].position.x), Float(coins[index].position.y)) / 4096 - point
                            if delta.x * delta.x + delta.y * delta.y < Float(bitPattern: 0x3D23D70B),
                               selected == nil || coins[index].depth < coins[selected!].depth {
                                selected = index
                            }
                        }
                        if selected != nil { effects.append(.sound(archive: 47, entry: 1)) }
                    }
                    if let selected {
                        coins[selected].position = .init(Self.fixed(min(0.8, max(-0.8, point.x))),
                                                         Self.fixed(min(1.13, max(-1.13, point.y))))
                        coins[selected].depth = 16384
                    }
                } else if let selected {
                    let point = coins[selected].position
                    coins[selected].position = .init(Self.fixed(Self.snap(Float(point.x) / 4096)),
                        Self.fixed(min(2.4, max(-2.4, Self.snap(Float(point.y) / 4096)))))
                    let order = depthOrder()
                    for (rank, index) in order.enumerated() {
                        coins[index].depth = Self.fixed(5 - Float(6 - rank) * Float(0.1))
                    }
                    self.selected = nil
                    effects.append(.sound(archive: 47, entry: 0))
                }
                if checkPending {
                    checkPending = false
                    returnValue = isCorrect ? 0 : 1
                    stage = isCorrect ? 2 : 4
                    if isCorrect { effects.append(.completionFade(60)) }
                }
                return effects
            case 2, 4:
                let success = stage == 2
                timer = 0; stage = 3
                return [.sound(archive: success ? 1 : 6, entry: 0)]
            case 3:
                timer += 1
                if timer > 120 { timer = 0; phase = 3; stage = 0 }
            default: break
            }
        case 3:
            if stage == 0 { stage = 1; return [.fadeOut(60)] }
            if fadeComplete { result = returnValue; return [.completed(returnValue)] }
        default: break
        }
        return []
    }
}
