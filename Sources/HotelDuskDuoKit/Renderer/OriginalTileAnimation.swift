import Foundation

public enum OriginalNintendoLZ {
    /// Nintendo LZ10, as selected by ARM9 02094088/02094120.
    public static func decode10(_ data: Data) throws -> Data {
        let bytes = Array(data)
        guard bytes.count >= 4, bytes[0] == 0x10 else { throw OriginalDataError.unsupported("Nintendo compression") }
        let length = Int(bytes[1]) | Int(bytes[2]) << 8 | Int(bytes[3]) << 16
        guard length > 0, length <= 64 * 1024 * 1024 else { throw OriginalDataError.invalid("LZ10 output size") }
        var output = [UInt8](), cursor = 4
        output.reserveCapacity(length)
        while output.count < length {
            guard cursor < bytes.count else { throw OriginalDataError.invalid("Truncated LZ10 flags") }
            let flags = bytes[cursor]
            cursor += 1
            for bit in stride(from: 7, through: 0, by: -1) {
                if output.count == length { break }
                if flags & (1 << bit) != 0 {
                    guard cursor + 2 <= bytes.count else { throw OriginalDataError.invalid("Truncated LZ10 reference") }
                    let high = Int(bytes[cursor]), low = Int(bytes[cursor + 1])
                    cursor += 2
                    let count = (high >> 4) + 3, distance = ((high & 15) << 8 | low) + 1
                    guard distance <= output.count, output.count + count <= length else {
                        throw OriginalDataError.invalid("LZ10 back-reference")
                    }
                    for _ in 0..<count { output.append(output[output.count - distance]) }
                } else {
                    guard cursor < bytes.count else { throw OriginalDataError.invalid("Truncated LZ10 literal") }
                    output.append(bytes[cursor])
                    cursor += 1
                }
            }
        }
        guard cursor == bytes.count else { throw OriginalDataError.invalid("Unconsumed LZ10 data") }
        return Data(output)
    }
}

/// Opening LRIM clips use a full tiled bitmap followed by original tile deltas.
/// Their script controls timing. There is no inferred frame rate or loop.
public struct OriginalTileAnimationClip: Sendable {
    public let payloadSHA256: String
    public let frames: [Data]
    public let headerPalette: Data
    public let initialTileData: Data
    public var frameCount: Int { frames.count }

    public init(data: Data) throws {
        let reader = OriginalBytes(data)
        guard try Data(reader.range(0, 4)) == Data("LRIM".utf8) else { throw OriginalDataError.unsupported("Tiled animation format") }
        let count = Int(try reader.u32(4)), offsets = Int(try reader.u32(8)), sizes = Int(try reader.u32(12))
        guard count > 0, count <= 255, offsets == 16, sizes == 16 + count * 4 else {
            throw OriginalDataError.invalid("LRIM table layout")
        }
        var end = 16 + count * 8
        _ = try reader.range(0, end)
        var decoded = [Data]()
        for index in 0..<count {
            let offset = Int(try reader.u32(offsets + index * 4)), size = Int(try reader.u32(sizes + index * 4))
            guard offset >= end, size >= 4 else { throw OriginalDataError.invalid("LRIM frame bounds") }
            decoded.append(try OriginalNintendoLZ.decode10(Data(reader.range(offset, size))))
            end = offset + size
        }
        let first = try OriginalBitmap(data: decoded[0])
        guard first.width == 256, first.height == 192, first.paletteCount == 256 else {
            throw OriginalDataError.unsupported("LRIM initial bitmap")
        }
        for frame in decoded.dropFirst() {
            guard frame.count >= 96 else { throw OriginalDataError.invalid("Truncated LRIM mask") }
            let replacements = frame.prefix(96).reduce(0) { $0 + $1.nonzeroBitCount }
            guard frame.count == 96 + replacements * 64 else { throw OriginalDataError.invalid("LRIM replacement tile count") }
        }
        payloadSHA256 = OriginalAnimationClip.digest(data)
        frames = decoded
        headerPalette = Data(decoded[0].prefix(528))
        initialTileData = Data(decoded[0].dropFirst(528))
    }
}

public struct OriginalTileAnimationCheckpoint: Codable, Equatable, Sendable {
    public let payloadSHA256: String
    public let frameIndex: Int
    public let tileData: Data
}

public struct OriginalTileAnimationDecoder: Sendable {
    public let clip: OriginalTileAnimationClip
    public private(set) var frameIndex: Int = -1
    public private(set) var tileData: Data

    public init(clip: OriginalTileAnimationClip) {
        self.clip = clip
        tileData = clip.initialTileData
    }

    public mutating func advance() throws -> OriginalBitmap? {
        let next = frameIndex + 1
        guard next < clip.frameCount else { return nil }
        if next > 0 {
            let frame = clip.frames[next]
            var cursor = 96
            for tile in 0..<768 where frame[tile / 8] & (0x80 >> (tile & 7)) != 0 {
                tileData.replaceSubrange(tile * 64..<tile * 64 + 64, with: frame[cursor..<cursor + 64])
                cursor += 64
            }
        }
        frameIndex = next
        return try currentBitmap()
    }

    public func currentBitmap() throws -> OriginalBitmap {
        guard frameIndex >= 0 else { throw OriginalDataError.invalid("LRIM has not presented a frame") }
        return try OriginalBitmap(data: clip.headerPalette + tileData)
    }

    public mutating func seek(frame: Int) throws -> OriginalBitmap {
        guard frame >= 0, frame < clip.frameCount else { throw OriginalDataError.invalid("LRIM frame index") }
        var rebuilt = Self(clip: clip)
        for _ in 0...frame { _ = try rebuilt.advance() }
        self = rebuilt
        return try currentBitmap()
    }

    public func checkpoint() -> OriginalTileAnimationCheckpoint {
        .init(payloadSHA256: clip.payloadSHA256, frameIndex: frameIndex, tileData: tileData)
    }

    public mutating func restore(_ checkpoint: OriginalTileAnimationCheckpoint) throws {
        guard checkpoint.payloadSHA256 == clip.payloadSHA256, checkpoint.frameIndex >= -1,
              checkpoint.frameIndex < clip.frameCount, checkpoint.tileData.count == 49152 else {
            throw OriginalDataError.invalid("LRIM checkpoint does not match clip")
        }
        frameIndex = checkpoint.frameIndex
        tileData = checkpoint.tileData
    }
}

public struct OriginalTileAnimationLibrary: Sendable {
    public struct Manifest: Decodable, Sendable {
        public struct Coverage: Decodable, Sendable { public let animations: Int; public let frames: Int }
        public struct Frame: Decodable, Sendable {
            public let frame: Int
            public let decompressedSHA256: String
            public let pixelsSHA256: String
            public let rgbaSHA256: String
        }
        public struct Record: Decodable, Sendable {
            public let source: String
            public let payloadSHA256: String
            public let frameCount: Int
            public let frames: [Frame]
        }
        public let formatVersion: Int
        public let coverage: Coverage
        public let animations: [Record]
    }
    public let manifest: Manifest
    private let root: URL

    public init(resourceRoot: URL) throws {
        root = resourceRoot.standardizedFileURL
        manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf:
            root.appendingPathComponent("OriginalTileAnimationManifest.json")))
        guard manifest.formatVersion == 1 else { throw OriginalDataError.unsupported("Tile animation manifest version") }
    }
    public static func bundled() throws -> Self {
        guard let root = Bundle.module.resourceURL else { throw OriginalDataError.missing("OriginalBitmaps") }
        return try .init(resourceRoot: root.appendingPathComponent("OriginalBitmaps"))
    }
    public func load(path: String) throws -> OriginalTileAnimationClip {
        guard let record = manifest.animations.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        let url = root.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else { throw OriginalDataError.invalid("Tile animation path leaves source directory") }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return try .init(data: data)
    }
}
