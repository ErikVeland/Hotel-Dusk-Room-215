import Foundation

/**
 * Notebook pages and ink from 0x020797CC, 0x02079CC8 and 0x02078DA8.
 */
public struct OriginalNotebook: Sendable {
    struct InkLayer: Sendable {
        let pixels: [UInt8]
        let offset: Int
        let rows: Int
    }

    public static let packedSize = 0x1800
    public private(set) var page = 0
    public private(set) var pages: [[UInt8]]
    public private(set) var pixels: [UInt8]
    private var inkLayers: [[InkLayer]]
    public private(set) var erasing = false
    private let locked: [Bool]
    private var undoPixels: [UInt8]
    private var previousTouch: SIMD2<Int>?

    public var canEdit: Bool { page < 3 && !locked[page] }
    public var pageCount: Int { pages.count }
    var currentInkLayers: [InkLayer] { inkLayers[page] }

    /// The first available memo that has not been read. The notebook opens at its page.
    public let unreadMemo: Int?

    /// Tile offsets read through the notebook's 0x02079CC0 table.
    private static let applePageSlots = [(x: 16, y: 14), (x: 4, y: 18), (x: 14, y: 24),
                                         (x: 8, y: 5), (x: 1, y: 2)]

    public init(game: OriginalGameState, load: (String) throws -> Data) throws {
        pages = (0..<3).map { Array(game.bytes[(0x3558 + $0 * Self.packedSize)..<(0x3558 + ($0 + 1) * Self.packedSize)]) }
        inkLayers = Array(repeating: [], count: 3)
        locked = (0..<3).map { game.bytes[0x13C8 + $0] != 0 }
        for index in 0..<16 where game.bytes[0x87B + index / 8] & (1 << (index % 8)) != 0 {
            let data = try load(String(format: "system/note/memo/memo%02d_M.bin", index + 1))
            guard data.count == Self.packedSize else { throw OriginalDataError.invalid("Notebook drawing length") }
            pages.append(Array(data))
            inkLayers.append([])
        }
        /**
         * 0x020797CC packs available Mila memos top-down onto shared pages. A page breaks
         * at 256 rows or when a later memo's group differs from the page's second memo onward.
         */
        var unread: Int?, startPage = 0, used = 0, group: Int?, pageStarted = false
        for index in 0..<32 where game.memoAvailable(index) {
            let data = Array(try load(String(format: "system/note/memo/mila%02d_M.bin", index + 1)))
            guard data.count == 0x10 + Self.packedSize, data[0..<4] == [0x4D, 0x49, 0x4C, 0x41] else {
                throw OriginalDataError.invalid("Mila memo \(index + 1)")
            }
            let rows = Int(data[4])
            if group == nil { group = Int(data[5]) }
            if !pageStarted || used + rows > 0x100 || group != Int(data[5]) {
                pages.append(Array(repeating: 0, count: Self.packedSize))
                inkLayers.append([])
                pageStarted = true
                used = 0
                group = nil
            }
            // 0x0207A458 copies the bottom `rows` bytes of each 8-pixel column.
            guard rows % 8 == 0, used % 8 == 0 else { throw OriginalDataError.invalid("Mila memo rows") }
            for column in 0..<24 {
                let source = 0x10 + column * 0x100 + 0x100 - rows
                let target = column * 0x100 + 0x100 - used - rows
                pages[pages.count - 1].replaceSubrange(target..<(target + rows), with: data[source..<(source + rows)])
            }
            inkLayers[inkLayers.count - 1].append(InkLayer(
                pixels: Self.unpack(Array(data[0x10...])), offset: used, rows: rows))
            used += rows
            if unread == nil, !game.memoRead(index) {
                unread = index
                startPage = pages.count - 1
            }
        }
        if game.appleNotebookPageMask != 0 {
            let path = "system/note/memo/appmem_M.bin"
            let data = try load(path)
            guard data.count == Self.packedSize else { throw OriginalDataError.invalid("Apple notebook page length") }
            var overview = Array(data)
            for index in Self.applePageSlots.indices where game.appleNotebookPageMask & (1 << index) == 0 {
                let slot = Self.applePageSlots[index]
                let start = slot.x * 0x100 + slot.y * 8
                for row in 0..<5 {
                    let lowerBound = start + row * 0x100
                    let range = lowerBound..<(lowerBound + 0x28)
                    guard range.upperBound <= overview.count else {
                        throw OriginalDataError.invalid("Apple notebook page slot")
                    }
                    overview.replaceSubrange(range, with: repeatElement(0, count: range.count))
                }
            }
            pages.append(overview)
            inkLayers.append([])

            for index in 1..<Self.applePageSlots.count where game.appleNotebookPageMask & (1 << index) != 0 {
                let path = String(format: "system/note/memo/apppic%d_M.bin", index + 1)
                let data = try load(path)
                guard data.count == Self.packedSize else { throw OriginalDataError.invalid("Apple notebook drawing length") }
                pages.append(Array(data))
                inkLayers.append([])
            }
        }
        unreadMemo = unread
        page = startPage
        pixels = page < 3 && locked[page] ? Array(repeating: 0, count: 0xC000) : Self.unpack(pages[page])
        undoPixels = pixels
    }

    /**
     * 0x02078EB4 expands each byte from its least significant bit.
     */
    public static func unpack(_ packed: [UInt8]) -> [UInt8] {
        packed.flatMap { byte in (0..<8).map { (byte >> $0) & 1 } }
    }

    public mutating func replaceInk(packed: Data) throws {
        guard canEdit, packed.count == Self.packedSize else {
            throw OriginalDataError.invalid("Notebook ink")
        }
        release()
        undoPixels = pixels
        pixels = Self.unpack(Array(packed))
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
