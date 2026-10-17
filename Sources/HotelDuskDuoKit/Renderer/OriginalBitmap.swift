import CoreGraphics
import Foundation

/// Original DS 8×8 tiled bitmap. Pixel orientation and palette indices remain
/// in source coordinates. The display layer chooses rotation and transparency.
public struct OriginalBitmap: Sendable {
    public let width: Int
    public let height: Int
    public let paletteCount: Int
    public let decodedPayload: Data
    public let indices: [UInt8]
    public let palette: [UInt16]

    public init(data: Data) throws {
        let decoded = data.prefix(3) == Data([0x12, 0x3d, 0xda])
            ? try OriginalContainer.decode(data, hasDirectoryRecord: false) : data
        let r = OriginalBytes(decoded)
        let kind = try r.u16(0), count = Int(try r.u16(2))
        let w = Int(try r.u16(4)), h = Int(try r.u16(6))
        guard kind == 0, [16,256].contains(count), w > 0, h > 0,
              w <= 1024, h <= 1024, w % 8 == 0, h % 8 == 0 else {
            throw OriginalDataError.unsupported("Original tiled bitmap header")
        }
        let pixelBytes = w * h / (count == 16 ? 2 : 1)
        guard try r.u32(8) == pixelBytes, try r.u32(12) == count * 2,
              decoded.count == 16 + count * 2 + pixelBytes else {
            throw OriginalDataError.invalid("Original bitmap section sizes")
        }
        let colours = try (0..<count).map { try r.u16(16 + $0 * 2) }
        let pixels = Array(try r.range(16 + count * 2, pixelBytes))
        var output = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let tile = (y / 8) * (w / 8) + x / 8
                let offset = tile * 64 + (y % 8) * 8 + x % 8
                output[y * w + x] = count == 256 ? pixels[offset]
                    : (pixels[offset / 2] >> (4 * (offset % 2))) & 15
            }
        }
        width = w; height = h; paletteCount = count
        decodedPayload = decoded; indices = output; palette = colours
    }

    public func rgba(transparentPaletteZero: Bool) -> Data {
        var data = [UInt8](); data.reserveCapacity(width * height * 4)
        for index in indices {
            let packed = palette[Int(index)]
            for shift in [0,5,10] {
                let value = UInt8((packed >> shift) & 31)
                data.append((value << 3) | (value >> 2))
            }
            data.append(transparentPaletteZero && index == 0 ? 0 : 255)
        }
        return Data(data)
    }

    public func makeCGImage(transparentPaletteZero: Bool) -> CGImage? {
        guard let provider = CGDataProvider(data: rgba(transparentPaletteZero: transparentPaletteZero) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

public struct OriginalBitmapLibrary: Sendable {
    public struct Manifest: Decodable, Sendable {
        public struct Record: Decodable, Sendable {
            public let source: String
            public let payloadSHA256: String
            public let status: String
            public let error: String?
            public let width: Int?
            public let height: Int?
            public let paletteCount: Int?
            public let decodedSHA256: String?
            public let rgbaSHA256: String?
        }
        public let formatVersion: Int
        public let images: [Record]
    }
    public let manifest: Manifest
    private let root: URL
    var resourceRoot: URL { root }
    public init(resourceRoot: URL) throws {
        root = resourceRoot.standardizedFileURL
        manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf:
            root.appendingPathComponent("OriginalBitmapManifest.json")))
        guard manifest.formatVersion == 1 else { throw OriginalDataError.unsupported("Bitmap manifest version") }
    }
    public static func bundled() throws -> Self {
        guard let root = Bundle.module.resourceURL else { throw OriginalDataError.missing("OriginalBitmaps") }
        return try .init(resourceRoot: root.appendingPathComponent("OriginalBitmaps"))
    }
    public func load(path: String) throws -> OriginalBitmap {
        guard let record = manifest.images.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        guard record.status == "decoded" else { throw OriginalDataError.unsupported(record.error ?? path) }
        let url = root.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else { throw OriginalDataError.invalid("Bitmap path leaves source directory") }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return try .init(data: data)
    }
}

/// Original 8-bit linear bitmap, as used by `trick/bell`. 0x021FCBEC reads its
/// pixel array at base + u16 0x1C + u16 0x1A × 2 for the touch mask. Header:
/// 16 zero bytes, u16 width, height, width, height, kind 4, palette count,
/// palette offset. Pixels are row-major in source orientation.
public struct OriginalLinearBitmap: Sendable {
    public let width: Int
    public let height: Int
    public let indices: [UInt8]
    public let palette: [UInt16]

    public init(data: Data) throws {
        let decoded = data.prefix(3) == Data([0x12, 0x3d, 0xda])
            ? try OriginalContainer.decode(data, hasDirectoryRecord: false) : data
        let r = OriginalBytes(decoded)
        guard decoded.count >= 0x20, decoded.prefix(16).allSatisfy({ $0 == 0 }) else {
            throw OriginalDataError.unsupported("Original linear bitmap header")
        }
        let w = Int(try r.u16(0x10)), h = Int(try r.u16(0x12))
        let count = Int(try r.u16(0x1A)), paletteOffset = Int(try r.u16(0x1C))
        guard try r.u16(0x14) == w, try r.u16(0x16) == h, try r.u16(0x18) == 4,
              w > 0, h > 0, count == 256, paletteOffset == 0x20,
              decoded.count == paletteOffset + count * 2 + w * h else {
            throw OriginalDataError.invalid("Original linear bitmap section sizes")
        }
        width = w; height = h
        palette = try (0..<count).map { try r.u16(paletteOffset + $0 * 2) }
        indices = Array(try r.range(paletteOffset + count * 2, w * h))
    }

    public func rgba(transparentPaletteZero: Bool) -> Data {
        var data = [UInt8](); data.reserveCapacity(width * height * 4)
        for index in indices {
            let packed = palette[Int(index)]
            for shift in [0, 5, 10] {
                let value = UInt8((packed >> shift) & 31)
                data.append((value << 3) | (value >> 2))
            }
            data.append(transparentPaletteZero && index == 0 ? 0 : 255)
        }
        return Data(data)
    }
}

extension OriginalBitmapLibrary {
    /// Loads a member that the tiled-bitmap manifest leaves unresolved, after
    /// checking its payload hash, as an original linear bitmap.
    public func loadLinear(path: String) throws -> OriginalLinearBitmap {
        guard let record = manifest.images.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        let url = resourceRoot.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(resourceRoot.path + "/") else { throw OriginalDataError.invalid("Bitmap path leaves source directory") }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return try .init(data: data)
    }
}
