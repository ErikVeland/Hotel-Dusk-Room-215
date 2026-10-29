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
 * Renders overlay 3's box field and derives touch masks from its MDF geometry.
 */
@MainActor
public final class OriginalBagSearchRenderer: OriginalBagSearchRendering {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let models: [OriginalModelMetalPreview]
    private let projection: OriginalBagSearchProjection
    private let backgroundNodes: Set<Int>

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let bitmaps = try OriginalBitmapLibrary.bundled()
        let paths = ["p01", "p02", "p03", "kaban"]
        let previews = try paths.map { name in
            try OriginalModelMetalPreview(modelPath: "trick/bag/\(name).mdf", models: .bundled(),
                textures: .bundled(), device: device,
                textureLoader: { textureName in
                    let bitmap = try bitmaps.loadLinear(path: "trick/bag/\(textureName).bin")
                    return try OriginalTexture(data: bitmap.decodedPayload)
                }, untexturedMaterials: name == "kaban" ? [] : [0])
        }
        models = previews
        projection = try OriginalBagSearchProjection(models: previews.map(\.model))
        backgroundNodes = Set([12, 13, 14, 15, 16])
    }

    public func render(_ process: OriginalBagSearchProcess) throws -> CGImage {
        try OriginalModelMetalPreview.render(width: 192, height: 256, device: device, queue: queue) { encoder in
            models[3].encode(encoder: encoder, viewProjection: projection.viewProjection,
                             visibleNodes: backgroundNodes)
            for type in models.indices {
                var instances = [simd_float4x4]()
                for object in process.objects where object.type == type {
                    instances.append(Self.translation(Self.position(object.positionFixed))
                        * Self.scale(object.scale))
                }
                guard !instances.isEmpty else { continue }
                let transforms = Dictionary(uniqueKeysWithValues: projection.nodesByType[type].map { ($0, instances) })
                models[type].encode(encoder: encoder, viewProjection: projection.viewProjection,
                                    visibleNodes: projection.nodesByType[type], nodeInstances: transforms)
            }
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
