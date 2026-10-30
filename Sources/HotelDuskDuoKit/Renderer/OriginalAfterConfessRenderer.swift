import CoreGraphics
import Foundation

@MainActor
final class OriginalAfterConfessRenderer {
    struct Pages {
        let touch: CGImage
        let upper: CGImage
    }

    private let touchScenes: [CGImage]
    private let upperScenes: [CGImage]

    convenience init() throws {
        try self.init(library: .bundled())
    }

    init(library: OriginalBitmapLibrary) throws {
        func image(_ name: String) throws -> CGImage {
            let texture = try library.loadTexture(path: "show/AfterConfess/\(name).bin")
            guard let image = OriginalEntrancePanels.rotated(
                rgba: texture.rgba, width: texture.storedWidth, height: texture.storedHeight) else {
                throw OriginalDataError.invalid("AfterConfess texture \(name)")
            }
            return image
        }

        touchScenes = [try image("AC_01L"),
                       try Self.composite(base: image("AC_02L1"), overlay: image("AC_02L2")),
                       try Self.composite(base: image("AC_03L1"), overlay: image("AC_03L2"))]
        upperScenes = [try Self.composite(base: image("AC_01R2"), overlay: image("AC_01R1")),
                       try image("AC_02R"), try Self.blankPage()]
    }

    func pages(for phase: OriginalAfterConfessProcess.Phase) -> Pages? {
        guard phase != .complete else { return nil }
        let index = phase.rawValue
        return Pages(touch: touchScenes[index], upper: upperScenes[index])
    }

    private static func composite(base: CGImage, overlay: CGImage) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("AfterConfess image context")
        }
        context.interpolationQuality = .none
        context.draw(base, in: CGRect(x: 0, y: 0, width: 192, height: 256))
        let width = min(192, overlay.artworkWidth)
        let height = min(256, overlay.artworkHeight)
        context.draw(overlay, in: CGRect(x: (192 - width) / 2, y: (256 - height) / 2,
                                         width: width, height: height))
        guard let image = context.makeImage() else {
            throw OriginalDataError.invalid("AfterConfess composite")
        }
        return image
    }

    private static func blankPage() throws -> CGImage {
        guard let context = OriginalArtwork.pageContext(),
              let image = context.makeImage() else {
            throw OriginalDataError.invalid("AfterConfess blank page")
        }
        return image
    }
}
