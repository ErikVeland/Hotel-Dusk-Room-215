import CoreGraphics
import Metal
import simd

@MainActor
public protocol OriginalMemoPullRendering: AnyObject {
    func render(_ puzzle: OriginalMemoPullProcess) throws -> CGImage
}

public typealias OriginalMemoPullRendererFactory = @MainActor () throws -> any OriginalMemoPullRendering

/**
 * Overlay 6 cabinet, wall and paper from the original placedmemo archive.
 */
@MainActor
public final class OriginalMemoPullRenderer: OriginalMemoPullRendering {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let cabinet: OriginalModelMetalPreview
    private let wall: OriginalModelMetalPreview
    private let paper: [MTLTexture]
    private let pipeline: MTLRenderPipelineState
    private let depth: MTLDepthStencilState
    private struct Vertex {
        var position: SIMD4<Float>
        var uv: SIMD2<Float>
    }

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func texture(_ name: String) throws -> OriginalTexture {
            try OriginalTexture(data: bitmaps.loadLinear(path: "trick/placedmemo/\(name).bin").decodedPayload)
        }
        func model(_ name: String) throws -> OriginalModelMetalPreview {
            try OriginalModelMetalPreview(modelPath: "trick/placedmemo/\(name).mdf", models: models,
                textures: textures, device: device, textureLoader: texture)
        }
        cabinet = try model("cabinet")
        wall = try model("kabe")
        paper = try ["001", "002", "003", "dmove", "move"].map { try texture($0).makeMetalTexture(device: device) }
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "memo_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "memo_fragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw OriginalDataError.missing("Memo depth state")
        }
        self.depth = depth
    }

    public func render(_ puzzle: OriginalMemoPullProcess) throws -> CGImage {
        let projection = Self.viewProjection
        let scene = Self.translation(SIMD3(-5612, -2007, 0) / 4096)
            * simd_float4x4(simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0)))
            * simd_float4x4(simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0)))
        func object(_ position: SIMD3<Float>, scale: Float) -> simd_float4x4 {
            scene * Self.translation(position / 4096) * simd_float4x4(diagonal: SIMD4(scale, scale, scale, 1))
        }
        return try OriginalModelMetalPreview.render(width: 384, height: 512, device: device, queue: queue) { encoder in
            cabinet.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(cabinet.model.nodes.indices),
                           modelTransform: object(SIMD3(3482, 82, 0), scale: 5652 / 4096))
            wall.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(wall.model.nodes.indices),
                        modelTransform: object(SIMD3(4616, -41, 0), scale: 6185 / 4096))
            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depth)
            encoder.setCullMode(.none)
            if puzzle.soundStage == 3 {
                drawPaper(position: SIMD3(-221, 2048, 0), angle: puzzle.remainingAngle,
                          texture: paper[4], projection: projection, encoder: encoder)
                drawPaper(position: puzzle.position, angle: puzzle.angle, texture: paper[3], projection: projection, encoder: encoder)
            } else {
                drawPaper(position: puzzle.position, angle: puzzle.angle, texture: paper[puzzle.soundStage],
                          projection: projection, encoder: encoder)
            }
        }
    }

    private func drawPaper(position: SIMD3<Int32>, angle: Float, texture: MTLTexture,
                           projection: simd_float4x4, encoder: MTLRenderCommandEncoder) {
        let pivot = SIMD3<Float>(221, 0, 0) / 4096
        let transform = Self.translation(SIMD3<Float>(position) / 4096 + pivot)
            * simd_float4x4(simd_quatf(angle: -angle, axis: SIMD3(0, 0, 1))) * Self.translation(-pivot)
        let points: [SIMD3<Float>] = [SIMD3(-737, -737, 0), SIMD3(737, -737, 0),
                                     SIMD3(-737, 737, 0), SIMD3(737, 737, 0)]
        let uv: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1), SIMD2(1, 1)]
        let vertices = [0, 1, 2, 1, 2, 3].map {
            Vertex(position: projection * transform * SIMD4(points[$0] / 4096, 1), uv: uv[$0])
        }
        encoder.setVertexBytes(vertices, length: MemoryLayout<Vertex>.stride * vertices.count, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private static func translation(_ position: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4(position, 1)
        return matrix
    }

    private static var viewProjection: simd_float4x4 {
        let position = SIMD3<Float>(OriginalMemoPullProjection.eye) / 4096
        let back = simd_normalize(position - SIMD3<Float>(OriginalMemoPullProjection.target) / 4096)
        let up = simd_normalize(simd_cross(SIMD3<Float>(-1, 1, 0), back))
        let right = simd_cross(up, back)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, back.x, 0), SIMD4(right.y, up.y, back.y, 0),
            SIMD4(right.z, up.z, back.z, 0), SIMD4(-simd_dot(right, position), -simd_dot(up, position), -simd_dot(back, position), 1)))
        let sx: Float = 1 / tan(.pi / 18), sy = sx / Float(bitPattern: 0x3FAAE3DA)
        return simd_float4x4(columns: (
            SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0), SIMD4(0, 0, 60 / -59.9, -1),
            SIMD4(0, 0, 6 / -59.9, 0))) * view
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Input { float4 position; float2 uv; };
    struct Vertex { float4 position [[position]]; float2 uv; };
    vertex Vertex memo_vertex(uint id [[vertex_id]], device const Input *vertices [[buffer(0)]]) {
        Vertex out; out.position = vertices[id].position; out.uv = vertices[id].uv; return out;
    }
    fragment float4 memo_fragment(Vertex in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
        constexpr sampler nearest(coord::normalized, address::clamp_to_edge, filter::nearest);
        float4 colour = tex.sample(nearest, in.uv);
        if (colour.a == 0) discard_fragment();
        return colour;
    }
    """
}
