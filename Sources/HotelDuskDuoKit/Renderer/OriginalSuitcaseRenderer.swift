import CoreGraphics
import Metal
import simd

@MainActor
public protocol OriginalSuitcaseRendering: AnyObject {
    func render(_ puzzle: OriginalSuitcaseKeyProcess) throws -> CGImage
}

public typealias OriginalSuitcaseRendererFactory = @MainActor () throws -> any OriginalSuitcaseRendering

/**
 * Original suitcase and key models, including their BIN textures and process transforms.
 */
@MainActor
public final class OriginalSuitcaseRenderer: OriginalSuitcaseRendering {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let bag: OriginalModelMetalPreview
    private let key: OriginalModelMetalPreview
    private let brokenKey: OriginalModelMetalPreview

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func load(_ name: String) throws -> OriginalModelMetalPreview {
            try OriginalModelMetalPreview(modelPath: "trick/bag/\(name).mdf", models: models,
                textures: textures, device: device, textureLoader: { name in
                    let bitmap = try bitmaps.loadLinear(path: "trick/bag/\(name).bin")
                    return try OriginalTexture(data: bitmap.decodedPayload)
                })
        }
        bag = try load("kaban")
        key = try load("KEY_01")
        brokenKey = try load("KEY_02")
    }

    public func render(_ puzzle: OriginalSuitcaseKeyProcess) throws -> CGImage {
        let projection = OriginalSuitcaseProjection.viewProjection(eye: puzzle.eye, target: puzzle.target)
        let currentKey = puzzle.isBroken ? brokenKey : key
        return try OriginalModelMetalPreview.render(width: 192, height: 256, device: device, queue: queue) { encoder in
            currentKey.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(currentKey.model.nodes.indices),
                modelTransform: Self.transform(position: puzzle.drawnKey, scale: puzzle.keyScale,
                    roll: puzzle.keyRoll, turn: puzzle.keyTurn))
            bag.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(bag.model.nodes.indices),
                modelTransform: Self.transform(position: puzzle.bag, scale: 0.73, roll: 0, turn: 0))
        }
    }

    /**
     * 0x02202950 applies scale, negative Euler angles in units of π, then translation.
     */
    private static func transform(position: SIMD3<Int32>, scale: Float, roll: Float, turn: Float) -> simd_float4x4 {
        let x = simd_float4x4(simd_quatf(angle: -roll * .pi, axis: SIMD3(1, 0, 0)))
        let z = simd_float4x4(simd_quatf(angle: -turn * .pi, axis: SIMD3(0, 0, 1)))
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4(SIMD3<Float>(position) / 4096, 1)
        return translation * z * x * simd_float4x4(diagonal: SIMD4(scale, scale, scale, 1))
    }
}
