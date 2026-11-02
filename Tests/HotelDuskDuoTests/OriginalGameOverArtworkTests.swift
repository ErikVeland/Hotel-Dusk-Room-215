import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalGameOverArtworkTests: XCTestCase {
    func testFinalGameOverBackgroundsLoadAsPortraitPages() throws {
        let images = try OriginalGameOverImages(library: OriginalBitmapLibrary.bundled())

        XCTAssertEqual(images.upper.artworkWidth, 192)
        XCTAssertEqual(images.upper.artworkHeight, 256)
        XCTAssertEqual(images.lower.artworkWidth, 192)
        XCTAssertEqual(images.lower.artworkHeight, 256)
        XCTAssertEqual(images.retrySelectedLower.artworkWidth, 192)
        XCTAssertEqual(images.retrySelectedLower.artworkHeight, 256)
        XCTAssertEqual(images.titleSelectedLower.artworkWidth, 192)
        XCTAssertEqual(images.titleSelectedLower.artworkHeight, 256)
    }
}
