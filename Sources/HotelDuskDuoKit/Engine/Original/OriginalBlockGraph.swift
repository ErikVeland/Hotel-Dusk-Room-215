import Foundation

/// BLK table relationships recovered from the original selector at 0x020551B8.
/// Table keys and condition fields stay opaque until their handlers are known.
public struct OriginalBlockGraph: Sendable {
    public struct Record: Sendable, Equatable {
        public let index: Int
        public let sourceOffset: Int
        public let raw: Data
        public let children: Range<Int>?
    }
    public let tables: [[Record]]
    public init(decoded data: Data) throws {
        let reader = OriginalBytes(data)
        let strides = [16,16,20,16]
        var offsets: [Int] = []
        var counts: [Int] = []
        for table in 0..<4 {
            offsets.append(Int(try reader.u32(table * 8)))
            counts.append(Int(try reader.u32(table * 8 + 4)))
        }
        guard offsets[0] == 32 else { throw OriginalDataError.invalid("BLK header size") }
        var result: [[Record]] = []
        for table in 0..<4 {
            let offset = offsets[table], count = counts[table], stride = strides[table]
            let end = table < 3 ? offsets[table + 1] : data.count
            guard offset <= end, end <= data.count, count <= (end - offset) / stride,
                  offset + count * stride == end else {
                throw OriginalDataError.invalid("BLK table \(table) bounds")
            }
            let records = try (0..<count).map { index -> Record in
                let position = offset + index * stride
                var children: Range<Int>?
                if table < 3 {
                    let relative = Int(try reader.u32(position + (table == 2 ? 8 : 4)))
                    let childCount = table == 2 ? Int(try reader.u16(position + 6))
                                               : Int(try reader.u32(position + 8))
                    let nextStride = strides[table + 1]
                    let start = relative / nextStride
                    guard relative % nextStride == 0, start <= counts[table + 1],
                          childCount <= counts[table + 1] - start else {
                        throw OriginalDataError.invalid("BLK child span at \(position)")
                    }
                    children = start..<start + childCount
                }
                return Record(index: index, sourceOffset: position,
                              raw: Data(try reader.range(position, stride)), children: children)
            }
            result.append(records)
        }
        tables = result
    }

    public func operations(forEvent index: Int) throws -> [Record] {
        guard tables[2].indices.contains(index), let children = tables[2][index].children else {
            throw OriginalDataError.invalid("BLK event index \(index)")
        }
        return Array(tables[3][children])
    }
}

/// This is a partial transcription of the original command dispatcher, not a
/// replacement opcode set. Unknown commands retain all sixteen source bytes.
public enum OriginalOperation: Sendable, Equatable {
    case dialogue(textIndex: UInt16)
    case wait(counter: UInt16)
    case setFlag32(index: UInt16)
    case clearFlag32(index: UInt16)
    case changeFlag852(value: UInt8, index: UInt16)
    case removeInventory(id: UInt16)
    case addInventory(id: UInt16)
    case removeAndClearInventory(id: UInt16)
    case setItemState(id: Int16, value: UInt8)
    case unrecovered(opcode: UInt8)

    public init(record: OriginalBlockGraph.Record) throws {
        guard record.raw.count == 16 else { throw OriginalDataError.invalid("Operation size") }
        let reader = OriginalBytes(record.raw)
        switch reader.bytes[0] {
        case 4: self = .dialogue(textIndex: try reader.u16(10))
        case 11: self = .wait(counter: try reader.u16(2))
        case 12: self = .setFlag32(index: try reader.u16(2))
        case 35: self = .clearFlag32(index: try reader.u16(2))
        case 18: self = .changeFlag852(value: reader.bytes[2], index: try reader.u16(4))
        case 24: self = .setItemState(id: Int16(bitPattern: try reader.u16(2)), value: reader.bytes[4])
        case 29: self = .removeInventory(id: try reader.u16(4))
        case 30: self = .addInventory(id: try reader.u16(4))
        case 49: self = .removeAndClearInventory(id: try reader.u16(2))
        default: self = .unrecovered(opcode: reader.bytes[0])
        }
    }
}
