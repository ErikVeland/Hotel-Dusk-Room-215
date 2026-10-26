import CoreGraphics
import Foundation

/// Overlay 33 texture banks and fixed-point quads from 021FE010/021FDB5C.
@MainActor
final class OriginalLinenWagonRenderer {
    private let background: CGImage
    private let opened: CGImage
    private let closed: CGImage
    private let gun: CGImage
    private let sheets: [CGImage]
    private let library: OriginalBitmapLibrary
    private var revealed: CGImage?
    var gunResourceReady: Bool { revealed != nil }

    init() throws {
        let library = try OriginalBitmapLibrary.bundled()
        self.library = library
        func image(_ name: String, rotated: Bool = false) throws -> CGImage {
            let texture = try library.loadTexture(path: "trick/linenwagon/\(name).bin")
            let image = rotated ? OriginalEntrancePanels.rotated(rgba: texture.rgba,
                width: texture.storedWidth, height: texture.storedHeight) : texture.makeCGImage()
            guard let image else { throw OriginalDataError.invalid("Linen wagon artwork: \(name)") }
            return image
        }
        background = try image("bg1", rotated: true)
        opened = try image("opened"); closed = try image("closed"); gun = try image("gun")
        sheets = try ["s_128", "s_p1_128", "s_p2_128", "s_p3_128"].map { try image($0) }
    }

    /// The source's 020A63E0 waits for texture upload, not a cinematic clip.
    func loadGunResource() throws {
        let texture = try library.loadTexture(path: "trick/linenwagon/bg2.bin")
        guard let image = OriginalEntrancePanels.rotated(rgba: texture.rgba,
            width: texture.storedWidth, height: texture.storedHeight) else {
            throw OriginalDataError.invalid("Linen wagon reveal artwork")
        }
        revealed = image
    }

    func render(_ puzzle: OriginalLinenWagonProcess) throws -> CGImage {
        guard let context = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8, bytesPerRow: 768,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw OriginalDataError.invalid("Linen wagon context")
        }
        context.interpolationQuality = .none
        func draw(_ image: CGImage, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat = 1) {
            context.setAlpha(alpha)
            context.draw(image, in: .init(x: x - width / 2, y: 256 - y - height / 2, width: width, height: height))
        }
        draw(background, x: 96, y: 128, width: 192, height: CGFloat(5489) * 192 / 4096)
        if puzzle.gunAlpha > 0, let revealed {
            let alpha = CGFloat(puzzle.gunAlpha) / 31
            draw(revealed, x: 96, y: 128 - CGFloat(1372) * 96 / 4096,
                 width: 192, height: CGFloat(2744) * 192 / 4096, alpha: alpha)
            draw(gun, x: 96 + CGFloat(1065) * 96 / 4096, y: 128 - CGFloat(164) * 96 / 4096,
                 width: CGFloat(1365) * 192 / 4096, height: CGFloat(683) * 192 / 4096, alpha: alpha)
        }
        let coverY = 128 + CGFloat(1843) * 96 / 4096
        draw(opened, x: 96, y: coverY, width: 64, height: 64, alpha: CGFloat(puzzle.coverAlpha) / 31)
        draw(closed, x: 96, y: coverY, width: 64, height: 64, alpha: CGFloat(31 - puzzle.coverAlpha) / 31)
        if puzzle.phase < 3 || puzzle.phase == 3 && puzzle.subphase == 0 {
            context.setAlpha(1)
            for piece in puzzle.pieces.sorted(by: { $0.z > $1.z }) where piece.throwDirection != 10 {
                let index = piece.highlight == 0 ? 0 : piece.highlight < 2 ? 1 : piece.highlight < 5 ? 2 : 3
                context.saveGState()
                context.translateBy(x: CGFloat(piece.pageCenter.x), y: CGFloat(256 - piece.pageCenter.y))
                context.rotate(by: -CGFloat(piece.rotation) * .pi)
                let extent = CGFloat(2731) * 96 / 4096
                context.draw(sheets[index], in: .init(x: -extent, y: -extent, width: extent * 2, height: extent * 2))
                context.restoreGState()
            }
        }
        guard let image = context.makeImage() else { throw OriginalDataError.invalid("Linen wagon image") }
        return image
    }
}
