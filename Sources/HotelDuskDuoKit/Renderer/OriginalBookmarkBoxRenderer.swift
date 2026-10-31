import CoreGraphics
import Metal
import simd

/// Original box model, independently hinged flaps, and the bookmark extraction layers.
@MainActor
final class OriginalBookmarkBoxRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let box: OriginalModelMetalPreview
    private let arrow: CGImage
    private let bookmark: CGImage
    private let lid: CGImage
    private let background: CGImage
    private let item: CGImage

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device; self.queue = queue
        let images = try OriginalBitmapLibrary.bundled()
        func texture(_ name: String) throws -> OriginalTexture { try images.loadTexture(path: "trick/corrugated/\(name).bin") }
        func image(_ name: String) throws -> CGImage {
            guard let image = try texture(name).makeCGImage() else { throw OriginalDataError.invalid("Bookmark box texture") }
            return image
        }
        box = try OriginalModelMetalPreview(modelPath: "trick/corrugated/box0307.mdf", models: .bundled(),
            textures: .bundled(), device: device, textureLoader: texture)
        arrow = try image("arrow"); bookmark = try image("_01bookmar")
        lid = try image("_02lid"); background = try image("_03bg_box")
        item = try OriginalInventoryArtwork.shared.image(for: 25)
    }

    func render(_ puzzle: OriginalBookmarkBoxProcess) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else {
            throw OriginalDataError.invalid("Bookmark box context")
        }
        context.interpolationQuality = .none
        func draw(_ image: CGImage, _ rect: CGRect) {
            context.draw(image, in: CGRect(x: rect.minX, y: 256 - rect.maxY, width: rect.width, height: rect.height))
        }
        if puzzle.phase < 2 {
            let angle = SIMD3<Float>(puzzle.angles) * (Float(bitPattern: 0x40490FD9) / 180)
            let body = Self.translation(.init(0, -1, -15 + puzzle.shake))
                * Self.rotation(angle.y, .init(0, 1, 0))
                * Self.rotation(angle.x, .init(1, 0, 0))
                * Self.rotation(angle.z, .init(0, 0, 1))
            let flaps: [Int: simd_float4x4] = [
                2: Self.translation(.init(5, 2.5, -1.5)) * Self.rotation(-230 * .pi / 180, .init(0, 0, 1)) * Self.translation(.init(-5, -2.5, 1.5)),
                5: Self.translation(.init(-5, 2.5, -1.5)) * Self.rotation(230 * .pi / 180, .init(0, 0, 1)) * Self.translation(.init(5, -2.5, 1.5)),
                3: Self.translation(.init(0, 2.5, 6.5)) * Self.rotation(248 * .pi / 180, .init(1, 0, 0)) * Self.translation(.init(0, -2.5, -6.5)),
                4: Self.translation(.init(0, 2.5, -6.588)) * Self.rotation(-248 * .pi / 180, .init(1, 0, 0)) * Self.translation(.init(0, -2.5, 6.588))
            ]
            let scene = try OriginalModelMetalPreview.render(width: 768, height: 1024, device: device, queue: queue) { encoder in
                box.encode(encoder: encoder, viewProjection: Self.projection, visibleNodes: Set(box.model.nodes.indices.filter { $0 != 6 || puzzle.taps >= 10 }),
                    modelTransform: body, nodeTransforms: flaps)
            }
            draw(scene, .init(x: 0, y: 0, width: 192, height: 256))
            for i in 0..<4 {
                context.saveGState()
                let centers: [CGPoint] = [.init(x: 96, y: 16), .init(x: 16, y: 128), .init(x: 104, y: 240), .init(x: 176, y: 128)]
                context.translateBy(x: centers[i].x, y: 256 - centers[i].y)
                context.rotate(by: CGFloat(i + 1) * .pi / 2)
                context.setAlpha(CGFloat(puzzle.arrowAlpha[i]) / 31)
                context.draw(arrow, in: .init(x: -16, y: -16, width: 32, height: 32))
                context.restoreGState()
            }
        } else {
            // Source vertices at 0x021FF5FC, 0x021FFA1C and 0x021FFE1C.
            draw(background, .init(x: 0, y: 0, width: 192, height: 256))
            if puzzle.itemAlpha > 0 {
                context.setAlpha(CGFloat(puzzle.itemAlpha) / 31)
                draw(item, .init(x: 32, y: 64, width: 128, height: 128))
                context.setAlpha(1)
            }
            context.setAlpha(CGFloat(31 - puzzle.itemAlpha) / 31)
            draw(bookmark, .init(x: CGFloat(puzzle.bookmarkX - 2), y: 123, width: 128, height: 66))
            context.setAlpha(1)
            if puzzle.itemAlpha < 31 { draw(lid, .init(x: 25, y: 0, width: 64, height: 256)) }
        }
        guard let result = context.makeImage() else { throw OriginalDataError.invalid("Bookmark box render") }
        return result
    }
    private static func translation(_ value: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4; matrix.columns.3 = SIMD4(value, 1); return matrix
    }
    private static func rotation(_ angle: Float, _ axis: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(simd_quatf(angle: angle, axis: axis))
    }
    private static var projection: simd_float4x4 {
        let sx: Float = 1 / tan(.pi / 6), sy = sx / Float(bitPattern: 0x3FAAE3DA)
        return simd_float4x4(columns: (SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, 60 / -59.9, -1), SIMD4(0, 0, 6 / -59.9, 0))) * translation(.init(0, 0, -4))
    }
}
