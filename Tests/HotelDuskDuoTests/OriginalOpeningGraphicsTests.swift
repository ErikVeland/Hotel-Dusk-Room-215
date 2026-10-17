import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class OriginalOpeningGraphicsTests: XCTestCase {
    func testEveryOriginalOpeningTextureMatchesIndependentRecovery() throws {
        let library = try OriginalOpeningGraphicsLibrary.bundled()
        XCTAssertEqual(library.manifest.textures.count, 35)
        XCTAssertEqual(library.manifest.textures.filter { $0.mode == 4 }.count, 18)
        for record in library.manifest.textures {
            let texture = try library.loadTexture(path: record.source)
            XCTAssertEqual(texture.mode, record.mode, record.source)
            XCTAssertEqual(texture.storedWidth, record.width, record.source)
            XCTAssertEqual(texture.storedHeight, record.height, record.source)
            XCTAssertEqual(OriginalAnimationClip.digest(texture.decodedPayload), record.decodedSHA256, record.source)
            XCTAssertEqual(OriginalAnimationClip.digest(texture.originalPaletteData), record.paletteSHA256, record.source)
            XCTAssertEqual(OriginalAnimationClip.digest(texture.originalPixelData), record.pixelDataSHA256, record.source)
            XCTAssertEqual(OriginalAnimationClip.digest(texture.rgba), record.rgbaSHA256, record.source)
            XCTAssertEqual(OriginalAnimationClip.digest(texture.openingPortraitRGBA()), record.portraitRGBA_SHA256, record.source)
            if texture.mode == 4 {
                for (index, pixel) in texture.originalPixelData.enumerated() {
                    XCTAssertEqual(texture.rgba[index * 4 + 3], pixel == 0 ? 0 : 255, record.source)
                }
            }
        }
    }

    func testOriginalStripTimingSoundAndFadeBoundaries() throws {
        let library = try OriginalOpeningGraphicsLibrary.bundled()
        var controller = try OriginalOpeningStripReveal(card: library.card(variant: 0))
        XCTAssertEqual(controller.advance(), [.fade(channel: 0, layerMask: 63, type: 3, initialValue: -16, duration: 30),
                                              .soundSetup(channel: 0, index: 72)])
        XCTAssertEqual(controller.counter, 1)
        XCTAssertTrue(try controller.drawCommands(page: 0).isEmpty)
        while controller.counter < 22 { XCTAssertTrue(controller.advance().isEmpty) }
        let first = try XCTUnwrap(controller.drawCommands(page: 0).first)
        XCTAssertEqual(first.texture, "show/op2/op3d/01-01L2.bin")
        XCTAssertEqual(first.x, 42)
        XCTAssertEqual(first.width, 19)
        XCTAssertEqual(controller.advance(), [.playSound(channel: 1)])
        while controller.counter < 180 { _ = controller.advance() }
        XCTAssertEqual(try controller.drawCommands(page: 0).count, 20)
        XCTAssertEqual(try controller.drawCommands(page: 1).count, 13)
        // Multiple intervals coincide, but the original controller plays once.
        XCTAssertEqual(controller.advance(), [.playSound(channel: 1)])
        while controller.counter < 230 { XCTAssertTrue(controller.advance().isEmpty) }
        XCTAssertEqual(controller.advance(), [.fade(channel: 0, layerMask: 63, type: 2, initialValue: 0, duration: 30)])
        XCTAssertEqual(controller.phase, .waitingForFade)
        XCTAssertEqual(controller.counter, 231)
        XCTAssertTrue(controller.advance().isEmpty)
        XCTAssertEqual(controller.advance(fadeComplete: true), [.complete])
        XCTAssertEqual(controller.phase, .finished)
        XCTAssertEqual(controller.counter, 0)
        XCTAssertTrue(controller.advance().isEmpty)
    }

    func testAllCardPixelsAndCheckpointContinuation() throws {
        let library = try OriginalOpeningGraphicsLibrary.bundled()
        for card in library.manifest.variants {
            var original = try OriginalOpeningStripReveal(card: card)
            while original.counter < 180 { _ = original.advance() }
            for page in 0...1 {
                XCTAssertEqual(OriginalAnimationClip.digest(try original.renderPortraitRGBA(page: page, library: library)),
                               card.pageRGBA180[page], "variant\(card.variant), page\(page)")
            }
            let data = try JSONEncoder().encode(original.checkpoint())
            let checkpoint = try JSONDecoder().decode(OriginalOpeningStripReveal.Checkpoint.self, from: data)
            var restored = try OriginalOpeningStripReveal(card: card)
            try restored.restore(checkpoint)
            XCTAssertEqual(original.checkpoint(), restored.checkpoint())
            for _ in 0..<60 {
                XCTAssertEqual(original.advance(), restored.advance())
                XCTAssertEqual(original.checkpoint(), restored.checkpoint())
            }
            XCTAssertEqual(original.advance(fadeComplete: true), restored.advance(fadeComplete: true))
        }
        XCTAssertThrowsError(try library.card(variant: 3))
    }
}
