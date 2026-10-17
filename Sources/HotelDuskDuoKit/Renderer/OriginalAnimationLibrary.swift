import Foundation

public struct OriginalAnimationLibrary: Sendable {
    public let manifest: OriginalAnimationManifest
    private let resourceRoot: URL

    public init(resourceRoot: URL) throws {
        self.resourceRoot = resourceRoot
        let data = try Data(contentsOf: resourceRoot.appendingPathComponent("OriginalAnimationManifest.json"))
        manifest = try JSONDecoder().decode(OriginalAnimationManifest.self, from: data)
        guard manifest.formatVersion == 1 else { throw OriginalAnimationError.invalid("unsupported manifest version") }
    }

    public static func bundled() throws -> OriginalAnimationLibrary {
        guard let root = Bundle.module.resourceURL?.appendingPathComponent("OriginalAnimations"),
              FileManager.default.fileExists(atPath: root.path) else {
            throw OriginalAnimationError.missing("OriginalAnimations")
        }
        return try .init(resourceRoot: root)
    }

    public func load(id: String) throws -> OriginalAnimationClip {
        guard let record = manifest.animations.first(where: { $0.id == id }) else {
            throw OriginalAnimationError.missing(id)
        }
        guard record.status == "decoded" else {
            throw OriginalAnimationError.unsupported(record.error ?? id)
        }
        let data = try verifiedPayload(path: record.source, sha256: record.payloadSHA256)
        return try .init(data: data, id: id)
    }

    public func loadColourGrid(id: String) throws -> OriginalAnimationColourGrid {
        guard let record = manifest.colourOverlays.first(where: { $0.id == id }) else {
            throw OriginalAnimationError.missing(id)
        }
        return try .init(data: verifiedPayload(path: record.source, sha256: record.payloadSHA256))
    }

    private func verifiedPayload(path: String, sha256: String) throws -> Data {
        let url = resourceRoot.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(resourceRoot.standardizedFileURL.path + "/") else {
            throw OriginalAnimationError.invalid("resource path leaves its animation directory")
        }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == sha256 else {
            throw OriginalAnimationError.invalid("payload hash differs from source manifest: \(path)")
        }
        return data
    }
}

public struct OriginalAnimationManifest: Decodable, Sendable {
    public let formatVersion: Int
    public let animations: [AnimationRecord]
    public let colourOverlays: [ColourRecord]
    public let coverage: Coverage
    public let remaining: [String]

    public struct AnimationRecord: Decodable, Sendable {
        public let id: String
        public let source: String
        public let payloadSHA256: String
        public let frameCount: Int
        public let loopStartIndex: Int
        public let status: String
        public let error: String?
        public let frames: [FrameRecord]
    }
    public struct FrameRecord: Decodable, Sendable {
        public let index: Int
        public let indexSHA256: String
        public let paletteSHA256: String
        public let rgbaSHA256: String
    }
    public struct ColourRecord: Decodable, Sendable {
        public let id: String
        public let source: String
        public let payloadSHA256: String
        public let frameCount: Int
        public let frameSHA256: [String]
    }
    public struct Coverage: Decodable, Sendable {
        public let animations: Int
        public let frames: Int
        public let decodedAnimations: Int
        public let decodedFrames: Int
        public let unsupportedAnimations: Int
        public let colourOverlays: Int
    }
}

/// Original MTC RGB555 vertex colours for the 17 by 33 character mesh.
/// These are not a bitmap overlay. The native renderer must use the recovered
/// mesh coordinates and texture modulation before this can alter a game frame.
public struct OriginalAnimationColourGrid: Sendable {
    public static let columns = 17
    public static let rows = 33
    public let frameCount: Int
    public let originalWidth: Int
    public let originalHeight: Int
    public let firstFrameNumber: Int
    public let lastFrameNumber: Int
    public let loopFrameNumber: Int
    private let bytes: [UInt8]

    public init(data: Data) throws {
        let b = Array(data)
        guard b.count >= 32 else { throw OriginalAnimationError.invalid("truncated MTC header") }
        func u16(_ i: Int) -> Int { Int(b[i]) | (Int(b[i + 1]) << 8) }
        let count = u16(0) | (u16(2) << 16)
        guard count > 0 && count <= 4096 && b.count == 32 + count * 1122 else {
            throw OriginalAnimationError.invalid("invalid MTC vertex count")
        }
        frameCount = count
        originalWidth = u16(4)
        originalHeight = u16(6)
        firstFrameNumber = u16(8)
        lastFrameNumber = u16(10)
        loopFrameNumber = u16(12)
        bytes = b
    }

    public func originalColours(frame: Int) throws -> [UInt16] {
        guard (0..<frameCount).contains(frame) else { throw OriginalAnimationError.invalid("MTC frame index outside animation") }
        let start = 32 + frame * 1122
        return stride(from: start, to: start + 1122, by: 2).map {
            UInt16(bytes[$0]) | (UInt16(bytes[$0 + 1]) << 8)
        }
    }
}
