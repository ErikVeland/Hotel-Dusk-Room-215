import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import XCTest
@testable import HotelDuskDuoKit

final class OriginalArtworkUpscaleTests: XCTestCase {
    private func fixture(complete: Bool = true) throws -> (OriginalArtwork, URL, Data) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let rgba = Data([255, 0, 0, 255, 0, 255, 0, 255])
        let key = "2x1-\(OriginalAnimationClip.digest(rgba))"
        let pixels = Data(Array(repeating: [UInt8]([255, 0, 0, 255, 255, 0, 0, 255,
                                                0, 255, 0, 255, 0, 255, 0, 255]), count: 2).flatMap { $0 })
        let image = try XCTUnwrap(OriginalArtwork(resourceRoot: nil).image(rgba: pixels, width: 4, height: 2))
        let url = root.appendingPathComponent(key + ".png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let data = try Data(contentsOf: url)
        let manifest: [String: Any] = ["formatVersion": 1, "scale": 2, "complete": complete,
            "images": [["key": key, "width": 2, "height": 1, "file": key + ".png",
                        "pngSHA256": OriginalAnimationClip.digest(data), "sources": ["fixture"]]]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: root.appendingPathComponent("ArtworkManifest.json"))
        return (OriginalArtwork(resourceRoot: root), root, rgba)
    }

    func testRotatedEnhancedImagePreservesSourceGeometryAndDirection() throws {
        let (artwork, root, rgba) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let image = try XCTUnwrap(artwork.image(rgba: rgba, width: 2, height: 1, rotated: true))
        XCTAssertEqual(image.width, 2)
        XCTAssertEqual(image.height, 4)
        XCTAssertEqual(artwork.logicalSize(of: image), CGSize(width: 1, height: 2))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(data: storage.baseAddress, width: image.width,
                height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        XCTAssertEqual(Array(bytes.prefix(4)), [0, 255, 0, 255])
        XCTAssertEqual(Array(bytes.suffix(4)), [255, 0, 0, 255])
    }

    func testIncompletePackUsesOriginalPixels() throws {
        let (artwork, root, rgba) = try fixture(complete: false)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(artwork.enhancedImage(rgba: rgba, width: 2, height: 1))
        let image = try XCTUnwrap(artwork.image(rgba: rgba, width: 2, height: 1))
        XCTAssertEqual(image.width, 2)
        XCTAssertEqual(image.height, 1)
    }

    func testDamagedPackDoesNotReplaceOriginalArtwork() throws {
        let (artwork, root, rgba) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let png = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: nil).first { $0.pathExtension == "png" })
        try Data("damaged".utf8).write(to: png)
        XCTAssertNil(artwork.enhancedImage(rgba: rgba, width: 2, height: 1))
        XCTAssertEqual(try XCTUnwrap(artwork.image(rgba: rgba, width: 2, height: 1)).width, 2)
    }

    func testPuzzleMaskCutsEnhancedPixelsAtOriginalCoordinates() throws {
        let (artwork, root, rgba) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let mask = Data([255, 0, 0, 0, 0, 255, 0, 255])
        let image = try XCTUnwrap(artwork.maskedImage(rgba: rgba, width: 2, height: 1, maskRGBA: mask))
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(image.height, 2)
        let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertEqual(pixels[3], 0)
        XCTAssertEqual(pixels[7], 0)
        XCTAssertEqual(pixels[11], 255)
        XCTAssertEqual(pixels[15], 255)
    }

    func testTexturesUseDoubleResolutionWithoutChangingSourcePixels() throws {
        let library = try OriginalTextureLibrary.bundled()
        let record = try XCTUnwrap(library.manifest.textures.first {
            $0.status == "decoded" && ($0.storedWidth ?? 0) > 32 && ($0.storedHeight ?? 0) > 32
        })
        let texture = try library.load(path: record.source)
        let originalHash = SHA256.hash(data: texture.rgba).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(originalHash, record.rgbaSHA256)
        let image = try XCTUnwrap(texture.makeCGImage())
        XCTAssertEqual(image.width, texture.storedWidth * 2)
        XCTAssertEqual(image.height, texture.storedHeight * 2)
        XCTAssertEqual(texture.rgba.count, texture.storedWidth * texture.storedHeight * 4)
    }
}
