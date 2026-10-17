import XCTest
import ImageIO
@testable import HotelDuskDuoKit

@MainActor
final class OriginalHangerRendererTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testCutCoversMatchOriginalVertices() throws {
        for (touch, capture) in [(SIMD2<Float>(45, 148), "cut"), (.init(45, 138), "upper"), (.init(145, 138), "upper-right")] {
            let file = root.appendingPathComponent("extracted/reference/chapter-two-hanger-\(capture)/first_cut-ram.bin")
            guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original cut-cover capture is unavailable") }
            let bytes = OriginalBytes(try Data(contentsOf: file))
            var cuts = OriginalHangerCuts()
            let cut = try XCTUnwrap(cuts.cut(at: touch))
            let points = OriginalHangerRenderer.cutCover(cut)
            for (index, point) in points.enumerated() {
                for axis in 0..<3 {
                    XCTAssertEqual(point[axis], Int32(bitPattern: try bytes.u32(0x258850 + 0x898 + index * 12 + axis * 4)), capture)
                }
            }
        }
    }

    func testRenderHangerAndCuttingStages() throws {
        let renderer = try OriginalHangerRenderer()
        var puzzle = OriginalHangerProcess()
        func capture(_ name: String) throws {
            let image = try renderer.render(puzzle)
            XCTAssertEqual(image.width, 192)
            XCTAssertEqual(image.height, 256)
            if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                let url = URL(fileURLWithPath: directory).appendingPathComponent("hanger_\(name).png")
                let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                XCTAssertTrue(CGImageDestinationFinalize(destination))
            }
        }
        puzzle.update()
        try capture("initial")
        puzzle.update(pageTouch: SIMD2(45, 148))
        for _ in 0..<63 { puzzle.update() }
        XCTAssertEqual(puzzle.stage, 3)
        try capture("pliers_open")
        for _ in 0..<30 { puzzle.update() }
        try capture("pliers_closed")
        for _ in 0..<160 { puzzle.update() }
        XCTAssertEqual(puzzle.phase, 1)
        try capture("first_cut")
        puzzle.update(pageTouch: SIMD2(145, 148))
        for _ in 0..<96 { puzzle.update() }
        try capture("second_cut")
    }

    func testInitialWallPixelsMatchOriginal() throws {
        let file = root.appendingPathComponent("extracted/reference/chapter-two-hanger-use/puzzle-bottom.ppm")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original hanger image is unavailable") }
        let reference = try Data(contentsOf: file), header = Data("P6\n256 192\n255\n".utf8)
        XCTAssertTrue(reference.starts(with: header))
        let pixels = Array(reference.dropFirst(header.count))
        let image = try OriginalHangerRenderer().render(OriginalHangerProcess())
        let rgba = try XCTUnwrap(image.dataProvider?.data) as Data
        for point in [SIMD2(10, 10), .init(70, 70), .init(140, 70), .init(50, 200), .init(170, 200)] {
            let original = (point.x * 256 + 255 - point.y) * 3
            let native = (point.y * 192 + point.x) * 4
            for channel in 0..<3 {
                XCTAssertEqual(rgba[native + channel], pixels[original + channel],
                    "Page \(point), native \(Array(rgba[native..<native + 3])), original \(Array(pixels[original..<original + 3]))")
            }
        }
    }
}
