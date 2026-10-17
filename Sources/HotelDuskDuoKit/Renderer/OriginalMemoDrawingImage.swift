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
        let source = Array(background.rgba), glyphs = Array(symbols.rgba)
        var rgba = [UInt8](repeating: 0, count: 192 * 256 * 4)
        for y in 0..<256 { for x in 0..<192 {
            let raw = x * 256 + 255 - y, target = (y * 192 + x) * 4
            for c in 0..<3 { rgba[target + c] = drawing.pixels[raw] == 0 ? source[raw * 4 + c] : 0 }
            rgba[target + 3] = 255
        } }
        func glyph(_ column: Int, at point: SIMD2<Int>) {
            for y in 0..<16 { for x in 0..<16 {
                let px = point.x + x, py = point.y + y
                guard (0..<192).contains(px), (0..<256).contains(py) else { continue }
                let raw = ((column + x) * symbols.storedWidth + 15 - y) * 4
                guard raw + 3 < glyphs.count, glyphs[raw + 3] != 0 else { continue }
                let target = (py * 192 + px) * 4
                for c in 0..<3 { rgba[target + c] = glyphs[raw + c] }
            } }
        }
        for (index, point) in drawing.points.enumerated() {
            let position = point.position &+ SIMD2(0, drawing.paper == .torn ? 59 : 0)
            glyph(index * 16, at: position)
            glyph([0x150, 0x180, 0x160][point.group], at: position &+ SIMD2(8, 8))
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let image = CGImage(width: 192, height: 256, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: 192 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw OriginalDataError.invalid("Memo drawing image")
        }
        return image
    }
}
