import Foundation

/**
 * Door selection state. The event runner owns dialogue, inventory and lock changes.
 */
public struct OriginalDoorScene {
    public let destination: Int16
    public let doorID: Int16
    public let area: UInt16
    public let view: OriginalUpViewTable.View
    public private(set) var selected: Int?
    public private(set) var item: UInt8?

    public init(destination: Int16, doorID: Int16, area: UInt16, view: OriginalUpViewTable.View) {
        self.destination = destination
        self.doorID = doorID
        self.area = area
        self.view = view
    }

    /**
     * A second press on the same component confirms it. Empty pixels clear the selection.
     */
    public mutating func select(_ component: Int?) -> Bool {
        let valid = component.flatMap { ($0 > 0 && $0 <= view.layers.count) ? $0 : nil }
        let confirmed = valid != nil && valid == selected
        selected = valid
        return confirmed
    }

    public mutating func use(_ item: UInt8?) { self.item = item; selected = nil }
    public mutating func clearSelection() { selected = nil }

    /**
     * The Chapter 10 cellar passage removes its plate after the source door event.
     */
    public func visibility(game: OriginalGameState) -> [Bool] {
        [true] + view.layers.map { layer in
            guard doorID == 42, layer.eventID == 415 else { return true }
            return game.value(for: .doorOpen(index: UInt16(doorID))) != false
        }
    }
}

/**
 * Original inventory labels from the 34-byte itemtext.dat records.
 */
public struct OriginalItemNames {
    public let names: [UInt8: String]

    public init(data: Data) throws {
        let reader = OriginalBytes(data), count = Int(try OriginalBytes(data).u32(0))
        guard count <= (data.count - 4) / 34, data.count == 4 + count * 34 else {
            throw OriginalDataError.invalid("Item name table length")
        }
        var names: [UInt8: String] = [:]
        for index in 0..<count {
            let offset = 4 + index * 34, id = try reader.u16(4 + index * 34)
            guard id < 88 else { throw OriginalDataError.invalid("Item name ID") }
            if names[UInt8(id)] == nil {
                names[UInt8(id)] = String(bytes: try reader.zeroTerminated(offset + 2, limit: 32), encoding: .isoLatin1)
            }
        }
        self.names = names
    }

    public static func bundled() throws -> Self {
        guard let root = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("Item names")
        }
        struct Manifest: Decodable {
            struct File: Decodable { let name: String; let sha256: String }
            let files: [File]
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        let data = try Data(contentsOf: root.appendingPathComponent("itemtext.dat"))
        guard manifest.files.first(where: { $0.name == "itemtext.dat" })?.sha256 == OriginalScriptCatalog.digest(data) else {
            throw OriginalDataError.checksum("itemtext.dat")
        }
        return try Self(data: data)
    }
}
