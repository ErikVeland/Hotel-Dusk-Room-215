import Foundation

/// Overlay 29 story variants: remove four sticks for three squares, or six for three triangles.
public struct OriginalMatchstickProcess: Equatable, Sendable {
    public enum Variant: UInt16, Sendable { case squares = 53, triangles = 54 }
    public struct Stick: Equatable, Sendable {
        public let id: Int
        public let origin: SIMD2<Int>
        public let angle: UInt16
        public let hitPolygon: [SIMD2<Int>]
        public fileprivate(set) var state: UInt8 = 1
        public var center: SIMD2<Int> {
            hitPolygon.reduce(.zero, &+) / SIMD2(repeating: hitPolygon.count)
        }
        func contains(_ point: SIMD2<Int>) -> Bool {
            let vertices = hitPolygon.map { $0 &- point }
            return vertices.indices.allSatisfy { index in
                let a = vertices[index], b = vertices[(index + 1) % vertices.count]
                return Int16(truncatingIfNeeded: a.x * b.y - b.x * a.y) <= 0
            }
        }
    }
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case sound(archive: Int, entry: Int)
        case completed(Int16)
    }
    public let variant: Variant
    public private(set) var sticks: [Stick]
    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var removed = 0
    public private(set) var selected: Int?
    public private(set) var flyX = 0
    public private(set) var flyY = 0
    public private(set) var spin: UInt16 = 0
    public private(set) var returnValue: Int16 = 1
    public private(set) var result: Int16?
    private var timer = 0
    private var animationStage = 0
    private var quitPending = false
    private var resetPending = false
    public var removalLimit: Int { variant == .squares ? 4 : 6 }
    public var canQuit: Bool { phase == 1 && removed != removalLimit && result == nil }
    public var canReset: Bool { canQuit && removed > 0 }
    public mutating func quit() { if canQuit { quitPending = true } }
    public mutating func reset() { if canReset { resetPending = true } }

    public init(variant: Variant) {
        self.variant = variant
        var sticks: [Stick] = []
        func append(_ id: Int, _ origin: SIMD2<Int>, _ angle: UInt16, _ vertices: [SIMD2<Int>]) {
            sticks.append(.init(id: id, origin: origin, angle: angle, hitPolygon: vertices))
        }
        if variant == .squares {
            for row in 0...4 {
                for column in 0..<2 where !(row == 0 && column == 1) && !(row == 4 && column == 0) {
                    let x = 48 + column * 48, y = 40 + row * 48
                    append(row * 4 + column, .init(x, y + 4), 0,
                        [.init(x, y), .init(x, y + 8), .init(x + 40, y + 8), .init(x + 40, y)])
                }
            }
            for row in 0..<4 {
                for column in 0...2 where !(row == 0 && column == 2) && !(row == 3 && column == 0) {
                    let x = 40 + column * 48, y = 48 + row * 48
                    append(20 + row * 4 + column, .init(x + 4, y), 0xC000,
                        [.init(x, y), .init(x, y + 40), .init(x + 8, y + 40), .init(x + 8, y)])
                }
            }
        } else {
            var index = 0
            for row in 0..<3 {
                for column in 0...row {
                    let x = (8 - row * 3 + column * 6) * 8, y = 88 + row * 48
                    for (bank, dx, angle, polygon): (Int, Int, UInt16, [SIMD2<Int>]) in [
                        (0, 8, 0, [.init(0, 4), .init(40, 4), .init(40, -4), .init(0, -4)]),
                        (1, 0, 0x2AAA, [.init(0, 0), .init(21, 0), .init(21, -39), .init(0, -39)]),
                        (2, 40, 0x5555, [.init(0, -8), .init(0, -39), .init(-14, -39), .init(-14, -8)])
                    ] {
                        let origin = SIMD2(x + dx, y)
                        append(bank * 6 + index, origin, angle, polygon.map { $0 &+ origin })
                    }
                    index += 1
                }
            }
        }
        self.sticks = sticks
    }

    /// 021FE4F8/021FE7C0 count complete shapes and reject every unused remaining stick.
    public var isCorrect: Bool {
        let present = Set(sticks.filter { $0.state == 1 }.map(\.id))
        let complete = shapeEdges.filter { $0.isSubset(of: present) }
        return complete.count == 3 && complete.reduce(into: Set<Int>()) { $0.formUnion($1) } == present
    }
    private var shapeEdges: [Set<Int>] {
        var result: [Set<Int>] = []
        if variant == .squares {
            for size in 1...2 {
                for row in 0...(4 - size) {
                    for column in 0...(2 - size) {
                        var edges = Set<Int>()
                        for step in 0..<size {
                            edges.insert(row * 4 + column + step)
                            edges.insert((row + size) * 4 + column + step)
                            edges.insert(20 + (row + step) * 4 + column)
                            edges.insert(20 + (row + step) * 4 + column + size)
                        }
                        result.append(edges)
                    }
                }
            }
        } else {
            for i in 0..<6 { result.append([i, 6 + i, 12 + i]) }
            for row in 0..<2 {
                for column in 0...row {
                    let i = row * 2 + column, top = row + column
                    result.append([top, 6 + i + 2, 12 + i + 1])
                    result.append([i + 1, i + 2, 6 + top, 6 + i + 1, 12 + top, 12 + i + 2])
                }
            }
            result.append([3, 4, 5, 6, 7, 9, 12, 14, 17])
        }
        return result
    }

    public mutating func update(pageTouch: SIMD2<Int>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        if quitPending { quitPending = false; phase = 3; stage = 0 }
        if resetPending { resetPending = false; phase = 5; stage = 0; timer = 0 }
        switch phase {
        case 0:
            if stage == 0 { stage = 1; return [.fadeIn(60)] }
            if fadeComplete { phase = 1; stage = 0 }
        case 1:
            if stage == 0, let touch = pageTouch,
               let index = sticks.firstIndex(where: { $0.state == 1 && $0.contains(touch) }) {
                selected = index; sticks[index].state = 2; removed += 1
                stage = 1; animationStage = 0; flyX = 0; flyY = 0; spin = 0
                return [.sound(archive: 8, entry: 1)]
            }
            if stage == 1 {
                stage = 2
            } else if stage == 2 {
                if animationStage == 0 {
                    flyX += 30; flyY += 40; spin &+= 128
                    if spin > 4095 { animationStage = 1 }
                } else if animationStage == 1 {
                    flyX += 256; flyY += 512
                    if flyY > 4095 { animationStage = 2 }
                } else {
                    if let selected { sticks[selected].state = 0 }
                    selected = nil; flyX = 0; flyY = 0; spin = 0; stage = 3
                }
            } else if stage == 3 {
                stage = 0
                if removed >= removalLimit { phase = 2 }
            }
        case 2:
            if stage == 0 {
                guard isCorrect else { phase = 3; return [] }
                returnValue = 0; stage = 1; timer = 0
                return [.completionFade(60)]
            }
            if stage == 1, fadeComplete {
                stage = 2; timer = 120
                return [.sound(archive: 1, entry: 0)]
            }
            if stage == 2 { timer -= 1; if timer <= 0 { phase = 3; stage = 0 } }
        case 3:
            if stage == 0 { stage = 1; return [.fadeOut(60)] }
            if fadeComplete { result = returnValue; return [.completed(returnValue)] }
        case 5:
            timer += 1
            if stage == 0 && timer > 30 {
                sticks = Self(variant: variant).sticks; removed = 0; selected = nil
                flyX = 0; flyY = 0; spin = 0; stage = 1; timer = 31
            } else if stage == 1 {
                timer -= 2
                if timer < 1 { phase = 1; stage = 0; timer = 0 }
            }
        default: break
        }
        return []
    }
}
