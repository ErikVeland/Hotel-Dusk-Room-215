import CoreGraphics
import Foundation

@MainActor
final class OriginalVSSceneRenderer {
    private let overlay: CGImage

    convenience init() throws {
        try self.init(library: .bundled())
    }

    init(library: OriginalBitmapLibrary) throws {
        let texture = try library.loadTexture(path: "show/VSScene/ED_A_01L2.bin")
        let sourceWidth = texture.storedWidth
        let sourceHeight = texture.storedHeight
        let cropTop = 81
        let cropHeight = min(175, sourceHeight - cropTop)
        guard sourceWidth == 256, cropHeight > 0,
              let source = OriginalArtwork.shared.image(rgba: texture.rgba, width: sourceWidth,
                  height: sourceHeight, rotated: true),
              let image = source.croppingArtwork(to: CGRect(x: cropTop, y: 0,
                  width: cropHeight, height: sourceWidth)) else {
            throw OriginalDataError.invalid("VSScene ending overlay")
        }
        overlay = image
    }

    func image() -> CGImage { overlay }

}
