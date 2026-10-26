import Foundation

/// Process 60, overlay 33. Fixed-point drag, throw and reveal state from the ROM.
/// A host must provide animation/fade completion and apply the returned effects.
public struct OriginalLinenWagonProcess: Equatable, Sendable {
    public struct Piece: Equatable, Sendable {
        public fileprivate(set) var x: Int
        public fileprivate(set) var y: Int
        public fileprivate(set) var z: Int
        public fileprivate(set) var throwDirection = 0
        public fileprivate(set) var highlight = 0
        public let rotation: Float
        fileprivate var grab = SIMD2<Int>.zero
        public var pageCenter: SIMD2<Float> { .init(96 + Float(x) * 96 / 4096, 128 - Float(y) * 96 / 4096) }
    }
    public enum Effect: Equatable, Sendable {
        case fadeIn, fadeOut, completionFade(Int)
        case sound(archive: Int, entry: Int)
        case loadGunAnimation
        case completed(Int16)
    }
    public private(set) var pieces: [Piece]
    public private(set) var stage = 0       // object +0x2A8
    public private(set) var phase = 0       // object +0x2AA
    public private(set) var subphase = 0    // object +0x2AC
    public private(set) var timer = 0
    public private(set) var selected: Int?
    public private(set) var coverOpened = false
    public private(set) var coverAlpha = 0
    public private(set) var gunAlpha = 0
    public private(set) var returnValue: Int16 = 2
    public private(set) var result: Int16?
    public private(set) var animationFrame = 0
    private var previousTouch: SIMD2<Int>?
    private var selectedDepth = 0
    private var quitPending = false

    public init(seed: UInt32 = 0) {
        var rng = seed
        func next() -> UInt32 { rng = rng &* 0x5D588B65 &+ 0x00269EC3; return rng }
        for _ in 0..<6 { _ = next() }
        pieces = (0..<6).map { index in
            let factor = Float(18 - index) / 18
            let x = Self.fixed(Float(80 + (index % 2) * 50 - 96) / 96)
            let y = Self.fixed(Float(128 - (100 + (index / 2) * 40)) / 96)
            return Piece(x: Int(Float(x) * factor), y: Int(Float(y) * factor),
                         z: Self.fixed(1 + Float(index) * Float(bitPattern: 0x3DCCCCCD)),
                         rotation: Float(next() >> 30) * 0.5)
        }
    }

    public var canQuit: Bool { result == nil && stage == 1 && phase < 4 }
    public var allSheetsRemoved: Bool { pieces.allSatisfy { $0.throwDirection == 10 } }
    public mutating func quit() { if canQuit { quitPending = true } }

    /// 0x021FDEF8: radius 40 page pixels; the lowest original Z wins overlaps.
    public func hit(pageTouch: SIMD2<Int>) -> Int? {
        let point = Self.world(pageTouch)
        var selected: Int?, depth = 0xA000
        for (index, piece) in pieces.enumerated() {
            let dx = Float(piece.x) / 4096 - point.x
            let dy = Float(piece.y) / 4096 - point.y
            if dx * dx + dy * dy < Float(bitPattern: 0x3E31C71C), piece.z < depth {
                selected = index; depth = piece.z
            }
        }
        return selected
    }

    /// 0x021FF970: throw only outside the source rectangle [42,158) × [69,208).
    static func throwDirection(x: Int, y: Int) -> Int {
        let left = fixed(Float(42 - 96) / 96), right = fixed(Float(158 - 96) / 96)
        let top = fixed(Float(128 - 69) / 96), bottom = fixed(Float(128 - 208) / 96)
        let horizontal = x < left ? -1 : (x >= right ? 1 : 0)
        let vertical = y > top ? 1 : (y <= bottom ? -1 : 0)
        return horizontal == 0 && vertical == 0 ? 0 : horizontal + 2 + (vertical + 1) * 3
    }

    public mutating func update(pageTouch: SIMD2<Int>? = nil, gunAnimationComplete: Bool = false,
                                fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let touch = pageTouch.flatMap { (0..<192).contains($0.x) && (0..<256).contains($0.y) ? $0 : nil }
        let pressed = touch != nil && previousTouch == nil
        defer { previousTouch = touch }
        // 0x021FF868 precedes the process update, including startup and exit.
        for index in pieces.indices {
            let direction = pieces[index].throwDirection
            if direction != 0 && direction != 10 {
                pieces[index].x += ((direction - 1) % 3 - 1) * 0xAB
                pieces[index].y += ((direction - 1) / 3 - 1) * 0xAB
            }
            let x = Float(pieces[index].x) / 4096, y = Float(pieces[index].y) / 4096
            if x * x > 4 || y * y > 4 { pieces[index].throwDirection = 10 }
        }
        animationFrame = (animationFrame + 1) % 64
        if quitPending {
            quitPending = false; stage = 3; phase = 0
            return [.fadeOut]
        }
        switch stage {
        case 0:
            if phase == 0 { phase = 1; return [.fadeIn] }
            phase = 0; stage = 2
        case 2:
            timer += 1
            if timer > 30 { stage = 1; timer = 0 }
        case 3:
            if phase == 0 { phase = 1; return [.completionFade(60)] }
            if fadeComplete { result = returnValue; return [.completed(returnValue)] }
        case 1:
            for index in pieces.indices { pieces[index].highlight = max(0, pieces[index].highlight - 1) }
            switch phase {
            case 0: phase = 1
            case 1:
                var effects: [Effect] = []
                if let index = selected {
                    if let touch {
                        let point = Self.world(touch)
                        pieces[index].x = Self.fixed(point.x) - pieces[index].grab.x
                        pieces[index].y = Self.fixed(point.y) - pieces[index].grab.y
                        pieces[index].highlight = min(5, pieces[index].highlight + 2)
                    } else {
                        selected = nil; animationFrame = 0
                        pieces[index].throwDirection = Self.throwDirection(x: pieces[index].x, y: pieces[index].y)
                        pieces[index].z = selectedDepth
                        if pieces[index].throwDirection != 0 {
                            returnValue = 1
                            effects.append(.sound(archive: 53, entry: 0))
                        }
                    }
                } else if pressed, let touch, let index = hit(pageTouch: touch) {
                    selected = index
                    let point = Self.world(touch)
                    pieces[index].grab = .init(Self.fixed(point.x) - pieces[index].x, Self.fixed(point.y) - pieces[index].y)
                    selectedDepth = pieces[index].z; pieces[index].z = 0xE66
                }
                if allSheetsRemoved { phase = 2; subphase = 0 }
                return effects
            case 2:
                if subphase == 0, pressed, let touch {
                    if Self.inside(touch, x: 64...128, y: 136...200) {
                        coverOpened = true; subphase = 1
                    } else if Self.inside(touch, x: 48...152, y: 80...136) {
                        phase = 3; subphase = 0
                    }
                } else if subphase == 1 {
                    coverAlpha += 1
                    if coverAlpha > 30 { coverAlpha = 31; subphase = 0 }
                }
            case 3:
                switch subphase {
                case 0: subphase = 1; return [.sound(archive: 53, entry: 0)]
                case 1: gunAlpha = 0; subphase = 2; return [.loadGunAnimation]
                case 2: if gunAnimationComplete { subphase = 3 }
                case 3:
                    gunAlpha += 1
                    if gunAlpha >= 31 { subphase = 4 }
                case 4:
                    guard pressed, let touch else { return [] }
                    if !coverOpened, Self.inside(touch, x: 64...128, y: 136...200) {
                        coverOpened = true; subphase = 5
                    }
                    if Self.inside(touch, x: 88...144, y: 104...136) {
                        phase = 4; subphase = 0; returnValue = 0
                        return [.completionFade(60), .fadeOut]
                    }
                case 5:
                    coverAlpha += 1
                    if coverAlpha >= 31 { coverAlpha = 31; subphase = 4 }
                default: break
                }
            case 4: timer = 0; phase = 5; return [.sound(archive: 1, entry: 0)]
            case 5:
                timer += 1
                if timer > 120 { timer = 0; phase = 0; stage = 3 }
            default: break
            }
        default: break
        }
        return []
    }

    private static func world(_ point: SIMD2<Int>) -> SIMD2<Float> {
        .init(Float(point.x - 96) / 96, Float(128 - point.y) / 96)
    }
    private static func fixed(_ value: Float) -> Int { Int((value * 4096).rounded(.toNearestOrAwayFromZero)) }
    private static func inside(_ point: SIMD2<Int>, x: ClosedRange<Int>, y: ClosedRange<Int>) -> Bool {
        x.contains(point.x) && y.contains(point.y)
    }
}
