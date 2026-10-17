import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalMemoDrawingTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func capture(_ name: String) throws -> OriginalBytes {
        let path = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original memo drawing capture is unavailable") }
        return OriginalBytes(try Data(contentsOf: path))
    }

    func testSymbolsAndInkMatchOriginal() throws {
        let image = try OriginalMemoDrawingImage(paper: .torn, library: .bundled())
        var memo = try OriginalMemoDrawing(paper: .torn, randomInfo: 100, mask: image.mask)
        let entry = try capture("chapter-two-memo-torn-return/page15"), base = 0x2CE010
        XCTAssertEqual(memo.code, Int(try entry.u16(base + 0x18568)))
        XCTAssertEqual(memo.points.count, Int(try entry.u16(base + 0x18566)))
        for (i, point) in memo.points.enumerated() {
            XCTAssertEqual(point.position.x, Int(try entry.u16(base + 0x184E8 + i * 6)))
            XCTAssertEqual(point.position.y, Int(try entry.u16(base + 0x184EA + i * 6)))
            XCTAssertEqual(point.group, Int(try entry.u16(base + 0x184EC + i * 6)))
        }
        for (name, point) in [("dot", SIMD2(40,105)), ("line", SIMD2(70,125)),
                               ("diagonal", SIMD2(100,155)), ("outside", SIMD2(175,215))] {
            for _ in 0..<(name == "line" ? 1 : 2) { memo.touch(x: point.x, y: point.y) }
            let ram = try capture("chapter-two-memo-drawing-ink/\(name)")
            let pointer = Int(try ram.u32(base + 0x328)) - 0x02000000
            let expected = Array(try ram.range(pointer, 0xC000))
            XCTAssertEqual(memo.pixels.indices.filter { memo.pixels[$0] != expected[$0] }, [], name)
        }
        memo.release()
        let before = memo.pixels
        memo.touch(x: -1, y: 300)
        XCTAssertEqual(memo.pixels, before)
        memo.clear()
        XCTAssertTrue(memo.pixels.allSatisfy { $0 == 0 })
        let cleared = try capture("chapter-two-memo-drawing-clear/cleared")
        let pointer = Int(try cleared.u32(base + 0x328)) - 0x02000000
        XCTAssertEqual(memo.pixels, Array(try cleared.range(pointer, 0xC000)))
    }

    func testOriginalImage() throws {
        try compareImage(paper: .torn, capture: "chapter-two-memo-torn-return/page15")
    }

    func testJoinedImage() throws {
        try compareImage(paper: .joined, capture: "chapter-two-memo-joined-ready/finished")
    }

    func testWholeImage() throws {
        try compareImage(paper: .whole, capture: "chapter-two-crowbar-whole-memo/finished")
    }

    private func compareImage(paper: OriginalMemoDrawing.Paper, capture name: String) throws {
        let renderer = try OriginalMemoDrawingImage(paper: paper, library: .bundled())
        let randomInfo = try capture(name).u16(0x11018C + 0x13D4)
        let memo = try OriginalMemoDrawing(paper: paper, randomInfo: randomInfo, mask: renderer.mask)
        let image = try renderer.render(memo)
        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 256)
        let source = root.appendingPathComponent("extracted/reference/\(name)-bottom.ppm")
        guard FileManager.default.fileExists(atPath: source.path) else { throw XCTSkip("The original memo image is unavailable") }
        let capture = try Data(contentsOf: source), header = Data("P6\n256 192\n255\n".utf8)
        XCTAssertTrue(capture.starts(with: header))
        let rgb = Array(capture.dropFirst(header.count)), rgba = try XCTUnwrap(image.dataProvider?.data) as Data
        var differences: [Int] = []
        for y in 0..<220 { for x in 0..<192 { for c in 0..<3 {
            if rgba[(y * 192 + x) * 4 + c] >> 3 != rgb[(x * 256 + 255 - y) * 3 + c] >> 3 {
                differences.append((y * 192 + x) * 3 + c)
            }
        } } }
        XCTAssertEqual(differences.count, 0, "First differing channels: \(differences.prefix(20))")
        if let folder = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            let path = URL(fileURLWithPath: folder).appendingPathComponent("memo-drawing-\(paper).png")
            let output = try XCTUnwrap(CGImageDestinationCreateWithURL(path as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(output, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(output))
        }
    }

    func testAllTenCodesUseTheOriginalPointCounts() throws {
        let counts = [14, 17, 16, 17, 13, 17, 17, 15, 17, 17]
        for seed in UInt16(100)..<110 {
            let memo = try OriginalMemoDrawing(paper: .joined, randomInfo: seed, mask: Array(repeating: 0, count: 0xC000))
            XCTAssertEqual(memo.code, Int(seed) + 27)
            XCTAssertEqual(memo.points.count, counts[Int(seed) - 100])
            XCTAssertTrue(memo.points.allSatisfy { (0..<192).contains($0.position.x) && (0..<256).contains($0.position.y) })
        }
        XCTAssertThrowsError(try OriginalMemoDrawing(paper: .torn, randomInfo: 0, mask: []))
    }

    func testRandomValueIsStoredAndRetained() throws {
        var game = try OriginalGameState(snapshot: Data(repeating: 0, count: OriginalGameState.byteCount))
        XCTAssertEqual(game.initialisePuzzleRandomInfo(seed: 0xE657DCF9), 100)
        XCTAssertEqual(game.initialisePuzzleRandomInfo(seed: 0), 100)
        var restored = try OriginalGameState(snapshot: Data(game.bytes))
        XCTAssertEqual(restored.initialisePuzzleRandomInfo(seed: .max), 100)
    }

    func testToolbarClearAndQuit() throws {
        let renderer = try OriginalMemoDrawingImage(paper: .torn, library: .bundled())
        var process = try OriginalMemoDrawingProcess(drawing: .init(paper: .torn, randomInfo: 100, mask: renderer.mask))
        XCTAssertFalse(process.canQuit)
        for _ in 0..<29 { process.update() }
        XCTAssertEqual(process.toolbarY, 228)
        XCTAssertTrue(process.canQuit)
        process.update(touch: SIMD2(40, 105))
        XCTAssertTrue(process.drawing.pixels.contains(0xE0))
        process.clear()
        XCTAssertTrue(process.drawing.pixels.allSatisfy { $0 == 0 })
        process.quit()
        XCTAssertEqual(process.update(), [.stopSound, .fadeOut(60)])
        XCTAssertNil(process.result)
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
    }
}
