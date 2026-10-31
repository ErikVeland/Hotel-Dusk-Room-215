import CoreGraphics
import Foundation

extension OriginalBitmapLibrary {
    /**
     * Notebook ink uses packed bits rather than a palette bitmap header.
     */
    public func loadNotebookData(path: String) throws -> Data {
        let data = try checkedPayload(path: path, includeDataFiles: true)
        return try OriginalContainer.decode(data, hasDirectoryRecord: false)
    }
}

/**
 * Converts the original 8×8 ink tiles to a transparent, upright book page.
 */
public enum OriginalNotebookImage {
    public static func render(_ notebook: OriginalNotebook) -> CGImage? {
        render(notebook, artwork: .shared)
    }

    static func render(_ notebook: OriginalNotebook, artwork: OriginalArtwork) -> CGImage? {
        if !notebook.canEdit, !notebook.currentInkLayers.isEmpty,
           let composite = enhancedComposite(notebook.currentInkLayers, artwork: artwork) {
            return composite
        }
        let rgba = inkRGBA(notebook.pixels)
        if !notebook.canEdit,
           let enhanced = artwork.enhancedImage(rgba: Data(rgba), width: 192, height: 256) {
            return enhanced
        }
        return makeImage(rgba, width: 192, height: 256)
    }

    private static func inkRGBA(_ pixels: [UInt8]) -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: 192 * 256 * 4)
        for y in 0..<256 { for x in 0..<192 {
            let rawX = 255 - y
            let source = (x / 8) * 0x800 + (rawX / 8) * 64 + (x % 8) * 8 + rawX % 8
            rgba[(y * 192 + x) * 4 + 3] = pixels[source] == 0 ? 0 : 255
        } }
        return rgba
    }

    private static func enhancedComposite(_ layers: [OriginalNotebook.InkLayer], artwork: OriginalArtwork) -> CGImage? {
        let width = 192 * 4, height = 256 * 4
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for layer in layers {
            let source = Data(inkRGBA(layer.pixels))
            guard let image = artwork.metalPixels(rgba: source, width: 192, height: 256),
                  image.width == width, image.height == height else { return nil }
            let pixels = [UInt8](image.data)
            for y in 0..<(layer.rows * 4) {
                let targetY = layer.offset * 4 + y
                guard targetY < height else { return nil }
                for x in 0..<width {
                    let sourceAlpha = (y * width + x) * 4 + 3
                    let targetAlpha = (targetY * width + x) * 4 + 3
                    rgba[targetAlpha] = max(rgba[targetAlpha], pixels[sourceAlpha])
                }
            }
        }
        guard let image = makeImage(rgba, width: width, height: height) else { return nil }
        artwork.remember(image, size: CGSize(width: 192, height: 256))
        return image
    }

    private static func makeImage(_ rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
