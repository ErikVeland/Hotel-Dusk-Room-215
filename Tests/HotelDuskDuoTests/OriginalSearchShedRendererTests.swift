import CoreGraphics
import Foundation
import ImageIO
import Metal
import XCTest
@testable import HotelDuskDuoKit

final class OriginalSearchShedRendererTests: XCTestCase {
    @MainActor func testSourceBoxesRenderFromRecoveredTransforms() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal unavailable on this host") }
        let renderer = try OriginalSearchShedRenderer()
        let image = try renderer.render(OriginalSearchShedProcess())
        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 256)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertGreaterThan(pixels.enumerated().filter { $0.offset % 4 == 3 && $0.element > 0 }.count, 256)
        XCTAssertGreaterThan(Set(pixels).count, 16)
        if let output = ProcessInfo.processInfo.environment["HOTEL_DUSK_MODEL_PREVIEW"] {
            let url = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}
