import CoreGraphics
import Foundation

/**
 * Original memo bitmap, numbered symbols and scratchpad ink.
 */
public struct OriginalMemoDrawingImage {
    public let mask: [UInt8]
    private let background: OriginalTexture
    private let symbols: OriginalTexture

    public init(paper: OriginalMemoDrawing.Paper, library: OriginalBitmapLibrary) throws {
        let name = paper == .torn ? "memo01" : paper == .joined ? "memo00" : "memo02"
        background = try library.loadTexture(path: "trick/pointtie/\(name).bin")
        symbols = try library.loadTexture(path: "trick/pointtie/moji.bin")
        guard background.storedWidth == 256, background.storedHeight == 192 else {
            throw OriginalDataError.invalid("Memo image dimensions")
        }
        mask = Array(background.originalPixelData)
    }

    public func render(_ drawing: OriginalMemoDrawing) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext(),
              let paper = OriginalArtwork.shared.image(rgba: background.rgba, width: background.storedWidth,
                height: background.storedHeight, rotated: true),
              let glyphs = OriginalArtwork.shared.image(rgba: symbols.rgba, width: symbols.storedWidth,
                height: symbols.storedHeight, rotated: true) else {
            throw OriginalDataError.invalid("Memo drawing context")
        }
        context.draw(paper, in: CGRect(x: 0, y: 0, width: 192, height: 256))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for y in 0..<256 { for x in 0..<192 {
            let raw = x * 256 + 255 - y
            if drawing.pixels[raw] != 0 { context.fill(CGRect(x: x, y: 255 - y, width: 1, height: 1)) }
        } }
        func glyph(_ column: Int, at point: SIMD2<Int>) {
            guard let image = glyphs.croppingArtwork(to: CGRect(x: column, y: 0, width: 16, height: 16)) else { return }
            context.draw(image, in: CGRect(x: point.x, y: 256 - point.y - 16, width: 16, height: 16))
        }
        for (index, point) in drawing.points.enumerated() {
            let position = point.position &+ SIMD2(0, drawing.paper == .torn ? 59 : 0)
            glyph(index * 16, at: position)
            glyph([0x150, 0x180, 0x160][point.group], at: position &+ SIMD2(8, 8))
        }
        guard let image = context.makeImage() else {
            throw OriginalDataError.invalid("Memo drawing image")
        }
        return image
    }
}
