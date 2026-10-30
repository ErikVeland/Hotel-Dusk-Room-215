import CoreGraphics
import Foundation

@MainActor
final class OriginalLabelPeelRenderer {
    let initialMask: [UInt8]
    private let bottle: CGImage
    private let label: OriginalTexture
    private let foldedCorner: CGImage
    private let peeledLabel: CGImage
    private let peelingLabel: CGImage

    init(library: OriginalBitmapLibrary) throws {
        let bottleTexture = try library.loadTexture(path: "trick/LabelPeel/bottle.bin")
        label = try library.loadTexture(path: "trick/LabelPeel/label_01.bin")
        let foldedTexture = try library.loadTexture(path: "trick/LabelPeel/label_02.bin")
        let peeledTexture = try library.loadTexture(path: "trick/LabelPeel/label_03.bin")
        let peelingTexture = try library.loadTexture(path: "trick/LabelPeel/label_04.bin")
        guard bottleTexture.storedWidth == 256, bottleTexture.storedHeight == 192,
              label.storedWidth == OriginalLabelPeelProcess.width,
              label.storedHeight == OriginalLabelPeelProcess.height,
              foldedTexture.storedWidth == 64, foldedTexture.storedHeight == 64,
              peeledTexture.storedWidth == OriginalLabelPeelProcess.width,
              peeledTexture.storedHeight == OriginalLabelPeelProcess.height,
              peelingTexture.storedWidth == OriginalLabelPeelProcess.width,
              peelingTexture.storedHeight == OriginalLabelPeelProcess.height,
              let image = OriginalEntrancePanels.rotated(rgba: bottleTexture.rgba,
                  width: bottleTexture.storedWidth, height: bottleTexture.storedHeight) else {
            throw OriginalDataError.invalid("Wine label artwork dimensions")
        }
        bottle = image
        foldedCorner = try Self.image(foldedTexture)
        peeledLabel = try Self.image(peeledTexture)
        peelingLabel = try Self.image(peelingTexture)
        let rgba = [UInt8](label.rgba)
        initialMask = (0..<OriginalLabelPeelProcess.width * OriginalLabelPeelProcess.height).map {
            rgba[$0 * 4 + 3] == 0 ? 0 : 1
        }
    }

    func render(_ process: OriginalLabelPeelProcess) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("Wine label image context")
        }
        context.interpolationQuality = .none
        context.draw(bottle, in: .init(x: 0, y: 0, width: 192, height: 256))

        if process.stage == .peel {
            let labelImage = process.peelDistance == 0 ? peeledLabel : peelingLabel
            context.draw(labelImage, in: .init(x: 32, y: 48, width: 128, height: 160))
            if process.peelDistance == 0 {
                context.draw(foldedCorner, in: .init(x: 96, y: 48, width: 64, height: 64))
            }
            guard let result = context.makeImage() else { throw OriginalDataError.invalid("Wine label image") }
            return result
        }

        var rgba = [UInt8](label.rgba)
        for index in process.mask.indices where process.mask[index] == 0 || process.mask[index] >= 128 {
            rgba[index * 4 + 3] = 0
        }
        guard let labelImage = OriginalArtwork.shared.maskedImage(rgba: label.rgba,
            width: label.storedWidth, height: label.storedHeight, maskRGBA: Data(rgba)) else {
            throw OriginalDataError.invalid("Wine label texture")
        }
        context.draw(labelImage, in: .init(x: 32, y: 48, width: 128, height: 160))
        guard let image = context.makeImage() else { throw OriginalDataError.invalid("Wine label image") }
        return image
    }

    private static func image(_ texture: OriginalTexture) throws -> CGImage {
        guard let image = texture.makeCGImage() else { throw OriginalDataError.invalid("Wine label texture") }
        return image
    }
}
