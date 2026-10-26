import CoreGraphics
import Foundation

/// Original doll backgrounds and stitch colour gradients, in portrait page coordinates.
@MainActor
final class OriginalDollRepairRenderer {
    private let whole: CGImage
    private let damaged: CGImage
    private let repaired: CGImage
    private let wing: CGImage
    private let point: CGImage
    init() throws {
        let library = try OriginalBitmapLibrary.bundled()
        func image(_ name: String, transparent: Bool = false) throws -> CGImage {
            let texture = try library.loadTexture(path: "trick/doll/\(name).bin")
            var pixels = Array(texture.rgba)
            if transparent && (texture.mode == 3 || texture.mode == 4) {
                for index in texture.originalPixelData.indices where texture.originalPixelData[index] == 0 {
                    pixels[index * 4 + 3] = 0
                }
            }
            guard let image = OriginalEntrancePanels.rotated(rgba: Data(pixels), width: texture.storedWidth, height: texture.storedHeight) else {
                throw OriginalDataError.invalid("Doll sprite image")
            }
            return image
        }
        whole = try image("bg_doll01"); damaged = try image("bg_doll11"); repaired = try image("bg_doll12")
        wing = try image("wing01", transparent: true)
        point = try image("penpoint", transparent: true)
    }
    func render(_ puzzle: OriginalDollRepairProcess) throws -> CGImage {
        guard let context = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8, bytesPerRow: 768,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw OriginalDataError.invalid("Doll repair context")
        }
        context.interpolationQuality = .none
        context.draw(puzzle.showsWholeDoll ? whole : puzzle.repaired || puzzle.stage >= 2 && puzzle.phase == 1 ? repaired : damaged,
            in: .init(x: 0, y: 0, width: 192, height: 256))
        if !puzzle.showsWholeDoll {
            for stitch in puzzle.stitches where stitch.crossesSeam {
                context.saveGState()
                context.translateBy(x: CGFloat(stitch.start.x), y: CGFloat(256 - stitch.start.y))
                let dx = CGFloat(stitch.end.x - stitch.start.x), dy = CGFloat(stitch.start.y - stitch.end.y)
                context.rotate(by: atan2(dy, dx))
                let length = hypot(dx, dy)
                context.clip(to: .init(x: 0, y: -1, width: length, height: 2))
                // Source vertex colours 0x043F and 0x7FFF.
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [CGColor(red: 1, green: 8 / 255, blue: 8 / 255, alpha: 1),
                             CGColor(gray: 1, alpha: 1)] as CFArray, locations: [0, 1]) {
                    context.drawLinearGradient(gradient, start: .zero, end: .init(x: length, y: 0), options: [])
                }
                context.restoreGState()
            }
            for (index, touch) in puzzle.trail.enumerated() {
                context.setAlpha(CGFloat(index + 1) / 16)
                context.draw(point, in: .init(x: touch.x - 4, y: 256 - touch.y - 4, width: 8, height: 8))
            }
            context.setAlpha(1)
        } else if puzzle.showsFallingWing {
            context.saveGState()
            context.translateBy(x: 79, y: CGFloat(256 - puzzle.wingY - 18))
            context.rotate(by: -CGFloat(puzzle.wingAngle) * .pi / 180)
            context.draw(wing, in: .init(x: -29, y: -46, width: 80, height: 64))
            context.restoreGState()
        }
        guard let result = context.makeImage() else { throw OriginalDataError.invalid("Doll repair render") }
        return result
    }
}
