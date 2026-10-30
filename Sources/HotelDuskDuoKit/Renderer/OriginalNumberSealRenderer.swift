import CoreGraphics
import Foundation

@MainActor
struct OriginalNumberSealRenderer {
    let image: CGImage

    init(process: OriginalNumberSealProcess, library: OriginalBitmapLibrary) throws {
        let background = try library.loadTexture(path: "trick/seal/bg.bin")
        let atlas = try library.loadTexture(path: "trick/seal/number.bin")
        guard background.storedWidth == 256, background.storedHeight == 192,
              atlas.storedWidth == 32, atlas.storedHeight >= 384 else {
            throw OriginalDataError.invalid("Number sticker artwork")
        }
        var pixels = [UInt8](background.rgba)
        let digits = [UInt8](atlas.rgba)
        func draw(sourceY: Int, targetY: Int) {
            for y in 0..<32 {
                for x in 0..<32 {
                    let source = ((sourceY + y) * atlas.storedWidth + x) * 4
                    let target = ((targetY + y) * 256 + 112 + x) * 4
                    let alpha = Int(digits[source + 3])
                    for channel in 0..<3 {
                        pixels[target + channel] = UInt8((Int(digits[source + channel]) * alpha
                            + Int(pixels[target + channel]) * (255 - alpha) + 127) / 255)
                    }
                    pixels[target + 3] = 255
                }
            }
        }
        draw(sourceY: process.number > 0 ? 320 : 352, targetY: 48)
        let magnitude = abs(process.number)
        if magnitude >= 10 { draw(sourceY: magnitude / 10 * 32, targetY: 80) }
        draw(sourceY: magnitude % 10 * 32, targetY: 112)
        guard let rendered = OriginalEntrancePanels.rotated(rgba: Data(pixels), width: 256, height: 192) else {
            throw OriginalDataError.invalid("Number sticker image")
        }
        image = rendered
    }
}
