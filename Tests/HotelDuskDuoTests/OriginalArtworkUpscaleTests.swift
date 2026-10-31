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

    func testManifestAllowsRetinaAnimationAlongsideFourTimesTextures() throws {
        let (oldArtwork, root, rgba) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let key = "2x1-\(OriginalAnimationClip.digest(rgba))"
        let pixels = Data(Array(repeating: [UInt8](repeating: 255, count: 16 * 4), count: 8).flatMap { $0 })
        let image = try XCTUnwrap(oldArtwork.image(rgba: pixels, width: 16, height: 8))
        let url = root.appendingPathComponent(key + ".png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let manifest: [String: Any] = ["formatVersion": 1, "scale": 4, "complete": true,
            "images": [["key": key, "width": 2, "height": 1, "scale": 8, "file": key + ".png",
                        "pngSHA256": OriginalAnimationClip.digest(try Data(contentsOf: url)), "sources": ["fixture"]]]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: root.appendingPathComponent("ArtworkManifest.json"))
        let artwork = OriginalArtwork(resourceRoot: root)
        let retina = try XCTUnwrap(artwork.enhancedImage(rgba: rgba, width: 2, height: 1))
        XCTAssertEqual(retina.width, 16)
        XCTAssertEqual(retina.height, 8)
        XCTAssertEqual(artwork.logicalSize(of: retina), CGSize(width: 2, height: 1))
    }

    func testMetalTextureUploadKeepsRowOrderAndAlpha() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let rgba = Data([255, 0, 0, 255, 0, 0, 255, 128])
        let key = "1x2-\(OriginalAnimationClip.digest(rgba))"
        let pixels = Data([255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255,
                           0, 0, 255, 128, 0, 0, 255, 128, 0, 0, 255, 128, 0, 0, 255, 128])
        let image = try XCTUnwrap(OriginalArtwork(resourceRoot: nil).image(rgba: pixels, width: 2, height: 4))
        let url = root.appendingPathComponent(key + ".png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let manifest: [String: Any] = ["formatVersion": 1, "scale": 2, "complete": true,
            "images": [["key": key, "width": 1, "height": 2, "file": key + ".png",
                        "pngSHA256": OriginalAnimationClip.digest(try Data(contentsOf: url)), "sources": ["fixture"]]]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: root.appendingPathComponent("ArtworkManifest.json"))
        let artwork = OriginalArtwork(resourceRoot: root)
        let upload = try XCTUnwrap(artwork.metalPixels(rgba: rgba, width: 1, height: 2))
        XCTAssertEqual(upload.width, 2)
        XCTAssertEqual(upload.height, 4)
        let data = [UInt8](upload.data)
        XCTAssertEqual(Array(data[0..<4]), [255, 0, 0, 255])
        XCTAssertEqual(Array(data[16..<20]), [0, 0, 255, 128])
    }

    func testPageCompositeKeepsLogicalCoordinatesAtFourTimesResolution() throws {
        let context = try XCTUnwrap(OriginalArtwork.pageContext(width: 2, height: 1))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        let image = try XCTUnwrap(context.makeImage())
        XCTAssertEqual(image.width, 8)
        XCTAssertEqual(image.height, 4)
        let data = try XCTUnwrap(image.dataProvider?.data) as Data
        XCTAssertGreaterThan(data[0], data[1] * 2)
        XCTAssertGreaterThan(data[17], data[16] * 2)
        XCTAssertEqual(data[3], 255)
        XCTAssertEqual(data[19], 255)
    }

    func testTexturesUseFourTimesResolutionWithoutChangingSourcePixels() throws {
        let library = try OriginalTextureLibrary.bundled()
        let record = try XCTUnwrap(library.manifest.textures.first {
            $0.status == "decoded" && ($0.storedWidth ?? 0) > 32 && ($0.storedHeight ?? 0) > 32
        })
        let texture = try library.load(path: record.source)
        let originalHash = SHA256.hash(data: texture.rgba).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(originalHash, record.rgbaSHA256)
        guard let image = OriginalArtwork.shared.enhancedImage(rgba: texture.rgba,
            width: texture.storedWidth, height: texture.storedHeight) else {
            throw XCTSkip("The complete artwork pack is not installed for this source texture")
        }
        XCTAssertEqual(image.width, texture.storedWidth * 4)
        XCTAssertEqual(image.height, texture.storedHeight * 4)
        XCTAssertEqual(texture.rgba.count, texture.storedWidth * texture.storedHeight * 4)
    }
}
