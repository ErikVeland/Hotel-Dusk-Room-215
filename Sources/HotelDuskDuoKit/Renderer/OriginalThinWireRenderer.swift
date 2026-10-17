import CoreGraphics
import Metal
import simd

/**
 * Original wire and suitcase models, followed by the lock bitmap layers from overlay 12.
 */
@MainActor
final class OriginalThinWireRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let bag: OriginalModelMetalPreview
    private let wire: OriginalModelMetalPreview
    private let layers: [CGImage]

    init(variant: OriginalThinWireProcess.Variant = .thin) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func load(_ name: String, directory: String = "bag") throws -> OriginalModelMetalPreview {
            try OriginalModelMetalPreview(modelPath: "trick/\(directory)/\(name).mdf", models: models,
                textures: textures, device: device, textureLoader: { name in
                    try OriginalTexture(data: bitmaps.loadLinear(path: "trick/\(directory)/\(name).bin").decodedPayload)
                })
        }
        bag = try load("kaban")
        wire = try variant == .thin ? load("harigane") : load("kitasen", directory: "hanger")
        layers = try ["hole", "01", "02", "03", "bg"].map { name in
            let bitmap = try bitmaps.loadLinear(path: "trick/bag/\(name).bin")
            guard let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: true),
                width: bitmap.width, height: bitmap.height) else {
                throw OriginalDataError.invalid("Thin-wire lock bitmap")
            }
            return image
        }
    }

    func render(_ puzzle: OriginalThinWireProcess) throws -> CGImage {
        if puzzle.showsLock { return try renderLock(puzzle) }
        let projection = OriginalSuitcaseProjection.viewProjection(eye: puzzle.eye, target: puzzle.target)
        return try OriginalModelMetalPreview.render(width: 192, height: 256, device: device, queue: queue) { encoder in
            wire.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(wire.model.nodes.indices),
                modelTransform: Self.transform(position: puzzle.drawnWire,
                    scale: puzzle.variant == .thin ? 0.006 : 0.06,
                    angles: puzzle.variant == .thin ? SIMD3(0.02, 0.98, 0.99) : SIMD3(0.5, 0, 0)))
            let base = Self.transform(position: SIMD3(-614, 984, -2009), scale: 0.73, angles: .zero)
            for node in bag.model.nodes.indices {
                let opening = puzzle.showsOpening && (1...4).contains(node) ? puzzle.lidRotation : 0
                let rotation = Self.transform(position: .zero, scale: 1, angles: SIMD3(opening, 0, 0))
                bag.encode(encoder: encoder, viewProjection: projection, visibleNodes: [node], modelTransform: base * rotation)
            }
        }
    }

    private func renderLock(_ puzzle: OriginalThinWireProcess) throws -> CGImage {
        guard let context = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8, bytesPerRow: 192 * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw OriginalDataError.invalid("Thin-wire lock image context")
        }
        context.interpolationQuality = .none
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 192, height: 256))
        context.saveGState()
        context.translateBy(x: 96, y: 128)
        context.rotate(by: -CGFloat(puzzle.lockRotation) * .pi)
        context.translateBy(x: -96, y: -128)
        context.draw(layers[0], in: CGRect(x: 32, y: 64, width: 128, height: 128))
        for (index, pin) in puzzle.pins.enumerated() {
            context.draw(layers[index + 1], in: CGRect(x: 80 + CGFloat(pin.position.x) * 96 / 4096,
                y: 112 + CGFloat(pin.position.y) * 96 / 4096, width: 32, height: 32))
        }
        context.restoreGState()
        context.draw(layers[4], in: CGRect(x: 0, y: 0, width: 192, height: 256))
        if puzzle.cursorVisible {
            // 0x02202374 draws the ten fixed-point vertices initialised at process offset 0x60C.
            let points: [SIMD2<Int32>] = [.init(205, 0), .init(166, 120), .init(63, 195), .init(-63, 195),
                .init(-166, 120), .init(-205, 0), .init(-166, -120), .init(-63, -195), .init(63, -195), .init(166, -120)]
            context.beginPath()
            for (index, point) in points.enumerated() {
                let radius = puzzle.contactRadius / 0.05
                let vertex = CGPoint(x: 96 + CGFloat(Float(puzzle.cursor.x) + Float(point.x) * radius) * 96 / 4096,
                    y: 128 + CGFloat(Float(puzzle.cursor.y) + Float(point.y) * radius) * 96 / 4096)
                if index == 0 { context.move(to: vertex) } else { context.addLine(to: vertex) }
            }
            context.closePath()
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fillPath()
        }
        guard let image = context.makeImage() else { throw OriginalDataError.invalid("Thin-wire lock image") }
        return image
    }

    private static func transform(position: SIMD3<Int32>, scale: Float, angles: SIMD3<Float>) -> simd_float4x4 {
        let x = simd_float4x4(simd_quatf(angle: -angles.x * .pi, axis: SIMD3(1, 0, 0)))
        let y = simd_float4x4(simd_quatf(angle: -angles.y * .pi, axis: SIMD3(0, 1, 0)))
        let z = simd_float4x4(simd_quatf(angle: -angles.z * .pi, axis: SIMD3(0, 0, 1)))
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4(SIMD3<Float>(position) / 4096, 1)
        return translation * z * y * x * simd_float4x4(diagonal: SIMD4(scale, scale, scale, 1))
    }
}
