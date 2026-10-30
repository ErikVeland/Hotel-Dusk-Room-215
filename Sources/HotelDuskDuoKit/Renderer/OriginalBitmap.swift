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
        OriginalArtwork.shared.image(rgba: rgba(transparentPaletteZero: transparentPaletteZero), width: width, height: height)
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

/// Original linear bitmap, as used by `trick/bell`. 0x021FCBEC reads its
/// pixel array at base + u16 0x1C + u16 0x1A × 2 for the touch mask. Header:
/// 16 zero bytes, u16 width, height, width, height, kind, palette count,
/// palette offset. Kind 1 uses A3I5 pixels. Kinds 3 and 4 use palette indices.
/// Pixels are row-major in source orientation.
public struct OriginalLinearBitmap: Sendable {
    public let width: Int
    public let height: Int
    public let decodedPayload: Data
    public let kind: UInt16
    public let indices: [UInt8]
    public let palette: [UInt16]

    public init(data: Data) throws {
        let decoded: Data
        if data.first == 0x30 { decoded = try Self.decodeRunLength(data) }
        else if data.prefix(3) == Data([0x12, 0x3d, 0xda]) {
            decoded = try OriginalContainer.decode(data, hasDirectoryRecord: false)
        } else { decoded = data }
        let r = OriginalBytes(decoded)
        guard decoded.count >= 0x20, decoded.prefix(16).allSatisfy({ $0 == 0 }) else {
            throw OriginalDataError.unsupported("Original linear bitmap header")
        }
        let w = Int(try r.u16(0x10)), h = Int(try r.u16(0x12))
        let count = Int(try r.u16(0x1A)), paletteOffset = Int(try r.u16(0x1C))
        let kind = try r.u16(0x18)
        guard try r.u16(0x14) == w, try r.u16(0x16) == h, [1, 3, 4].contains(kind),
              w > 0, h > 0, count == (kind == 1 ? 32 : 256), paletteOffset == 0x20,
              decoded.count == paletteOffset + count * 2 + w * h else {
            throw OriginalDataError.invalid("Original linear bitmap section sizes")
        }
        width = w; height = h
        decodedPayload = decoded
        self.kind = kind
        palette = try (0..<count).map { try r.u16(paletteOffset + $0 * 2) }
        indices = Array(try r.range(paletteOffset + count * 2, w * h))
    }

    /**
     * Decodes the Nintendo 0x30 stream used by the original still backgrounds.
     */
    static func decodeRunLength(_ data: Data) throws -> Data {
        let reader = OriginalBytes(data)
        let header = try reader.u32(0)
        let length = Int(header >> 8)
        guard header & 0xFF == 0x30, length > 0, length <= 64 * 1024 * 1024 else {
            throw OriginalDataError.invalid("Bitmap run-length header")
        }
        var output = Data(), cursor = 4
        output.reserveCapacity(length)
        while output.count < length {
            let control = try reader.range(cursor, 1).first!
            cursor += 1
            let repeated = control & 0x80 != 0
            let count = Int(control & 0x7F) + (repeated ? 3 : 1)
            guard count <= length - output.count else {
                throw OriginalDataError.invalid("Bitmap run-length output overflow")
            }
            if repeated {
                let value = try reader.range(cursor, 1).first!
                output.append(contentsOf: repeatElement(value, count: count))
                cursor += 1
            } else {
                output.append(contentsOf: try reader.range(cursor, count))
                cursor += count
            }
        }
        guard cursor == data.count else { throw OriginalDataError.invalid("Bitmap run-length trailing bytes") }
        return output
    }

    public func rgba(transparentPaletteZero: Bool) -> Data {
        var data = [UInt8](); data.reserveCapacity(width * height * 4)
        for index in indices {
            let packed = palette[Int(kind == 1 ? index & 31 : index)]
            for shift in [0, 5, 10] {
                let value = UInt8((packed >> shift) & 31)
                data.append((value << 3) | (value >> 2))
            }
            if kind == 1 {
                let alpha = index >> 5
                let expanded = (alpha << 2) | (alpha >> 1)
                data.append((expanded << 3) | (expanded >> 2))
            } else { data.append(transparentPaletteZero && index == 0 ? 0 : 255) }
        }
        return Data(data)
    }
}

extension OriginalBitmapLibrary {
    /// Loads a member that the tiled-bitmap manifest leaves unresolved, after
    /// checking its payload hash, as an original linear bitmap.
    public func loadLinear(path: String) throws -> OriginalLinearBitmap {
        try .init(data: checkedPayload(path: path))
    }

    /**
     * Loads a DTX member from the bitmap archive without imposing linear-bitmap dimensions.
     */
    public func loadTexture(path: String) throws -> OriginalTexture {
        try .init(data: checkedPayload(path: path))
    }

    private func checkedPayload(path: String) throws -> Data {
        guard let record = manifest.images.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        let url = resourceRoot.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(resourceRoot.path + "/") else { throw OriginalDataError.invalid("Bitmap path leaves source directory") }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return data
    }
}
