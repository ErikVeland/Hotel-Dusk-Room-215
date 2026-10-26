import CoreGraphics
import Metal
import simd

@MainActor
public protocol OriginalCrowbarRendering: AnyObject {
    func render(_ puzzle: OriginalCrowbarProcess) throws -> CGImage
}

public typealias OriginalCrowbarRendererFactory = @MainActor (Bool) throws -> any OriginalCrowbarRendering

/**
 * Overlay 5 crowbar, cabinet, wall and paper from the original archives.
 */
@MainActor
public final class OriginalCrowbarRenderer: OriginalCrowbarRendering {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let cabinet: OriginalModelMetalPreview
    private let wall: OriginalModelMetalPreview
    private let crowbar: OriginalModelMetalPreview
    private let paper: MTLTexture
    private let pipeline: MTLRenderPipelineState
    private let depth: MTLDepthStencilState
    private struct Vertex {
        var position: SIMD4<Float>
        var uv: SIMD2<Float>
    }

    public init(tornPaper: Bool) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func texture(_ name: String) throws -> OriginalTexture {
            try OriginalTexture(data: bitmaps.loadLinear(path: "trick/cabinet/\(name).bin").decodedPayload)
        }
        func model(_ name: String) throws -> OriginalModelMetalPreview {
            try OriginalModelMetalPreview(modelPath: "trick/cabinet/\(name).mdf", models: models,
                textures: textures, device: device, textureLoader: texture)
        }
        cabinet = try model("cabinet")
        wall = try model("kabe")
        crowbar = try model("baru")
        paper = try OriginalTexture(data: bitmaps.loadLinear(path: "trick/placedmemo/\(tornPaper ? "move" : "001").bin").decodedPayload).makeMetalTexture(device: device)
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "crowbar_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "crowbar_fragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw OriginalDataError.missing("Crowbar depth state")
        }
        self.depth = depth
    }

    public func render(_ puzzle: OriginalCrowbarProcess) throws -> CGImage {
        let projection = Self.viewProjection(shake: puzzle.cameraShake)
        let scene = Self.translation(SIMD3(-5612, -2007, 0) / 4096)
            * Self.rotation(.pi, axis: SIMD3(0, 1, 0))
            * Self.rotation(.pi / 2, axis: SIMD3(1, 0, 0))
        func object(_ position: SIMD3<Float>, angles: SIMD3<Float> = .zero, scale: Float) -> simd_float4x4 {
            Self.translation(position / 4096)
                * Self.rotation(-angles.y, axis: SIMD3(0, 1, 0))
                * Self.rotation(-angles.z, axis: SIMD3(0, 0, 1))
                * Self.rotation(-angles.x, axis: SIMD3(1, 0, 0))
                * simd_float4x4(diagonal: SIMD4(scale, scale, scale, 1))
        }
        return try OriginalModelMetalPreview.render(width: 192, height: 256, device: device, queue: queue) { encoder in
            cabinet.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(cabinet.model.nodes.indices),
                modelTransform: scene * object(SIMD3(4915, -294, 0), angles: SIMD3(0, 0, puzzle.cabinetAngle), scale: 11428 / 4096))
            wall.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(wall.model.nodes.indices),
                modelTransform: scene * object(SIMD3(16753, -294, 205), scale: 11346 / 4096))
            crowbar.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(crowbar.model.nodes.indices),
                modelTransform: object(SIMD3<Float>(puzzle.position), angles: SIMD3(.pi / 2, puzzle.angle, .pi / 2), scale: 819 / 4096))
            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depth)
            encoder.setCullMode(.none)
            let transform = object(SIMD3(-614, Float(puzzle.paperY), 246),
                angles: SIMD3(.pi / 2, 0, Float(bitPattern: 0x4020D97C)), scale: 3277 / 4096)
            let points: [SIMD3<Float>] = [SIMD3(-1024, 0, -1024), SIMD3(1024, 0, -1024),
                                         SIMD3(-1024, 0, 1024), SIMD3(1024, 0, 1024)]
            let uv: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1), SIMD2(1, 1)]
            let vertices = [0, 1, 2, 1, 2, 3].map {
                Vertex(position: projection * transform * SIMD4(points[$0] / 4096, 1), uv: uv[$0])
            }
            encoder.setVertexBytes(vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
            encoder.setFragmentTexture(paper, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }
    }

    private static func rotation(_ angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(simd_quatf(angle: angle, axis: axis))
    }

    private static func translation(_ position: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4(position, 1)
        return matrix
    }

    private static func viewProjection(shake: Int32) -> simd_float4x4 {
        let position = SIMD3<Float>(OriginalCrowbarProjection.eye &+ SIMD3(0, 0, shake)) / 4096
        let back = simd_normalize(position - SIMD3<Float>(OriginalCrowbarProjection.target &+ SIMD3(0, 0, shake)) / 4096)
        let up = simd_normalize(simd_cross(SIMD3<Float>(-1, 1, 0), back))
        let right = simd_cross(up, back)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, back.x, 0), SIMD4(right.y, up.y, back.y, 0),
            SIMD4(right.z, up.z, back.z, 0), SIMD4(-simd_dot(right, position), -simd_dot(up, position), -simd_dot(back, position), 1)))
        let sx: Float = 1 / tan(.pi / 6), sy = sx / Float(bitPattern: 0x3FAAE3DA)
        return simd_float4x4(columns: (
            SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0), SIMD4(0, 0, 60 / -59.9, -1),
            SIMD4(0, 0, 6 / -59.9, 0))) * view
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Input { float4 position; float2 uv; };
    struct Vertex { float4 position [[position]]; float2 uv; };
    vertex Vertex crowbar_vertex(uint id [[vertex_id]], device const Input *vertices [[buffer(0)]]) {
        Vertex out; out.position = vertices[id].position; out.uv = vertices[id].uv; return out;
    }
    fragment float4 crowbar_fragment(Vertex in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
        constexpr sampler nearest(coord::normalized, address::clamp_to_edge, filter::nearest);
        float4 colour = tex.sample(nearest, in.uv);
        if (colour.a == 0) discard_fragment();
        return colour;
    }
    """
}
