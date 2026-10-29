import XCTest
import ImageIO
@testable import HotelDuskDuoKit

@MainActor
final class OriginalSuitcaseContentsRendererTests: XCTestCase {
    func testRenderOverviewAndCompartments() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/chapter-two-suitcase-open/lower-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original suitcase state is unavailable") }
        let bytes = try Data(contentsOf: file)
        let game = try OriginalGameState(snapshot: bytes.subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        let renderer = try OriginalSuitcaseContentsRenderer()
        for (name, point) in [("overview", SIMD2<Float>?.none), ("upper", SIMD2<Float>(96, 100)), ("lower", SIMD2<Float>(96, 160))] {
            var process = OriginalSuitcaseContentsProcess(contents: renderer.initialContents)
            try process.update(game: game)
            try process.update(game: game)
            if let point {
                try process.update(pageTouch: point, game: game)
                try process.update(game: game)
            }
            let image = try renderer.render(process, game: game)
            XCTAssertEqual(image.width, 384)
            XCTAssertEqual(image.height, 512)
            if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                let url = URL(fileURLWithPath: directory).appendingPathComponent("suitcase_\(name).png")
                let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                XCTAssertTrue(CGImageDestinationFinalize(destination))
            }
        }
    }
}
