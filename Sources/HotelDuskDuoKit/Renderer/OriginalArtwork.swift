import CoreGraphics
import Foundation
import ImageIO

public final class OriginalArtwork: @unchecked Sendable {
    private static let hdGraphicsPreferenceKey = "hdGraphicsEnabled"

    public static let shared = OriginalArtwork(resourceRoot: Bundle.module.resourceURL?
        .appendingPathComponent("EnhancedArtwork"))

    public static var isHDGraphicsEnabled: Bool {
        UserDefaults.standard.object(forKey: hdGraphicsPreferenceKey) as? Bool ?? true
    }

    private struct Manifest: Decodable {
        struct Record: Decodable {
            let key: String
            let width: Int
            let height: Int
            let file: String
            let pngSHA256: String
            let sources: [String]
            let scale: Int?
        }
        let formatVersion: Int
        let scale: Int
        let complete: Bool
        let images: [Record]
    }

    private let root: URL?
    private let records: [String: Manifest.Record]
    private let sourceRecords: [String: Manifest.Record]
    private let animationFrameRecords: [String: Manifest.Record]
    private let defaultScale: Int
    private let cache = NSCache<NSString, CGImage>()
    private final class Size: NSObject {
        let value: CGSize
        init(_ value: CGSize) { self.value = value }
    }
    private let sizes = NSMapTable<AnyObject, Size>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    private let lock = NSLock()

    public init(resourceRoot: URL?) {
        root = resourceRoot
        if let url = resourceRoot?.appendingPathComponent("ArtworkManifest.json"),
           let data = try? Data(contentsOf: url),
           let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
           manifest.formatVersion == 1, (2...4).contains(manifest.scale), manifest.complete {
            defaultScale = manifest.scale
            records = Dictionary(manifest.images.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
            sourceRecords = Dictionary(manifest.images.flatMap { record in
                record.sources.map { ($0, record) }
            }, uniquingKeysWith: { first, _ in first })
            animationFrameRecords = Dictionary(manifest.images.flatMap { record in
                record.sources.filter { $0.hasPrefix("OriginalAnimations/") }.map { ($0, record) }
            }, uniquingKeysWith: { first, _ in first })
        } else {
            defaultScale = 1
            records = [:]
            sourceRecords = [:]
            animationFrameRecords = [:]
        }
        cache.totalCostLimit = 128 * 1024 * 1024
    }

    public func enhancedImage(rgba: Data, width: Int, height: Int) -> CGImage? {
        guard Self.isHDGraphicsEnabled, width > 0, height > 0,
              rgba.count == width * height * 4, !records.isEmpty else { return nil }
        let key = "\(width)x\(height)-\(OriginalAnimationClip.digest(rgba))"
        guard let record = records[key], record.width == width, record.height == height else { return nil }
        return load(record)
    }

    /// The enhanced first-pass image of an animation frame named `<anm>#<frame>`.
    func animationFrameImage(source: String, width: Int, height: Int) -> CGImage? {
        guard Self.isHDGraphicsEnabled, let record = animationFrameRecords[source],
              record.width == width, record.height == height else { return nil }
        return load(record)
    }

    func namedImage(source: String) -> CGImage? {
        guard Self.isHDGraphicsEnabled else { return nil }
        guard let record = sourceRecords[source] else { return nil }
        return load(record)
    }

    /**
     * Returns inspection artwork cropped to a matching flat room surface.
     */
    func inspectionTexturePixels(sourcePath: String, rgba: Data, width: Int, height: Int,
                                paintingFoundMask: UInt16) -> (data: Data, width: Int, height: Int)? {
        guard Self.isHDGraphicsEnabled, width > 0, height > 0,
              let replacement = Self.inspectionTextureReplacements[sourcePath] else { return nil }
        let sourcePath = replacement.revealedSource.flatMap { revealedSource in
            replacement.paintingIndex.map { paintingIndex in
                paintingFoundMask & (1 << paintingIndex) == 0 ? replacement.source : revealedSource
            }
        } ?? replacement.source
        guard let source = namedImage(source: sourcePath),
              let rotated = rotatedImage(source, logicalWidth: 256, logicalHeight: 192) else { return nil }

        let scaleX = CGFloat(rotated.width) / 192
        let scaleY = CGFloat(rotated.height) / 256
        let outputWidth = width * 4
        let outputHeight = height * 4
        var sourcePixels = [UInt8](repeating: 0, count: rotated.width * rotated.height * 4)
        let sourceRendered = sourcePixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: rotated.width, height: rotated.height,
                bitsPerComponent: 8, bytesPerRow: rotated.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(rotated, in: CGRect(x: 0, y: 0, width: rotated.width, height: rotated.height))
            return true
        }
        guard sourceRendered else { return nil }
        let sourceQuad = replacement.quad ?? [
            CGPoint(x: replacement.crop.minX, y: replacement.crop.minY),
            CGPoint(x: replacement.crop.maxX, y: replacement.crop.minY),
            CGPoint(x: replacement.crop.maxX, y: replacement.crop.maxY),
            CGPoint(x: replacement.crop.minX, y: replacement.crop.maxY)
        ]
        let scaledQuad = sourceQuad.map { CGPoint(x: $0.x * scaleX, y: $0.y * scaleY) }
        let destination = replacement.destination
        let cropWidth = destination.map { max(1, Int((CGFloat(outputWidth) * $0.width).rounded())) } ?? outputWidth
        let cropHeight = destination.map { max(1, Int((CGFloat(outputHeight) * $0.height).rounded())) } ?? outputHeight
        guard var pixels = Self.projectiveCrop(sourcePixels, sourceWidth: rotated.width, sourceHeight: rotated.height,
            quad: scaledQuad, outputWidth: cropWidth, outputHeight: cropHeight) else { return nil }
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[offset + 3])
            if alpha > 0 && alpha < 255 {
                for channel in 0..<3 {
                    pixels[offset + channel] = UInt8(min(255, (Int(pixels[offset + channel]) * 255 + alpha / 2) / alpha))
                }
            }
        }
        guard let destination else { return (Data(pixels), outputWidth, outputHeight) }
        var composite = Self.upscale(rgba: rgba, width: width, height: height, scale: 4)
        let originX = Int((CGFloat(outputWidth) * destination.minX).rounded())
        let originY = Int((CGFloat(outputHeight) * destination.minY).rounded())
        for row in 0..<cropHeight {
            for column in 0..<cropWidth {
                let targetOffset = ((originY + row) * outputWidth + originX + column) * 4
                let sourceOffset = (row * cropWidth + column) * 4
                let alpha = Int(pixels[sourceOffset + 3])
                guard alpha > 0 else { continue }
                let inverseAlpha = 255 - alpha
                for channel in 0..<3 {
                    composite[targetOffset + channel] = UInt8((Int(pixels[sourceOffset + channel]) * alpha
                        + Int(composite[targetOffset + channel]) * inverseAlpha + 127) / 255)
                }
                composite[targetOffset + 3] = 255
            }
        }
        return (Data(composite), outputWidth, outputHeight)
    }

    private struct InspectionTextureReplacement {
        let source: String
        let crop: CGRect
        var quad: [CGPoint]? = nil
        var destination: CGRect? = nil
        var paintingIndex: Int? = nil
        var revealedSource: String? = nil
    }

    private static func upscale(rgba: Data, width: Int, height: Int, scale: Int) -> [UInt8] {
        let source = [UInt8](rgba)
        var output = [UInt8](repeating: 0, count: width * height * scale * scale * 4)
        for y in 0..<(height * scale) {
            for x in 0..<(width * scale) {
                let sourceOffset = ((y / scale) * width + x / scale) * 4
                let targetOffset = (y * width * scale + x) * 4
                output[targetOffset..<(targetOffset + 4)] = source[sourceOffset..<(sourceOffset + 4)]
            }
        }
        return output
    }

    private static func projectiveCrop(_ source: [UInt8], sourceWidth: Int, sourceHeight: Int,
                                       quad: [CGPoint], outputWidth: Int, outputHeight: Int) -> [UInt8]? {
        guard quad.count == 4, source.count == sourceWidth * sourceHeight * 4,
              sourceWidth > 0, sourceHeight > 0, outputWidth > 0, outputHeight > 0 else { return nil }
        let x = quad.map { Double($0.x) }
        let y = quad.map { Double($0.y) }
        let dx1 = x[1] - x[2], dx2 = x[3] - x[2]
        let dx3 = x[0] - x[1] + x[2] - x[3]
        let dy1 = y[1] - y[2], dy2 = y[3] - y[2]
        let dy3 = y[0] - y[1] + y[2] - y[3]
        let denominator = dx1 * dy2 - dx2 * dy1
        let g: Double, h: Double
        if abs(dx3) + abs(dy3) < 0.0001 || abs(denominator) < 0.0001 {
            g = 0
            h = 0
        } else {
            g = (dx3 * dy2 - dx2 * dy3) / denominator
            h = (dx1 * dy3 - dx3 * dy1) / denominator
        }
        let a = x[1] - x[0] + g * x[1], b = x[3] - x[0] + h * x[3], c = x[0]
        let d = y[1] - y[0] + g * y[1], e = y[3] - y[0] + h * y[3], f = y[0]
        var output = [UInt8](repeating: 0, count: outputWidth * outputHeight * 4)
        for row in 0..<outputHeight {
            let v = (Double(row) + 0.5) / Double(outputHeight)
            for column in 0..<outputWidth {
                let u = (Double(column) + 0.5) / Double(outputWidth)
                let divisor = g * u + h * v + 1
                guard abs(divisor) > 0.0001 else { continue }
                let px = min(Double(sourceWidth - 1), max(0, (a * u + b * v + c) / divisor - 0.5))
                let py = min(Double(sourceHeight - 1), max(0, (d * u + e * v + f) / divisor - 0.5))
                let left = Int(px), top = Int(py)
                let right = min(sourceWidth - 1, left + 1), bottom = min(sourceHeight - 1, top + 1)
                let wx = px - Double(left), wy = py - Double(top)
                let outputOffset = (row * outputWidth + column) * 4
                for channel in 0..<4 {
                    let topLeft = Double(source[(top * sourceWidth + left) * 4 + channel])
                    let topRight = Double(source[(top * sourceWidth + right) * 4 + channel])
                    let bottomLeft = Double(source[(bottom * sourceWidth + left) * 4 + channel])
                    let bottomRight = Double(source[(bottom * sourceWidth + right) * 4 + channel])
                    let upper = topLeft + (topRight - topLeft) * wx
                    let lower = bottomLeft + (bottomRight - bottomLeft) * wx
                    output[outputOffset + channel] = UInt8(min(255, max(0, upper + (lower - upper) * wy)))
                }
            }
        }
        return output
    }

    /**
     * Maps front-facing inspection artwork to the matching room texture UVs.
     */
    private static let inspectionTextureReplacements: [String: InspectionTextureReplacement] = [
        "map/R102/R102/poster.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/102poster.bin#opaque",
            crop: CGRect(x: 8, y: 34, width: 142, height: 212)),
        "map/R114/R114/photobred.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/114deskphoto.bin#opaque",
            crop: .zero,
            quad: [CGPoint(x: 42, y: 78), CGPoint(x: 178, y: 60),
                   CGPoint(x: 185, y: 127), CGPoint(x: 51, y: 140)]),
        "map/R115/R115/calander.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/115calenup.bin#opaque",
            crop: .zero,
            quad: [CGPoint(x: 12, y: 58), CGPoint(x: 181, y: 58),
                   CGPoint(x: 181, y: 206), CGPoint(x: 12, y: 206)]),
        "map/R117/R117/photo.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/117paintingbase.bin#opaque",
            crop: CGRect(x: 7, y: 32, width: 144, height: 162), paintingIndex: 2,
            revealedSource: "OriginalBitmaps/map/sdata/SearchUp/117paintingup.bin#opaque"),
        "map/R117/R117/menuboard1.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/117blackboardup1.bin#opaque",
            crop: .zero,
            quad: [CGPoint(x: 13, y: 15), CGPoint(x: 177, y: 15),
                   CGPoint(x: 166, y: 210), CGPoint(x: 48, y: 237)]),
        "map/R117/R117/menuboard2.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/117blackboardup2.bin#opaque",
            crop: .zero,
            quad: [CGPoint(x: 13, y: 15), CGPoint(x: 177, y: 15),
                   CGPoint(x: 166, y: 210), CGPoint(x: 48, y: 237)]),
        "map/R117/R117/menuboard3.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/117blackboardup3.bin#opaque",
            crop: .zero,
            quad: [CGPoint(x: 13, y: 15), CGPoint(x: 177, y: 15),
                   CGPoint(x: 166, y: 210), CGPoint(x: 48, y: 237)]),
        "map/R123/R123/photo32.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/123photoup.bin#opaque",
            crop: .zero,
            quad: [CGPoint(x: 5, y: 75), CGPoint(x: 188, y: 75),
                   CGPoint(x: 190, y: 228), CGPoint(x: 3, y: 228)]),
        "map/R125/R125/poster05_l.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/125paintingbase.bin#opaque",
            crop: CGRect(x: 11, y: 61, width: 169, height: 164), paintingIndex: 0,
            revealedSource: "OriginalBitmaps/map/sdata/SearchUp/125paingup.bin#opaque"),
        "map/R205/R205/photo.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/205paintingbase.bin#opaque",
            crop: CGRect(x: 7, y: 32, width: 144, height: 162), paintingIndex: 4,
            revealedSource: "OriginalBitmaps/map/sdata/SearchUp/205paintingup.bin#opaque"),
        "map/R207/R207/photo.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/207paintingbase.bin#opaque",
            crop: .zero,
            quad: [CGPoint(x: 10, y: 79), CGPoint(x: 151, y: 82),
                   CGPoint(x: 162, y: 213), CGPoint(x: 19, y: 210)],
            paintingIndex: 3,
            revealedSource: "OriginalBitmaps/map/sdata/SearchUp/207paintingup.bin#opaque"),
        "map/R213/R213/photo.dtx": InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/213painting.bin#opaque",
            crop: CGRect(x: 7, y: 32, width: 144, height: 162), paintingIndex: 1,
            revealedSource: "OriginalBitmaps/map/sdata/SearchUp/213paintingup.bin#opaque"),
        "map/R213/R213/211.dtx": doorPlateReplacement(211),
        "map/R213/R213/212.dtx": doorPlateReplacement(212),
        "map/R213/R213/213.dtx": doorPlateReplacement(213),
        "map/R213/R213/214.dtx": doorPlateReplacement(214),
        "map/R213/R213/215.dtx": doorPlateReplacement(215),
        "map/R213/R213/216.dtx": doorPlateReplacement(216),
        "map/R213/R213/217.dtx": doorPlateReplacement(217),
        "map/R213/R213/218.dtx": doorPlateReplacement(218),
        "map/R213/R213/219.dtx": doorPlateReplacement(219),
        "map/R213/R213/220.dtx": doorPlateReplacement(220)
    ]

    private static func doorPlateReplacement(_ number: Int) -> InspectionTextureReplacement {
        InspectionTextureReplacement(
            source: "OriginalBitmaps/map/sdata/SearchUp/plate\(number).bin#transparent",
            crop: .zero,
            quad: [CGPoint(x: 72, y: 199), CGPoint(x: 119, y: 199),
                   CGPoint(x: 119, y: 221), CGPoint(x: 72, y: 221)],
            destination: CGRect(x: 0.31, y: 0.15, width: 0.38, height: 0.70))
    }

    /**
     * Returns the saved Chapter 9 painting bit for a room with a mapped painting.
     */
    static func paintingStateBit(forMapName mapName: String) -> UInt16? {
        let index: Int
        switch mapName {
        case "R125": index = 0
        case "R117": index = 2
        case "R205": index = 4
        case "R207": index = 3
        case "R213": index = 1
        default: return nil
        }
        return 1 << index
    }

    private func load(_ record: Manifest.Record) -> CGImage? {
        if let image = cache.object(forKey: record.key as NSString) { return image }
        let scale = record.scale ?? defaultScale
        guard (1...8).contains(scale) else { return nil }
        guard (record.file == record.key + ".png" || record.file == record.key + ".webp"), let root,
              let data = try? Data(contentsOf: root.appendingPathComponent(record.file)),
              OriginalAnimationClip.digest(data) == record.pngSHA256,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              image.width == record.width * scale, image.height == record.height * scale else { return nil }
        remember(image, size: CGSize(width: record.width, height: record.height))
        cache.setObject(image, forKey: record.key as NSString, cost: image.bytesPerRow * image.height)
        return image
    }

    public func image(rgba: Data, width: Int, height: Int, rotated: Bool = false) -> CGImage? {
        guard width > 0, height > 0, rgba.count == width * height * 4 else { return nil }
        let enhanced = enhancedImage(rgba: rgba, width: width, height: height)
        if !rotated, let enhanced { return enhanced }
        if rotated, let enhanced {
            let key = "rotated-\(width)x\(height)-\(OriginalAnimationClip.digest(rgba))"
            if let image = cache.object(forKey: key as NSString) { return image }
            guard let context = CGContext(data: nil, width: enhanced.height, height: enhanced.width,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.translateBy(x: CGFloat(enhanced.height), y: 0)
            context.rotate(by: .pi / 2)
            context.draw(enhanced, in: CGRect(x: 0, y: 0, width: enhanced.width, height: enhanced.height))
            guard let image = context.makeImage() else { return nil }
            remember(image, size: CGSize(width: height, height: width))
            cache.setObject(image, forKey: key as NSString, cost: image.bytesPerRow * image.height)
            return image
        }
        var pixels = rgba
        var outputWidth = width
        var outputHeight = height
        if rotated {
            let input = [UInt8](rgba)
            var output = [UInt8](repeating: 0, count: input.count)
            for y in 0..<height {
                for x in 0..<width {
                    let from = (y * width + x) * 4
                    let to = ((width - 1 - x) * height + y) * 4
                    output[to..<to + 4] = input[from..<from + 4]
                }
            }
            pixels = Data(output)
            outputWidth = height
            outputHeight = width
        }
        guard let provider = CGDataProvider(data: pixels as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: outputWidth, height: outputHeight, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: outputWidth * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    func metalPixels(rgba: Data, width: Int, height: Int) -> (data: Data, width: Int, height: Int)? {
        guard let image = enhancedImage(rgba: rgba, width: width, height: height) else { return nil }
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let rendered = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard rendered else { return nil }
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[offset + 3])
            if alpha > 0 && alpha < 255 {
                for channel in 0..<3 {
                    pixels[offset + channel] = UInt8(min(255, (Int(pixels[offset + channel]) * 255 + alpha / 2) / alpha))
                }
            }
        }
        return (Data(pixels), image.width, image.height)
    }

    func rotatedImage(_ source: CGImage, logicalWidth: Int, logicalHeight: Int) -> CGImage? {
        guard let context = CGContext(data: nil, width: source.height, height: source.width,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: CGFloat(source.height), y: 0)
        context.rotate(by: .pi / 2)
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        guard let image = context.makeImage() else { return nil }
        remember(image, size: CGSize(width: logicalHeight, height: logicalWidth))
        return image
    }

    func maskedImage(rgba: Data, width: Int, height: Int, maskRGBA: Data, rotated: Bool = false) -> CGImage? {
        guard rgba.count == width * height * 4, maskRGBA.count == rgba.count else { return nil }
        let enhanced = metalPixels(rgba: rgba, width: width, height: height)
        var pixels = [UInt8](enhanced?.data ?? rgba)
        let outputWidth = enhanced?.width ?? width
        let outputHeight = enhanced?.height ?? height
        let scale = outputWidth / width
        let mask = [UInt8](maskRGBA)
        for y in 0..<outputHeight {
            for x in 0..<outputWidth where mask[((y / scale) * width + x / scale) * 4 + 3] == 0 {
                pixels[(y * outputWidth + x) * 4 + 3] = 0
            }
        }
        guard let image = OriginalArtwork(resourceRoot: nil).image(rgba: Data(pixels),
            width: outputWidth, height: outputHeight) else { return nil }
        if rotated { return rotatedImage(image, logicalWidth: width, logicalHeight: height) }
        remember(image, size: CGSize(width: width, height: height))
        return image
    }

    func logicalSize(of image: CGImage) -> CGSize {
        lock.lock()
        defer { lock.unlock() }
        return sizes.object(forKey: image)?.value ?? CGSize(width: image.width, height: image.height)
    }

    func remember(_ image: CGImage, size: CGSize) {
        lock.lock()
        sizes.setObject(Size(size), forKey: image)
        lock.unlock()
    }

    static func pageContext(width: Int = 192, height: Int = 256) -> CGContext? {
        let scale = isHDGraphicsEnabled ? 4 : 1
        guard let context = CGContext(data: nil, width: width * scale, height: height * scale,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        context.interpolationQuality = .high
        return context
    }
}

extension CGImage {
    var artworkWidth: Int { Int(OriginalArtwork.shared.logicalSize(of: self).width) }
    var artworkHeight: Int { Int(OriginalArtwork.shared.logicalSize(of: self).height) }

    func croppingArtwork(to rect: CGRect) -> CGImage? {
        let size = OriginalArtwork.shared.logicalSize(of: self)
        guard size.width > 0, size.height > 0 else { return nil }
        let scaleX = CGFloat(width) / size.width
        let scaleY = CGFloat(height) / size.height
        guard let image = cropping(to: CGRect(x: rect.minX * scaleX, y: rect.minY * scaleY,
            width: rect.width * scaleX, height: rect.height * scaleY)) else { return nil }
        OriginalArtwork.shared.remember(image, size: rect.size)
        return image
    }
}
