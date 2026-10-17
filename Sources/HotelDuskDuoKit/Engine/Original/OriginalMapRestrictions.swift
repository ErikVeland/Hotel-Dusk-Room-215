import Foundation

/**
 * Original standing-position restrictions read by 0x0202E394 and 0x020B58EC.
 */
public struct OriginalMapRestrictions: Sendable {
    public struct Place: Sendable {
        public let map: Int16
        public let point: Int16
        public let blockedSearchAreas: [Int16]
        public let blockedDoor: Int16
    }
    public let places: [Place]
    private let occupiedMapSearchPermissions: [UInt8]

    public init(standPlaces: Data, occupiedMapSearchPermissions: Data) throws {
        let reader = OriginalBytes(standPlaces)
        let count = Int(try reader.u32(0))
        guard standPlaces.count >= 4, count <= (standPlaces.count - 4) / 16,
              standPlaces.count == 4 + count * 16, occupiedMapSearchPermissions.count == 47 else {
            throw OriginalDataError.invalid("Original map restriction tables")
        }
        places = try (0..<count).map { index in
            let offset = 4 + index * 16
            return Place(map: Int16(bitPattern: try reader.u16(offset + 2)),
                point: Int16(bitPattern: try reader.u16(offset + 4)),
                blockedSearchAreas: try (0..<4).map { Int16(bitPattern: try reader.u16(offset + 6 + $0 * 2)) },
                blockedDoor: Int16(bitPattern: try reader.u16(offset + 14)))
        }
        self.occupiedMapSearchPermissions = Array(occupiedMapSearchPermissions)
    }

    public static func bundled() throws -> Self {
        guard let root = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("Original map restrictions")
        }
        struct Manifest: Decodable {
            struct File: Decodable { let name: String; let sha256: String }
            let files: [File]
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        func checked(_ name: String) throws -> Data {
            guard let record = manifest.files.first(where: { $0.name == name }) else { throw OriginalDataError.missing(name) }
            let data = try Data(contentsOf: root.appendingPathComponent(name))
            guard OriginalScriptCatalog.digest(data) == record.sha256 else { throw OriginalDataError.checksum(name) }
            return data
        }
        return try Self(standPlaces: checked("standplace.dat"),
                        occupiedMapSearchPermissions: checked("map_search_permissions.bin"))
    }

    /**
     * 0x0202E394 checks story gates, room occupancy, then each person's standing position.
     */
    public func permitsSearch(area: Int16, game: OriginalGameState) -> Bool {
        let map = game.mapID
        guard (0..<47).contains(map) else { return false }
        if map == 43, area == 2,
           game.value(for: .gameFlag(index: 32)) == true || game.value(for: .gameFlag(index: 48)) == false { return false }
        if game.chapter == 9, game.nowTime == 3 { return false }
        for person in 0..<18 {
            guard let marker = game.personMarker(person), marker / 100 == Int(map) else { continue }
            if game.bytes[0x87F] == 0, occupiedMapSearchPermissions[Int(map)] == 0 { return false }
            if let place = places.first(where: { $0.map == map && $0.point == Int16(marker % 100) }),
               place.blockedSearchAreas.contains(area) { return false }
        }
        return true
    }

    /**
     * 0x0202E938 checks the destination gate, then people standing at this door.
     */
    public func permitsDoor(to destination: Int16, table: OriginalDoorTable, game: OriginalGameState) -> Bool {
        if destination == 41, game.value(for: .gameFlag(index: 32)) != true { return false }
        let door = table.connection(from: game.mapID, to: destination)?.id ?? -1
        for person in 0..<18 {
            guard let marker = game.personMarker(person), marker / 100 == Int(game.mapID) else { continue }
            if let place = places.first(where: { $0.map == game.mapID && $0.point == Int16(marker % 100) }),
               place.blockedDoor == door { return false }
        }
        return true
    }
}
