import CryptoKit
import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class OriginalTileAnimationTests: XCTestCase {
    private func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    func testAllOriginalOpeningFramesMatchIndependentDecoder() throws {
        let library = try OriginalTileAnimationLibrary.bundled()
        XCTAssertEqual(library.manifest.coverage.animations, 19)
        XCTAssertEqual(library.manifest.coverage.frames, 135)
        var frames = 0
        for record in library.manifest.animations {
            let clip = try library.load(path: record.source)
            var decoder = OriginalTileAnimationDecoder(clip: clip)
            XCTAssertEqual(clip.frameCount, record.frameCount)
            for reference in record.frames {
                let frame = try XCTUnwrap(decoder.advance())
                XCTAssertEqual(sha(clip.frames[reference.frame]), reference.decompressedSHA256, record.source)
                XCTAssertEqual(sha(decoder.tileData), reference.pixelsSHA256, record.source)
                XCTAssertEqual(sha(frame.rgba(transparentPaletteZero: false)), reference.rgbaSHA256, record.source)
                frames += 1
            }
            XCTAssertNil(try decoder.advance())
        }
        XCTAssertEqual(frames, 135)
    }
    func testCheckpointKeepsExactTilesThroughPauseAndReopen() throws {
        let library = try OriginalTileAnimationLibrary.bundled()
        let clip = try library.load(path: "show/op2/0829OPAni/05-05R.bin")
        var decoder = OriginalTileAnimationDecoder(clip: clip)
        _ = try decoder.seek(frame: 3)
        let saved = try JSONEncoder().encode(decoder.checkpoint())
        var restored = OriginalTileAnimationDecoder(clip: clip)
        try restored.restore(JSONDecoder().decode(OriginalTileAnimationCheckpoint.self, from: saved))
        XCTAssertEqual(try restored.currentBitmap().decodedPayload, try decoder.currentBitmap().decodedPayload)
        XCTAssertEqual(try restored.advance()?.decodedPayload, try decoder.advance()?.decodedPayload)
        var wrong = OriginalTileAnimationDecoder(clip: try library.load(path: "show/op2/0829OPAni/06-03R.bin"))
        XCTAssertThrowsError(try wrong.restore(decoder.checkpoint()))
        XCTAssertThrowsError(try OriginalNintendoLZ.decode10(Data([0x10, 3, 0, 0, 0x80, 0, 0])))
        XCTAssertThrowsError(try OriginalTileAnimationClip(data: Data(repeating: 0, count: 16)))
    }
}
