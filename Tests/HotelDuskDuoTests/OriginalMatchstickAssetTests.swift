import XCTest
@testable import HotelDuskDuoKit

final class OriginalMatchstickAssetTests: XCTestCase {
    func testBundledStickTextureLoadsForTheNativeRenderer() throws {
        let texture = try OriginalBitmapLibrary.bundled().loadTexture(path: "trick/sticktex.bin")

        XCTAssertEqual(texture.storedWidth, 8)
        XCTAssertEqual(texture.storedHeight, 40)
        XCTAssertFalse(texture.rgba.isEmpty)
    }
}
