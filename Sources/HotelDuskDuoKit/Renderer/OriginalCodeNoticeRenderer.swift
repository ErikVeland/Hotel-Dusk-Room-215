import CoreGraphics
import Foundation

/**
 * Loads the recovered paper background used by overlay 36.
 */
@MainActor
struct OriginalCodeNoticeRenderer {
    let pageBackground: CGImage

    init() throws {
        try self.init(library: .bundled())
    }

    init(library: OriginalBitmapLibrary) throws {
        let texture = try library.loadTexture(path: "trick/code/bg.bin")
        guard let image = OriginalEntrancePanels.rotated(rgba: texture.rgba,
                                                         width: texture.storedWidth,
                                                         height: texture.storedHeight),
              image.artworkWidth == 192, image.artworkHeight == 256 else {
            throw OriginalDataError.invalid("Code notice background")
        }
        pageBackground = image
    }
}
