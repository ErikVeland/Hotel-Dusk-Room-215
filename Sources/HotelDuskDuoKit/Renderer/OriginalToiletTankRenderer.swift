import CoreGraphics
import Metal
import simd

@MainActor
public protocol OriginalToiletTankRendering: AnyObject {
    func render(_ puzzle: OriginalToiletTankProcess) throws -> CGImage
}

public typealias OriginalToiletTankRendererFactory = @MainActor () throws -> any OriginalToiletTankRendering

/// Original toilet model and the lid/flush pivots from overlay 26.
@MainActor
public final class OriginalToiletTankRenderer: OriginalToiletTankRendering {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let model: OriginalModelMetalPreview
    private let lid: Int
    private let handle: Int

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device; self.queue = queue
        let images = try OriginalBitmapLibrary.bundled()
        model = try OriginalModelMetalPreview(modelPath: "trick/toilet/toilet.mdf", models: .bundled(),
            textures: .bundled(), device: device, textureLoader: { try images.loadTexture(path: "trick/toilet/\($0).bin") })
        guard let lid = model.model.nodes.firstIndex(where: { $0.name == "cube49" }),
              let handle = model.model.nodes.firstIndex(where: { $0.name == "cyl2" }) else {
            throw OriginalDataError.invalid("Toilet tank model pivots")
        }
        self.lid = lid; self.handle = handle
    }
    public func render(_ puzzle: OriginalToiletTankProcess) throws -> CGImage {
        let body = Self.translation(.init(-3.32, -1.57, -1.26))
            * Self.rotation(180, .init(0, 1, 0)) * Self.rotation(-16.7, .init(1, 0, 0))
        let lidPivot = SIMD3<Float>(3.5, 0, 0.8), handlePivot = SIMD3<Float>(3.5, -2.48, 0)
        let nodes = [
            lid: Self.translation(lidPivot) * Self.rotation(puzzle.lidAngle, .init(0, 1, 0)) * Self.translation(-lidPivot),
            handle: Self.translation(handlePivot) * Self.rotation(puzzle.phase == 2 ? puzzle.flushAngle : 0, .init(0, 0, 1)) * Self.translation(-handlePivot)
        ]
        return try OriginalModelMetalPreview.render(width: 384, height: 512, device: device, queue: queue) { encoder in
            model.encode(encoder: encoder, viewProjection: Self.projection, visibleNodes: Set(model.model.nodes.indices), modelTransform: body, nodeTransforms: nodes)
        }
    }
    private static func translation(_ value: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4; matrix.columns.3 = SIMD4(value, 1); return matrix
    }
    private static func rotation(_ degrees: Float, _ axis: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(simd_quatf(angle: degrees * Float(bitPattern: 0x40490FD9) / 180, axis: axis))
    }
    private static var projection: simd_float4x4 {
        let sx: Float = 1 / tan(.pi / 12), sy = sx / Float(bitPattern: 0x3FAAE3DA)
        return simd_float4x4(columns: (SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, 60 / -59.9, -1), SIMD4(0, 0, 6 / -59.9, 0))) * translation(.init(0, 0, -4))
    }
}
