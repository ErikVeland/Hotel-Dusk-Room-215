import CoreGraphics
import Foundation
import Metal
import simd

/**
 * Renders overlay 28's cassette-deck models from captured source transforms.
 */
@MainActor
final class OriginalCassetteDeckRenderer {
    enum Object: Hashable {
        case radio
        case front
        case tape
    }

    struct ModelTransform: Equatable, Sendable {
        let rotationDegrees: SIMD3<Float>
        let translation: SIMD3<Float>

        init(rotationDegrees: SIMD3<Float>, translation: SIMD3<Float>) {
            self.rotationDegrees = rotationDegrees
            self.translation = translation
        }

        var matrix: simd_float4x4 {
            Self.translationMatrix(translation)
                * Self.rotationMatrix(rotationDegrees.z, axis: SIMD3(0, 0, 1))
                * Self.rotationMatrix(rotationDegrees.y, axis: SIMD3(0, 1, 0))
                * Self.rotationMatrix(rotationDegrees.x, axis: SIMD3(1, 0, 0))
        }

        private static func translationMatrix(_ value: SIMD3<Float>) -> simd_float4x4 {
            var matrix = matrix_identity_float4x4
            matrix.columns.3 = SIMD4(value, 1)
            return matrix
        }

        private static func rotationMatrix(_ degrees: Float, axis: SIMD3<Float>) -> simd_float4x4 {
            simd_float4x4(simd_quatf(angle: degrees * .pi / 180, axis: axis))
        }
    }

    struct SceneState: Equatable, Sendable {
        let radio: ModelTransform
        let front: ModelTransform
        let tape: ModelTransform
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let radio: OriginalModelMetalPreview
    private let front: OriginalModelMetalPreview
    private let tape: OriginalModelMetalPreview

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let bitmaps = try OriginalBitmapLibrary.bundled()
        let models = try OriginalModelLibrary.bundled()
        let textures = try OriginalTextureLibrary.bundled()
        func texture(_ name: String) throws -> OriginalTexture {
            try bitmaps.loadTexture(path: "trick/cassette02/\(name).bin")
        }
        radio = try OriginalModelMetalPreview(modelPath: "trick/cassette02/radio.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        front = try OriginalModelMetalPreview(modelPath: "trick/cassette02/front.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        tape = try OriginalModelMetalPreview(modelPath: "trick/cassette02/tape.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
    }

    func render(camera: OriginalCassetteDeckCamera, state: SceneState) throws -> CGImage {
        let scene = try OriginalModelMetalPreview.render(width: 256, height: 192,
            device: device, queue: queue) { encoder in
                radio.encode(encoder: encoder, viewProjection: camera.viewProjection,
                    visibleNodes: Set(radio.model.nodes.indices), modelTransform: state.radio.matrix)
                front.encode(encoder: encoder, viewProjection: camera.viewProjection,
                    visibleNodes: Set(front.model.nodes.indices), modelTransform: state.front.matrix)
                tape.encode(encoder: encoder, viewProjection: camera.viewProjection,
                    visibleNodes: Set(tape.model.nodes.indices), modelTransform: state.tape.matrix)
            }
        var rgba = Data(count: 256 * 192 * 4)
        rgba.withUnsafeMutableBytes { storage in
            guard let context = CGContext(data: storage.baseAddress, width: 256, height: 192,
                bitsPerComponent: 8, bytesPerRow: 256 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 192))
            context.interpolationQuality = .none
            context.draw(scene, in: CGRect(x: 0, y: 0, width: 256, height: 192))
        }
        guard let page = OriginalEntrancePanels.rotated(rgba: rgba, width: 256, height: 192) else {
            throw OriginalDataError.invalid("Cassette-deck scene image")
        }
        return page
    }

    func hitMask(for object: Object, camera: OriginalCassetteDeckCamera,
                 state: SceneState) throws -> OriginalModelProjectedMask {
        let model: OriginalModel
        let transform: ModelTransform
        switch object {
        case .radio:
            model = radio.model
            transform = state.radio
        case .front:
            model = front.model
            transform = state.front
        case .tape:
            model = tape.model
            transform = state.tape
        }
        return try OriginalModelProjectedMask(model: model, viewProjection: camera.viewProjection,
            modelTransform: transform.matrix, width: 256, height: 192)
    }

    /**
     * Selects the nearest visible model through its projected mesh mask.
     */
    func hitTest(pagePoint: SIMD2<Float>, camera: OriginalCassetteDeckCamera,
                 state: SceneState, padding: Float = 8) throws -> Object? {
        guard pagePoint.x.isFinite, pagePoint.y.isFinite,
              (0..<192).contains(pagePoint.x), (0..<256).contains(pagePoint.y) else { return nil }
        let sourcePoint = SIMD2(255 - pagePoint.y, pagePoint.x)
        let candidates = try [Object.radio, .front, .tape].compactMap { object -> (Object, Float)? in
            guard let depth = try hitMask(for: object, camera: camera, state: state)
                .depth(at: sourcePoint, padding: padding) else { return nil }
            return (object, depth)
        }
        return candidates.min { $0.1 < $1.1 }?.0
    }
}
