import CoreGraphics
import Metal
import simd

@MainActor
public protocol OriginalSuitcaseContentsRendering: AnyObject {
    var initialContents: OriginalSuitcaseContents { get }
    func render(_ process: OriginalSuitcaseContentsProcess, game: OriginalGameState) throws -> CGImage
}

public typealias OriginalSuitcaseContentsRendererFactory = @MainActor () throws -> any OriginalSuitcaseContentsRendering

/**
 * Source suitcase model and compartment textures from overlay 24.
 */
@MainActor
public final class OriginalSuitcaseContentsRenderer: OriginalSuitcaseContentsRendering {
    public let initialContents: OriginalSuitcaseContents
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let bag: OriginalModelMetalPreview
    private let bitmaps: OriginalBitmapLibrary
    private let backgrounds: [CGImage]
    private let upper: [CGImage]
    private let lower: [CGImage]
    private let memo: CGImage
    private let strap: CGImage
    private var itemImages: [UInt8: CGImage] = [:]

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw OriginalDataError.missing("Metal device")
        }
        self.device = device
        self.queue = queue
        let bitmaps = try OriginalBitmapLibrary.bundled()
        self.bitmaps = bitmaps
        func texture(_ name: String) throws -> OriginalTexture {
            try bitmaps.loadTexture(path: "trick/searchbag/\(name).bin")
        }
        func image(_ texture: OriginalTexture, rotated: Bool) throws -> CGImage {
            let result = rotated ? OriginalEntrancePanels.rotated(rgba: texture.rgba,
                width: texture.storedWidth, height: texture.storedHeight) : texture.makeCGImage()
            guard let result else { throw OriginalDataError.invalid("Suitcase texture image") }
            return result
        }
        let lowerTextures = try OriginalSuitcaseContents.lowerObjects.map { try texture($0.texture) }
        initialContents = try OriginalSuitcaseContents(lowerHitMasks: lowerTextures.map(\.originalPixelData))
        lower = try lowerTextures.enumerated().map { try image($0.element, rotated: $0.offset != 0) }
        upper = try OriginalSuitcaseContents.upperObjects.enumerated().map {
            try image(texture($0.element.texture), rotated: $0.offset > 1)
        }
        backgrounds = try ["bg", "bg_bag01", "bg_bag02"].map { try image(texture($0), rotated: true) }
        memo = try image(texture("_13memoT"), rotated: true)
        strap = try image(texture("_19rubber"), rotated: true)
        bag = try OriginalModelMetalPreview(modelPath: "trick/searchbag/kaban.mdf",
            models: OriginalModelLibrary.bundled(), textures: OriginalTextureLibrary.bundled(),
            device: device, textureLoader: texture)
    }

    public func render(_ process: OriginalSuitcaseContentsProcess, game: OriginalGameState) throws -> CGImage {
        let renderScale = 2
        guard let context = CGContext(data: nil, width: 192 * renderScale, height: 256 * renderScale, bitsPerComponent: 8,
            bytesPerRow: 192 * renderScale * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw OriginalDataError.invalid("Suitcase image context")
        }
        context.scaleBy(x: CGFloat(renderScale), y: CGFloat(renderScale))
        context.interpolationQuality = .high
        func draw(_ image: CGImage, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
            context.draw(image, in: CGRect(x: x, y: 256 - y - height, width: width, height: height))
        }
        if let compartment = process.compartment {
            draw(backgrounds[compartment == .upper ? 1 : 2], x: 0, y: 0, width: 192, height: 256)
            let objects = OriginalSuitcaseContents.objects(in: compartment)
            let positions = process.contents.positions(in: compartment)
            let visible = try process.contents.visibleIndices(in: compartment, game: game)
            let order = compartment == .upper ? Array(visible.reversed()) : visible
            for index in order {
                let object = objects[index]
                let position = object.drawingOrigin + positions[index] - object.initialPosition
                let image = compartment == .upper ?
                    (index == 3 && game.value(for: .gameFlag(index: 44)) == true ? memo : upper[index]) : lower[index]
                draw(image, x: CGFloat(position.x), y: CGFloat(position.y),
                    width: CGFloat(image.width), height: CGFloat(image.height))
            }
            if compartment == .upper { draw(strap, x: 0, y: 152, width: 192, height: 64) }
        } else {
            draw(backgrounds[0], x: 0, y: 0, width: 192, height: 256)
            draw(try overview(process, game: game), x: 0, y: 0, width: 192, height: 256)
        }
        if process.itemShade > 0 {
            context.setFillColor(CGColor(gray: 0, alpha: CGFloat(process.itemShade) / 31))
            context.fill(CGRect(x: 0, y: 0, width: 192, height: 256))
        }
        if process.itemVisible, let item = process.item {
            if itemImages[item] == nil { itemImages[item] = try OriginalTouchPictureImages.item(item, library: bitmaps) }
            if let image = itemImages[item] {
                let size = CGFloat(process.itemScale) * 128
                draw(image, x: 96 - size / 2, y: 128 - size / 2, width: size, height: size)
            }
        }
        guard let image = context.makeImage() else { throw OriginalDataError.invalid("Suitcase image") }
        return image
    }

    private func overview(_ process: OriginalSuitcaseContentsProcess, game: OriginalGameState) throws -> CGImage {
        let held = Set(try game.inventory.items)
        func flag(_ index: UInt16) -> Bool { game.value(for: .gameFlag(index: index)) == true }
        let hidden = Set(bag.model.nodes.indices.filter { index in
            switch bag.model.nodes[index].name {
            case "redbox": return held.contains(14) || !flag(46)
            case "bill": return game.chapter >= 5 || !flag(40) || held.contains(28)
            case "file": return !flag(51) || held.contains(49)
            default: return false
            }
        })
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4(0, -0.5, -13107.0 / 4096, 1)
        let upperRotation = simd_float4x4(simd_quatf(angle: -(-0.1 + process.lidRotation) * .pi, axis: SIMD3(1, 0, 0)))
        let lowerRotation = simd_float4x4(simd_quatf(angle: 0.1 * .pi, axis: SIMD3(1, 0, 0)))
        let sx: Float = 3548.0 / 2046, sy = sx / (5468.0 / 4096)
        let near: Float = 16753.0 / 4096, far: Float = 30884.0 / 4096
        var view = matrix_identity_float4x4
        view.columns.3.z = -4
        let projection = simd_float4x4(columns: (SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, far / (near - far), -1), SIMD4(0, 0, near * far / (near - far), 0))) * view
        return try OriginalModelMetalPreview.render(width: 192, height: 256, device: device, queue: queue) { encoder in
            for node in bag.model.nodes.indices where node > 0 && !hidden.contains(node) {
                bag.encode(encoder: encoder, viewProjection: projection, visibleNodes: [node],
                    modelTransform: translation * (node <= 4 ? upperRotation : lowerRotation))
            }
        }
    }
}
