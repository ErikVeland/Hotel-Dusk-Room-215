import CoreGraphics
import Foundation

@MainActor
final class OriginalLabelPeelRenderer {
    let initialMask: [UInt8]
    private let bottle: CGImage
    private let label: OriginalTexture

    init(library: OriginalBitmapLibrary) throws {
        let bottleTexture = try library.loadTexture(path: "trick/LabelPeel/bottle.bin")
        label = try library.loadTexture(path: "trick/LabelPeel/label_01.bin")
        guard bottleTexture.storedWidth == 256, bottleTexture.storedHeight == 192,
              label.storedWidth == OriginalLabelPeelProcess.width,
              label.storedHeight == OriginalLabelPeelProcess.height,
              let image = OriginalEntrancePanels.rotated(rgba: bottleTexture.rgba,
                  width: bottleTexture.storedWidth, height: bottleTexture.storedHeight) else {
            throw OriginalDataError.invalid("Wine label artwork dimensions")
        }
        bottle = image
        let rgba = [UInt8](label.rgba)
        initialMask = (0..<OriginalLabelPeelProcess.width * OriginalLabelPeelProcess.height).map {
            rgba[$0 * 4 + 3] == 0 ? 0 : 1
        }
    }

    func render(_ process: OriginalLabelPeelProcess) throws -> CGImage {
        guard let context = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8,
            bytesPerRow: 768, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw OriginalDataError.invalid("Wine label image context")
        }
        context.interpolationQuality = .none
        context.draw(bottle, in: .init(x: 0, y: 0, width: 192, height: 256))

        var rgba = [UInt8](label.rgba)
        for index in process.mask.indices where process.mask[index] == 0 || process.mask[index] >= 128 {
            rgba[index * 4 + 3] = 0
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let colourSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let labelImage = CGImage(width: label.storedWidth, height: label.storedHeight,
                  bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: label.storedWidth * 4,
                  space: colourSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw OriginalDataError.invalid("Wine label texture")
        }
        context.draw(labelImage, in: .init(x: 32, y: 48, width: 128, height: 160))
        guard let image = context.makeImage() else { throw OriginalDataError.invalid("Wine label image") }
        return image
    }
}
