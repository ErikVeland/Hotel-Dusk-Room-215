import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class LosslessArtworkFormatTests: XCTestCase {
    func testLosslessWebPUsesTheSameSourceKeyAndLogicalDimensions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Data([255, 0, 0, 255, 0, 255, 0, 255])
        let key = "2x1-\(OriginalAnimationClip.digest(original))"
        let data = try XCTUnwrap(Data(base64Encoded: "UklGRiIAAABXRUJQVlA4TBYAAAAvA0AAAA+w//Mf8x8VFAIIgIImov/x"))
        try data.write(to: root.appendingPathComponent(key + ".webp"))
        let manifest: [String: Any] = ["formatVersion": 1, "scale": 2, "complete": true,
            "images": [["key": key, "width": 2, "height": 1, "file": key + ".webp",
                        "pngSHA256": OriginalAnimationClip.digest(data), "sources": ["fixture"]]]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: root.appendingPathComponent("ArtworkManifest.json"))
        let artwork = OriginalArtwork(resourceRoot: root)
        let image = try XCTUnwrap(artwork.enhancedImage(rgba: original, width: 2, height: 1))
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(image.height, 2)
        XCTAssertEqual(artwork.logicalSize(of: image), CGSize(width: 2, height: 1))
    }

    func testRealAnimationWebPDecodesIdenticallyToPNG() throws {
        guard let pngPath = ProcessInfo.processInfo.environment["HOTEL_DUSK_ARTWORK_CANDIDATE"],
              let webpPath = ProcessInfo.processInfo.environment["HOTEL_DUSK_WEBP_CANDIDATE"] else {
            throw XCTSkip("Set the PNG and WebP candidate paths for the real-frame comparison")
        }
        let clip = try OriginalAnimationLibrary.bundled().load(id: "Hy_hanas_")
        var decoder = OriginalAnimationDecoder(clip: clip)
        let frame = try XCTUnwrap(decoder.advance(loop: false))
        let pngArtwork = OriginalArtwork(resourceRoot: URL(fileURLWithPath: pngPath))
        let webpArtwork = OriginalArtwork(resourceRoot: URL(fileURLWithPath: webpPath))
        let png = try XCTUnwrap(pngArtwork.metalPixels(rgba: frame.rgba, width: frame.width, height: frame.height))
        let webp = try XCTUnwrap(webpArtwork.metalPixels(rgba: frame.rgba, width: frame.width, height: frame.height))
        XCTAssertEqual(png.width, webp.width)
        XCTAssertEqual(png.height, webp.height)
        XCTAssertEqual(png.data, webp.data)
    }
}
