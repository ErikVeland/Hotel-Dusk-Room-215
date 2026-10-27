import CoreGraphics
import Foundation
import Metal
import simd

/**
 * Renders the recovered cassette, writing tool and source background from overlay 25.
 */
@MainActor
final class OriginalCassetteRenderer {
    enum Tool: Equatable {
        case ballpoint
        case pencil
    }

    enum MaskedObject: Hashable {
        case tape
        case tool
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let tape: OriginalModelMetalPreview
    private let tool: OriginalModelMetalPreview
    private let tableSurface: CassetteTableSurface
    private let background: CGImage
    private var hitMasks: [MaskedObject: OriginalModelProjectedMask] = [:]

    init(tool: Tool) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func texture(_ name: String) throws -> OriginalTexture {
            try bitmaps.loadTexture(path: "trick/cassette/\(name).bin")
        }
        let models = try OriginalModelLibrary.bundled()
        let textures = try OriginalTextureLibrary.bundled()
        tableSurface = try CassetteTableSurface(texture: texture("table"), device: device)
        tape = try OriginalModelMetalPreview(modelPath: "trick/cassette/tape.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        let modelName = tool == .pencil ? "pencil" : "ballpen"
        self.tool = try OriginalModelMetalPreview(modelPath: "trick/cassette/\(modelName).mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        guard let image = try texture("bg").makeCGImage() else {
            throw OriginalDataError.invalid("Cassette background texture")
        }
        background = image
    }

    func render() throws -> CGImage {
        let scene = try OriginalModelMetalPreview.render(width: 256, height: 192,
            device: device, queue: queue) { encoder in
                tape.encode(encoder: encoder, viewProjection: Self.viewProjection,
                    visibleNodes: Set(tape.model.nodes.indices),
                    modelTransform: Self.sourceSceneTransform * Self.translation(SIMD3(1.43, 0, 0.39)))
                tool.encode(encoder: encoder, viewProjection: Self.viewProjection,
                    visibleNodes: Set(tool.model.nodes.indices),
                    modelTransform: Self.sourceSceneTransform * Self.translation(SIMD3(-0.9, 25, -2.3)))
                tableSurface.encode(encoder: encoder, viewProjection: Self.viewProjection,
                    modelTransform: Self.sourceTableTransform)
            }
        var rgba = Data(count: 256 * 192 * 4)
        rgba.withUnsafeMutableBytes { storage in
            guard let context = CGContext(data: storage.baseAddress, width: 256, height: 192,
                bitsPerComponent: 8, bytesPerRow: 256 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.interpolationQuality = .none
            context.draw(background, in: CGRect(x: 0, y: 0, width: 256, height: 192))
            context.draw(scene, in: CGRect(x: 0, y: 0, width: 256, height: 192))
        }
        guard let page = OriginalEntrancePanels.rotated(rgba: rgba, width: 256, height: 192) else {
            throw OriginalDataError.invalid("Cassette scene image")
        }
        return page
    }

    func hitMask(for object: MaskedObject) throws -> OriginalModelProjectedMask {
        if let mask = hitMasks[object] { return mask }
        let model: OriginalModel
        let localTransform: simd_float4x4
        switch object {
        case .tape:
            model = tape.model
            localTransform = Self.translation(SIMD3(1.43, 0, 0.39))
        case .tool:
            model = tool.model
            localTransform = Self.translation(SIMD3(-0.9, 25, -2.3))
        }
        let mask = try OriginalModelProjectedMask(model: model, viewProjection: Self.viewProjection,
            modelTransform: Self.sourceSceneTransform * localTransform, width: 256, height: 192)
        hitMasks[object] = mask
        return mask
    }

    /**
     * Selects the nearest cassette object from the rotated touch-page coordinates.
     */
    func hitTest(pagePoint: SIMD2<Float>, padding: Float = 2) throws -> MaskedObject? {
        guard pagePoint.x.isFinite, pagePoint.y.isFinite,
              (0..<192).contains(pagePoint.x), (0..<256).contains(pagePoint.y) else { return nil }
        let sourcePoint = SIMD2(255 - pagePoint.y, pagePoint.x)
        let candidates = try [MaskedObject.tape, .tool].compactMap { object -> (MaskedObject, Float)? in
            guard let depth = try hitMask(for: object).depth(at: sourcePoint, padding: padding) else { return nil }
            return (object, depth)
        }
        return candidates.min { $0.1 < $1.1 }?.0
    }

    private static func translation(_ value: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4(value, 1)
        return matrix
    }

    private static func scale(_ value: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4(value.x, 0, 0, 0), SIMD4(0, value.y, 0, 0),
            SIMD4(0, 0, value.z, 0), SIMD4(0, 0, 0, 1)))
    }

    private static func rotation(_ degrees: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(simd_quatf(angle: degrees * .pi / 180, axis: axis))
    }

    /**
     * Overlay 25's shared object rotation and translation at +0x4B8...+0x4CC.
     */
    private static var sourceSceneTransform: simd_float4x4 {
        translation(SIMD3(-4, 0.5, -26))
            * rotation(-50, axis: SIMD3(0, 1, 0))
            * rotation(4, axis: SIMD3(1, 0, 0))
            * rotation(-90, axis: SIMD3(0, 0, 1))
    }

    /**
     * Overlay 25's transformed table quad from 0x021FF614 and its config at 0x021FFC50.
     */
    private static var sourceTableTransform: simd_float4x4 {
        translation(SIMD3(-4, 0.5, -26))
            * rotation(-50, axis: SIMD3(0, 1, 0))
            * rotation(4, axis: SIMD3(1, 0, 0))
            * rotation(-90, axis: SIMD3(0, 0, 1))
            * scale(SIMD3(2, 18, 18))
    }

    /**
     * Overlay 25 sets a 20-degree field of view, 4:3 aspect, 0.1 near plane and 60 far plane.
     */
    private static var viewProjection: simd_float4x4 {
        let eye = SIMD3<Float>(0, 0, 4)
        let target = SIMD3<Float>(0, 0, 0)
        let back = simd_normalize(eye - target)
        let cameraUp = SIMD3<Float>(0, -1, 0)
        let right = simd_normalize(simd_cross(cameraUp, back))
        let up = simd_cross(back, right)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, back.x, 0), SIMD4(right.y, up.y, back.y, 0),
            SIMD4(right.z, up.z, back.z, 0),
            SIMD4(-simd_dot(right, eye), -simd_dot(up, eye), -simd_dot(back, eye), 1)))
        let sy: Float = 1 / tan(.pi / 18)
        let sx = sy / Float(bitPattern: 0x3FAAE3DA)
        let projection = simd_float4x4(columns: (
            SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, 60 / -59.9, -1), SIMD4(0, 0, 6 / -59.9, 0)))
        return projection * view
    }
}

@MainActor
private final class CassetteTableSurface {
    private struct Vertex {
        var position: SIMD3<Float>
        var uv: SIMD2<Float>
    }

    private struct Uniforms {
        var viewProjection: simd_float4x4
        var world: simd_float4x4
    }

    private let pipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let vertices: MTLBuffer
    private let texture: MTLTexture
    private let sampler: MTLSamplerState

    init(texture source: OriginalTexture, device: MTLDevice) throws {
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "cassette_table_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "cassette_table_fragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor),
              let vertices = device.makeBuffer(bytes: Self.quad,
                  length: MemoryLayout<Vertex>.stride * Self.quad.count, options: .storageModeShared) else {
            throw OriginalDataError.invalid("Cassette table surface resources")
        }
        self.depthState = depthState
        self.vertices = vertices
        self.texture = try source.makeMetalTexture(device: device)
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest
        samplerDescriptor.mipFilter = .notMipmapped
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw OriginalDataError.invalid("Cassette table sampler")
        }
        self.sampler = sampler
    }

    func encode(encoder: MTLRenderCommandEncoder, viewProjection: simd_float4x4,
                modelTransform: simd_float4x4) {
        var uniforms = Uniforms(viewProjection: viewProjection, world: modelTransform)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: Self.quad.count)
    }

    private static let quad = [
        Vertex(position: SIMD3(0, 0, 0), uv: SIMD2(0, 0)),
        Vertex(position: SIMD3(0, 63, 0), uv: SIMD2(0, 1)),
        Vertex(position: SIMD3(63, 0, 0), uv: SIMD2(1, 0)),
        Vertex(position: SIMD3(63, 63, 0), uv: SIMD2(1, 1))
    ]

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Vertex { float3 position; float2 uv; };
    struct Uniforms { float4x4 viewProjection; float4x4 world; };
    struct Output { float4 position [[position]]; float2 uv; };
    vertex Output cassette_table_vertex(uint id [[vertex_id]], device const Vertex *vertices [[buffer(0)]],
                                        constant Uniforms &u [[buffer(1)]]) {
        Output out; out.position = u.viewProjection * u.world * float4(vertices[id].position, 1);
        out.uv = vertices[id].uv; return out;
    }
    fragment float4 cassette_table_fragment(Output in [[stage_in]], texture2d<float> image [[texture(0)]],
                                            sampler imageSampler [[sampler(0)]]) {
        return image.sample(imageSampler, in.uv);
    }
    """
}
