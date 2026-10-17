import Foundation

/**
 * Notebook pages and ink from 0x020797CC, 0x02079CC8 and 0x02078DA8.
 */
public struct OriginalNotebook: Sendable {
    public static let packedSize = 0x1800
    public private(set) var page = 0
    public private(set) var pages: [[UInt8]]
    public private(set) var pixels: [UInt8]
    public private(set) var erasing = false
    private let locked: [Bool]
    private var undoPixels: [UInt8]
    private var previousTouch: SIMD2<Int>?

    public var canEdit: Bool { page < 3 && !locked[page] }
    public var pageCount: Int { pages.count }

    public init(game: OriginalGameState, load: (String) throws -> Data) throws {
        guard game.bytes[0x13CC..<0x13D0].allSatisfy({ $0 == 0 }),
              game.bytes[0x13D8..<0x13DA].allSatisfy({ $0 == 0 }) else {
            throw OriginalDataError.unsupported("Mila and apple notebook page composition")
        }
        pages = (0..<3).map { Array(game.bytes[(0x3558 + $0 * Self.packedSize)..<(0x3558 + ($0 + 1) * Self.packedSize)]) }
        locked = (0..<3).map { game.bytes[0x13C8 + $0] != 0 }
        for index in 0..<16 where game.bytes[0x87B + index / 8] & (1 << (index % 8)) != 0 {
            let data = try load(String(format: "system/note/memo/memo%02d_M.bin", index + 1))
            guard data.count == Self.packedSize else { throw OriginalDataError.invalid("Notebook drawing length") }
            pages.append(Array(data))
        }
        pixels = locked[0] ? Array(repeating: 0, count: 0xC000) : Self.unpack(pages[0])
        undoPixels = pixels
    }

    /**
     * 0x02078EB4 expands each byte from its least significant bit.
     */
    public static func unpack(_ packed: [UInt8]) -> [UInt8] {
        packed.flatMap { byte in (0..<8).map { (byte >> $0) & 1 } }
    }

    public mutating func storePage() {
        guard canEdit else { return }
        pages[page] = stride(from: 0, to: pixels.count, by: 8).map { start in
            (0..<8).reduce(UInt8(0)) { $0 | (pixels[start + $1] << $1) }
        }
    }

    public mutating func turnPage(forward: Bool) {
        release()
        storePage()
        page = (page + (forward ? 1 : pageCount - 1)) % pageCount
        if page >= 3 || !locked[page] { pixels = Self.unpack(pages[page]) }
        undoPixels = pixels
    }

    public mutating func toggleEraser() { release(); erasing.toggle() }

    public mutating func clear() {
        guard canEdit else { return }
        release()
        if pixels.contains(1) {
            undoPixels = pixels
            pixels = Array(repeating: 0, count: 0xC000)
        }
    }

    /**
     * 0x020788B0 swaps both buffers, so another press restores the edit.
     */
    public mutating func undo() {
        guard canEdit else { return }
        release()
        swap(&pixels, &undoPixels)
    }

    public mutating func release() { previousTouch = nil }

    /**
     * 0x020784AC starts a stroke without drawing until the next held sample.
     */
    public mutating func touch(x: Int, y: Int) {
        guard canEdit, (0..<192).contains(x), (0..<256).contains(y) else { return }
        let point = SIMD2(x, y)
        if let previousTouch { line(from: previousTouch, to: point) }
        else { undoPixels = pixels }
        previousTouch = point
    }

    private mutating func line(from start: SIMD2<Int>, to end: SIMD2<Int>) {
        var a = start, b = end
        if a.x == b.x {
            if a.y == b.y { stamp(x: a.x, y: a.y) }
            else { for y in min(a.y, b.y)..<max(a.y, b.y) { stamp(x: a.x, y: y) } }
            return
        }
        if a.x > b.x { swap(&a, &b) }
        let slope = Float(b.y - a.y) / Float(b.x - a.x)
        if slope >= -1 && slope <= 1 {
            for dx in 0...(b.x - a.x) {
                stamp(x: a.x + dx, y: Int(0.5 + (Float(a.y) + Float(dx) * slope)))
            }
        } else {
            if a.y > b.y { swap(&a, &b) }
            let inverse = Float(b.x - a.x) / Float(b.y - a.y)
            for dy in 0...(b.y - a.y) {
                stamp(x: Int(0.5 + (Float(a.x) + Float(dy) * inverse)), y: a.y + dy)
            }
        }
    }

    private mutating func stamp(x: Int, y: Int) {
        let offsets = erasing ? -2...2 : 0...1
        for dx in offsets { for dy in offsets {
            let px = x + dx, py = y + dy
            guard (4..<188).contains(px), (0..<256).contains(py) else { continue }
            let rawX = 255 - py
            let offset = (px / 8) * 0x800 + (rawX / 8) * 64 + (px % 8) * 8 + rawX % 8
            pixels[offset] = erasing ? 0 : 1
        } }
    }
}
