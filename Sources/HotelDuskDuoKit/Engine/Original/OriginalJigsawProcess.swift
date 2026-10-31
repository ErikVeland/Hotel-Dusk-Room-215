import Foundation

/**
 * Overlay 2: the incomplete, full, reverse and restored jigsaw processes.
 * Positions use the original 20.12 world coordinates. Angles use units of π.
 */
public struct OriginalJigsawProcess: Equatable, Codable, Sendable {
    public enum Variant: UInt16, Codable, Sendable {
        case incomplete = 26, full = 39, reverse = 40, restored = 84
        var maskSlot: Int? {
            switch self {
            case .incomplete: return 0
            case .full: return 1
            case .reverse: return nil
            case .restored: return 2
            }
        }
    }
    public let variant: Variant
    public var processID: UInt16 { variant.rawValue }
    public private(set) var reverseVisible = false
    private var foldedShut = false
    private var reopened = false
    private var reverseCompleted = false

    public struct Point: Equatable, Codable, Sendable {
        public var x: Int32
        public var y: Int32
        public init(_ x: Int32, _ y: Int32) { self.x = x; self.y = y }
    }

    public struct Piece: Equatable, Codable, Sendable {
        public var position: Point
        public var depth: Int32
        public var angle: Float
        public var movable: Bool
    }

    public enum Effect: Equatable, Sendable {
        case fadeIn(updates: Int)
        case fadeOut(updates: Int)
        case completionFade(updates: Int)
        case sound(archive: Int, entry: Int)
        case hint(pairA: Int16, pairB: Int16)
        case completed(Int16)
    }

    public private(set) var pieces: [Piece]
    public private(set) var seed: UInt32
    public private(set) var phase = 0            // +0x2AC
    public private(set) var stage = 0            // +0x2AE
    public private(set) var selected: Int?       // +0x2FE
    public private(set) var holding = false     // +0x2FC
    public private(set) var result: Int16?
    private var grabOffset = Point(0, 0)
    private var rotationTarget: Float = 0
    private var timer = 0
    private var idleSeconds: Double?
    private var awaitingHint = false

    /**
     * 0x0220183C supplies the five loose pieces. A saved nonzero mask replaces it.
     */
    public init(seed: UInt32, savedLooseMask: UInt32 = 0, variant: Variant = .incomplete) {
        self.seed = seed
        self.variant = variant
        let defaultMask: UInt32 = variant == .full ? 0xFFFFF : variant == .reverse ? 0 : 0x668
        let mask = savedLooseMask & 0xFFFFF == 0 ? defaultMask : savedLooseMask & 0xFFFFF
        pieces = (0..<20).map { index in
            Piece(position: Self.target(index), depth: Self.fixed(-Float(index) * 0.001),
                  angle: 1.5, movable: mask & (1 << index) != 0)
        }
        for index in pieces.indices where pieces[index].movable { scatter(index) }
    }

    /**
     * 0x021FE9C4 and 0x022013D8 form the grid, then offset each unit quad by 0.2.
     */
    public static func target(_ index: Int) -> Point {
        let base = gridBase(index)
        return Point(fixed(Float(base.x) / 4096 + 0.3 - 0.5), fixed(Float(base.y) / 4096 + 0.3 - 0.5))
    }

    public func isPlaced(_ index: Int) -> Bool {
        pieces.indices.contains(index) && pieces[index].position == Self.target(index) && pieces[index].angle == 1.5
    }

    public var placedCount: Int { pieces.indices.filter(isPlaced).count }
    public var acceptsInput: Bool { variant != .reverse && phase == 1 && stage == 0 && result == nil }
    public var awaitsFold: Bool { variant == .reverse && phase == 3 && stage == 1 && result == nil && !reopened }

    /// Only the reverse process accepts a close/open cycle. Opening to any
    /// angle is sufficient. Earlier folds cannot carry into this process.
    public mutating func receiveFold(isClosed: Bool) {
        guard variant == .reverse, phase == 3, stage == 1, result == nil else { return }
        if isClosed { foldedShut = true }
        else if foldedShut { reopened = true; foldedShut = false }
    }

    public mutating func cancelPendingFold() { foldedShut = false; reopened = false }
    public var looseMask: UInt32 {
        pieces.indices.reduce(0) { $0 | (pieces[$1].movable ? UInt32(1) << $1 : 0) }
    }

    /**
     * 0x02201280 selects the nearest unplaced unit rectangle, without an alpha mask.
     */
    public mutating func beginTouch(world point: Point) {
        guard acceptsInput, !holding else { return }
        let hits = pieces.indices.filter { index in
            let piece = pieces[index]
            return !isPlaced(index) && point.x >= piece.position.x && point.x <= piece.position.x + 4096
                && point.y >= piece.position.y && point.y <= piece.position.y + 4096
        }
        guard let index = hits.max(by: { pieces[$0].depth < pieces[$1].depth }) else { return }
        selected = index
        holding = true
        grabOffset = Point(point.x - pieces[index].position.x, point.y - pieces[index].position.y)
        let depth = pieces[index].depth
        for other in pieces.indices where other != index && pieces[other].depth > depth {
            pieces[other].depth -= 4
        }
        pieces[index].depth = 4
        idleSeconds = nil
    }

    /**
     * 0x021FDB30 retains the grab offset and clamps the quad's origin to the stage.
     */
    public mutating func moveTouch(world point: Point) {
        guard acceptsInput, holding, let index = selected else { return }
        pieces[index].position = Point(max(-8192, min(4096, point.x - grabOffset.x)),
                                       max(-12288, min(4096, point.y - grabOffset.y)))
    }

    @discardableResult
    public mutating func endTouch() -> [Effect] {
        guard acceptsInput, holding, let index = selected else { return [] }
        let target = Self.target(index)
        let base = Self.gridBase(index)
        let dx = Float(pieces[index].position.x) / 4096 + 0.5 - (Float(base.x) / 4096 + 0.3)
        let dy = Float(pieces[index].position.y) / 4096 + 0.5 - (Float(base.y) / 4096 + 0.3)
        var effects: [Effect] = []
        if dx * dx + dy * dy < 0.09, pieces[index].angle == 1.5 {
            pieces[index].position = target
            pieces[index].movable = false
            selected = nil
            effects.append(.sound(archive: 26, entry: 0))
        }
        holding = false
        phase = 2
        stage = 0
        idleSeconds = 0
        return effects
    }

    /**
     * Original rotation buttons add or subtract 0.5, then ease by 0.3 per update.
     */
    @discardableResult
    public mutating func rotate(increasing: Bool) -> [Effect] {
        guard acceptsInput, !holding, let index = selected else { return [] }
        rotationTarget = pieces[index].angle + (increasing ? 0.5 : -0.5)
        stage = 1
        idleSeconds = 0
        return [.sound(archive: 26, entry: 1)]
    }

    public mutating func quit() {
        guard phase == 1 || phase == 3, result == nil else { return }
        holding = false
        phase = 4
        stage = 0
        idleSeconds = nil
    }

    /**
     * The host resumes this process after its mode-20 hint conversation.
     */
    public mutating func finishHint() {
        guard phase == 5, awaitingHint else { return }
        awaitingHint = false
        stage = 1
        timer = 0
    }

    /**
     * Recovered update phases at 0x021FD72C, 0x021FE234 and 0x021FE578.
     */
    public mutating func update(screen0FadeComplete: Bool = false, elapsedSeconds: Double = 1 / 59.8261) -> [Effect] {
        guard result == nil else { return [] }
        var effects: [Effect] = []
        switch phase {
        case 0:
            if stage == 0 { effects.append(.fadeIn(updates: 60)) }
            if stage == 3 { phase = variant == .reverse ? 3 : 1; stage = 0 }
            else { stage += 1 }
        case 1:
            if stage == 1, let index = selected {
                let difference = rotationTarget - pieces[index].angle
                if abs(difference) < 0.01 {
                    pieces[index].angle = rotationTarget.truncatingRemainder(dividingBy: 2)
                    if pieces[index].angle < 0 { pieces[index].angle += 2 }
                    stage = 0
                } else { pieces[index].angle += 0.3 * difference }
            }
        case 2:
            switch stage {
            case 0: stage = placedCount == 20 ? 2 : 1
            case 1: phase = 1; stage = 0
            case 2:
                stage = 3
                effects.append(.completionFade(updates: 60))
            case 3:
                timer = 0; stage = 4
                effects.append(.sound(archive: 1, entry: 0))
            case 4:
                timer += 1
                if timer > 120 { timer = 0; phase = 4; stage = 0; idleSeconds = nil }
            default: break
            }
        case 3:
            switch stage {
            case 0:
                cancelPendingFold()
                stage = 1
            case 1:
                if reopened { stage = 2; effects.append(.fadeOut(updates: 5)) }
            case 2:
                if screen0FadeComplete { reverseVisible = true; stage = 4 }
            case 4:
                stage = 5
                timer = 0
            case 5:
                timer += 1
                if timer == 60 {
                    reverseCompleted = true
                    effects += [.completionFade(updates: 60), .sound(archive: 1, entry: 0)]
                }
                if timer > 300 { timer = 0; phase = 4; stage = 0 }
            default: break
            }
        case 4:
            if stage == 0 {
                stage = 1
                effects.append(.fadeOut(updates: 60))
            } else if screen0FadeComplete {
                let count = placedCount
                let value: Int16 = variant == .reverse ? (reverseCompleted ? 0 : 1)
                    : count == 20 ? 0 : variant == .incomplete && count == 15 ? 2 : 1
                result = value
                effects.append(.completed(value))
            }
        case 5:
            guard !awaitingHint else { return [] }
            timer += 1
            if stage == 0, timer >= 30 {
                let pair: Int16 = nextRandom() & 0x80000000 == 0 ? 1 : 2
                awaitingHint = true
                effects.append(.hint(pairA: variant == .incomplete ? 3 : 16, pairB: pair))
            } else if stage == 1, timer >= 30 { phase = 2; stage = 0; timer = 0 }
        default: break
        }
        if let idle = idleSeconds {
            let elapsed = elapsedSeconds.isFinite ? max(0, elapsedSeconds) : 0
            idleSeconds = idle + elapsed
            // 0x021FD72C requests the hint once five elapsed seconds have passed.
            if idle + elapsed >= 5 { phase = 5; stage = 0; timer = 0; idleSeconds = nil }
        }
        return effects
    }

    private static func fixed(_ value: Float) -> Int32 {
        Int32(value * 4096 + (value > 0 ? 0.5 : -0.5))
    }

    private static func gridBase(_ index: Int) -> Point {
        Point(fixed(Float(1 - index % 4) * 0.6), fixed((Float(index / 4) - 2.5) * 0.6))
    }

    private mutating func nextRandom() -> UInt32 {
        seed = seed &* 0x5D588B65 &+ 0x269EC3
        return seed
    }

    /**
     * 0x02200F04 uses the original LCG, ranges and excluded button regions.
     */
    private mutating func scatter(_ index: Int) {
        while true {
            let x = (Float(((nextRandom() >> 16) * 30) >> 16) - 20) * 0.09
            let y = -2.5 - Float(((nextRandom() >> 16) * 7) >> 16) * 0.1
            if x > 0.1 && y < -2.2 { continue }
            if x > 0.3 && y < -2.5 { continue }
            pieces[index].angle = Float(nextRandom() >> 30) * 0.5
            pieces[index].position = Point(Self.fixed(x), Self.fixed(y))
            return
        }
    }
}
