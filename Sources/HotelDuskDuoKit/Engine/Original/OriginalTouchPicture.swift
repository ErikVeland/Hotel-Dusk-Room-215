import Foundation

/**
 * The 40-byte records loaded by 0x0205B2A4 from touchevent.lst.
 */
public struct OriginalTouchPictureTable: Sendable {
    public struct Record: Equatable, Sendable {
        public let id: UInt16
        public let foreground: String
        public let background: String
        public let x: Int
        public let y: Int
        public let mode: UInt16
    }
    public let records: [Record]

    public init(data: Data) throws {
        let reader = OriginalBytes(data)
        let count = Int(try reader.u32(0))
        guard count <= (data.count - 4) / 40, data.count == 4 + count * 40 else {
            throw OriginalDataError.invalid("Touch picture table length")
        }
        records = try (0..<count).map { index in
            let base = 4 + index * 40
            func name(_ offset: Int) throws -> String {
                let bytes = try reader.zeroTerminated(base + offset, limit: 16)
                guard bytes.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }) else {
                    throw OriginalDataError.invalid("Touch picture asset name")
                }
                return String(decoding: bytes, as: UTF8.self)
            }
            return Record(id: try reader.u16(base), foreground: try name(2), background: try name(18),
                x: Int(Int16(bitPattern: try reader.u16(base + 34))),
                y: Int(Int16(bitPattern: try reader.u16(base + 36))), mode: try reader.u16(base + 38))
        }
    }

    public static func bundled() throws -> Self {
        guard let root = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("Touch picture table")
        }
        struct Manifest: Decodable {
            struct File: Decodable { let name: String; let sha256: String }
            let files: [File]
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        let name = "touchevent.lst"
        guard let record = manifest.files.first(where: { $0.name == name }) else { throw OriginalDataError.missing(name) }
        let data = try Data(contentsOf: root.appendingPathComponent(name))
        guard OriginalScriptCatalog.digest(data) == record.sha256 else { throw OriginalDataError.checksum(name) }
        return try Self(data: data)
    }
}

/**
 * Input and return stages of 0x0200F324, after its image-loading stages finish.
 */
public struct OriginalTouchPicture: Sendable {
    public enum Phase: Equatable, Sendable { case selecting, fading, returning, complete }
    public enum Effect: Equatable, Sendable { case selectSound, confirmSound }
    public let record: OriginalTouchPictureTable.Record
    public let mask: [UInt8]
    public private(set) var phase = Phase.selecting
    public private(set) var selected = false
    public private(set) var touching = false
    public private(set) var fadeUpdates = 0

    public init(record: OriginalTouchPictureTable.Record, indices: [UInt8], width: Int, height: Int) throws {
        guard record.mode == 0 else { throw OriginalDataError.unsupported("Touch picture mode \(record.mode)") }
        let fullPage = !record.background.isEmpty
        guard width == (fullPage ? 256 : 128), height == (fullPage ? 192 : 128), indices.count == width * height else {
            throw OriginalDataError.invalid("Touch picture dimensions")
        }
        self.record = record
        // 0x020100C0 packs each four 2×2 occupancy blocks into one byte.
        var packed = [UInt8]()
        packed.reserveCapacity(width * height / 16)
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 8) {
                var byte: UInt8 = 0
                for block in 0..<4 {
                    let offset = y * width + x + block * 2
                    if [offset, offset + 1, offset + width, offset + width + 1].contains(where: { indices[$0] != 0 }) {
                        byte |= 3 << (block * 2)
                    }
                }
                packed.append(byte)
            }
        }
        mask = packed
    }

    /**
     * 0x0200FF7C checks the whole mask byte, including neighbouring 2×2 blocks.
     */
    public func contains(pageX: Int, pageY: Int) -> Bool {
        guard (8...183).contains(pageX), (8...247).contains(pageY) else { return false }
        let cropped = record.background.isEmpty
        let x = pageX - (cropped ? record.x : 0), y = pageY - (cropped ? record.y : 0)
        let width = cropped ? 128 : 192, height = cropped ? 128 : 256
        guard (0..<width).contains(x), (0..<height).contains(y) else { return false }
        let index = (height / 2 - 1 - y / 2) + (x / 2) * (height / 2)
        return mask[index / 4] != 0
    }

    /**
     * A press selects the object. A later press on the selected object confirms it.
     */
    public mutating func touch(pageX: Int, pageY: Int) -> [Effect] {
        guard phase == .selecting else { return [] }
        let newPress = !touching
        touching = true
        let hit = contains(pageX: pageX, pageY: pageY)
        let confirmed = selected == hit && newPress && hit
        let newlySelected = hit && !selected
        selected = hit
        if confirmed {
            phase = .fading
            fadeUpdates = 20
            return [.confirmSound]
        }
        return newlySelected ? [.selectSound] : []
    }

    public mutating func release() { touching = false }

    /// Native single-tap input keeps the original hit mask and completion stages.
    public mutating func activate(pageX: Int, pageY: Int) -> [Effect] {
        guard phase == .selecting, contains(pageX: pageX, pageY: pageY) else { return [] }
        selected = true
        touching = false
        phase = .fading
        fadeUpdates = 20
        return [.confirmSound]
    }

    /**
     * Stages 17 and 18 wait for the 20-update fade, then return to the talk controller.
     */
    public mutating func update() {
        switch phase {
        case .fading:
            if fadeUpdates > 0 { fadeUpdates -= 1 }
            else { phase = .returning }
        case .returning: phase = .complete
        case .selecting, .complete: break
        }
    }
}
