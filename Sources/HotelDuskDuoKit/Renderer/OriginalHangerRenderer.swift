import CoreGraphics
import Metal
import simd

/**
 * Overlay 4 hanger, hinged pliers, hook layers and textured cut covers.
 */
@MainActor
final class OriginalHangerRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let hanger: OriginalModelMetalPreview
    private let pliers: OriginalModelMetalPreview
    private let wall: MTLTexture
    private let frontHook: MTLTexture
    private let backHook: MTLTexture
    private let pipeline: MTLRenderPipelineState
    private let depth: MTLDepthStencilState

    private struct Vertex {
        var position: SIMD4<Float>
        var uv: SIMD2<Float>
    }

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func texture(_ name: String) throws -> OriginalTexture {
            try OriginalTexture(data: bitmaps.loadLinear(path: "trick/hanger/\(name).bin").decodedPayload)
        }
        func model(_ name: String) throws -> OriginalModelMetalPreview {
            try OriginalModelMetalPreview(modelPath: "trick/hanger/\(name).mdf", models: models,
                textures: textures, device: device, textureLoader: texture,
                untexturedMaterials: name == "Hanga" ? [0] : [])
        }
        /**
         * The original Hanga material table binds its first texture slot to -1.
         */
        hanger = try model("Hanga")
        pliers = try model("penchi")
        wall = try texture("gabe").makeMetalTexture(device: device)
        frontHook = try texture("hook2").makeMetalTexture(device: device)
        backHook = try texture("hook1").makeMetalTexture(device: device)
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "hanger_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "hanger_texture")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw OriginalDataError.missing("Hanger depth state")
        }
        self.depth = depth
    }

    func render(_ puzzle: OriginalHangerProcess) throws -> CGImage {
        let projection = Self.projection(puzzle.cameraBounds)
        return try OriginalModelMetalPreview.render(width: 192, height: 256, device: device, queue: queue) { encoder in
            if puzzle.phase == 3, puzzle.stage == 3 {
                let base = Self.transform(position: puzzle.pliersPosition, scale: 0.1,
                    angles: SIMD3(0.2, 0, puzzle.pliersRotation))
                for node in 1...2 {
                    let opening = node == 1 ? puzzle.pliersOpening : -puzzle.pliersOpening
                    let rotation = Self.transform(position: .zero, scale: 1, angles: SIMD3(0, opening, 0))
                    pliers.encode(encoder: encoder, viewProjection: projection, visibleNodes: [node], modelTransform: base * rotation)
                }
            }
            for index in puzzle.severed.sorted() {
                let points = Self.cutCover(puzzle.cutting.cuts[index])
                let uv = points.map { point in
                    SIMD2(Float(Int(128 + Float(point.y) * 96 / 4096)) / 256,
                          Float(192 - Int(96 - Float(point.x) * 96 / 4096)) / 192)
                }
                draw(points: points.map { SIMD4(SIMD3<Float>($0) / 4096, 1) }, uv: uv,
                     texture: wall, projection: projection, encoder: encoder)
            }
            hanger.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(hanger.model.nodes.indices),
                modelTransform: Self.transform(position: SIMD3(0, 0, 20480), scale: 0.2, angles: SIMD3(0.5, 0, 1)))
            quad(halfWidth: 341, halfHeight: 342, position: SIMD3(133, 2239, 8192), texture: frontHook,
                 projection: projection, encoder: encoder)
            quad(halfWidth: 341, halfHeight: 342, position: SIMD3(133, 2239, 24576), texture: backHook,
                 projection: projection, encoder: encoder)
            quad(halfWidth: 5461, halfHeight: 4100, position: SIMD3(0, 0, 40960), texture: wall,
                 projection: projection, encoder: encoder)
        }
    }

    /**
     * 0x02203178 covers a 0.025-unit length of wire, extending 0.05 units to either side.
     */
    static func cutCover(_ cut: OriginalHangerCuts.Cut) -> [SIMD3<Int32>] {
        let quad = OriginalHangerCuts.hitQuads[cut.region]
        let start = SIMD2<Float>(quad[0] &+ quad[1]) * 0.5 / 4096
        let end = SIMD2<Float>(quad[2] &+ quad[3]) * 0.5 / 4096
        let direction = end - start
        let length = (direction.x * direction.x + direction.y * direction.y).squareRoot()
        let normal = SIMD2(direction.y, -direction.x) * (0.05 / length)
        let half = direction * (0.025 / length) * 0.5
        let point = SIMD2<Float>(cut.position) / 4096
        return [point - normal - half, point + normal - half, point + normal + half, point - normal + half].map {
            SIMD3(Int32(($0.x * 4096).rounded(.toNearestOrAwayFromZero)),
                  Int32(($0.y * 4096).rounded(.toNearestOrAwayFromZero)), 4096)
        }
    }

    private func quad(halfWidth: Int32, halfHeight: Int32, position: SIMD3<Int32>, texture: MTLTexture,
                      projection: simd_float4x4, encoder: MTLRenderCommandEncoder) {
        let transform = Self.transform(position: position, scale: 1, angles: SIMD3(0, 0, 0.5))
        let points = [SIMD3(-halfWidth, -halfHeight, 0), SIMD3(halfWidth, -halfHeight, 0),
                      SIMD3(halfWidth, halfHeight, 0), SIMD3(-halfWidth, halfHeight, 0)]
        draw(points: points.map { transform * SIMD4(SIMD3<Float>($0) / 4096, 1) },
             uv: [SIMD2(1, 0), SIMD2(0, 0), SIMD2(0, 1), SIMD2(1, 1)],
             texture: texture, projection: projection, encoder: encoder, polygonAlpha: 30)
    }

    private func draw(points: [SIMD4<Float>], uv: [SIMD2<Float>], texture: MTLTexture,
                      projection: simd_float4x4, encoder: MTLRenderCommandEncoder, polygonAlpha: UInt32 = 31) {
        let vertices = [0, 1, 2, 0, 2, 3].map { Vertex(position: projection * points[$0], uv: uv[$0]) }
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depth)
        encoder.setCullMode(.none)
        vertices.withUnsafeBytes { encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 0) }
        encoder.setFragmentTexture(texture, index: 0)
        var alpha = polygonAlpha
        encoder.setFragmentBytes(&alpha, length: MemoryLayout<UInt32>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    /**
     * 0x02026EBC uses X as camera up. Rotating the DS framebuffer restores world X/Y page axes.
     */
    private static func projection(_ bounds: SIMD4<Int32>) -> simd_float4x4 {
        let b = SIMD4<Float>(bounds) / 4096
        let width = b.w - b.y, height = b.z - b.x
        let near: Float = 410.0 / 4096, far: Float = 60
        return simd_float4x4(columns: (SIMD4(2 / width, 0, 0, 0), SIMD4(0, 2 / height, 0, 0),
            SIMD4(0, 0, 1 / (far - near), 0),
            SIMD4(-(b.w + b.y) / width, -(b.z + b.x) / height, -near / (far - near), 1)))
    }

    private static func transform(position: SIMD3<Int32>, scale: Float, angles: SIMD3<Float>) -> simd_float4x4 {
        let x = simd_float4x4(simd_quatf(angle: -angles.x * .pi, axis: SIMD3(1, 0, 0)))
        let y = simd_float4x4(simd_quatf(angle: -angles.y * .pi, axis: SIMD3(0, 1, 0)))
        let z = simd_float4x4(simd_quatf(angle: -angles.z * .pi, axis: SIMD3(0, 0, 1)))
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4(SIMD3<Float>(position) / 4096, 1)
        let fixedScale = (scale * 4096).rounded(.toNearestOrAwayFromZero) / 4096
        return translation * z * y * x * simd_float4x4(diagonal: SIMD4(fixedScale, fixedScale, fixedScale, 1))
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Input { float4 position; float2 uv; };
    struct Vertex { float4 position [[position]]; float2 uv; };
    vertex Vertex hanger_vertex(uint id [[vertex_id]], device const Input *vertices [[buffer(0)]]) {
        Vertex out; out.position = vertices[id].position; out.uv = vertices[id].uv; return out;
    }
    fragment float4 hanger_texture(Vertex in [[stage_in]], texture2d<float> tex [[texture(0)]],
                                   constant uint &alpha [[buffer(0)]]) {
        constexpr sampler nearest(coord::normalized, address::clamp_to_edge, filter::nearest);
        float4 colour = tex.sample(nearest, in.uv);
        if (colour.a == 0) discard_fragment();
        // 0x02200FB0 uses alpha 30 over opaque black. 0x02203700 uses alpha 31.
        uint3 five = uint3(round(colour.rgb * 255.0)) >> 3;
        uint3 six = (five << 1) + select(uint3(0), uint3(1), five != 0);
        six = ((six * (alpha + 1)) >> 5) & uint3(62);
        // The original VRAM display reads the five-bit capture into six-bit colour.
        return float4(float3((six << 2) | (six >> 4)) / 255.0, 1);
    }
    """
}
