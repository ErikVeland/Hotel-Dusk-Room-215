import Foundation

/// Defaults loaded by 0x020B4C28 and read by the original state initializer.
public struct OriginalStateDefaults: Sendable {
    public let doorTable: OriginalDoorTable
    public let doors: [Int16: Int16]
    public let doorCount: Int
    public let objects: [Int16: Int16]

    public init(doorData: Data, objectData: Data) throws {
        doorTable = try OriginalDoorTable(data: doorData)
        let object = OriginalBytes(objectData)
        let count = doorTable.records.count
        let objectCount = Int(try object.u32(0))
        guard objectCount <= (objectData.count - 4) / 48,
              objectData.count == 4 + objectCount * 48 else {
            throw OriginalDataError.invalid("Original state default tables")
        }
        var doors: [Int16: Int16] = [:], objects: [Int16: Int16] = [:]
        for record in doorTable.records {
            if doors[record.id] == nil { doors[record.id] = record.initialState }
        }
        for index in 0..<objectCount {
            let offset = 4 + index * 48
            let id = Int16(bitPattern: try object.u16(offset))
            if objects[id] == nil { objects[id] = Int16(bitPattern: try object.u16(offset + 8)) }
        }
        self.doors = doors
        doorCount = count
        self.objects = objects
    }

    public static func bundled() throws -> Self {
        guard let directory = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("Original game defaults")
        }
        func checked(_ name: String, _ digest: String) throws -> Data {
            let data = try Data(contentsOf: directory.appendingPathComponent(name))
            guard OriginalScriptCatalog.digest(data) == digest else { throw OriginalDataError.checksum(name) }
            return data
        }
        return try Self(
            doorData: checked("door_flg.bin", "f2c7ba4ccd8a372befcf57153414edbbada08c0fad3c7caaa4ab9ebaa5feef18"),
            objectData: checked("onoffobjs.dat", "8ba8e930bdec70e56109b36c368e05631731225222e714a0c6db04494b0350cc"))
    }
}

/// Native storage for the original game-state fields. Source offsets make
/// reference snapshots directly comparable without executing ROM instructions.
public struct OriginalGameState: Equatable, Sendable, OriginalConditionContext {
    public static let byteCount = 0x7D58
    public private(set) var bytes: [UInt8]
    /// CHK type 12 reads a separate process global at original address 0x02107739.
    public var conditionGlobalByte: UInt8?

    public init(snapshot: Data, conditionGlobalByte: UInt8? = nil) throws {
        guard snapshot.count == Self.byteCount else { throw OriginalDataError.invalid("Original game-state size") }
        bytes = Array(snapshot)
        self.conditionGlobalByte = conditionGlobalByte
    }

    /// 0x020989EC clears the complete storage before 0x02097544 initializes it.
    /// The caller supplies the original clock conversion result. Nil represents
    /// the original clock-read failure, which stores -1 at offset 0x1368.
    public static func newGame(defaults: OriginalStateDefaults, timestamp: Int64?) throws -> Self {
        var state = try Self(snapshot: Data(repeating: 0, count: byteCount))
        try state.initialize(defaults: defaults, timestamp: timestamp)
        return state
    }

    /// 0x02097544 also runs without a full clear. Preserve all untouched fields.
    public mutating func initialize(defaults: OriginalStateDefaults, timestamp: Int64?) throws {
        for offset in stride(from: 0, to: 8, by: 2) { write16(offset, 0) }
        write32(8, 0); write32(12, 0x3000); write32(16, 0); write32(20, 0)
        for index in 0..<13 { write16(0x18 + index * 2, 0); write16(0x32 + index * 2, 0) }
        bytes[0x42] = 0; bytes[0x43] = 0
        for index in 0..<defaults.doorCount {
            write16(0x112 + index * 2, UInt16(bitPattern: defaults.doors[Int16(index + 1)] ?? -1))
        }
        for index in 0..<18 {
            write16(0xCA4 + index * 4, .max)
            bytes[0xCA6 + index * 4] = .max
        }
        for offset in 0x44..<0x9C { bytes[offset] = .max }
        bytes[0x9C] = 0
        try apply(.addInventory(id: 21))
        try apply(.addInventory(id: 22))
        try apply(.setFlag32(index: 0))
        for index in 14...16 { bytes[0xF5 + index] = 2 }
        for index in 0..<256 { setBit(base: 0x852, index: index, value: defaults.objects[Int16(index), default: 0] != 0) }
        for offset in 0xCEC..<0xD0C { bytes[offset] = 0 }
        bytes[0xCEC] = 1
        for offset in 0x3558..<Self.byteCount { bytes[offset] = 0 }
        // The original adds six and clamps each four-bit value to 0...6.
        for index in 0..<18 {
            let offset = 0xD0C + index / 2, shift = (index % 2) * 4
            let nibble = Int((bytes[offset] >> shift) & 15)
            let signedNibble = index % 2 == 1 && nibble >= 8 ? nibble - 16 : nibble
            let value = min(6, max(0, signedNibble + 6))
            bytes[offset] = (bytes[offset] & ~(15 << shift)) | UInt8(value << shift)
        }
        write16(0x13BC, .max)
        let ticks = UInt64(bitPattern: timestamp ?? -1)
        write32(0x1368, UInt32(truncatingIfNeeded: ticks))
        write32(0x136C, UInt32(truncatingIfNeeded: ticks >> 32))
    }

    public var snapshot: Data { Data(bytes) }

    /**
     * 0x02098800 clears the notebook notification when its editor opens.
     */
    public mutating func openNotebook() { bytes[0x87D] = 0 }

    /// 0x020989E0 / 0x020989D4: the bar jukebox's saved sequence, or -1.
    public var jukeboxSequence: Int16 { Int16(bitPattern: read16(0x13BC)) }
    public mutating func setJukeboxSequence(_ id: Int16) { write16(0x13BC, UInt16(bitPattern: id)) }

    /// 0x02098910: a script made this Mila memo available (opcode 46, 0x02098894).
    public func memoAvailable(_ index: Int) -> Bool { bit(base: 0x13CC, index: index) == true }

    /// 0x02098984: the notebook has shown this memo.
    public func memoRead(_ index: Int) -> Bool { bit(base: 0x13D0, index: index) == true }

    /// 0x02098948 marks a shown memo as read.
    public mutating func markMemoRead(_ index: Int) {
        guard (0..<32).contains(index) else { return }
        setBit(base: 0x13D0, index: index, value: true)
    }

    /**
     * 0x02078DA8 stores the three writable pages in the original game state.
     */
    public mutating func storeNotebook(_ notebook: OriginalNotebook) {
        for page in 0..<3 where bytes[0x13C8 + page] == 0 {
            let start = 0x3558 + page * OriginalNotebook.packedSize
            bytes.replaceSubrange(start..<(start + OriginalNotebook.packedSize), with: notebook.pages[page])
        }
    }

    /**
     * 0x02098AAC clears the person's item marker when an inventory item is shown.
     */
    public mutating func markItemShown(_ item: UInt8, person: Int16) {
        guard (0..<18).contains(person), item < 88 else { return }
        setBit(base: 0x13E4 + Int(person) * 11, index: Int(item), value: false)
    }

    /**
     * 0x02097E28 reads the object flag bank at 0x852.
     */
    public func objectVisible(_ index: UInt16) -> Bool {
        index < 256 && bytes[0x852 + Int(index / 8)] & (1 << (index % 8)) != 0
    }

    /**
     * 0x02026DD4 records successful puzzle exits in the process-ID-minus-24 flag bank.
     */
    public mutating func markPuzzleCompleted(processID: UInt16) {
        guard (24..<95).contains(processID) else { return }
        // The launch ID can differ from CTrickBase's recorded ID. Overlay 26
        // stores 49 for the tank; overlay 2 stores 40 for the restored jigsaw.
        let recordedID: UInt16 = processID == 48 ? 49 : processID == 84 ? 40 : processID
        setBit(base: 0x872, index: Int(recordedID - 24), value: true)
    }

    public var cabinetDialRetainedValue: UInt16 { read16(0x13D6) }
    /// Overlay 13 stores the Christmas tree decoration order at state offset 0x13DA.
    public var christmasTreeDecorationOrder: UInt16 { read16(0x13DA) }
    public mutating func storeChristmasTreeDecorationOrder(_ value: UInt16) { write16(0x13DA, value) }
    /**
     * Overlay 22 stores the wine-label peel position plus 0x1000 at state offset 0x13DC.
     */
    public var wineLabelPeelState: UInt16 {
        get { read16(0x13DC) }
        set { write16(0x13DC, newValue) }
    }
    /// The notebook and overlay 38 use the same five apple-painting bits.
    public var appleNotebookPageMask: UInt16 { applePaintingFoundMask }
    public var cashboxDialRetainedValue: UInt16 { read16(0x13DE) }
    public mutating func storeCashboxDialValue(_ value: UInt16) { write16(0x13DE, value) }

    /**
     * Overlay 38 reads and writes its apple mask at game offset 0x13D8.
     */
    public var applePaintingFoundMask: UInt16 {
        get { read16(0x13D8) & 0x1F }
        set {
            let preservedBits = read16(0x13D8) & 0xFFE0
            write16(0x13D8, preservedBits | (newValue & 0x1F))
        }
    }

    /**
     * Overlay 10 stores 999 minus the displayed cabinet number when the process exits.
     */
    public mutating func storeCabinetDialValue(_ value: UInt16) { write16(0x13D6, value) }

    /**
     * 0x02027CF4 retains a nonzero puzzle random value at game offset 0x13D4.
     */
    public mutating func initialisePuzzleRandomInfo(seed: UInt32) -> UInt16 {
        var value = read16(0x13D4), random = seed
        while value == 0 {
            random = random &* 0x5D588B65 &+ 0x269EC3
            value = UInt16(truncatingIfNeeded: random >> 16)
        }
        write16(0x13D4, value)
        return value
    }

    /**
     * 0x020987CC copies the live state into the retry checkpoint. This does not write a save file.
     */
    public mutating func saveRetryCheckpoint() {
        write16(0x1384, 0)
        let current = Array(bytes[0..<0x1AAC])
        bytes.replaceSubrange(0x1AAC..<0x3558, with: current)
    }
    public var chapter: UInt16 { read16(0) }
    public var nowTime: UInt16 { read16(2) }
    public var mapPosition: SIMD3<Float> {
        SIMD3(Float(Int32(bitPattern: read32(8))), Float(Int32(bitPattern: read32(12))), Float(Int32(bitPattern: read32(16))))
    }
    public var facing: Float { Float(bitPattern: read32(20)) }


    /**
     * Map request 3 changes time and clears conversation blocks (0x02097E5C, 0x02097BEC).
     */
    mutating func applyTimeChange(_ value: Int16) {
        write16(2, UInt16(bitPattern: value))
        for offset in 0x176..<0x812 { bytes[offset] = 0 }
    }

    /**
     * Request 4 resets chapter-local state before process 140 (0x0202C264, 0x020340D0).
     */
    mutating func beginChapter(_ chapter: UInt16) throws {
        guard chapter < 10 else { throw OriginalDataError.invalid("Chapter number") }
        applyTimeChange(0)
        write16(0, chapter)
        for offset in 0x812..<0x852 { bytes[offset] = 0 }
        for offset in 0x880..<0xA80 { bytes[offset] = 0 }
        for base in [0xD15, 0x14CC] {
            for offset in base..<(base + 47 * 32) { bytes[offset] = 0 }
        }
        bytes[0x137B] = 1
    }

    /**
     * Process 9 records the chapter time label and clears the transition flag (0x02017278).
     */
    mutating func beginChapterTitle(label: String) throws {
        if nowTime == 0 { try setTimeLabel(label) }
        bytes[0x137B] = 0
    }

    /**
     * Process 126 copies its label, including its terminator, at 0x1346 (0x02098868).
     */
    mutating func setTimeLabel(_ label: String) throws {
        let encoded = Array(label.utf8)
        guard encoded.count < 0x22, !encoded.contains(0) else {
            throw OriginalDataError.invalid("Saved time label")
        }
        bytes.replaceSubrange(0x1346..<(0x1346 + encoded.count + 1), with: encoded + [0])
    }
    public var mapID: Int16 { Int16(bitPattern: read16(4)) }
    public var previousMapID: Int16 { Int16(bitPattern: read16(6)) }

    /**
     * Overlay 2 reads and saves the Chapter 1 loose-piece mask at 0x02111638.
     */
    public var chapterOneJigsawMask: UInt32 {
        get { UInt32(read16(0x14AC)) | UInt32(read16(0x14AE)) << 16 }
        set { write32(0x14AC, newValue & 0xFFFFF) }
    }

    public func jigsawMask(for variant: OriginalJigsawProcess.Variant) -> UInt32 {
        guard let slot = variant.maskSlot else { return 0 }
        let offset = 0x14AC + slot * 4
        return (UInt32(read16(offset)) | UInt32(read16(offset + 2)) << 16) & 0xFFFFF
    }

    public mutating func setJigsawMask(_ mask: UInt32, for variant: OriginalJigsawProcess.Variant) {
        guard let slot = variant.maskSlot else { return }
        write32(0x14AC + slot * 4, mask & 0xFFFFF)
    }

    /**
     * Returns the person's current conversation block (0x02097BB4).
     */
    public func conversationBlock(map: Int16, person: Int16) -> UInt16? {
        guard (0..<47).contains(map), (0..<18).contains(person) else { return nil }
        return read16(0x176 + Int(map) * 0x24 + Int(person) * 2)
    }

    /**
     * Records the selected normal-script block (0x020296C4 and 0x02097B7C).
     * Special scene IDs use person slot zero in the original state table.
     */
    public mutating func rememberConversationBlock(scene: UInt16, block: UInt16) {
        guard (0..<47).contains(mapID) else { return }
        let person = scene > 17 ? 0 : Int(scene)
        write16(0x176 + Int(mapID) * 0x24 + person * 2, block)
    }

    /**
     * Returns the model marker key used by 0x0202F824 to place a person.
     */
    public func personMarker(_ person: Int) -> Int? {
        guard (0..<18).contains(person) else { return nil }
        let offset = 0xCA4 + person * 4
        let map = Int(Int16(bitPattern: read16(offset)))
        let point = Int(Int8(bitPattern: bytes[offset + 2]))
        guard map >= 0, point >= 0 else { return nil }
        return map * 100 + point
    }

    /**
     * 0x02097198 stores scripted map placement as fixed coordinates and a float angle.
     */
    public mutating func setMapPosition(_ position: SIMD3<Float>, facing: Float) {
        for axis in 0..<3 { write32(8 + axis * 4, UInt32(bitPattern: Int32(position[axis]))) }
        write32(20, facing.bitPattern)
    }

    /**
     * Map construction at 0x02029B78 marks the room through 0x020982C8.
     */
    public mutating func markMapVisited() {
        guard (0..<47).contains(mapID) else { return }
        bytes[0x1388 + Int(mapID)] |= 1
    }

    /**
     * 0x0209714C: a negative previous ID copies the old current map.
     */
    public mutating func setMap(_ map: Int16, previous: Int16) {
        write16(6, UInt16(bitPattern: previous < 0 ? mapID : previous))
        write16(4, UInt16(bitPattern: map))
    }

    /// 0x02097CC4 with bit selector zero, used by mode-3 event startup.
    public func itemCheckFlag(_ index: Int16) -> Bool {
        guard index >= 0, index < 256 else { return false }
        return bytes[0x812 + Int(index / 4)] & (1 << ((index % 4) * 2)) != 0
    }
    public var inventory: OriginalInventory {
        get throws {
            guard bytes[0x9C] <= 88 else { throw OriginalDataError.invalid("Original inventory count") }
            return try OriginalInventory(items: Array(bytes[0x44..<(0x44 + Int(bytes[0x9C]))]),
                                  itemStates: Array(bytes[0x9D..<0xF5]))
        }
    }

    /// Verified state-only operation handlers. Waits and presentation commands
    /// belong to the controller and must not alter this storage.
    public mutating func apply(_ operation: OriginalOperation) throws {
        switch operation {
        case .setFlag32(let index), .clearFlag32(let index):
            guard index < 64 else { return }
            let offset = 0x32 + Int(index / 8) * 2, mask = UInt16(1) << (index % 8)
            if case .setFlag32 = operation { write16(offset, read16(offset) | mask) }
            else { write16(offset, read16(offset) & ~mask) }
        case .changeFlag852(let value, let index):
            guard index < 256 else { return }
            setBit(base: 0x852, index: Int(index), value: value != 0)
        case .addInventory, .removeInventory, .removeAndClearInventory, .setItemState:
            var held = try inventory
            let previous = held.items
            try held.apply(operation)
            for (index, item) in held.items.enumerated() { bytes[0x44 + index] = item }
            if held.items.count < previous.count, held.items == Array(previous.dropLast()) {
                // Removing the last entry writes FF. Removing from the middle
                // shifts entries but leaves the old final byte untouched.
                bytes[0x44 + previous.count - 1] = .max
            }
            bytes[0x9C] = UInt8(held.items.count)
            bytes.replaceSubrange(0x9D..<0xF5, with: held.itemStates)
        default: throw OriginalDataError.unsupported("Operation does not write recovered game state")
        }
    }

    /// 0x02097FC0 records normal-script completion in two original flag banks.
    public mutating func markEventCompleted(group: Int16, event: Int16) {
        guard group >= 0, group < 47, event >= 0, event < 256 else { return }
        setBit(base: 0xD15 + Int(group) * 32, index: Int(event), value: true)
        setBit(base: 0x14CC + Int(group) * 32, index: Int(event), value: true)
    }

    @discardableResult
    public mutating func apply(_ command: OriginalStateCommand) throws -> [OriginalStateCommandEffect] {
        switch command {
        case .keywordAvailable(let ids):
            for id in ids where id >= 0 && id < 128 { bytes[0x880 + Int(id) * 4] = 1 }
        case .keywordUnavailable(let id):
            // 0x020984E4 clears availability and preserves the used and person fields.
            if id >= 0 && id < 128 { bytes[0x880 + Int(id) * 4] = 0 }
        case .itemCheckFlags(let ids):
            for id in ids where id >= 0 && id < 256 {
                bytes[0x812 + Int(id / 4)] |= UInt8(1 << ((id % 4) * 2))
            }
        case .setPersonLocation(let index, let location, let field6, let field7):
            guard index < 18 else { return [] }
            let offset = 0xCA4 + Int(index) * 4
            write16(offset, location); bytes[offset + 2] = field6
            bytes[offset + 3] = UInt8(bitPattern: field7)
        case .clearPersonLocation(let index):
            guard index < 18 else { return [] }
            let offset = 0xCA4 + Int(index) * 4
            write16(offset, .max); bytes[offset + 2] = .max
        case .door(let index, let value):
            if index < 51 { write16(0x110 + Int(index) * 2, UInt16(bitPattern: value)) }
            if index == 42 { return [.door42Changed] }
        case .personState(let index, let value):
            if index >= 0, index < 18 { bytes[0xF5 + Int(index)] = value }
        case .flag12F5(let index): try setOriginalBit(base: 0x12F5, index: Int(index))
        case .flag12FE(let index): try setOriginalBit(base: 0x12FE, index: Int(index))
        case .flag87B(let index):
            try setOriginalBit(base: 0x87B, index: Int(index))
            bytes[0x87D] = 1
        case .replaceInventory(let new, let old):
            let count = Int(bytes[0x9C]), newID = UInt8(truncatingIfNeeded: new), oldID = UInt8(truncatingIfNeeded: old)
            guard count <= 88 else { throw OriginalDataError.invalid("Original inventory count") }
            guard let oldIndex = bytes[0x44..<(0x44 + count)].firstIndex(of: oldID) else { return [] }
            if let newIndex = bytes[0x44..<(0x44 + count)].lastIndex(of: newID) {
                if newIndex == 0x44 + count - 1 { bytes[newIndex] = .max }
                else { for index in newIndex..<(0x44 + count - 1) { bytes[index] = bytes[index + 1] } }
                bytes[0x9C] -= 1
            }
            let signedID = Int(Int16(bitPattern: new)), stateOffset = 0x9D + signedID
            guard bytes.indices.contains(stateOffset) else { throw OriginalDataError.invalid("Original replacement item state") }
            if bytes[stateOffset] == 0, signedID >= 0, signedID < 88 { bytes[stateOffset] = 1 }
            // 0x02097AFC keeps the pre-removal index, including when an existing
            // replacement item was removed at an earlier index.
            bytes[oldIndex] = newID
        case .byte87E(let value): bytes[0x87E] = value ? 1 : 0
        case .byte87F(let value): bytes[0x87F] = value
        case .flag13CC(let index): try setOriginalBit(base: 0x13CC, index: Int(index))
        case .incrementCounter1380(let enabled): if enabled { bytes[0x1380] &+= 1 }
        }
        return []
    }

    /// Keyword fields at 0x880 + ID × 4: available (0x02098544), used
    /// (0x0209857C) and the s16 mask of people already asked (0x0209855C).
    public func keywordAvailable(_ id: Int) -> Bool { (0..<128).contains(id) && bytes[0x880 + id * 4] != 0 }
    public func keywordUsed(_ id: Int) -> Bool { (0..<128).contains(id) && bytes[0x881 + id * 4] != 0 }
    public func keywordAsked(_ id: Int, person: Int) -> Bool {
        guard (0..<128).contains(id), (0..<16).contains(person) else { return false }
        return (Int16(bitPattern: read16(0x882 + id * 4)) >> person) & 1 != 0
    }

    /// 0x02098440 replaces the mask with this person's bit; it does not add it.
    public mutating func markKeywordAsked(_ id: Int, person: Int) {
        guard (0...0x80).contains(id), (0...0x10).contains(person) else { return }
        write16(0x882 + id * 4, UInt16(truncatingIfNeeded: 1 << person))
    }

    /// 0x02098504: the keyword has no more questions to ask.
    public mutating func markKeywordUsed(_ id: Int) {
        guard (0..<0x80).contains(id) else { return }
        bytes[0x881 + id * 4] = 1
    }

    /// 0x02097F6C: a signed nibble per person at 0xD0C, set to 6 on a new game.
    public func personNibble(_ person: Int) -> Int {
        guard person >= 0, 0xD0C + person / 2 < bytes.count else { return 0 }
        let byte = bytes[0xD0C + person / 2]
        return Int(person % 2 == 0 ? byte & 0x0F : byte >> 4)
    }

    private mutating func setOriginalBit(base: Int, index: Int) throws {
        let offset = base + index / 8, shift = Int(UInt8(truncatingIfNeeded: index % 8))
        guard bytes.indices.contains(offset) else { throw OriginalDataError.invalid("Original flag write bounds") }
        if shift < 8 { bytes[offset] |= UInt8(1 << shift) }
    }

    public func value(for probe: OriginalConditionProbe) -> Bool? {
        switch probe {
        case .eventFlag(let group, let index):
            guard group < 47, index < 256 else { return false }
            return bit(base: 0xD15 + Int(group) * 32, index: Int(index))
        case .gameFlag(let index):
            // The original getter returns its nonzero state pointer out of range.
            guard index < 64 else { return true }
            return read16(0x32 + Int(index / 8) * 2) & (1 << (index % 8)) != 0
        case .inventoryContains(let index):
            guard bytes[0x9C] <= 88 else { return nil }
            return bytes[0x44..<(0x44 + Int(bytes[0x9C]))].contains(index)
        case .doorOpen(let index):
            let offset = 0x110 + Int(index) * 2
            return offset + 1 < bytes.count ? read16(offset) != 0 : nil
        case .trickFlag(let index): return bit(base: 0x872, index: Int(Int16(bitPattern: index)))
        case .keyword(let index, let person):
            let offset = 0x880 + Int(index) * 4
            guard offset >= 0, offset + 3 < bytes.count else { return nil }
            guard let person else { return bytes[offset + 1] != 0 }
            let value = Int32(Int16(bitPattern: read16(offset + 2))), shift = Int(UInt8(truncatingIfNeeded: person))
            return shift >= 32 ? value < 0 : (value >> shift) & 1 != 0
        case .memo(let index): return bit(base: 0x13D0, index: Int(index))
        case .chapterEquals(let value): return Int(chapter) == Int(value)
        case .globalByteIsZero: return conditionGlobalByte.map { $0 == 0 }
        case .counter1380(let comparison, let threshold):
            let actual = Int16(bytes[0x1380])
            switch comparison { case 0: return actual == threshold; case 1: return actual > threshold
            case 2: return actual < threshold; default: return nil }
        case .state137F: return bytes[0x137F] != 0
        }
    }

    private func read16(_ offset: Int) -> UInt16 { UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8 }
    private mutating func write16(_ offset: Int, _ value: UInt16) {
        bytes[offset] = UInt8(truncatingIfNeeded: value); bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    }
    private func read32(_ offset: Int) -> UInt32 {
        UInt32(read16(offset)) | UInt32(read16(offset + 2)) << 16
    }

    private mutating func write32(_ offset: Int, _ value: UInt32) {
        for index in 0..<4 { bytes[offset + index] = UInt8(truncatingIfNeeded: value >> (index * 8)) }
    }
    private func bit(base: Int, index: Int) -> Bool? {
        let offset = base + index / 8, shift = Int(UInt8(truncatingIfNeeded: index % 8))
        guard bytes.indices.contains(offset) else { return nil }
        return shift < 32 && (UInt32(bytes[offset]) >> shift) & 1 != 0
    }
    private mutating func setBit(base: Int, index: Int, value: Bool) {
        let offset = base + index / 8, mask = UInt8(1 << (index % 8))
        if value { bytes[offset] |= mask } else { bytes[offset] &= ~mask }
    }
}
