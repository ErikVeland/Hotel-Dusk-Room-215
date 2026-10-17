import Foundation

/// Additional state writes from the original 0x0203BC9C dispatcher. Unknown
/// commands return nil, so their controller effects cannot be skipped silently.
public enum OriginalStateCommand: Equatable, Sendable {
    case keywordAvailable([Int16])
    case itemCheckFlags([Int16])
    case setPersonLocation(index: UInt16, location: UInt16, field6: UInt8, field7: Int8)
    case clearPersonLocation(index: UInt16)
    case door(index: UInt16, value: Int16)
    case personState(index: Int16, value: UInt8)
    case flag12F5(index: Int16)
    case flag12FE(index: UInt16)
    case flag87B(index: UInt16)
    case replaceInventory(new: UInt16, old: UInt16)
    case byte87E(Bool)
    case byte87F(UInt8)
    case flag13CC(index: UInt16)
    case incrementCounter1380(Bool)

    public init?(record: OriginalBlockGraph.Record) throws {
        let reader = OriginalBytes(record.raw)
        guard record.raw.count == 16 else { throw OriginalDataError.invalid("Original state command size") }
        switch reader.bytes[0] {
        case 10:
            let kind = try reader.u16(4)
            guard kind == 1 || kind == 2 else { return nil }
            let count = Int(try reader.u16(2))
            guard count <= 5 else { throw OriginalDataError.invalid("Original keyword list exceeds command") }
            let ids = try (0..<count).map { Int16(bitPattern: try reader.u16(6 + $0 * 2)) }
            self = kind == 1 ? .keywordAvailable(ids) : .itemCheckFlags(ids)
        case 13:
            let index = try reader.u16(8)
            self = reader.bytes[2] == 0 ? .clearPersonLocation(index: index)
                : .setPersonLocation(index: index, location: try reader.u16(4),
                                     field6: reader.bytes[6], field7: Int8(bitPattern: reader.bytes[10]))
        case 19: self = .door(index: try reader.u16(4), value: reader.bytes[2] == 0 ? 1 : 0)
        case 23: self = .personState(index: Int16(bitPattern: try reader.u16(2)), value: reader.bytes[4])
        case 25: self = .flag12F5(index: Int16(bitPattern: try reader.u16(2)))
        case 33: self = .flag12FE(index: try reader.u16(2))
        case 37: self = .flag87B(index: try reader.u16(2))
        case 39: self = .replaceInventory(new: try reader.u16(2), old: try reader.u16(4))
        case 40: self = .byte87E(reader.bytes[2] != 0)
        case 42: self = .byte87F(reader.bytes[2])
        case 46: self = .flag13CC(index: try reader.u16(2))
        case 51: self = .incrementCounter1380(reader.bytes[2] != 0)
        default: return nil
        }
    }
}

public enum OriginalStateCommandEffect: Equatable, Sendable {
    /// Opcode19 also writes one to the optional controller pointer at +0x40C.
    /// The session owner must forward this signal when that object exists.
    case door42Changed
}
