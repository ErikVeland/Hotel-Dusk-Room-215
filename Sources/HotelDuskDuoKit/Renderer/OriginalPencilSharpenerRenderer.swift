import CoreGraphics
import Foundation
import ImageIO

/**
 * Loads the rotated original process capture used for the native screen.
 */
public struct OriginalPencilSharpenerRenderer: Sendable {
    public let image: CGImage

    public init() throws {
        try self.init(bundle: .module)
    }

    init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: "OriginalPencilSharpener", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width == 192, image.height == 256 else {
            throw OriginalDataError.invalid("Pencil-sharpener process image")
        }
        self.image = image
    }
}
