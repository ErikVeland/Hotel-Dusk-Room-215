import CoreGraphics
import Foundation
import Metal
import simd

/// A native diagnostic renderer for recovered room geometry. It is not the
/// gameplay camera/controller or a claim of DS rasterization equivalence.
public final class OriginalModelMetalPreview {
    public let model: OriginalModel
    public let device: MTLDevice
    public let texturePaths: [Int: String]
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let untexturedPipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let draws: [Draw]

    private struct Draw {
        let node: Int
        let buffers: OriginalModelMetalGeometry
        let texture: MTLTexture?
        let dimensions: SIMD4<UInt32>
        let sampling: SIMD4<UInt32>
    }
    private struct Uniforms {
        var viewProjection: simd_float4x4
        var world: simd_float4x4
        var dimensions: SIMD4<UInt32>
        var sampling: SIMD4<UInt32>
    }

    /// Texture lookup uses an exact, case-insensitive name within the model's
    /// archive directory. Missing or unsupported referenced textures throw.
    /// The caller can preserve materials whose original runtime texture slot was unbound.
    public init(modelPath: String, models: OriginalModelLibrary, textures: OriginalTextureLibrary,
                device: MTLDevice, textureLoader: ((String) throws -> OriginalTexture)? = nil,
                untexturedMaterials: Set<Int> = []) throws {
        self.device = device
        model = try models.load(path: modelPath)
        guard let queue = device.makeCommandQueue() else { throw OriginalDataError.invalid("Metal command queue") }
        self.queue = queue
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "original_model_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "original_model_fragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        let colour = descriptor.colorAttachments[0]!
        colour.isBlendingEnabled = true
        colour.sourceRGBBlendFactor = .sourceAlpha
        colour.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colour.sourceAlphaBlendFactor = .one
        colour.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.fragmentFunction = library.makeFunction(name: "original_model_colour")
        untexturedPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .lessEqual
        depth.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depth) else {
            throw OriginalDataError.invalid("Metal depth state")
        }
        self.depthState = depthState
        var materialTextures = [Int: (OriginalTexture, MTLTexture)]()
        var resolvedPaths = [Int: String]()
        var prepared = [Draw]()
        let directory = (modelPath as NSString).deletingLastPathComponent
        for group in model.groups {
            guard let geometry = group.render else { continue }
            let material = model.materials[group.material]
            var dimensions = SIMD4<UInt32>(repeating: 0)
            var sampling = SIMD4<UInt32>(repeating: 0)
            var gpuTexture: MTLTexture?
            if !material.texture.isEmpty, !untexturedMaterials.contains(group.material) {
                if materialTextures[group.material] == nil {
                    let requested = directory + "/" + material.texture + ".dtx"
                    let texture: OriginalTexture
                    if let textureLoader { texture = try textureLoader(material.texture) }
                    else {
                        let matches = textures.manifest.textures.filter { $0.source.lowercased() == requested.lowercased() }
                        guard matches.count == 1, let record = matches.first else { throw OriginalDataError.missing(requested) }
                        texture = try textures.load(path: record.source)
                        resolvedPaths[group.material] = record.source
                    }
                    materialTextures[group.material] = (texture, try texture.makeMetalTexture(device: device))
                }
                let (texture, uploaded) = materialTextures[group.material]!
                gpuTexture = uploaded
                dimensions = SIMD4(UInt32(max(8, texture.allocatedWidth)), UInt32(max(8, texture.allocatedHeight)),
                                   UInt32(texture.storedWidth), UInt32(texture.storedHeight))
                // ARM9 0208b8c4/0208b8d4 pass these bytes to 02083cd0.
                // Its original switch maps both values 1 and 2 to S repeat.
                let repeatValue = material.originalRecord[46]
                let repeatMask: UInt32 = repeatValue == 3 ? 3 : ([1, 2].contains(repeatValue) ? 1 : 0)
                let flipValue = UInt32(material.originalRecord[47])
                sampling = SIMD4(1, repeatMask, flipValue <= 3 ? flipValue : 0, 0)
            }
            prepared.append(try Draw(node: group.node, buffers: geometry.makeMetalBuffers(device: device),
                                     texture: gpuTexture, dimensions: dimensions, sampling: sampling))
        }
        draws = prepared
        texturePaths = resolvedPaths
    }

    /// The caller supplies camera and visibility. This renderer never moves
    /// the player, creates hotspots, or decides which objects the story reveals.
    public func encode(encoder: MTLRenderCommandEncoder, viewProjection: simd_float4x4,
                       visibleNodes: Set<Int>, modelTransform: simd_float4x4 = matrix_identity_float4x4) {
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)
        for draw in draws where visibleNodes.contains(draw.node) {
            encoder.setRenderPipelineState(draw.texture == nil ? untexturedPipeline : pipeline)
            let values = model.nodes[draw.node].worldFixed.map { Float($0) / 4096 }
            let world = simd_float4x4(columns: (
                SIMD4(values[0], values[1], values[2], values[3]),
                SIMD4(values[4], values[5], values[6], values[7]),
                SIMD4(values[8], values[9], values[10], values[11]),
                SIMD4(values[12], values[13], values[14], values[15])))
            var uniforms = Uniforms(viewProjection: viewProjection, world: modelTransform * world,
                                    dimensions: draw.dimensions, sampling: draw.sampling)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentTexture(draw.texture, index: 0)
            draw.buffers.draw(encoder: encoder)
        }
    }

    public func render(width: Int, height: Int, viewProjection: simd_float4x4,
                       visibleNodes: Set<Int>) throws -> CGImage {
        try Self.render(width: width, height: height, device: device, queue: queue) { encoder in
            encode(encoder: encoder, viewProjection: viewProjection, visibleNodes: visibleNodes)
        }
    }

    /**
     * Shares one colour and depth target between the caller's original model draws.
     */
    static func render(width: Int, height: Int, device: MTLDevice, queue: MTLCommandQueue,
                       encode: (MTLRenderCommandEncoder) -> Void) throws -> CGImage {
        guard width > 0, height > 0, width <= 4096, height <= 4096 else { throw OriginalDataError.invalid("Preview dimensions") }
        let colourDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                        width: width, height: height, mipmapped: false)
        colourDescriptor.usage = [.renderTarget]
        colourDescriptor.storageMode = .shared
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                                       width: width, height: height, mipmapped: false)
        depthDescriptor.usage = [.renderTarget]
        depthDescriptor.storageMode = .private
        guard let colour = device.makeTexture(descriptor: colourDescriptor),
              let depth = device.makeTexture(descriptor: depthDescriptor), let command = queue.makeCommandBuffer() else {
            throw OriginalDataError.invalid("Preview render allocation")
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = colour
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw OriginalDataError.invalid("Preview encoder") }
        encode(encoder)
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        var rgba = Data(count: width * height * 4)
        rgba.withUnsafeMutableBytes { bytes in
            colour.getBytes(bytes.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        guard let provider = CGDataProvider(data: rgba as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw OriginalDataError.invalid("Preview image")
        }
        return image
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct SourceVertex { short x; short y; short z; short u; short v; ushort rgb; };
    struct Uniforms { float4x4 vp; float4x4 world; uint4 dimensions; uint4 sampling; };
    struct Vertex { float4 position [[position]]; float2 uv; float3 rgb; };
    vertex Vertex original_model_vertex(uint id [[vertex_id]], device const SourceVertex *vertices [[buffer(0)]],
                                         constant Uniforms &u [[buffer(1)]]) {
        SourceVertex v = vertices[id]; Vertex out;
        out.position = u.vp * u.world * float4(float3(v.x, v.y, v.z) / 4096.0, 1);
        out.uv = float2(v.u, v.v) / 16.0;
        out.rgb = float3(v.rgb & 31, (v.rgb >> 5) & 31, (v.rgb >> 10) & 31) / 31.0;
        return out;
    }
    int source_texel_address(int p, uint extent, bool repeat, bool mirror) {
        if (!repeat) return clamp(p, 0, int(extent) - 1);
        int period = int(extent) * (mirror ? 2 : 1);
        p = ((p % period) + period) % period;
        return mirror && p >= int(extent) ? period - 1 - p : p;
    }
    fragment float4 original_model_colour(Vertex in [[stage_in]]) { return float4(in.rgb, 1); }
    fragment float4 original_model_fragment(Vertex in [[stage_in]], constant Uniforms &u [[buffer(1)]],
                                             texture2d<float> tex [[texture(0)]]) {
        int2 p = int2(floor(in.uv));
        p.x = source_texel_address(p.x, u.dimensions.x, u.sampling.y & 1, u.sampling.z & 1);
        p.y = source_texel_address(p.y, u.dimensions.y, u.sampling.y & 2, u.sampling.z & 2);
        // Omitted source texels remain undefined. Never synthesize padding.
        if (p.x >= int(u.dimensions.z) || p.y >= int(u.dimensions.w)) discard_fragment();
        float4 colour = tex.read(uint2(p));
        if (colour.a == 0) discard_fragment();
        return float4(colour.rgb * in.rgb, colour.a);
    }
    """
}
