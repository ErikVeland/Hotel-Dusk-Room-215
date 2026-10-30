import CoreGraphics
import Foundation

@MainActor
final class OriginalCoinRenderer {
    private let coin: CGImage
    private let background: CGImage
    init() throws {
        let library = try OriginalBitmapLibrary.bundled()
        func image(_ name: String) throws -> CGImage {
            let texture = try library.loadTexture(path: "trick/coin/\(name).bin")
            guard let image = OriginalEntrancePanels.rotated(rgba: texture.rgba,
                width: texture.storedWidth, height: texture.storedHeight) else {
                throw OriginalDataError.invalid("Coin puzzle artwork")
            }
            return image
        }
        coin = try image("coin")
        background = try image("coin_bg")
    }
    func render(_ puzzle: OriginalCoinProcess) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("Coin puzzle context")
        }
        context.interpolationQuality = .none
        context.draw(background, in: .init(x: 0, y: 0, width: 192, height: 256))
        for index in puzzle.coins.indices.sorted(by: { puzzle.coins[$0].depth > puzzle.coins[$1].depth }) {
            let position = puzzle.coins[index].position
            context.draw(coin, in: .init(x: 96 + CGFloat(position.x) / 4096 * 96 - 19.2,
                y: 128 + CGFloat(position.y) / 4096 * 96 - 19.2, width: 38.4, height: 38.4))
        }
        guard let result = context.makeImage() else { throw OriginalDataError.invalid("Coin puzzle image") }
        return result
    }
}
