import CoreGraphics
import Foundation

@MainActor
final class OriginalFountainPenRenderer {
    private let surface: OriginalBitmap
    private let dust: OriginalBitmap
    private let chalked: CGImage
    private let unclear: CGImage
    private let inscription: CGImage

    init() throws {
        let library = try OriginalBitmapLibrary.bundled()
        func bitmap(_ name: String) throws -> OriginalBitmap { try library.load(path: "trick/faunainpen/\(name).bin") }
        func image(_ name: String) throws -> CGImage {
            let bitmap = try bitmap(name)
            guard let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: false),
                width: bitmap.width, height: bitmap.height) else { throw OriginalDataError.invalid("Fountain pen picture") }
            return image
        }
        surface = try bitmap("001R"); dust = try bitmap("closeup3")
        chalked = try image("002R"); unclear = try image("unclear"); inscription = try image("closeupR")
    }

    func makeProcess(seed: UInt32) throws -> OriginalFountainPenProcess {
        try .init(surface: Array(surface.decodedPayload.suffix(0xC000)),
                  dust: Array(dust.decodedPayload.suffix(0xC000)), seed: seed)
    }

    func render(_ puzzle: OriginalFountainPenProcess) throws -> CGImage {
        let original = puzzle.phase < 2 ? surface : dust
        var payload = Data(original.decodedPayload.prefix(528))
        payload.append(contentsOf: puzzle.mask)
        let foreground = try OriginalBitmap(data: payload)
        guard let image = OriginalEntrancePanels.rotated(rgba: foreground.rgba(transparentPaletteZero: true),
                width: 256, height: 192),
              let context = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8, bytesPerRow: 768,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw OriginalDataError.invalid("Fountain pen image context")
        }
        context.interpolationQuality = .none
        let frame = CGRect(x: 0, y: 0, width: 192, height: 256)
        context.draw(puzzle.phase < 2 ? chalked : puzzle.inscriptionVisible ? inscription : unclear, in: frame)
        context.draw(image, in: frame)
        guard let result = context.makeImage() else { throw OriginalDataError.invalid("Fountain pen render") }
        return result
    }
}
