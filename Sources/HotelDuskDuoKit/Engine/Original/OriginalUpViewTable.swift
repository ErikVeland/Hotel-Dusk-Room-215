import Foundation

/**
 * Close-up layers indexed by 0x020B4A80. Each view has one background and up to 15 overlays.
 */
public struct OriginalUpViewTable: Sendable {
    public struct Layer: Equatable, Sendable {
        public let asset: String
        public let detailAsset: String
        public let eventID: Int16
        public let itemID: Int16
        public let processID: Int16
        public let reserved: UInt16
    }
    public struct View: Equatable, Sendable {
        public let id: Int16
        public let background: String
        public let layers: [Layer]
    }
    public let views: [View]

    public init(data: Data) throws {
        let reader = OriginalBytes(data), count = Int(try OriginalBytes(data).u32(0))
        guard count <= (data.count - 4) / 20 else { throw OriginalDataError.invalid("Close-up table length") }
        /**
         * Names occupy 16 bytes. R117's close_plate_rest uses the complete field.
         */
        func name(at offset: Int) throws -> String {
            String(decoding: try reader.range(offset, 16).prefix { $0 != 0 }, as: UTF8.self)
        }
        var cursor = 4 + count * 20
        views = try (0..<count).map { index in
            let offset = 4 + index * 20
            let layerCount = Int(try reader.u16(offset + 2))
            guard (1...16).contains(layerCount) else { throw OriginalDataError.invalid("Close-up layer count") }
            let layers = try (0..<(layerCount - 1)).map { _ -> Layer in
                let start = cursor
                cursor += 40
                return Layer(asset: try name(at: start),
                    detailAsset: try name(at: start + 16),
                    eventID: Int16(bitPattern: try reader.u16(start + 32)),
                    itemID: Int16(bitPattern: try reader.u16(start + 34)),
                    processID: Int16(bitPattern: try reader.u16(start + 36)), reserved: try reader.u16(start + 38))
            }
            return View(id: Int16(bitPattern: try reader.u16(offset)),
                background: try name(at: offset + 4), layers: layers)
        }
        // 0x020B4A80 addresses only the declared views and layers. R103 retains unused records.
        // Each referenced record is bounds-checked by OriginalBytes above.
    }

    public static func bundled(map: String) throws -> Self {
        guard let root = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("Close-up table")
        }
        struct Manifest: Decodable {
            struct File: Decodable { let name: String; let sha256: String }
            let files: [File]
        }
        let name = "sdata/\(map).upv"
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        guard let record = manifest.files.first(where: { $0.name == name }) else { throw OriginalDataError.missing(name) }
        let data = try Data(contentsOf: root.appendingPathComponent(name))
        guard OriginalScriptCatalog.digest(data) == record.sha256 else { throw OriginalDataError.checksum(name) }
        return try Self(data: data)
    }
}
