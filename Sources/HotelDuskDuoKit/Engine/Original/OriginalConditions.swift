import Foundation

public enum OriginalConditionProbe: Hashable, Sendable {
    case eventFlag(group: UInt16, index: UInt16)
    case gameFlag(index: UInt16)
    case inventoryContains(index: UInt8)
    case doorOpen(index: UInt16)
    case trickFlag(index: UInt16)
    case keyword(index: Int16, person: Int16?)
    case memo(index: Int8)
    case chapterEquals(Int8)
    case globalByteIsZero
    case counter1380(comparison: Int16, threshold: Int16)
    case state137F
}

/// Nil means the original state has not been recovered. It must never be
/// substituted with false, which could silently select a different story event.
public protocol OriginalConditionContext {
    func value(for probe: OriginalConditionProbe) -> Bool?
}

public struct OriginalConditions: Sendable {
    public struct Record: Sendable {
        public let sourceOffset: Int
        public let raw: Data
    }
    public struct Entry: Sendable {
        public let first: [Record]?
        public let second: [Record]?
    }
    public enum Result: Equatable, Sendable {
        case pass
        case fail(sourceOffset: Int)
        case unresolvedState(OriginalConditionProbe, sourceOffset: Int)
        case unrecoveredCondition(kind: Int8, sourceOffset: Int)
    }
    public let entries: [Entry]

    public init(decoded data: Data, eventCount: Int) throws {
        guard eventCount >= 0, eventCount <= data.count / 16 else {
            throw OriginalDataError.invalid("CHK entry count")
        }
        let reader = OriginalBytes(data)
        func records(at position: Int) throws -> [Record]? {
            let offset = try reader.u32(position)
            let count = Int(try reader.u32(position + 4))
            if offset == .max { return nil }
            let start = Int(offset)
            guard start >= eventCount * 16, start <= data.count,
                  count <= (data.count - start) / 16 else {
                throw OriginalDataError.invalid("CHK list bounds")
            }
            return try (0..<count).map { index in
                let position = start + index * 16
                return Record(sourceOffset: position, raw: Data(try reader.range(position, 16)))
            }
        }
        entries = try (0..<eventCount).map { index in
            try Entry(first: records(at: index * 16), second: records(at: index * 16 + 8))
        }
    }

    /// Read-only form of the original check. Use evaluate with a commit callback
    /// when selecting gameplay events, because checks also change session state.
    public func evaluatePredicates(eventKey: Int16, context: some OriginalConditionContext) throws -> Result {
        try evaluate(eventKey: eventKey, context: context, onCommit: {})
    }

    /// Transcribed from 0x02029254, including its early returns. A successful
    /// check commits immediately, even if a later check rejects the event.
    public func evaluate(eventKey: Int16, context: some OriginalConditionContext,
                         onCommit: () throws -> Void) throws -> Result {
        if eventKey == -1 { try onCommit(); return .pass }
        guard eventKey >= 0, entries.indices.contains(Int(eventKey)) else {
            throw OriginalDataError.invalid("CHK event key")
        }
        guard let records = entries[Int(eventKey)].first else { try onCommit(); return .pass }
        var result = Result.pass
        for record in records {
            let reader = OriginalBytes(record.raw)
            let kind = Int8(bitPattern: reader.bytes[0])
            let probe: OriginalConditionProbe
            let inverted: Bool
            switch kind {
            case 0:
                probe = .eventFlag(group: try reader.u16(2), index: try reader.u16(4))
                inverted = reader.bytes[6] != 0
            case 1:
                probe = .gameFlag(index: try reader.u16(2))
                inverted = reader.bytes[4] != 0
            case 5:
                probe = .inventoryContains(index: UInt8(truncatingIfNeeded: try reader.u16(2)))
                inverted = reader.bytes[4] != 0
            case 6:
                probe = .doorOpen(index: try reader.u16(4))
                inverted = reader.bytes[2] != 0
            case 8:
                probe = .trickFlag(index: try reader.u16(4))
                inverted = reader.bytes[2] != 0
            case 7:
                let person = try reader.u16(6)
                probe = .keyword(index: Int16(bitPattern: try reader.u16(4)),
                                 person: person == .max ? nil : Int16(bitPattern: person))
                inverted = reader.bytes[2] != 0
            case 10:
                probe = .memo(index: Int8(bitPattern: reader.bytes[3]))
                inverted = reader.bytes[2] != 0
            case 11:
                probe = .chapterEquals(Int8(bitPattern: reader.bytes[3]))
                inverted = reader.bytes[2] != 0
            case 12:
                probe = .globalByteIsZero
                inverted = false
            case 13:
                let comparison = Int16(bitPattern: try reader.u16(4))
                // Other comparison values retain the previous result. This is
                // explicit in the original dispatch, not a guessed fallback.
                if !(0...2).contains(comparison) {
                    if result == .pass { try onCommit(); return .pass }
                    continue
                }
                probe = .counter1380(comparison: comparison,
                                     threshold: Int16(bitPattern: try reader.u16(2)))
                inverted = false
            case 14:
                probe = .state137F
                inverted = reader.bytes[2] != 0
            default:
                // Unhandled kinds terminate with the previous result at
                // 0x02029540. Original files include kinds 2 and 4 here.
                return result
            }
            guard let actual = context.value(for: probe) else {
                return .unresolvedState(probe, sourceOffset: record.sourceOffset)
            }
            let passed = kind == 11
                ? (actual ? reader.bytes[2] == 0 : reader.bytes[2] == 1)
                : actual != inverted
            result = passed ? .pass : .fail(sourceOffset: record.sourceOffset)
            if passed {
                try onCommit()
                if kind == 13 { return result }
            } else if kind != 13 { return result }
        }
        return result
    }
}
