import CoreGraphics
import Foundation

@MainActor
final class OriginalMatchstickRenderer {
    private let background: CGImage
    private let stick: CGImage
    init() throws {
        let library = try OriginalBitmapLibrary.bundled()
        func image(_ path: String) throws -> CGImage {
            let texture = try library.loadTexture(path: path)
            guard let image = OriginalEntrancePanels.rotated(rgba: texture.rgba,
                width: texture.storedWidth, height: texture.storedHeight) else {
                throw OriginalDataError.invalid("Matchstick image")
            }
            return image
        }
        background = try image("trick/coin/coin_bg.bin")
        stick = try image("trick/sticktex.bin")
    }
    func render(_ puzzle: OriginalMatchstickProcess) throws -> CGImage {
        guard let context = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8, bytesPerRow: 768,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw OriginalDataError.invalid("Matchstick context")
        }
        context.interpolationQuality = .none
        context.draw(background, in: .init(x: 0, y: 0, width: 192, height: 256))
        for match in puzzle.sticks where match.state != 0 {
            context.saveGState()
            let flying = match.state == 2
            context.translateBy(x: CGFloat(match.origin.x) + (flying ? CGFloat(puzzle.flyX) * 192 / 4096 : 0),
                y: CGFloat(256 - match.origin.y) + (flying ? CGFloat(puzzle.flyY) * 256 / 4096 : 0))
            let angle = match.angle &+ (flying ? puzzle.spin : 0)
            context.rotate(by: CGFloat(angle) * 2 * .pi / 65536)
            context.draw(stick, in: .init(x: 0, y: -4, width: 40, height: 8))
            context.restoreGState()
        }
        guard let image = context.makeImage() else { throw OriginalDataError.invalid("Matchstick render") }
        return image
    }
}
