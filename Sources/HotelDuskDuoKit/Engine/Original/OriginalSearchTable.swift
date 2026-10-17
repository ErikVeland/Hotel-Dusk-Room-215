import Foundation

/// Search-view table `data/map/sdata/<map>.srh`, loaded by the search process
/// initializer 0x02030B04 and indexed by 0x020B45E4. The layout is a u16 area
/// count, a u16 second-table count, 20-byte area records, 24-byte records and
/// then 8-byte subarea entries. Bytes after the entry table are retained but
/// not interpreted (R119, R123, R126 and R304 contain such bytes).
public struct OriginalSearchTable: Equatable, Sendable {
    public struct Area: Equatable, Sendable {
        public let areaID: UInt16
        public let entries: [Entry]
        /// Model resource name, for example `R102_03`. Stored NUL-padded.
        public let name: String
    }
    public struct Entry: Equatable, Sendable {
        public let subareaID: UInt16
        /// Up-view selector returned by 0x020B462C. 0xFFFF is no up view.
        public let upViewID: UInt16
        public let raw: [UInt8]
    }
    public struct Door: Equatable, Sendable {
        public let areaID: UInt16
        public let upViewID: UInt16
        public let doorID: UInt16
        public let name: String
    }

    public let areas: [Area]
    public let secondRecords: [[UInt8]]
    public let doors: [Door]
    public let trailingBytes: [UInt8]

    public init(data: Data) throws {
        let reader = OriginalBytes(data)
        let areaCount = Int(try reader.u16(0)), secondCount = Int(try reader.u16(2))
        var counts: [(UInt16, Int, String)] = []
        for index in 0..<areaCount {
            let offset = 4 + index * 20
            let name = try reader.zeroTerminated(offset + 4, limit: 16)
            counts.append((try reader.u16(offset), Int(try reader.u16(offset + 2)),
                           String(decoding: name, as: UTF8.self)))
        }
        var offset = 4 + areaCount * 20
        secondRecords = try (0..<secondCount).map { index in
            Array(try reader.range(offset + index * 24, 24))
        }
        doors = try (0..<secondCount).map { index in
            let start = offset + index * 24
            return Door(areaID: try reader.u16(start), upViewID: try reader.u16(start + 2),
                doorID: try reader.u16(start + 4),
                name: String(decoding: try reader.zeroTerminated(start + 8, limit: 16), as: UTF8.self))
        }
        offset += secondCount * 24
        var areas: [Area] = []
        for (areaID, count, name) in counts {
            let entries = try (0..<count).map { index -> Entry in
                let start = offset + index * 8
                return Entry(subareaID: try reader.u16(start), upViewID: try reader.u16(start + 2),
                             raw: Array(try reader.range(start, 8)))
            }
            offset += count * 8
            areas.append(Area(areaID: areaID, entries: entries, name: name))
        }
        self.areas = areas
        trailingBytes = Array(data.dropFirst(offset))
    }

    /// GameData copies of the original tables, checked against the manifest.
    public static func bundled(map: String) throws -> Self {
        guard let directory = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("Original game data")
        }
        struct Manifest: Decodable { struct File: Decodable { let name: String; let sha256: String }; let files: [File] }
        let manifest = try JSONDecoder().decode(Manifest.self,
            from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        let name = "sdata/\(map).srh"
        guard let record = manifest.files.first(where: { $0.name == name }) else {
            throw OriginalDataError.missing(name)
        }
        let data = try Data(contentsOf: directory.appendingPathComponent(name))
        guard OriginalScriptCatalog.digest(data) == record.sha256 else { throw OriginalDataError.checksum(name) }
        return try Self(data: data)
    }

    /// 0x020B462C: the first area with this ID, then its first matching subarea.
    /// Returns nil where the source returns -1 (no area or no entry).
    public func upViewID(area: UInt16, subarea: UInt16) -> UInt16? {
        guard let match = areas.first(where: { $0.areaID == area }) else { return nil }
        return match.entries.first(where: { $0.subareaID == subarea })?.upViewID
    }

    /**
     * 0x020B4894 and 0x020B48D8 return the first matching door view and area.
     */
    public func door(id: UInt16) -> Door? { doors.first { $0.doorID == id } }
}

/// The look branch of the search process (0x0203314C, then 0x02031944 case 0).
/// It writes the talk session read by the selector at 0x020551B8.
public enum OriginalSearchSelection {
    public enum Outcome: Equatable, Sendable {
        /// Case 0: scene 0xFFFE, mode 10, event 0, block 0, the area and the
        /// picked subarea, and upView from search-process field +0x32.
        case look(OriginalEventSelectionContext)
        /**
         * Case 2 runs the same entry event before the host opens process 98.
         */
        case closeup(OriginalEventSelectionContext, upViewID: UInt16)
    }

    /// `subarea` is the two digits of the picked `objNN` model node
    /// (0x02033528). `upViewField` is search-process +0x32, which the
    /// initializer 0x02030B04 sets to -1 and no recovered code changes.
    public static func look(table: OriginalSearchTable, mapID: Int16, nowTime: UInt16,
                            area: UInt16, subarea: UInt16, upViewField: Int16 = -1) -> Outcome {
        var context = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0, modeID: 10, eventID: 0,
                                                    nowTime: nowTime, mapID: mapID)
        context.areaID = area
        context.subareaID = subarea
        context.upViewID = upViewField
        if let upView = table.upViewID(area: area, subarea: subarea), upView < 0xFFFF {
            return .closeup(context, upViewID: upView)
        }
        return .look(context)
    }
}
