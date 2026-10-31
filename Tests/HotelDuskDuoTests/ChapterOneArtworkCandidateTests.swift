import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class ChapterOneArtworkCandidateTests: XCTestCase {
    func testIsolatedCandidateLoadsSourceTextureAndAnimationAtTheirOwnScales() throws {
        guard let path = ProcessInfo.processInfo.environment["HOTEL_DUSK_ARTWORK_CANDIDATE"] else {
            throw XCTSkip("Set HOTEL_DUSK_ARTWORK_CANDIDATE to the isolated verification pack")
        }
        let artwork = OriginalArtwork(resourceRoot: URL(fileURLWithPath: path))
        let texture = try OriginalTextureLibrary.bundled().load(path: "map/R213/R213/door.dtx")
        let enhancedTexture = try XCTUnwrap(artwork.enhancedImage(rgba: texture.rgba,
            width: texture.storedWidth, height: texture.storedHeight))
        XCTAssertEqual(enhancedTexture.width, texture.storedWidth * 4)
        XCTAssertEqual(enhancedTexture.height, texture.storedHeight * 4)

        let clip = try OriginalAnimationLibrary.bundled().load(id: "Hy_hanas_")
        var decoder = OriginalAnimationDecoder(clip: clip)
        let frame = try XCTUnwrap(decoder.advance(loop: false))
        let enhancedFrame = try XCTUnwrap(artwork.enhancedImage(rgba: frame.rgba,
            width: frame.width, height: frame.height))
        XCTAssertEqual(enhancedFrame.width, frame.width * 8)
        XCTAssertEqual(enhancedFrame.height, frame.height * 8)
        XCTAssertEqual(artwork.logicalSize(of: enhancedFrame), CGSize(width: frame.width, height: frame.height))
    }
}
