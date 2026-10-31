import CoreGraphics
import Foundation
import Metal
import simd

@MainActor
public protocol OriginalBowlingRendering: AnyObject {
    func render(_ state: OriginalBowlingRenderer.SceneState) throws -> CGImage
}

public typealias OriginalBowlingRendererFactory = @MainActor () throws -> any OriginalBowlingRendering

/**
 * Renders overlay 11's bowling models from the source camera and process state.
 */
@MainActor
public final class OriginalBowlingRenderer: OriginalBowlingRendering {
    public struct SceneState: Equatable, Sendable {
        public let camera: OriginalBowlingCameraBasis
        public let ballPosition: SIMD3<Float>
        public let pins: [OriginalBowlingPinField.Pin]

        public init(cameraMatrixFixed20_12: [Int32], ballPositionFixed20_12: SIMD3<Int32>,
                    pins: [OriginalBowlingPinField.Pin]) throws {
            guard let camera = OriginalBowlingCameraBasis(matrixFixed20_12: cameraMatrixFixed20_12),
                  pins.count == OriginalBowlingPinField.pinCount else {
                throw OriginalDataError.invalid("Bowling scene state")
            }
            self.camera = camera
            ballPosition = SIMD3(Float(ballPositionFixed20_12.x), Float(ballPositionFixed20_12.y),
                                 Float(ballPositionFixed20_12.z)) / 4_096
            self.pins = pins
        }
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let lane: OriginalModelMetalPreview
    private let ball: OriginalModelMetalPreview
    private let pin: OriginalModelMetalPreview
    private let viewProjection: simd_float4x4

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let models = try OriginalModelLibrary.bundled()
        let textures = try OriginalTextureLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func texture(_ name: String) throws -> OriginalTexture {
            let archivedName = [
                "R119_tenjyo01": "_tenjyo01",
                "R119_yuka03": "_yuka03",
                "R119_kabe02_S": "_kabe02_S"
            ][name] ?? name
            return try bitmaps.loadTexture(path: "trick/bowling/\(archivedName).bin")
        }
        lane = try OriginalModelMetalPreview(modelPath: "trick/bowling/2Frouka.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        ball = try OriginalModelMetalPreview(modelPath: "trick/bowling/boulball.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        pin = try OriginalModelMetalPreview(modelPath: "trick/bowling/boulpin.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        viewProjection = Self.projection
    }

    public func render(_ state: SceneState) throws -> CGImage {
        let view = Self.view(camera: state.camera)
        let camera = viewProjection * view
        let pinInstances = state.pins.filter(\.isActive).map { value in
            Self.translation(Self.position(value.positionFixed20_12)) * Self.rotationY(value.directionAngle)
                * Self.rotationX(value.rotation)
        }
        let pinNodes = Dictionary(uniqueKeysWithValues: pin.model.nodes.indices.map { ($0, pinInstances) })
        let scene = try OriginalModelMetalPreview.render(width: 1024, height: 768,
            device: device, queue: queue) { encoder in
                lane.encode(encoder: encoder, viewProjection: camera,
                            visibleNodes: Set(lane.model.nodes.indices))
                ball.encode(encoder: encoder, viewProjection: camera,
                            visibleNodes: Set(ball.model.nodes.indices),
                            modelTransform: Self.translation(state.ballPosition))
                pin.encode(encoder: encoder, viewProjection: camera,
                           visibleNodes: Set(pin.model.nodes.indices), nodeInstances: pinNodes)
            }
        guard let context = OriginalArtwork.pageContext(width: 256, height: 192) else {
            throw OriginalDataError.invalid("Bowling composition")
        }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 256, height: 192))
        context.draw(scene, in: CGRect(x: 0, y: 0, width: 256, height: 192))
        guard let combined = context.makeImage(),
              let page = OriginalArtwork.shared.rotatedImage(combined, logicalWidth: 256, logicalHeight: 192) else {
            throw OriginalDataError.invalid("Bowling scene image")
        }
        return page
    }

    func ballHitMask(_ state: SceneState) throws -> OriginalModelProjectedMask {
        try OriginalModelProjectedMask(model: ball.model,
            viewProjection: viewProjection * Self.view(camera: state.camera),
            modelTransform: Self.translation(state.ballPosition), width: 256, height: 192)
    }

    func selectsBall(pagePoint: SIMD2<Float>, state: SceneState, padding: Float = 4) throws -> Bool {
        guard pagePoint.x.isFinite, pagePoint.y.isFinite,
              (0..<192).contains(pagePoint.x), (0..<256).contains(pagePoint.y) else { return false }
        let sourcePoint = SIMD2(255 - pagePoint.y, pagePoint.x)
        return try ballHitMask(state).depth(at: sourcePoint, padding: padding) != nil
    }

    private static func position(_ fixed: SIMD3<Int32>) -> SIMD3<Float> {
        SIMD3(Float(fixed.x), Float(fixed.y), Float(fixed.z)) / 4_096
    }

    private static func translation(_ value: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4(value, 1)
        return matrix
    }

    private static func rotationX(_ angle: Float) -> simd_float4x4 {
        simd_float4x4(simd_quatf(angle: angle, axis: SIMD3(1, 0, 0)))
    }

    private static func rotationY(_ angle: Float) -> simd_float4x4 {
        simd_float4x4(simd_quatf(angle: angle, axis: SIMD3(0, 1, 0)))
    }

    private static func view(camera: OriginalBowlingCameraBasis) -> simd_float4x4 {
        let backward = -camera.forward
        return simd_float4x4(columns: (
            SIMD4(camera.right.x, camera.up.x, backward.x, 0),
            SIMD4(camera.right.y, camera.up.y, backward.y, 0),
            SIMD4(camera.right.z, camera.up.z, backward.z, 0),
            SIMD4(-simd_dot(camera.right, camera.origin), -simd_dot(camera.up, camera.origin),
                  -simd_dot(backward, camera.origin), 1)))
    }

    private static var projection: simd_float4x4 {
        let near: Float = 0.1
        let far: Float = 100
        let focalLength = 1 / tan(OriginalBowlingTouchRay.projectionAngleDegrees * .pi / 180)
        return simd_float4x4(columns: (
            SIMD4(focalLength, 0, 0, 0),
            SIMD4(0, focalLength, 0, 0),
            SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, near * far / (near - far), 0)))
    }
}
