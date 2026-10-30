import CoreGraphics
import Foundation

@MainActor
final class OriginalChristmasTreeRenderer {
    private struct Decoration {
        let image: CGImage
        let alpha: [UInt8]
        let width: Int
        let height: Int
    }

    private let background: CGImage
    private let decorations: [Decoration]
    private let traySize = CGSize(width: 16, height: 16)
    private let treeSize = CGSize(width: 22, height: 22)

    init(library: OriginalBitmapLibrary) throws {
        let texture = try library.loadTexture(path: "trick/ChristmasTree/tree_s.bin")
        guard let background = OriginalEntrancePanels.rotated(rgba: texture.rgba,
            width: texture.storedWidth, height: texture.storedHeight) else {
            throw OriginalDataError.invalid("Christmas tree background")
        }
        self.background = background
        decorations = try (1...11).map { index in
            let texture = try library.loadTexture(path: "trick/ChristmasTree/kazari\(String(format: "%02d", index)).bin")
            guard texture.mode == 1,
                  let image = Self.image(texture.rgba, width: texture.storedWidth, height: texture.storedHeight) else {
                throw OriginalDataError.invalid("Christmas tree decoration \(index)")
            }
            let pixels = [UInt8](texture.rgba)
            return Decoration(image: image, alpha: stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] },
                              width: texture.storedWidth, height: texture.storedHeight)
        }
    }

    func render(_ process: OriginalChristmasTreeProcess, draggedDecoration: Int? = nil,
                at dragPoint: SIMD2<Float>? = nil) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("Christmas tree render context")
        }
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: 256)
        context.scaleBy(x: 1, y: -1)
        context.draw(background, in: CGRect(x: 0, y: 0, width: 192, height: 256))

        let placed = process.arrangement.decorationAtTarget
        for target in placed.indices {
            guard let decoration = placed[target], decoration != draggedDecoration else { continue }
            draw(decoration, at: OriginalChristmasTreeLayout.pageDecorationTargets[target],
                 size: treeSize, in: context)
        }
        for slot in process.decorationOrder.indices {
            let decoration = process.decorationOrder[slot]
            guard decoration != draggedDecoration, process.canPickDecoration(decoration) else { continue }
            draw(decoration, at: trayPoint(slot), size: traySize, in: context)
        }
        if let draggedDecoration, let dragPoint {
            draw(draggedDecoration, at: dragPoint, size: treeSize, in: context)
        }
        guard let image = context.makeImage() else { throw OriginalDataError.invalid("Christmas tree image") }
        return image
    }

    func decoration(at point: SIMD2<Float>, process: OriginalChristmasTreeProcess) -> Int? {
        let placed = process.arrangement.decorationAtTarget
        for target in placed.indices.reversed() {
            guard let decoration = placed[target],
                  hit(decoration, at: point, centre: OriginalChristmasTreeLayout.pageDecorationTargets[target],
                      size: treeSize) else { continue }
            return decoration
        }
        for slot in process.decorationOrder.indices.reversed() {
            let decoration = process.decorationOrder[slot]
            guard process.canPickDecoration(decoration),
                  hit(decoration, at: point, centre: trayPoint(slot), size: traySize) else { continue }
            return decoration
        }
        return nil
    }

    func target(at point: SIMD2<Float>) -> Int? {
        OriginalChristmasTreeLayout.decorationTarget(at: point)
    }

    private func draw(_ decoration: Int, at centre: SIMD2<Float>, size: CGSize, in context: CGContext) {
        guard decorations.indices.contains(decoration) else { return }
        let rect = CGRect(x: CGFloat(centre.x) - size.width / 2,
                          y: CGFloat(centre.y) - size.height / 2,
                          width: size.width, height: size.height)
        context.draw(decorations[decoration].image, in: rect)
    }

    private func hit(_ decoration: Int, at point: SIMD2<Float>, centre: SIMD2<Float>, size: CGSize) -> Bool {
        guard decorations.indices.contains(decoration), point.x.isFinite, point.y.isFinite else { return false }
        let rect = CGRect(x: CGFloat(centre.x) - size.width / 2,
                          y: CGFloat(centre.y) - size.height / 2,
                          width: size.width, height: size.height)
        guard rect.insetBy(dx: -2, dy: -2).contains(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))) else { return false }
        let sprite = decorations[decoration]
        for offsetY in -2...2 {
            for offsetX in -2...2 {
                let x = Int((CGFloat(point.x) - rect.minX + CGFloat(offsetX)) * CGFloat(sprite.width) / size.width)
                let y = Int((CGFloat(point.y) - rect.minY + CGFloat(offsetY)) * CGFloat(sprite.height) / size.height)
                guard (0..<sprite.width).contains(x), (0..<sprite.height).contains(y),
                      sprite.alpha[y * sprite.width + x] > 16 else { continue }
                return true
            }
        }
        return false
    }

    private func trayPoint(_ slot: Int) -> SIMD2<Float> {
        SIMD2(9 + Float(slot) * 17, 240)
    }

    private static func image(_ rgba: Data, width: Int, height: Int) -> CGImage? {
        OriginalArtwork.shared.image(rgba: rgba, width: width, height: height)
    }
}
