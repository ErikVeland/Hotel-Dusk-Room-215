import CoreGraphics
import Foundation

/// The original pamphlet comparison and its palette-zero drawing colour.
@MainActor
final class OriginalDifferencesRenderer {
    private let background: OriginalTexture
    init() throws {
        background = try OriginalBitmapLibrary.bundled().loadTexture(path: "trick/pamph/diffbg.bin")
        guard background.storedWidth == 256, background.storedHeight == 192 else {
            throw OriginalDataError.invalid("Pamphlet dimensions")
        }
    }
    func makeProcess() throws -> OriginalDifferencesProcess { try .init(mask: Array(background.originalPixelData)) }
    func render(_ puzzle: OriginalDifferencesProcess) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext(),
              let artwork = OriginalArtwork.shared.image(rgba: background.rgba, width: background.storedWidth,
                height: background.storedHeight, rotated: true) else {
            throw OriginalDataError.invalid("Pamphlet context")
        }
        context.draw(artwork, in: CGRect(x: 0, y: 0, width: 192, height: 256))
        context.setFillColor(CGColor(red: 231.0 / 255, green: 82.0 / 255, blue: 82.0 / 255, alpha: 1))
        for y in 0..<256 { for x in 0..<192 {
            let raw = x * 256 + 255 - y
            if puzzle.drawing.pixels[raw] != 0 {
                context.fill(CGRect(x: x, y: 255 - y, width: 1, height: 1))
            }
        } }
        guard let image = context.makeImage() else {
            throw OriginalDataError.invalid("Pamphlet image")
        }
        return image
    }
}
