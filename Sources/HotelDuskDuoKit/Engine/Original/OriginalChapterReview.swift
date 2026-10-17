import Foundation

/**
 * Chapter review records from SPN, consumed by 0x0203D61C modes 17 and 24.
 */
public struct OriginalChapterReview: Sendable {
    public struct Answer: Sendable {
        public let advances: Bool
        public let eventID: UInt16
        public let conditions: [OriginalConditionProbe]

        public func available(in game: OriginalGameState) -> Bool {
            conditions.allSatisfy { game.value(for: $0) == true }
        }
    }

    public struct Question: Sendable {
        public let promptEvent: UInt16
        public let nextEvent: UInt16
        public let answers: [Answer]
    }

    public let questions: [Question]

    public init(decoded data: Data) throws {
        let reader = OriginalBytes(data)
        let count = Int(try reader.u16(0))
        guard count <= (data.count - 2) / 8 else { throw OriginalDataError.invalid("Chapter review header") }
        questions = try (0..<count).map { index in
            let offset = 2 + index * 8
            let answerCount = Int(try reader.u16(offset + 4))
            var cursor = Int(try reader.u16(offset + 6))
            guard cursor >= 2 + count * 8, answerCount <= (data.count - cursor) / 4 else {
                throw OriginalDataError.invalid("Chapter review answer span")
            }
            let answers = try (0..<answerCount).map { _ -> Answer in
                let header = try reader.range(cursor, 4)
                let advances = header[header.startIndex] != 0
                let conditionCount = Int(header[header.startIndex + 1])
                let eventID = try reader.u16(cursor + 2)
                cursor += 4
                let conditions = try (0..<conditionCount).compactMap { _ -> OriginalConditionProbe? in
                    let kind = try reader.u16(cursor)
                    let first = try reader.u16(cursor + 2)
                    let second = try reader.u16(cursor + 4)
                    _ = try reader.u16(cursor + 6)
                    cursor += 8
                    switch kind {
                    case 0: return .gameFlag(index: first)
                    case 1: return .inventoryContains(index: UInt8(truncatingIfNeeded: first))
                    case 2: return .eventFlag(group: first, index: second)
                    default: return nil
                    }
                }
                return Answer(advances: advances, eventID: eventID, conditions: conditions)
            }
            return Question(promptEvent: try reader.u16(offset), nextEvent: try reader.u16(offset + 2), answers: answers)
        }
    }
}
