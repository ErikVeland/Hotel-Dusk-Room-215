import CryptoKit
import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class OriginalTextureTests: XCTestCase {
    private func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testEveryRecoveredTextureMatchesIndependentPythonDecoder() throws {
        let library = try OriginalTextureLibrary.bundled()
        XCTAssertEqual(library.manifest.coverage.textures, 2957)
        XCTAssertEqual(library.manifest.coverage.decoded, 2919)
        XCTAssertEqual(library.manifest.coverage.unsupported, 38)
        var checked = 0
        for record in library.manifest.textures where record.status == "decoded" {
            let texture = try library.load(path: record.source)
            XCTAssertEqual(texture.mode, record.mode, record.source)
            XCTAssertEqual(texture.storedWidth, record.storedWidth, record.source)
            XCTAssertEqual(texture.storedHeight, record.storedHeight, record.source)
            XCTAssertEqual(sha(texture.decodedPayload), record.decodedSHA256, record.source)
            XCTAssertEqual(sha(texture.originalPaletteData), record.paletteSHA256, record.source)
            XCTAssertEqual(sha(texture.originalPixelData), record.pixelDataSHA256, record.source)
            XCTAssertEqual(sha(texture.rgba), record.rgbaSHA256, record.source)
            checked += 1
        }
        XCTAssertEqual(checked, 2919)
    }

    func testPaddedStorageRetainsOriginalDimensions() throws {
        let texture = try OriginalTextureLibrary.bundled().load(path: "map/R109/R109_s03/r109_paper01.dtx")
        XCTAssertEqual(texture.allocatedWidth, 32)
        XCTAssertEqual(texture.allocatedHeight, 64)
        XCTAssertEqual(texture.logicalWidth, 32)
        XCTAssertEqual(texture.logicalHeight, 44)
        XCTAssertEqual(texture.storedWidth, 32)
        XCTAssertEqual(texture.storedHeight, 64)
        XCTAssertEqual(texture.originalPixelData.count, 2048)
    }

    func testUnknownCompressedCropsDoNotProduceReplacementArt() throws {
        let library = try OriginalTextureLibrary.bundled()
        for record in library.manifest.textures where record.status == "unsupported" {
            XCTAssertThrowsError(try library.load(path: record.source), record.source)
        }
        XCTAssertThrowsError(try OriginalTexture(data: Data(repeating: 0, count: 31)))
    }
}
