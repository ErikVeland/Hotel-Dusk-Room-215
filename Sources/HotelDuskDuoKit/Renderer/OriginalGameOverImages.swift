import CoreGraphics
import Foundation

/**
 * Final source backgrounds used by the original game-over screens.
 */
@MainActor
struct OriginalGameOverImages {
    private static var cached: Self?

    let upper: CGImage
    let lower: CGImage
    let retrySelectedLower: CGImage
    let titleSelectedLower: CGImage

    init(library: OriginalBitmapLibrary) throws {
        let upperBitmap = try library.loadLinear(path: "talktest/GameOverImage/haikei_L03.bin")
        let lowerBitmap = try library.loadLinear(path: "talktest/GameOverImage/haikei_R03.bin")
        guard upperBitmap.width == 256, upperBitmap.height == 192,
              lowerBitmap.width == 256, lowerBitmap.height == 192 else {
            throw OriginalDataError.invalid("Original game-over background size")
        }

        guard let upperImage = OriginalEntrancePanels.rotated(
            rgba: upperBitmap.rgba(transparentPaletteZero: false),
            width: upperBitmap.width,
            height: upperBitmap.height
        ) else {
            throw OriginalDataError.invalid("Original upper game-over background")
        }
        upper = upperImage

        var lowerPixels = [UInt8](lowerBitmap.rgba(transparentPaletteZero: false))
        let title = try library.loadLinear(path: "talktest/GameOverImage/go03.bin")
        try Self.composite(title, atX: 128, y: 31, into: &lowerPixels)
        let menu = try library.loadLinear(path: "talktest/GameOverImage/menu001a.bin")
        let selectedMenu = try library.loadLinear(path: "talktest/GameOverImage/menu002a.bin")
        try Self.composite(menu, atX: 0, y: 64, into: &lowerPixels)
        guard let lowerImage = OriginalEntrancePanels.rotated(
            rgba: Data(lowerPixels), width: lowerBitmap.width, height: lowerBitmap.height
        ) else {
            throw OriginalDataError.invalid("Original lower game-over composition")
        }
        lower = lowerImage

        // menu002a highlights both labels, so retain only the source columns for each choice.
        var retryPixels = lowerPixels
        try Self.composite(selectedMenu, atX: 0, y: 64, sourceX: 48..<84, into: &retryPixels)
        guard let retryImage = OriginalEntrancePanels.rotated(
            rgba: Data(retryPixels), width: lowerBitmap.width, height: lowerBitmap.height
        ) else {
            throw OriginalDataError.invalid("Original Retry selection composition")
        }
        retrySelectedLower = retryImage

        var titlePixels = lowerPixels
        try Self.composite(selectedMenu, atX: 0, y: 64, sourceX: 12..<48, into: &titlePixels)
        guard let titleImage = OriginalEntrancePanels.rotated(
            rgba: Data(titlePixels), width: lowerBitmap.width, height: lowerBitmap.height
        ) else {
            throw OriginalDataError.invalid("Original title selection composition")
        }
        titleSelectedLower = titleImage
    }

    static func bundled() -> Self? {
        if let cached { return cached }
        guard let images = try? Self(library: OriginalBitmapLibrary.bundled()) else { return nil }
        cached = images
        return images
    }

    /**
     * Places the recovered title and menu layers at their captured source coordinates.
     */
    private static func composite(_ bitmap: OriginalLinearBitmap, atX originX: Int, y originY: Int,
                                  sourceX: Range<Int> = 0..<128, into destination: inout [UInt8]) throws {
        guard bitmap.width == 128, bitmap.height == 128,
              originX >= 0, originY >= 0,
              sourceX.lowerBound >= 0, sourceX.upperBound <= bitmap.width,
              originX + bitmap.width <= 256, originY + bitmap.height <= 192 else {
            throw OriginalDataError.invalid("Original game-over overlay size")
        }
        let source = [UInt8](bitmap.rgba(transparentPaletteZero: true))
        for y in 0..<bitmap.height {
            for x in sourceX {
                let sourceOffset = (y * bitmap.width + x) * 4
                let alpha = Int(source[sourceOffset + 3])
                guard alpha > 0 else { continue }
                let targetOffset = ((originY + y) * 256 + originX + x) * 4
                let inverseAlpha = 255 - alpha
                for channel in 0..<3 {
                    destination[targetOffset + channel] = UInt8(
                        (Int(source[sourceOffset + channel]) * alpha
                         + Int(destination[targetOffset + channel]) * inverseAlpha + 127) / 255
                    )
                }
                destination[targetOffset + 3] = 255
            }
        }
    }
}
