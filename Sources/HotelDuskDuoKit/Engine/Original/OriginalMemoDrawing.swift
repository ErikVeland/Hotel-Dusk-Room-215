import Foundation

/**
 * Overlay 15 scratchpad, symbol positions and clipped ink for Chapter 2 process 34.
 */
public struct OriginalMemoDrawing: Equatable, Sendable {
    public enum Paper: Int, Sendable { case torn, joined, whole }
    public struct Point: Equatable, Sendable {
        public let position: SIMD2<Int>
        public let group: Int
    }
    public let paper: Paper
    public let code: Int
    public let points: [Point]
    public private(set) var pixels = [UInt8](repeating: 0, count: 0xC000)
    public private(set) var previousTouch: SIMD2<Int>?
    private let mask: [UInt8]

    public init(paper: Paper, randomInfo: UInt16, mask: [UInt8]) throws {
        guard randomInfo != 0, mask.count == 0xC000 else {
            throw OriginalDataError.invalid("Memo random value or drawing mask")
        }
        self.paper = paper
        self.mask = mask
        code = Int(randomInfo % 10) + 127
        let digits = [code / 100, code / 10 % 10, code % 10]
        points = digits.enumerated().flatMap { group, digit in
            Self.digits[digit].map { Point(position: $0 &+ SIMD2(0, group * 72 + 8), group: group) }
        }
    }

    public mutating func release() { previousTouch = nil }
    public mutating func clear() { pixels = Array(repeating: 0, count: 0xC000) }

    public func accepts(_ point: SIMD2<Int>) -> Bool {
        (0..<192).contains(point.x) && (0..<256).contains(point.y) && mask[point.x * 256 + 255 - point.y] != 1
    }

    /**
     * 0x021FE2DC samples the current point before drawing a three-pixel stroke.
     */
    public mutating func touch(x: Int, y: Int) {
        guard (0..<192).contains(x), (0..<256).contains(y) else { return }
        let point = SIMD2(x, y), previous = previousTouch ?? point
        previousTouch = point
        guard mask[x * 256 + 255 - y] != 1 else { return }
        line(from: previous, to: point)
    }

    /**
     * 0x021FDD94 excludes the line endpoint. Repeated held samples stamp that endpoint.
     */
    private mutating func line(from start: SIMD2<Int>, to end: SIMD2<Int>) {
        var a = start, b = end
        if a.x == b.x {
            if a.y == b.y { stamp(a) }
            else { for y in min(a.y, b.y)..<max(a.y, b.y) { stamp(SIMD2(a.x, y)) } }
            return
        }
        if a.x > b.x { swap(&a, &b) }
        let slope = Float(b.y - a.y) / Float(b.x - a.x)
        if slope > -1 && slope < 1 {
            for dx in 0..<(b.x - a.x) {
                stamp(SIMD2(a.x + dx, Int(Float(0.5) + (Float(a.y) + Float(dx) * slope))))
            }
        } else {
            if a.y > b.y { swap(&a, &b) }
            let inverse = Float(b.x - a.x) / Float(b.y - a.y)
            for dy in 0..<(b.y - a.y) {
                stamp(SIMD2(Int(Float(0.5) + (Float(a.x) + Float(dy) * inverse)), a.y + dy))
            }
        }
    }

    private mutating func stamp(_ point: SIMD2<Int>) {
        for dx in -1...1 { for dy in -1...1 {
            let x = min(191, max(0, point.x + dx)), y = min(255, max(0, point.y + dy))
            let index = x * 256 + 255 - y
            if mask[index] != 1 { pixels[index] = 0xE0 }
        } }
    }

    /**
     * Original digit geometry at 0x021FE50C, with counts at 0x021FE4F8.
     */
    private static let digits: [[SIMD2<Int>]] = [
        [.init(152,32), .init(96,8), .init(32,8), .init(16,40), .init(56,56), .init(128,56), .init(144,40)],
        [.init(128,16), .init(144,40), .init(16,24)],
        [.init(112,8), .init(144,32), .init(128,56), .init(88,48), .init(48,16), .init(24,8), .init(24,56)],
        [.init(120,8), .init(144,24), .init(136,56), .init(112,56), .init(80,24), .init(56,56), .init(16,16)],
        [.init(144,32), .init(64,8), .init(72,56), .init(96,40), .init(32,32)],
        [.init(136,48), .init(144,16), .init(88,8), .init(88,48), .init(64,56), .init(16,48), .init(24,16)],
        [.init(144,32), .init(88,16), .init(56,8), .init(24,24), .init(32,56), .init(72,56), .init(64,24)],
        [.init(112,16), .init(128,8), .init(136,56), .init(48,40)],
        [.init(128,56), .init(152,32), .init(120,8), .init(56,56), .init(24,32), .init(48,8), .init(112,56)],
        [.init(120,56), .init(144,40), .init(128,8), .init(96,24), .init(104,56), .init(16,16)]
    ]
}
