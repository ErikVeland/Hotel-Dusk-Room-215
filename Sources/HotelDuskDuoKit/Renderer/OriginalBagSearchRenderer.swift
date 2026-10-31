import CoreGraphics
import Foundation
import Metal
import simd

@MainActor
public protocol OriginalBagSearchRendering: AnyObject {
    func render(_ process: OriginalBagSearchProcess) throws -> CGImage
    func object(at point: SIMD2<Float>, process: OriginalBagSearchProcess) throws -> Int?
    func planePointFixed(at point: SIMD2<Float>) -> SIMD2<Int32>?
}

public typealias OriginalBagSearchRendererFactory = @MainActor () throws -> any OriginalBagSearchRendering

/**
 * Renders overlay 30's cube field and derives touch masks from its MDF geometry.
 */
@MainActor
public final class OriginalBagSearchRenderer: OriginalBagSearchRendering {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let model: OriginalModelMetalPreview
    private let projection: OriginalBagSearchProjection

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let bitmaps = try OriginalBitmapLibrary.bundled()
        model = try OriginalModelMetalPreview(modelPath: "trick/searchshed/soko.mdf",
            models: .bundled(), textures: .bundled(), device: device,
            textureLoader: { textureName in
                try bitmaps.loadTexture(path: "trick/searchshed/\(textureName).bin")
            })
        projection = try OriginalBagSearchProjection(models: [model.model])
    }

    public func render(_ process: OriginalBagSearchProcess) throws -> CGImage {
        try OriginalModelMetalPreview.render(width: 384, height: 512, device: device, queue: queue) { encoder in
            let instances = process.objects.filter { $0.type != nil }.map {
                Self.translation(Self.position($0.positionFixed)) * Self.scale($0.scale)
            }
            model.encode(encoder: encoder, viewProjection: projection.viewProjection,
                         visibleNodes: [2], nodeInstances: [2: instances])
        }
    }

    /**
     * Returns the nearest object's projected model surface at a page point.
     */
    public func object(at point: SIMD2<Float>, process: OriginalBagSearchProcess) throws -> Int? {
        try projection.object(at: point, process: process)
    }

    /**
     * Maps a page point to the source object's horizontal plane in 20.12 units.
     */
    public func planePointFixed(at point: SIMD2<Float>) -> SIMD2<Int32>? {
        projection.planePointFixed(at: point)
    }

    private static func position(_ fixed: SIMD3<Int32>) -> SIMD3<Float> {
        SIMD3(Float(fixed.x), Float(fixed.y), Float(fixed.z)) / 4_096
    }

    private static func translation(_ value: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4(value, 1)
        return matrix
    }

    private static func scale(_ value: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(columns: (SIMD4(value.x, 0, 0, 0), SIMD4(0, value.y, 0, 0),
                                SIMD4(0, 0, value.z, 0), SIMD4(0, 0, 0, 1)))
    }
}
