import Foundation
import CryptoKit

/// Original strings retain their control bytes and indexes. A text-table index
/// is not an execution order; BLK/CHK records select the dialogue at runtime.
public struct OriginalTextTable: Sendable {
    public struct Entry: Sendable, Equatable {
        public let index: Int
        public let offset: Int
        public let bytes: Data
        public var utf8: String? { String(data: bytes, encoding: .utf8) }
    }
    public let entries: [Entry]
    public init(decoded data: Data) throws {
        let reader = OriginalBytes(data)
        let count = Int(try reader.u32(0))
        guard count <= (data.count - 4) / 4 else { throw OriginalDataError.invalid("Text offset count") }
        let base = 4 + count * 4
        entries = try (0..<count).map { index in
            let relative = Int(try reader.u32(4 + index * 4))
            guard relative < data.count - base else { throw OriginalDataError.invalid("Text offset \(index)") }
            let offset = base + relative
            return Entry(index: index, offset: offset,
                         bytes: Data(try reader.zeroTerminated(offset, limit: data.count - offset)))
        }
    }
}

public struct OriginalEventLabel: Sendable, Equatable {
    public let sourceOffset: Int
    public let key: UInt16
    public let label: String
    public static func decode(_ data: Data) throws -> [Self] {
        guard data.count % 32 == 0 else { throw OriginalDataError.invalid("DBG record size") }
        let reader = OriginalBytes(data)
        return try stride(from: 0, to: data.count, by: 32).map { offset in
            let bytes = try reader.zeroTerminated(offset + 2, limit: 30)
            guard let label = String(bytes: bytes, encoding: .ascii) else {
                throw OriginalDataError.invalid("DBG label encoding")
            }
            return Self(sourceOffset: offset, key: try reader.u16(offset), label: label)
        }
    }
}

public struct OriginalChoiceRecord: Sendable, Equatable {
    public let sourceOffset: Int
    public let labelBytes: Data
    /// These fields remain opaque until their original handlers are recovered.
    public let fields: [UInt32]
    public static func decode(_ data: Data) throws -> [Self] {
        guard data.count % 64 == 0 else { throw OriginalDataError.invalid("KIF record size") }
        let reader = OriginalBytes(data)
        return try stride(from: 0, to: data.count, by: 64).map { offset in
            Self(sourceOffset: offset,
                 labelBytes: Data(try reader.zeroTerminated(offset, limit: 48)),
                 fields: try (0..<4).map { try reader.u32(offset + 48 + $0 * 4) })
        }
    }
}

/// A chapter's `.ttk` keyword table (`EP1_.ttk`), read by the question menu
/// at 0x0203D61C. Each 0x80-byte record holds the label (0x00–0x5F), the
/// keyword ID (u16 at 0x60) and one flag byte per person (0x70 + person).
/// A first byte of 0xFF ends the table.
public struct OriginalKeywordTable: Sendable, Equatable {
    public struct Record: Sendable, Equatable {
        public let index: Int
        public let labelBytes: Data
        public let keywordID: UInt16
        public let personFlags: [UInt8]
        public var label: String { String(data: labelBytes, encoding: .isoLatin1) ?? "" }
    }
    public let records: [Record]

    public init(decoded data: Data) throws {
        let reader = OriginalBytes(data)
        var records: [Record] = []
        var offset = 0
        while offset + 0x80 <= data.count, reader.bytes[offset] != 0xFF, records.count < 0x80 {
            records.append(Record(index: records.count,
                labelBytes: Data(try reader.zeroTerminated(offset, limit: 0x60)),
                keywordID: try reader.u16(offset + 0x60),
                personFlags: Array(try reader.range(offset + 0x70, 0x10))))
            offset += 0x80
        }
        self.records = records
    }

    /// `EP1_R102` uses `EP1_.ttk`.
    public static func chapterFile(for program: String) -> String? {
        guard let underscore = program.firstIndex(of: "_") else { return nil }
        return program[...underscore] + ".ttk"
    }
}

public struct OriginalScriptProgram: Sendable {
    public let name: String
    public let text: OriginalTextTable
    public let eventLabels: [OriginalEventLabel]
    public let choices: [OriginalChoiceRecord]
    public let blockData: Data
    public let conditionData: Data
    public var review: OriginalChapterReview? = nil
    public var blocks: OriginalBlockGraph { get throws { try OriginalBlockGraph(decoded: blockData) } }
    public var conditions: OriginalConditions {
        get throws { try OriginalConditions(decoded: conditionData, eventCount: blocks.tables[2].count) }
    }
}

/// Bundled source records are checked before decoding. This catalog describes
/// recovered data; it does not assert that its command semantics are ported.
public struct OriginalScriptCatalog: Sendable {
    public struct Manifest: Decodable, Sendable {
        public let romSHA256: String
        public let files: [FileRecord]
    }
    public struct FileRecord: Decodable, Sendable {
        public let name: String
        public let sha256: String
        public let decodedSHA256: String?
    }
    public let manifest: Manifest
    private let directory: URL

    public static func bundled() throws -> Self {
        guard let directory = Bundle.module.url(forResource: "Scripts", withExtension: nil) else {
            throw OriginalDataError.missing("Original script resources")
        }
        return try Self(directory: directory)
    }

    public init(directory: URL) throws {
        self.directory = directory
        manifest = try JSONDecoder().decode(Manifest.self,
                        from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        let names = manifest.files.map(\.name)
        guard Set(names).count == names.count,
              names.allSatisfy({ !$0.contains("/") && !$0.contains("\\") && $0 != ".." }) else {
            throw OriginalDataError.invalid("Script manifest names")
        }
    }

    public func decodedFile(_ name: String) throws -> Data {
        guard let record = manifest.files.first(where: { $0.name == name }) else {
            throw OriginalDataError.missing(name)
        }
        let raw = try Data(contentsOf: directory.appendingPathComponent(name))
        guard Self.digest(raw) == record.sha256 else { throw OriginalDataError.checksum(name) }
        let data = try OriginalContainer.decode(raw)
        if let expected = record.decodedSHA256, Self.digest(data) != expected {
            throw OriginalDataError.checksum("Decoded \(name)")
        }
        return data
    }

    public var programNames: [String] {
        manifest.files.filter { $0.name.hasSuffix(".blk") }.map { String($0.name.dropLast(4)) }.sorted()
    }

    /// The original loader permits rooms without a chapter script and uses System responses.
    /// Only an absent room program is empty. Present but damaged files still fail validation.
    public func loadMapProgram(chapter: UInt16, mapID: Int16) throws -> OriginalScriptProgram {
        guard chapter < 10, let map = OriginalMapExploration.supportedMaps[mapID] else {
            throw OriginalDataError.unsupported("Room program")
        }
        let name = "EP\(chapter + 1)_\(map)"
        if manifest.files.contains(where: { $0.name.hasPrefix(name + ".") }) {
            return try loadProgram(name)
        }
        let emptyTables = Data((0..<4).flatMap { _ in [UInt8(32), 0, 0, 0, 0, 0, 0, 0] })
        return try OriginalScriptProgram(name: name,
            text: OriginalTextTable(decoded: Data(repeating: 0, count: 4)),
            eventLabels: [], choices: [], blockData: emptyTables, conditionData: Data())
    }

    public func loadProgram(_ name: String) throws -> OriginalScriptProgram {
        let debugName = "\(name).dbg"
        let reviewName = name.firstIndex(of: "_").map { String(name[...$0]) + ".spn" }
        let review = try reviewName.flatMap { file in
            guard manifest.files.contains(where: { $0.name == file }) else { return nil as OriginalChapterReview? }
            let data = try decodedFile(file)
            return data.isEmpty ? nil : try OriginalChapterReview(decoded: data)
        }
        let labels = manifest.files.contains { $0.name == debugName }
            ? try OriginalEventLabel.decode(decodedFile(debugName)) : []
        return try OriginalScriptProgram(name: name,
            text: OriginalTextTable(decoded: decodedFile("\(name).txt")),
            eventLabels: labels,
            choices: OriginalChoiceRecord.decode(decodedFile("\(name).kif")),
            blockData: decodedFile("\(name).blk"),
            conditionData: decodedFile("\(name).chk"), review: review)
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
