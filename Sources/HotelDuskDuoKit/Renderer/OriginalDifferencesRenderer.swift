import CoreGraphics
import Foundation

/// The original pamphlet comparison and its palette-zero drawing colour.
@MainActor
final class OriginalDifferencesRenderer {
    private let background: OriginalTexture
    init() throws {
        background = try OriginalBitmapLibrary.bundled().loadTexture(path: "trick/pamph/diffbg.bin")
        guard background.storedWidth == 256, background.storedHeight == 192 else {
            throw OriginalDataError.invalid("Pamphlet dimensions")
        }
    }
    func makeProcess() throws -> OriginalDifferencesProcess { try .init(mask: Array(background.originalPixelData)) }
    func render(_ puzzle: OriginalDifferencesProcess) throws -> CGImage {
        let source = Array(background.rgba)
        var pixels = [UInt8](repeating: 0, count: 192 * 256 * 4)
        let colour: [UInt8] = [231, 82, 82] // Original BGR555 palette entry 0x295C.
        for y in 0..<256 { for x in 0..<192 {
            let raw = x * 256 + 255 - y, at = (y * 192 + x) * 4
            for channel in 0..<3 {
                pixels[at + channel] = puzzle.drawing.pixels[raw] == 0 ? source[raw * 4 + channel] : colour[channel]
            }
            pixels[at + 3] = 255
        } }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: 192, height: 256, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: 768, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw OriginalDataError.invalid("Pamphlet image")
        }
        return image
    }
}
