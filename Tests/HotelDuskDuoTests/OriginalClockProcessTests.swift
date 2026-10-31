import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalClockProcessTests: XCTestCase {
    func testActiveClockMatchesEveryOriginalCounterFrame() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/clock-process-counters/clock-frames.csv")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("The original clock counter trace is not available")
        }
        let rows = try String(contentsOf: path, encoding: .utf8).split(separator: "\n").dropFirst().map { $0.split(separator: ",").map(String.init) }
        let start = try XCTUnwrap(rows.firstIndex(where: { $0[2] == "6" }))
        var clock = try OriginalClockProcess(label: "05:10PM", tick: XCTUnwrap(UInt64(rows[start][13])))
        var checked = 0
        for row in rows.dropFirst(start + 1) {
            guard row[2] != "8" else { break }
            let frame = try XCTUnwrap(Int(row[0]))
            clock.update(tick: try XCTUnwrap(UInt64(row[13])), draw: frame % 2 == 0)
            let actual = [clock.phase, clock.animation, clock.counter, clock.hold, clock.showsLabel ? 1 : 0,
                          clock.alpha, clock.hour, clock.minute, clock.second]
            let expected = try [2, 3, 4, 5, 7, 8, 9, 10, 11].map { try XCTUnwrap(Int(row[$0])) }
            XCTAssertEqual(actual, expected, "Original frame \(frame)")
            checked += 1
        }
        XCTAssertEqual(checked, 245)
    }

    func testMinuteRolloverAndCompletionUseClockUpdatesAndDraws() throws {
        var clock = try OriginalClockProcess(label: "12:00AM")
        XCTAssertEqual([clock.hour, clock.minute, clock.second], [11, 59, 58])
        XCTAssertFalse(clock.update(tick: 1, draw: false))
        XCTAssertTrue(clock.update(tick: 2, draw: false))
        XCTAssertTrue(clock.update(tick: 3, draw: false))
        XCTAssertEqual([clock.hour, clock.minute, clock.second], [0, 0, 0])
        XCTAssertTrue(clock.showsLabel)
        for frame in 0..<200 { clock.update(tick: 3, draw: frame % 2 == 0) }
        XCTAssertTrue(clock.isComplete)
        XCTAssertNil(clock.labelDraw)
    }

    @MainActor
    func testMorningClockTransitionUsesItsOriginalBitmap() throws {
        let clock = try OriginalClockProcess(label: "08:00AM")
        XCTAssertEqual(clock.bitmapName, "0800am")
        XCTAssertEqual([clock.hour, clock.minute, clock.second], [7, 59, 58])
        let renderer = try OriginalClockRenderer(process: clock, library: .bundled())
        XCTAssertEqual(try renderer.render(clock).width, 192)
    }

    func testMalformedClockLabelsStayExplicit() {
        for label in ["NONE", "13:10PM", "05:60PM", "5:10 PM"] {
            XCTAssertThrowsError(try OriginalClockProcess(label: label), label)
        }
    }

    @MainActor
    func testRendererKeepsTheClockFaceOpaque() throws {
        var clock = try OriginalClockProcess(label: "05:10PM")
        for frame in 1...240 { clock.update(tick: UInt64(frame / 60), draw: frame % 2 == 0) }
        let renderer = try OriginalClockRenderer(process: clock, library: .bundled())
        let image = try renderer.render(clock)
        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 256)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        let white = 90 * image.bytesPerRow + 80 * 4
        XCTAssertTrue(pixels[white..<(white + 3)].allSatisfy { $0 > 235 })
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            let path = URL(fileURLWithPath: directory).appendingPathComponent("clock-render.png")
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            let output = try XCTUnwrap(CGImageDestinationCreateWithURL(path as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(output, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(output))
        }
    }
}
