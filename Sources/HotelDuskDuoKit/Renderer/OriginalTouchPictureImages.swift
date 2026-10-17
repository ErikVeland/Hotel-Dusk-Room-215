import CoreGraphics
import Foundation

/**
 * Original foreground, background and packed selection mask in book orientation.
 */
@MainActor
public struct OriginalTouchPictureImages {
    public let background: CGImage?
    public let foreground: CGImage
    public let highlight: CGImage
    public let x: Int
    public let y: Int

    public init(picture: OriginalTouchPicture, foreground: OriginalLinearBitmap,
                background: OriginalLinearBitmap?, highlightRGB: (UInt8, UInt8, UInt8)) throws {
        func image(_ bitmap: OriginalLinearBitmap, transparent: Bool) throws -> CGImage {
            guard let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: transparent),
                width: bitmap.width, height: bitmap.height) else { throw OriginalDataError.invalid("Touch picture pixels") }
            return image
        }
        self.foreground = try image(foreground, transparent: true)
        self.background = try background.map { try image($0, transparent: false) }
        x = background == nil ? picture.record.x : 0
        y = background == nil ? picture.record.y : 0
        var rgba = [UInt8]()
        for row in 0..<foreground.height {
            for column in 0..<foreground.width {
                let block = (row / 2) * (foreground.width / 2) + column / 2
                let occupied = (picture.mask[block / 4] >> ((block % 4) * 2)) & 3 != 0
                /**
                 * 0x0200FD50 and 0x0200FE64 use polygon alpha 15: (15 + 1) / 32.
                 */
                rgba += [highlightRGB.0, highlightRGB.1, highlightRGB.2, occupied ? 128 : 0]
            }
        }
        guard let highlight = OriginalEntrancePanels.rotated(rgba: Data(rgba), width: foreground.width, height: foreground.height) else {
            throw OriginalDataError.invalid("Touch picture highlight")
        }
        self.highlight = highlight
    }

    public static func item(_ id: UInt8, library: OriginalBitmapLibrary) throws -> CGImage {
        let bitmap = try library.loadLinear(path: String(format: "system/ItemImage/item%03d.bin", Int(id)))
        guard let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: true),
            width: bitmap.width, height: bitmap.height) else { throw OriginalDataError.invalid("Item picture pixels") }
        return image
    }
}
