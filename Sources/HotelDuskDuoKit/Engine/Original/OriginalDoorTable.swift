import Foundation

/**
 * Door connections loaded by 0x020B5348. Record order controls duplicate lookup.
 */
public struct OriginalDoorTable: Sendable {
    public struct Side: Equatable, Sendable {
        public let viewFlag: Int16
        public let positiveCode: Int8
        public let zeroCode: Int8
    }

    public struct Record: Equatable, Sendable {
        public let id: Int16
        public let initialState: Int16
        public let mapA: Int16
        public let mapB: Int16
        public let sideA: Side
        public let sideB: Side
    }

    public let records: [Record]

    public init(data: Data) throws {
        let reader = OriginalBytes(data)
        let count = Int(Int16(bitPattern: try reader.u16(0)))
        guard count >= 0, count <= 50, data.count == 16 + count * 16 else {
            throw OriginalDataError.invalid("Door table length")
        }
        records = try (0..<count).map { index in
            let offset = 16 + index * 16
            func short(_ field: Int) throws -> Int16 { Int16(bitPattern: try reader.u16(offset + field)) }
            return try Record(id: short(0), initialState: short(2), mapA: short(4), mapB: short(6),
                sideA: Side(viewFlag: short(8), positiveCode: Int8(bitPattern: data[offset + 12]),
                            zeroCode: Int8(bitPattern: data[offset + 13])),
                sideB: Side(viewFlag: short(10), positiveCode: Int8(bitPattern: data[offset + 14]),
                            zeroCode: Int8(bitPattern: data[offset + 15])))
        }
    }

    /**
     * 0x020B537C returns the first connection in either direction.
     */
    public func connection(from source: Int16, to destination: Int16) -> Record? {
        records.first { ($0.mapA == source && $0.mapB == destination) || ($0.mapB == source && $0.mapA == destination) }
    }

    /**
     * 0x020B54C4 and 0x020B53EC read the fields for the current side of the door.
     */
    public func side(from source: Int16, to destination: Int16) -> Side? {
        guard let record = connection(from: source, to: destination) else { return nil }
        return record.mapA == source ? record.sideA : record.sideB
    }

    /**
     * 0x0202DEC4 bypasses inspection for these sides when the original door flag is zero.
     */
    public func departsDirectly(from source: Int16, to destination: Int16, game: OriginalGameState) -> Bool {
        guard let record = connection(from: source, to: destination),
              let side = side(from: source, to: destination),
              game.value(for: .doorOpen(index: UInt16(bitPattern: record.id))) == false else { return false }
        return side.viewFlag != 0 || (source == 39 && destination == 31)
            || (source == 17 && destination == 26) || (source == 26 && destination == 5)
    }
}
