import CoreGraphics
import Metal
import simd

@MainActor
public protocol OriginalCabinetDialRendering: AnyObject {
    func render(_ puzzle: OriginalCabinetDialProcess) throws -> CGImage
}

public typealias OriginalCabinetDialRendererFactory = @MainActor (OriginalCabinetDialProcess.Variant) throws -> any OriginalCabinetDialRendering

/**
 * Original dial cylinder strips, cabinet bitmap and drawer models from overlay 10.
 */
@MainActor
public final class OriginalCabinetDialRenderer: OriginalCabinetDialRendering {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let cabinet: OriginalModelMetalPreview
    private let wall: OriginalModelMetalPreview
    private let dial: MTLTexture
    private let background: MTLTexture
    private let backgroundV: Float
    private let pipeline: MTLRenderPipelineState
    private let depth: MTLDepthStencilState
    private struct Vertex {
        var position: SIMD4<Float>
        var uv: SIMD2<Float>
    }

    public init(variant: OriginalCabinetDialProcess.Variant = .cabinet) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let models = try OriginalModelLibrary.bundled(), textures = try OriginalTextureLibrary.bundled()
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func texture(_ name: String) throws -> OriginalTexture {
            try OriginalTexture(data: bitmaps.loadLinear(path: "trick/dial/\(name).bin").decodedPayload)
        }
        cabinet = try OriginalModelMetalPreview(modelPath: "trick/dial/cabinet.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        wall = try OriginalModelMetalPreview(modelPath: "trick/dial/kabe.mdf", models: models,
            textures: textures, device: device, textureLoader: texture)
        func dialTexture(_ name: String) throws -> MTLTexture {
            let folder = variant == .cabinet ? "dial" : "cashbox"
            return try bitmaps.loadTexture(path: "trick/\(folder)/\(name).bin").makeMetalTexture(device: device)
        }
        dial = try dialTexture("dial")
        background = try dialTexture("dial_cbnt")
        backgroundV = variant == .cashbox ? 0.75 : 1
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "dial_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "dial_fragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw OriginalDataError.missing("Cabinet dial depth state")
        }
        self.depth = depth
    }

    public func render(_ puzzle: OriginalCabinetDialProcess) throws -> CGImage {
        let projection = Self.viewProjection(drawer: puzzle.showsDrawer)
        return try OriginalModelMetalPreview.render(width: 768, height: 1024, device: device, queue: queue) { encoder in
            if puzzle.showsDrawer {
                guard puzzle.stage > 0 else { return }
                let transform = Self.rotation(-.pi, axis: SIMD3(0, 1, 0)) * Self.scale(2970 / 4096)
                wall.encode(encoder: encoder, viewProjection: projection, visibleNodes: Set(wall.model.nodes.indices), modelTransform: transform)
                for index in cabinet.model.nodes.indices {
                    let local = index == 0
                        ? Self.translation(SIMD3(0, 0, Float((puzzle.drawerOpening * 4096).rounded()) / 4096)) * Self.scale(3342 / 4096)
                        : Self.scale(2970 / 4096)
                    cabinet.encode(encoder: encoder, viewProjection: projection, visibleNodes: [index], modelTransform: local * transform)
                }
                return
            }
            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depth)
            encoder.setCullMode(.none)
            let backdrop = Self.translation(SIMD3(0, 0, 4751) / 4096)
                * Self.rotation(-.pi / 2, axis: SIMD3(0, 0, 1)) * Self.scale(4656 / 4096)
            let points: [SIMD3<Float>] = [SIMD3(-2, -1.5, 0), SIMD3(2, -1.5, 0), SIMD3(-2, 1.5, 0), SIMD3(2, 1.5, 0)]
            let uv: [SIMD2<Float>] = [SIMD2(1, 0), SIMD2(0, 0), SIMD2(1, backgroundV), SIMD2(0, backgroundV)]
            for wheel in 0..<3 {
                let transform = Self.translation(SIMD3(Float(puzzle.wheelCentres[wheel]), -483, 0) / 4096)
                    * Self.rotation(-puzzle.angles[wheel] * .pi, axis: SIMD3(1, 0, 0))
                for segment in 0..<10 {
                    func edge(_ index: Int, x: Float) -> SIMD3<Float> {
                        let angle = Float(index) * .pi * Float(0.2)
                        let y = Int32((Float(1.16) * Float(cos(Double(angle))) * 4096).rounded())
                        let z = Int32((Float(1.16) * Float(sin(Double(angle))) * 4096).rounded())
                        return SIMD3(x, Float(y) / 4096, Float(z) / 4096)
                    }
                    let points = [edge(segment, x: -2007 / 4096), edge(segment, x: 2007 / 4096),
                                  edge((segment + 1) % 10, x: -2007 / 4096), edge((segment + 1) % 10, x: 2007 / 4096)]
                    let start = Float(segment) * Float(0.1), end = Float(segment + 1) * Float(0.1)
                    let uv: [SIMD2<Float>] = [SIMD2(end, 0), SIMD2(end, 1), SIMD2(start, 0), SIMD2(start, 1)]
                    draw(points: points, uv: uv, texture: dial, matrix: projection * transform, encoder: encoder)
                }
            }
            /**
             * Composites the translucent A3I5 surround after the opaque wheel faces.
             */
            draw(points: points, uv: uv, texture: background, matrix: projection * backdrop, encoder: encoder)
        }
    }

    private func draw(points: [SIMD3<Float>], uv: [SIMD2<Float>], texture: MTLTexture,
                      matrix: simd_float4x4, encoder: MTLRenderCommandEncoder) {
        let vertices = [0, 1, 2, 1, 2, 3].map { Vertex(position: matrix * SIMD4(points[$0], 1), uv: uv[$0]) }
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Vertex>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private static func translation(_ value: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4(value, 1)
        return matrix
    }
    private static func rotation(_ value: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(simd_quatf(angle: value, axis: axis))
    }
    private static func scale(_ value: Float) -> simd_float4x4 {
        simd_float4x4(diagonal: SIMD4(value, value, value, 1))
    }
    private static func viewProjection(drawer: Bool) -> simd_float4x4 {
        let position: SIMD3<Float> = drawer ? SIMD3(1802, 2089, 1556) / 4096 : SIMD3(0, 0, 50)
        let target: SIMD3<Float> = drawer ? SIMD3(205, -23757, -39035) / 4096 : .zero
        let back = simd_normalize(position - target)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), back))
        let up = simd_cross(back, right)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, back.x, 0), SIMD4(right.y, up.y, back.y, 0),
            SIMD4(right.z, up.z, back.z, 0), SIMD4(-simd_dot(right, position), -simd_dot(up, position), -simd_dot(back, position), 1)))
        let sx: Float = drawer ? 3548 / 2046 : 4094 / 138
        let sy = sx / Float(bitPattern: 0x3FAAE3DA)
        return simd_float4x4(columns: (SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, 60 / -59.9, -1), SIMD4(0, 0, 6 / -59.9, 0))) * view
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Input { float4 position; float2 uv; };
    struct Vertex { float4 position [[position]]; float2 uv; };
    vertex Vertex dial_vertex(uint id [[vertex_id]], device const Input *vertices [[buffer(0)]]) {
        Vertex out; out.position = vertices[id].position; out.uv = vertices[id].uv; return out;
    }
    fragment float4 dial_fragment(Vertex in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
        constexpr sampler nearest(coord::normalized, address::clamp_to_edge, filter::nearest);
        float4 colour = tex.sample(nearest, in.uv);
        if (colour.a == 0) discard_fragment();
        return colour;
    }
    """
}
