import Foundation

/**
 * Object flags and model names from the 48-byte onoffobjs.dat records.
 */
public struct OriginalObjectVisibility: Sendable {
    public struct Record: Equatable, Sendable {
        public let flag: UInt16
        public let map: Int16
        public let area: UInt16
        public let subarea: UInt16
        public let roomNode: String
    }
    public let records: [Record]

    public init(data: Data) throws {
        let reader = OriginalBytes(data)
        let count = Int(try reader.u32(0))
        guard data.count >= 4, count <= (data.count - 4) / 48, data.count == 4 + count * 48 else {
            throw OriginalDataError.invalid("Object visibility table length")
        }
        records = try (0..<count).map { index in
            let offset = 4 + index * 48
            let flag = try reader.u16(offset)
            guard flag < 256 else { throw OriginalDataError.invalid("Object visibility flag") }
            return Record(flag: flag, map: Int16(bitPattern: try reader.u16(offset + 2)),
                area: try reader.u16(offset + 4), subarea: try reader.u16(offset + 6),
                roomNode: String(decoding: try reader.zeroTerminated(offset + 12, limit: 16), as: UTF8.self))
        }
    }

    public static func bundled() throws -> Self {
        guard let root = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("Object visibility table")
        }
        let data = try Data(contentsOf: root.appendingPathComponent("onoffobjs.dat"))
        guard OriginalScriptCatalog.digest(data) == "8ba8e930bdec70e56109b36c368e05631731225222e714a0c6db04494b0350cc" else {
            throw OriginalDataError.checksum("onoffobjs.dat")
        }
        return try Self(data: data)
    }

    /**
     * 0x0202C624 controls room nodes. 0x02033938 controls search rendering and hit geometry.
     * 0x0208C5A4 changes the first node with the requested name prefix.
     */
    public func visibleNodes(in model: OriginalModel, map: Int16, area: UInt16?, game: OriginalGameState) -> Set<Int> {
        var visible = Set(model.nodes.indices)
        for record in records where record.map == map && (area == nil || record.area == area) {
            let name = area == nil ? record.roomNode : String(format: "obj%02d", Int(record.subarea))
            guard let index = model.nodes.firstIndex(where: { $0.name.hasPrefix(name) }) else { continue }
            if game.objectVisible(record.flag) { visible.insert(index) }
            else { visible.remove(index) }
        }
        return visible
    }
}
