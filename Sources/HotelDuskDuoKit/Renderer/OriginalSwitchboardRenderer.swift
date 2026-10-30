import CoreGraphics

/// Original panel images and the three source crop rectangles at 0x021FD9A8.
@MainActor
final class OriginalSwitchboardRenderer {
    private let off: CGImage
    private let on: CGImage

    init() throws {
        let library = try OriginalBitmapLibrary.bundled()
        func image(_ name: String) throws -> CGImage {
            let bitmap = try library.loadLinear(path: "trick/switchboard/\(name).bin")
            guard let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: true),
                width: bitmap.width, height: bitmap.height) else { throw OriginalDataError.invalid("Switchboard image") }
            return image
        }
        off = try image("paneloff"); on = try image("panelon")
    }

    func render(_ puzzle: OriginalSwitchboardProcess) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("Switchboard context")
        }
        context.interpolationQuality = .none
        context.draw(off, in: CGRect(x: 0, y: 0, width: 192, height: 256))
        for (visible, rect) in [(puzzle.leftOn, CGRect(x: 19, y: 104, width: 52, height: 77)),
                               (puzzle.rightOn, CGRect(x: 120, y: 104, width: 51, height: 77)),
                               (puzzle.lightOn, CGRect(x: 80, y: 112, width: 32, height: 32))] where visible {
            guard let crop = on.croppingArtwork(to: rect) else { throw OriginalDataError.invalid("Switchboard crop") }
            context.draw(crop, in: CGRect(x: rect.minX, y: 256 - rect.maxY, width: rect.width, height: rect.height))
        }
        guard let result = context.makeImage() else { throw OriginalDataError.invalid("Switchboard render") }
        return result
    }
}
