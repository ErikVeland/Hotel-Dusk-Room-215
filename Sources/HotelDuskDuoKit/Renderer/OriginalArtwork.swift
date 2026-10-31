import CoreGraphics
import Foundation
import ImageIO

public final class OriginalArtwork: @unchecked Sendable {
    private static let hdGraphicsPreferenceKey = "hdGraphicsEnabled"

    public static let shared = OriginalArtwork(resourceRoot: Bundle.module.resourceURL?
        .appendingPathComponent("EnhancedArtwork"))

    private static var hdGraphicsEnabled: Bool {
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
    private let namedRecords: [String: Manifest.Record]
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
            namedRecords = Dictionary(manifest.images.flatMap { record in
                record.sources.filter { $0.hasPrefix("Images/") }.map { ($0, record) }
            }, uniquingKeysWith: { first, _ in first })
        } else {
            defaultScale = 1
            records = [:]
            namedRecords = [:]
        }
        cache.totalCostLimit = 128 * 1024 * 1024
    }

    public func enhancedImage(rgba: Data, width: Int, height: Int) -> CGImage? {
        guard Self.hdGraphicsEnabled, width > 0, height > 0,
              rgba.count == width * height * 4, !records.isEmpty else { return nil }
        let key = "\(width)x\(height)-\(OriginalAnimationClip.digest(rgba))"
        guard let record = records[key], record.width == width, record.height == height else { return nil }
        return load(record)
    }

    func namedImage(source: String) -> CGImage? {
        guard Self.hdGraphicsEnabled else { return nil }
        guard let record = namedRecords[source] else { return nil }
        return load(record)
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
        guard let context = CGContext(data: nil, width: width * 4, height: height * 4,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: 4, y: 4)
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
