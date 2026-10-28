import CoreGraphics
import Foundation

/**
 * Loads the original typewriter screen artwork.
 */
@MainActor
struct OriginalTypewriterRenderer {
    let upperScreen: CGImage
    let touchScreen: CGImage

    init() throws {
        try self.init(library: .bundled())
    }

    init(library: OriginalBitmapLibrary) throws {
        let upper = try library.loadTexture(path: "trick/typewriter/bg_1.bin")
        let touch = try library.loadTexture(path: "trick/typewriter/bg_2.bin")
        guard upper.storedWidth == 256, upper.storedHeight == 192,
              touch.storedWidth == 256, touch.storedHeight == 192,
              let upperImage = OriginalEntrancePanels.rotated(rgba: upper.rgba, width: 256, height: 192),
              let touchImage = OriginalEntrancePanels.rotated(rgba: touch.rgba, width: 256, height: 192) else {
            throw OriginalDataError.invalid("Typewriter screen artwork")
        }
        upperScreen = upperImage
        touchScreen = touchImage
    }
}
