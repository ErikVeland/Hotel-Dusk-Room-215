import XCTest
@testable import HotelDuskDuoKit

final class OriginalBitmapTests: XCTestCase {
    func testEveryRecoveredBitmapMatchesSourcePixels() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let images = library.manifest.images.filter { $0.status == "decoded" }
        XCTAssertGreaterThan(images.count, 100)
        for record in images {
            let image = try library.load(path: record.source)
            XCTAssertEqual(image.width, record.width, record.source)
            XCTAssertEqual(image.height, record.height, record.source)
            XCTAssertEqual(image.paletteCount, record.paletteCount, record.source)
            XCTAssertEqual(OriginalAnimationClip.digest(image.decodedPayload), record.decodedSHA256, record.source)
            XCTAssertEqual(OriginalAnimationClip.digest(image.rgba(transparentPaletteZero: false)), record.rgbaSHA256, record.source)
        }
    }

    func testOpeningRadioRetainsSourceOrientationAndCallerTransparency() throws {
        let image = try OriginalBitmapLibrary.bundled().load(path: "show/op2/0829OPImg/06-01L.bin")
        XCTAssertEqual(image.width, 256)
        XCTAssertEqual(image.height, 192)
        let opaque = [UInt8](image.rgba(transparentPaletteZero: false))
        let overlay = [UInt8](image.rgba(transparentPaletteZero: true))
        for (pixel, index) in image.indices.enumerated() {
            XCTAssertEqual(opaque[pixel * 4 + 3], 255)
            XCTAssertEqual(overlay[pixel * 4 + 3], index == 0 ? 0 : 255)
            XCTAssertEqual(Array(opaque[pixel * 4..<pixel * 4 + 3]), Array(overlay[pixel * 4..<pixel * 4 + 3]))
        }
        XCTAssertNotNil(image.makeCGImage(transparentPaletteZero: false))
        XCTAssertThrowsError(try OriginalBitmap(data: image.decodedPayload.dropLast()))
    }
}
