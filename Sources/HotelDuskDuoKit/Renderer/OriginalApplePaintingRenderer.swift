import CoreGraphics
import Foundation

/**
 * Renders the recovered apple artwork into overlay 38's portrait page space.
 */
public struct OriginalApplePaintingRenderer: Sendable {
    public static let pageWidth = 192
    public static let pageHeight = 256

    private let bitmaps: [OriginalLinearBitmap]

    public init(library: OriginalBitmapLibrary) throws {
        bitmaps = try (1...5).map { index in
            try library.loadLinear(path: "trick/alphabet/apple\(index).bin")
        }
    }

    /**
     * Renders one source painting using the recovered three-to-one camera scale.
     */
    public func render(index: Int, cameraX: Float = 0, cameraY: Float = 0) throws -> CGImage {
        guard bitmaps.indices.contains(index), cameraX.isFinite, cameraY.isFinite else {
            throw OriginalDataError.invalid("Apple painting selection or camera")
        }
        let bitmap = bitmaps[index]
        guard let artwork = Self.image(from: bitmap),
              let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("Apple painting image")
        }

        context.clear(CGRect(x: 0, y: 0, width: Self.pageWidth, height: Self.pageHeight))
        context.interpolationQuality = .high
        let scale = CGFloat(1.0 / 3.0)
        let originX = CGFloat(64) + CGFloat(cameraY) / 96
        let originY = CGFloat(Self.pageHeight) / 3 + CGFloat(cameraX) / 128
        context.draw(artwork, in: CGRect(x: originX, y: originY,
                                         width: CGFloat(artwork.artworkWidth) * scale,
                                         height: CGFloat(artwork.artworkHeight) * scale))
        guard let image = context.makeImage() else {
            throw OriginalDataError.invalid("Apple painting page image")
        }
        return image
    }

    public func mask(for index: Int) throws -> OriginalApplePaintingMask {
        guard bitmaps.indices.contains(index) else {
            throw OriginalDataError.invalid("Apple painting selection")
        }
        return OriginalApplePaintingMask(bitmap: bitmaps[index])
    }

    private static func image(from bitmap: OriginalLinearBitmap) -> CGImage? {
        OriginalArtwork.shared.image(rgba: bitmap.rgba(transparentPaletteZero: true), width: bitmap.width, height: bitmap.height)
    }
}
