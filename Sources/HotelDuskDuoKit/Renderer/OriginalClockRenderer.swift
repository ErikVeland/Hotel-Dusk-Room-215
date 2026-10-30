import CoreGraphics

/**
 * Original clock and TalkTime bitmap layers in book-page coordinates.
 */
@MainActor
final class OriginalClockRenderer {
    private let clock: CGImage
    private let hands: [CGImage]
    private let label: CGImage
    private let layers: [CGImage]

    init(process: OriginalClockProcess, library: OriginalBitmapLibrary) throws {
        func image(_ path: String, transparentZero: Bool = true) throws -> CGImage {
            let bitmap = try library.loadLinear(path: path)
            guard let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: transparentZero),
                width: bitmap.width, height: bitmap.height) else {
                throw OriginalDataError.invalid("Clock bitmap")
            }
            return image
        }
        clock = try image("trick/clock/clock.bin", transparentZero: false)
        hands = try ["sec", "min", "hour"].map { try image("trick/clock/\($0).bin") }
        label = try image("talktest/TalkTime/\(process.bitmapName).bin")
        let period = process.label.hasSuffix("AM") ? "am" : "pm"
        layers = try (1...6).map { try image("talktest/TalkTime/\($0 < 4 ? "m" : period)0\($0).bin") }
    }

    func render(_ process: OriginalClockProcess) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("Clock image context")
        }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 192, height: 256))
        context.interpolationQuality = .none
        func draw(_ image: CGImage, rect: CGRect, alpha: CGFloat) {
            context.saveGState()
            context.setAlpha(max(0, min(1, alpha)))
            context.draw(image, in: CGRect(x: rect.minX, y: 256 - rect.maxY, width: rect.width, height: rect.height))
            context.restoreGState()
        }
        draw(clock, rect: CGRect(x: 32, y: 24, width: 128, height: 128), alpha: CGFloat(process.alpha) / 31)
        for (hand, angle) in zip(hands, process.handAngles) {
            context.saveGState()
            // The original orthographic matrix has X scale 3068/4096. Its hand pivot is (0, 164).
            let verticalScale: CGFloat = 128 * 3068 / 4096
            let centreY = 128 - CGFloat(1707) / 4096 * verticalScale
            context.translateBy(x: 96, y: 256 - centreY)
            context.scaleBy(x: 96, y: verticalScale)
            context.rotate(by: -CGFloat(angle) * .pi)
            context.setAlpha(1)
            context.draw(hand, in: CGRect(x: -CGFloat(164) / 4096, y: -CGFloat(hand.height) / 128,
                width: CGFloat(hand.width) / 96, height: CGFloat(hand.height) / 128))
            context.restoreGState()
        }
        if let state = process.labelDraw {
            let image = state.layer < 0 ? label : layers[state.layer]
            let rect: CGRect
            if state.layer < 0 { rect = CGRect(x: 40, y: 178, width: 108, height: 32) }
            else if state.layer < 3 { rect = CGRect(x: 32, y: 178, width: 128, height: 26) }
            else { rect = CGRect(x: 40, y: 159, width: 108, height: 64) }
            draw(image, rect: rect, alpha: CGFloat(state.alpha) / 31)
        }
        guard let result = context.makeImage() else { throw OriginalDataError.invalid("Clock image") }
        return result
    }
}
