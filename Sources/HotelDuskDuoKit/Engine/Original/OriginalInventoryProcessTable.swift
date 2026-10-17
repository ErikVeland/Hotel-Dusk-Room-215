import Foundation

/**
 * Inventory processes selected by trickitem.bin and the search dispatcher at 0x02031944.
 */
public struct OriginalInventoryProcessTable: Sendable {
    public struct Record: Equatable, Sendable {
        public let index: Int16
        public let item: UInt16
        public let trick: UInt16
        public let requiredItem: UInt16
        public var processID: UInt16 { trick + 23 }
    }
    public let records: [Record]

    public init(data: Data) throws {
        let bytes = OriginalBytes(data)
        let count = Int(try bytes.u16(0))
        guard data.count == 2 + count * 6, count <= Int(Int16.max) else {
            throw OriginalDataError.invalid("Inventory process table length")
        }
        records = try (0..<count).map { index in
            let offset = 2 + index * 6
            let trick = try bytes.u16(offset + 2)
            guard trick <= UInt16.max - 23 else { throw OriginalDataError.invalid("Inventory process ID") }
            return try Record(index: Int16(index), item: bytes.u16(offset), trick: trick,
                              requiredItem: bytes.u16(offset + 4))
        }
    }

    public func process(for item: UInt8, game: OriginalGameState) throws -> Record? {
        let inventory = try game.inventory.items
        guard inventory.contains(item), let record = records.first(where: { $0.item == UInt16(item) }) else { return nil }
        if record.requiredItem != 0 {
            return inventory.contains(UInt8(truncatingIfNeeded: record.requiredItem)) ? record : nil
        }
        if item == 8, game.value(for: .gameFlag(index: 26)) == true { return nil }
        if (item == 13 || item == 63), game.chapter > 1 { return nil }
        return record
    }

    public static func bundled() throws -> Self {
        guard let root = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("Inventory process table")
        }
        struct Manifest: Decodable {
            struct File: Decodable { let name: String; let sha256: String }
            let files: [File]
        }
        let name = "trickitem.bin"
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        guard let record = manifest.files.first(where: { $0.name == name }) else { throw OriginalDataError.missing(name) }
        let data = try Data(contentsOf: root.appendingPathComponent(name))
        guard OriginalScriptCatalog.digest(data) == record.sha256 else { throw OriginalDataError.checksum(name) }
        return try Self(data: data)
    }
}
