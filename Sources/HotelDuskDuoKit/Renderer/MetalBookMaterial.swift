import SwiftUI
import MetalKit

/// All material passes share one compiled Metal pipeline. Views render only when
/// their parameters change; the settling clock lives in PaperbackPageSurface.
struct MetalBookMaterial: View {
    enum Pass: Float { case stock = 0, light = 1, spine = 2, photoCard = 3, tape = 4 }
    var pass: Pass
    var side: PaperPageSide = .left
    var angle: Double = 180
    var flex: Double = 0

    var body: some View {
        MetalMaterialHost(parameters: MetalPaperParameters(pass: pass.rawValue,
                            angle: Float(angle), flex: Float(flex),
                            side: side == .left ? 0 : 1,
                            seed: side == .left ? 215 : 219))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct MetalPaperParameters: Equatable {
    var pass: Float = 0
    var angle: Float = 180
    var flex: Float = 0
    var side: Float = 0
    var seed: Float = 215
}

struct MetalPaperUniforms {
    var viewport: SIMD4<Float>
    var material: SIMD4<Float>
}

enum MetalPaperError: Error {
    case noDevice, missingShader, missingFunction, missingCommandBuffer, missingEncoder, missingTexture
}

final class MetalPaperPipeline {
    static let shared: Result<MetalPaperPipeline, Error> = Result { try MetalPaperPipeline() }
    let device: MTLDevice
    let queue: MTLCommandQueue
    let state: MTLRenderPipelineState

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw MetalPaperError.noDevice }
        guard let url = Bundle.module.url(forResource: "BookPaper", withExtension: "metal", subdirectory: "Metal") else {
            throw MetalPaperError.missingShader
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        let library = try device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        guard let vertex = library.makeFunction(name: "bookPaperVertex"),
              let fragment = library.makeFunction(name: "bookPaperFragment") else { throw MetalPaperError.missingFunction }
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // The layer compositor receives premultiplied colour over the page.
        self.state = try device.makeRenderPipelineState(descriptor: descriptor)
        guard let queue = device.makeCommandQueue() else { throw MetalPaperError.missingCommandBuffer }
        self.device = device
        self.queue = queue
    }

    func encode(texture: MTLTexture, parameters: MetalPaperParameters, scale: Float,
                command: MTLCommandBuffer) throws {
        let render = MTLRenderPassDescriptor()
        render.colorAttachments[0].texture = texture
        render.colorAttachments[0].loadAction = .clear
        render.colorAttachments[0].storeAction = .store
        render.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: render) else { throw MetalPaperError.missingEncoder }
        var uniforms = MetalPaperUniforms(
            viewport: SIMD4(Float(texture.width), Float(texture.height), max(1,scale), parameters.pass),
            material: SIMD4(parameters.angle,parameters.flex,parameters.side,parameters.seed))
        encoder.setRenderPipelineState(state)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MetalPaperUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    /// The same GPU path used by the live view, rendered offscreen for fidelity tests.
    func snapshot(width: Int, height: Int, parameters: MetalPaperParameters) throws -> CGImage {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                            width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw MetalPaperError.missingTexture }
        guard let command = queue.makeCommandBuffer() else { throw MetalPaperError.missingCommandBuffer }
        try encode(texture: texture, parameters: parameters, scale: 1, command: command)
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        var bytes = [UInt8](repeating: 0, count: width*height*4)
        texture.getBytes(&bytes, bytesPerRow: width*4, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0)
        // CAMetalLayer expects premultiplied output; the stock is opaque and the
        // overlay shader supplies premultiplied colour for composition.
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width*4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue |
                                                         CGBitmapInfo.byteOrder32Little.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw MetalPaperError.missingTexture
        }
        return image
    }
}

private final class PaperMetalDelegate: NSObject, MTKViewDelegate {
    let pipeline: MetalPaperPipeline?
    var parameters: MetalPaperParameters
    init(parameters: MetalPaperParameters) {
        self.parameters = parameters
        self.pipeline = try? MetalPaperPipeline.shared.get()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { view.draw() }
    func draw(in view: MTKView) {
        guard let pipeline, let drawable = view.currentDrawable,
              let command = pipeline.queue.makeCommandBuffer() else { return }
        let scale = Float(view.drawableSize.width / max(1,view.bounds.width))
        do { try pipeline.encode(texture: drawable.texture, parameters: parameters, scale: scale, command: command) }
        catch { return }
        command.present(drawable)
        command.commit()
    }
}

#if canImport(UIKit)
private struct MetalMaterialHost: UIViewRepresentable {
    var parameters: MetalPaperParameters
    func makeCoordinator() -> PaperMetalDelegate { PaperMetalDelegate(parameters: parameters) }
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.pipeline?.device)
        configure(view, coordinator: context.coordinator)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.parameters = parameters
        view.setNeedsDisplay()
    }
}
#else
private struct MetalMaterialHost: NSViewRepresentable {
    var parameters: MetalPaperParameters
    func makeCoordinator() -> PaperMetalDelegate { PaperMetalDelegate(parameters: parameters) }
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.pipeline?.device)
        configure(view, coordinator: context.coordinator)
        view.layer?.isOpaque = false
        return view
    }
    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.parameters = parameters
        view.needsDisplay = true
    }
}
#endif

private func configure(_ view: MTKView, coordinator: PaperMetalDelegate) {
    view.delegate = coordinator
    view.colorPixelFormat = .bgra8Unorm
    view.clearColor = MTLClearColorMake(0,0,0,0)
    view.isPaused = true
    view.enableSetNeedsDisplay = true
    view.framebufferOnly = false
    view.preferredFramesPerSecond = 30
}

/// Static stock is shaded once on the GPU, then retained as an image. Hinge
/// lighting remains a live Metal pass over the page and its printed content.
enum MetalPaperStock {
    private static let left = render(side: 0, seed: 215)
    private static let right = render(side: 1, seed: 219)
    static let photoCard = material(.photoCard, width: 384, height: 512, seed: 315)
    static let tape = material(.tape, width: 240, height: 64, seed: 79)
    static let secondTape = material(.tape, width: 240, height: 64, seed: 215)
    static func image(for side: PaperPageSide) -> CGImage? { side == .left ? left : right }
    private static func material(_ pass: MetalBookMaterial.Pass, width: Int, height: Int, seed: Float) -> CGImage? {
        guard let pipeline = try? MetalPaperPipeline.shared.get() else { return nil }
        return try? pipeline.snapshot(width: width, height: height,
                                      parameters: MetalPaperParameters(pass: pass.rawValue, seed: seed))
    }
    private static func render(side: Float, seed: Float) -> CGImage? {
        guard let pipeline = try? MetalPaperPipeline.shared.get() else { return nil }
        return try? pipeline.snapshot(width: 768, height: 1024,
                                      parameters: MetalPaperParameters(side: side, seed: seed))
    }
}
