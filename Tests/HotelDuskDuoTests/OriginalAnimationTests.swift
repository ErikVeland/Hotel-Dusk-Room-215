import CryptoKit
import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class OriginalAnimationTests: XCTestCase {
    private func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testEveryRecoveredFrameMatchesIndependentPythonDecoder() throws {
        let library = try OriginalAnimationLibrary.bundled()
        XCTAssertEqual(library.manifest.coverage.animations, 347)
        XCTAssertEqual(library.manifest.coverage.decodedAnimations, 346)
        XCTAssertEqual(library.manifest.coverage.decodedFrames, 3021)
        var verified = 0
        for record in library.manifest.animations where record.status == "decoded" {
            let clip = try library.load(id: record.id)
            var decoder = OriginalAnimationDecoder(clip: clip)
            XCTAssertEqual(clip.frameCount, record.frameCount, record.id)
            for reference in record.frames {
                let frame = try XCTUnwrap(decoder.advance(loop: false), record.id)
                XCTAssertEqual(frame.frameIndex, reference.index, record.id)
                XCTAssertEqual(sha(frame.originalIndexData), reference.indexSHA256, "\(record.id) frame \(reference.index)")
                XCTAssertEqual(sha(frame.originalPaletteData), reference.paletteSHA256, record.id)
                XCTAssertEqual(sha(frame.rgba), reference.rgbaSHA256, "\(record.id) frame \(reference.index)")
                verified += 1
            }
            XCTAssertNil(try decoder.advance(loop: false))
        }
        XCTAssertEqual(verified, 3021)
    }

    func testLoopUsesOriginalRestartAndCheckpointPreservesDeltaBuffer() throws {
        let clip = try OriginalAnimationLibrary.bundled().load(id: "Hy_hanas_")
        XCTAssertEqual(clip.clearWord, 30)
        XCTAssertEqual(clip.loopStartIndex, 8)
        var uninterrupted = OriginalAnimationDecoder(clip: clip)
        for _ in 0..<clip.frameCount { _ = try uninterrupted.advance() }
        let checkpoint = uninterrupted.checkpoint()
        let encoded = try JSONEncoder().encode(checkpoint)
        var restored = OriginalAnimationDecoder(clip: clip)
        try restored.restore(JSONDecoder().decode(OriginalAnimationCheckpoint.self, from: encoded))
        for _ in 0..<9 {
            let a = try XCTUnwrap(uninterrupted.advance())
            let b = try XCTUnwrap(restored.advance())
            XCTAssertEqual(a.rgba, b.rgba)
            XCTAssertEqual(a.originalIndexData, b.originalIndexData)
            XCTAssertEqual(uninterrupted.frameIndex, restored.frameIndex)
        }
        XCTAssertEqual(uninterrupted.loopCount, 3)
        var other = OriginalAnimationDecoder(clip: try OriginalAnimationLibrary.bundled().load(id: "Dn_mae_"))
        XCTAssertThrowsError(try other.restore(checkpoint))
    }

    func testUnknownBraceletStreamFailsWithoutSubstituteFrames() throws {
        let library = try OriginalAnimationLibrary.bundled()
        XCTAssertThrowsError(try library.load(id: "Br_bracelet_")) { error in
            guard case OriginalAnimationError.unsupported = error else {
                return XCTFail("Expected explicit recovery limit, got \(error)")
            }
        }
        XCTAssertThrowsError(try OriginalAnimationClip(data: Data(repeating: 0, count: 31)))
    }

    func testAllOriginalColourGridFramesRemainIntact() throws {
        let library = try OriginalAnimationLibrary.bundled()
        XCTAssertEqual(library.manifest.colourOverlays.count, 54)
        for record in library.manifest.colourOverlays {
            let grid = try library.loadColourGrid(id: record.id)
            XCTAssertEqual(grid.frameCount, record.frameCount)
            for frame in 0..<grid.frameCount {
                let colours = try grid.originalColours(frame: frame)
                XCTAssertEqual(colours.count, 561)
                let bytes = colours.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] }
                XCTAssertEqual(sha(Data(bytes)), record.frameSHA256[frame], record.id)
            }
        }
    }
}
