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

    func render(_ puzzle: OriginalCoinEdgeProcess) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("Coin edge puzzle context")
        }
        context.interpolationQuality = .none
        context.draw(background, in: .init(x: 0, y: 0, width: 192, height: 256))
        context.setLineCap(.butt)
        context.setLineWidth(2)

        for (edge, state) in puzzle.edgeStates.sorted(by: { left, right in
            if left.key.row != right.key.row { return left.key.row < right.key.row }
            if left.key.column != right.key.column { return left.key.column < right.key.column }
            return left.key.orientation.rawValue < right.key.orientation.rawValue
        }) where state != .absent {
            context.setStrokeColor(state == .selected
                ? CGColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 1)
                : CGColor(red: 0.48, green: 0.42, blue: 0.34, alpha: 0.55))
            let row = edge.row
            let column = edge.column
            let x = puzzle.xOffset - row * 3 + column * 6
            let y = 32 + (puzzle.yOffset + (row + column + 1) * 6) * 8
            let start: CGPoint
            let end: CGPoint
            switch edge.orientation {
            case .horizontal:
                let left = (puzzle.xOffset + column * 6) * 8
                let top = (puzzle.yOffset + row * 6 + 4) * 8
                start = CGPoint(x: left, y: top + 4)
                end = CGPoint(x: left + 40, y: top + 4)
            case .vertical:
                let left = (puzzle.xOffset + column * 6 - 1) * 8
                let top = (puzzle.yOffset + row * 6 + 5) * 8
                start = CGPoint(x: left + 4, y: top)
                end = CGPoint(x: left + 4, y: top + 40)
            case .triangleA:
                let left = (x + 1) * 8
                start = CGPoint(x: left, y: y)
                end = CGPoint(x: left + 40, y: y)
            case .triangleB:
                let left = x * 8
                start = CGPoint(x: left, y: y)
                end = CGPoint(x: left + 21 * 8, y: y - 39 * 8)
            case .triangleC:
                let left = (x + 5) * 8
                start = CGPoint(x: left, y: y - 8 * 8)
                end = CGPoint(x: left - 14 * 8, y: y - 39 * 8)
            }
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        }

        guard let result = context.makeImage() else {
            throw OriginalDataError.invalid("Coin edge puzzle image")
        }
        return result
    }
}
