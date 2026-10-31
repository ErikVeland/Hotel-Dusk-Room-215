import XCTest
import ImageIO
@testable import HotelDuskDuoKit

@MainActor
final class OriginalThickWireRendererTests: XCTestCase {
    func testWireIsVisibleInInsertionView() throws {
        let puzzle = OriginalThinWireProcess(variant: .thick)
        let image = try OriginalThinWireRenderer(variant: .thick).render(puzzle)
        let bytes = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertEqual(image.width, 768)
        XCTAssertEqual(image.height, 1024)
        for y in [215, 225, 235, 245] {
            let wire = Int(bytes[(y * 192 + 110) * 4])
            let background = Int(bytes[(y * 192 + 107) * 4])
            XCTAssertGreaterThan(abs(wire - background), 10, "Wire contrast at row \(y)")
        }
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let url = URL(fileURLWithPath: directory).appendingPathComponent("thick_wire_insertion.png")
            let output = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(output, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(output))
        }
    }
}
