import CoreGraphics
import Foundation

/**
 * Renders the two overlay 35 screens from their original DTX layers.
 */
@MainActor
final class OriginalPicturePeelRenderer {
    let initialMask: [UInt8]
    let upperScreen: CGImage
    private let background: [UInt8]
    private let sample: [UInt8]
    private let picture: [UInt8]

    init(library: OriginalBitmapLibrary) throws {
        let textures = try ["bg1", "bg2", "pic", "pic_sample"].map {
            try library.loadTexture(path: "trick/picturepeel/\($0).bin")
        }
        guard textures.allSatisfy({ $0.storedWidth == 256 && $0.storedHeight == 192 }) else {
            throw OriginalDataError.invalid("Picture peel texture dimensions")
        }
        let picturePixels = [UInt8](textures[2].rgba)
        guard let image = OriginalEntrancePanels.rotated(rgba: textures[0].rgba,
                                                         width: 256, height: 192) else {
            throw OriginalDataError.invalid("Picture peel upper screen")
        }
        background = [UInt8](textures[1].rgba)
        picture = picturePixels
        sample = [UInt8](textures[3].rgba)
        initialMask = (0..<(256 * 192)).map { picturePixels[$0 * 4 + 3] == 0 ? 0 : 1 }
        upperScreen = image
    }

    func render(_ process: OriginalPicturePeelProcess) throws -> CGImage {
        guard process.mask.count == 192 * 256 else {
            throw OriginalDataError.invalid("Picture peel mask dimensions")
        }
        var pixels = [UInt8](repeating: 0, count: 256 * 192 * 4)
        for index in 0..<(256 * 192) {
            let backgroundOffset = index * 4
            let sampleAlpha = Int(sample[backgroundOffset + 3])
            let pictureAlpha = process.mask[index] == 0 ? 0 : Int(picture[backgroundOffset + 3])
            let base = (background[backgroundOffset], background[backgroundOffset + 1], background[backgroundOffset + 2])
            let under = Self.composite(sample, alpha: sampleAlpha, over: base, at: backgroundOffset)
            let result = Self.composite(picture, alpha: pictureAlpha, over: under, at: backgroundOffset)
            pixels[backgroundOffset] = result.0
            pixels[backgroundOffset + 1] = result.1
            pixels[backgroundOffset + 2] = result.2
            pixels[backgroundOffset + 3] = 255
        }
        guard let image = OriginalEntrancePanels.rotated(rgba: Data(pixels), width: 256, height: 192) else {
            throw OriginalDataError.invalid("Picture peel lower screen")
        }
        return image
    }

    private static func composite(_ foreground: [UInt8], alpha: Int,
                                  over background: (UInt8, UInt8, UInt8), at offset: Int) -> (UInt8, UInt8, UInt8) {
        let inverse = 255 - alpha
        let channels = [background.0, background.1, background.2]
        return (0..<3).map { channel in
            UInt8((Int(foreground[offset + channel]) * alpha
                + Int(channels[channel]) * inverse + 127) / 255)
        }.withUnsafeBufferPointer { ($0[0], $0[1], $0[2]) }
    }
}
