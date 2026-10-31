import CoreGraphics
import Metal
import simd

/**
 * Overlay 9 generated mesh, desk quad and pulsing PointLight texture.
 */
@MainActor
final class OriginalPaperclipRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let colourPipeline: MTLRenderPipelineState
    private let depth: MTLDepthStencilState
    private let desk: MTLTexture
    private let marker: MTLTexture
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
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "paperclip_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "paperclip_texture")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        let colour = descriptor.colorAttachments[0]!
        colour.isBlendingEnabled = true
        colour.sourceRGBBlendFactor = .sourceAlpha
        colour.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colour.sourceAlphaBlendFactor = .one
        colour.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.fragmentFunction = library.makeFunction(name: "paperclip_colour")
        colourPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = true
        guard let depth = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw OriginalDataError.missing("Paperclip depth state")
        }
        self.depth = depth
        let bitmaps = try OriginalBitmapLibrary.bundled()
        func texture(_ name: String) throws -> MTLTexture {
            let bitmap = try bitmaps.loadLinear(path: "trick/clip/\(name).bin")
            return try OriginalTexture(data: bitmap.decodedPayload).makeMetalTexture(device: device)
        }
        desk = try texture("desk")
        marker = try texture("PointLight")
    }

    func render(_ puzzle: OriginalPaperclipProcess, markerFrame: Int) throws -> CGImage {
        let wireRotation = simd_quatf(angle: -puzzle.rotation * .pi, axis: SIMD3(0, 1, 0))
        let translation = SIMD3<Float>(puzzle.translation) / 4096
        let wire = Self.wireQuads(points: puzzle.points).flatMap { quad in
            Self.triangles(quad.map { wireRotation.act($0) + translation })
        }
        // 0x021FE660 fixed-point quad, rotated by -1.5π about Y and translated down one unit.
        let deskRotation = simd_quatf(angle: -1.5 * .pi, axis: SIMD3(0, 1, 0))
        let deskPoints: [SIMD3<Float>] = [SIMD3(-28467, 0, -21053), SIMD3(28467, 0, -21053),
                                        SIMD3(28467, 0, 21053), SIMD3(-28467, 0, 21053)]
        let background = Self.triangles(deskPoints.map { deskRotation.act($0 / 4096) + SIMD3(0, -1, 0) })
        let frame = markerFrame % 31
        let size = (1 + Float(frame) / 64) * 0.5
        let light = puzzle.activePoint.map { index in
            Self.triangles([SIMD3(-size, 0, -size), SIMD3(size, 0, -size),
                            SIMD3(size, 0, size), SIMD3(-size, 0, size)].map { $0 + puzzle.points[index] })
        }
        func buffer(_ vertices: [Vertex]) throws -> MTLBuffer {
            try vertices.withUnsafeBytes { bytes in
                guard let result = device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count) else {
                    throw OriginalDataError.missing("Paperclip vertex buffer")
                }
                return result
            }
        }
        let backgroundBuffer = try buffer(background), wireBuffer = try buffer(wire)
        let lightBuffer = try light.map(buffer)
        return try OriginalModelMetalPreview.render(width: 768, height: 1024, device: device, queue: queue) { encoder in
            encoder.setDepthStencilState(depth)
            encoder.setCullMode(.none)
            draw(backgroundBuffer, count: background.count, texture: desk, encoder: encoder)
            draw(wireBuffer, count: wire.count, texture: nil, encoder: encoder)
            if let lightBuffer, let light {
                draw(lightBuffer, count: light.count, texture: marker, alpha: Float(31 - frame) / 31, encoder: encoder)
            }
        }
    }

    /**
     * 0x02200B98 builds eight fixed-point vertices per segment. 0x021FFBE0 joins their three visible faces.
     */
    static func wireQuads(points: [SIMD3<Float>]) -> [[SIMD3<Float>]] {
        guard points.count == 16 else { return [] }
        let segments: [[SIMD3<Float>]] = (0..<15).map { index in
            let start = SIMD2(points[index].x, points[index].z)
            let end = SIMD2(points[index + 1].x, points[index + 1].z)
            let middle = (start + end) * 0.5
            let a = start + (middle - start) * 0.2, b = end + (middle - end) * 0.2
            let direction = b - a
            let normal = SIMD2(-direction.y, direction.x) * (0.25 / simd_length(direction))
            let magnitude = simd_length(normal)
            return [a, b].flatMap { centre in
                [-Float(0.5), -0.25, 0.25, 0.5].enumerated().map { corner, factor in
                    let point = centre + normal * magnitude * factor
                    let y: Float = corner == 1 || corner == 2 ? 1.73 * magnitude * 0.25 : 0
                    let value = SIMD3(point.x, y, point.y)
                    return SIMD3((0..<3).map { (value[$0] * 4096).rounded(.toNearestOrAwayFromZero) / 4096 })
                }
            }
        }
        var quads = [Array(segments[0][0..<4])]
        for index in segments.indices {
            let segment = segments[index]
            for face in 0..<3 {
                quads.append([segment[face], segment[face + 1], segment[face + 5], segment[face + 4]])
                if index < 14 {
                    let next = segments[index + 1]
                    quads.append([next[face], next[face + 1], segment[face + 5], segment[face + 4]])
                }
            }
        }
        quads.append(Array(segments[14][4..<8]))
        return quads
    }

    private static func triangles(_ points: [SIMD3<Float>]) -> [Vertex] {
        let uv: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1)]
        return [0, 1, 2, 0, 2, 3].map { Vertex(position: SIMD4(points[$0], 1), uv: uv[$0]) }
    }

    private func draw(_ buffer: MTLBuffer, count: Int, texture: MTLTexture?, alpha: Float = 1,
                      encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(texture == nil ? colourPipeline : pipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        var opacity = alpha
        encoder.setFragmentBytes(&opacity, length: MemoryLayout<Float>.size, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: count)
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Input { float4 position; float2 uv; };
    struct Vertex { float4 position [[position]]; float2 uv; };
    vertex Vertex paperclip_vertex(uint id [[vertex_id]], device const Input *vertices [[buffer(0)]]) {
        Input v = vertices[id]; Vertex out;
        float distance = 8 - v.position.y;
        // 0x021FE2B4: half-angle 30°, aspect 1.33507848, near 0.1, rotated DS viewport.
        out.position = float4(v.position.x / tan(M_PI_F / 6),
                             -v.position.z / (tan(M_PI_F / 6) * 1.33507848),
                             (60 * distance - 6) / 59.9, distance);
        out.uv = v.uv;
        return out;
    }
    fragment float4 paperclip_colour(Vertex in [[stage_in]]) { return float4(1); }
    fragment float4 paperclip_texture(Vertex in [[stage_in]], texture2d<float> tex [[texture(0)]],
                                     constant float &alpha [[buffer(1)]]) {
        constexpr sampler nearest(coord::normalized, address::clamp_to_edge, filter::nearest);
        float4 colour = tex.sample(nearest, in.uv);
        if (colour.a == 0) discard_fragment();
        return float4(colour.rgb, colour.a * alpha);
    }
    """
}
