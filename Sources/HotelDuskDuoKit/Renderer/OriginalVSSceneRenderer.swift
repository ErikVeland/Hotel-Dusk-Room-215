import CoreGraphics
import Foundation

@MainActor
final class OriginalVSSceneRenderer {
    private let overlay: CGImage

    convenience init() throws {
        try self.init(library: .bundled())
    }

    init(library: OriginalBitmapLibrary) throws {
        let texture = try library.loadTexture(path: "show/VSScene/ED_A_01L2.bin")
        let sourceWidth = texture.storedWidth
        let sourceHeight = texture.storedHeight
        let cropTop = 81
        let cropHeight = min(175, sourceHeight - cropTop)
        guard sourceWidth == 256, cropHeight > 0,
              let provider = Self.rotatedTexture(texture.rgba, width: sourceWidth,
                                                 cropTop: cropTop, cropHeight: cropHeight),
              let image = CGImage(width: cropHeight, height: sourceWidth,
                                  bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: cropHeight * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil,
                                  shouldInterpolate: false, intent: .defaultIntent) else {
            throw OriginalDataError.invalid("VSScene ending overlay")
        }
        overlay = image
    }

    func image() -> CGImage { overlay }

    private static func rotatedTexture(_ rgba: Data, width: Int,
                                       cropTop: Int, cropHeight: Int) -> CGDataProvider? {
        let source = [UInt8](rgba)
        let outputWidth = cropHeight
        let outputHeight = width
        var output = [UInt8](repeating: 0, count: outputWidth * outputHeight * 4)
        for y in 0..<outputHeight {
            for x in 0..<outputWidth {
                let sourceOffset = ((cropTop + x) * width + width - 1 - y) * 4
                let outputOffset = (y * outputWidth + x) * 4
                output[outputOffset..<outputOffset + 4] = source[sourceOffset..<sourceOffset + 4]
            }
        }
        return CGDataProvider(data: Data(output) as CFData)
    }
}
