import CoreGraphics
import Foundation

extension OriginalBitmapLibrary {
    /**
     * Notebook ink uses packed bits rather than a palette bitmap header.
     */
    public func loadNotebookData(path: String) throws -> Data {
        guard let record = manifest.images.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        let url = resourceRoot.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(resourceRoot.path + "/") else { throw OriginalDataError.invalid("Notebook path leaves source directory") }
        let data = try Data(contentsOf: url)
        guard OriginalScriptCatalog.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return try OriginalContainer.decode(data, hasDirectoryRecord: false)
    }
}

/**
 * Converts the original 8×8 ink tiles to a transparent, upright book page.
 */
public enum OriginalNotebookImage {
    public static func render(_ notebook: OriginalNotebook) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: 192 * 256 * 4)
        for y in 0..<256 { for x in 0..<192 {
            let rawX = 255 - y
            let source = (x / 8) * 0x800 + (rawX / 8) * 64 + (x % 8) * 8 + rawX % 8
            rgba[(y * 192 + x) * 4 + 3] = notebook.pixels[source] == 0 ? 0 : 255
        } }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: 192, height: 256, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 192 * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
