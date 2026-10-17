import Foundation

/// Defaults loaded by 0x020B4C28 and read by the original state initializer.
public struct OriginalStateDefaults: Sendable {
    public let doors: [Int16: Int16]
    public let doorCount: Int
    public let objects: [Int16: Int16]

    public init(doorData: Data, objectData: Data) throws {
        let door = OriginalBytes(doorData), object = OriginalBytes(objectData)
        let count = Int(Int16(bitPattern: try door.u16(0)))
        let objectCount = Int(try object.u32(0))
        guard count >= 0, count <= 50, doorData.count == 16 + count * 16,
              objectCount <= (objectData.count - 4) / 48,
              objectData.count == 4 + objectCount * 48 else {
            throw OriginalDataError.invalid("Original state default tables")
        }
        var doors: [Int16: Int16] = [:], objects: [Int16: Int16] = [:]
        for index in 0..<count {
            let offset = 16 + index * 16
            let id = Int16(bitPattern: try door.u16(offset))
            if doors[id] == nil { doors[id] = Int16(bitPattern: try door.u16(offset + 2)) }
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
    public var chapter: UInt16 { read16(0) }
    public var nowTime: UInt16 { read16(2) }
    public var mapID: Int16 { Int16(bitPattern: read16(4)) }
    public var previousMapID: Int16 { Int16(bitPattern: read16(6)) }

    /// 0x0209714C: a negative previous ID copies the old current map.
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
