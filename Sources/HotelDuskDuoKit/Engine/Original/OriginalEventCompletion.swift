import Foundation

/// A CHK second-span record, read by event completion at 0x0203D61C.
/// These are original transitions, not a list of additional predicates.
public struct OriginalEventTransition: Equatable, Sendable {
    public let sourceOffset: Int
    public let sceneID: UInt16
    public let blockID: UInt16
    public let modeID: UInt16
    public let eventID: UInt16

    public init?(record: OriginalConditions.Record) throws {
        let reader = OriginalBytes(record.raw)
        guard reader.bytes[0] == 0 else { return nil }
        sourceOffset = record.sourceOffset
        modeID = UInt16(reader.bytes[2])
        sceneID = try reader.u16(4)
        blockID = try reader.u16(6)
        eventID = try reader.u16(8)
    }

    public func apply(to session: inout OriginalEventSession) {
        session.selection.sceneID = sceneID
        // Every source call supplies zero as the fifth (stack) argument.
        session.commit(.init(blockID: blockID, modeID: modeID, eventID: eventID, operationIndex: 0))
    }
}

/// The recovered, state-only exit paths from 0x0203D61C. The controller must
/// first finish its original animation, fade, and process-return waits.
public enum OriginalEventCompletion {
    public struct Completion: Equatable, Sendable {
        public let transition: OriginalEventTransition?
        public let preventContextRestore: Bool
        public func apply(to session: inout OriginalEventSession) {
            transition?.apply(to: &session)
            if preventContextRestore { session.restoreOverride = 1 }
        }
    }
    public enum Result: Equatable, Sendable {
        case completed(Completion)
        case requiresOriginalHandler(mode: UInt16)
    }

    public static func stateOnlyExit(event: OriginalBlockGraph.Record, conditions: OriginalConditions,
                                     processReturn: Int16 = 0) throws -> Result {
        let reader = OriginalBytes(event.raw)
        let mode = try reader.u16(0), key = Int16(bitPattern: try reader.u16(4))
        let records: [OriginalConditions.Record]?
        if key == -1 { records = nil }
        else {
            guard key >= 0, conditions.entries.indices.contains(Int(key)) else {
                throw OriginalDataError.invalid("Event completion key")
            }
            records = conditions.entries[Int(key)].second
        }
        switch mode {
        case 2, 3, 4, 5, 15:
            var transition: OriginalEventTransition?
            if let records {
                let index = mode == 15 ? max(0, Int(processReturn)) : 0
                guard records.indices.contains(index) else {
                    throw OriginalDataError.invalid("Original process return exceeds transition table")
                }
                transition = try OriginalEventTransition(record: records[index])
            }
            return .completed(Completion(transition: transition,
                                         preventContextRestore: mode == 5 && transition != nil))
        case 10...14:
            // 0x0203E7C8, first update (+0x0A == 0): a transition is applied
            // at once. Exits to modes other than 15 also start the closeup
            // fade and sound (0x0204FE58, 0x02009D88), which are presentation.
            // Without a transition, the closeup returns to the search view
            // through fades and process state that are not recovered.
            guard let first = records?.first, let transition = try OriginalEventTransition(record: first) else {
                return .requiresOriginalHandler(mode: mode)
            }
            return .completed(Completion(transition: transition, preventContextRestore: false))
        case 6, 18, 19, 20, 23, 25, 29, 31, 32:
            return .completed(Completion(transition: nil, preventContextRestore: false))
        default: return .requiresOriginalHandler(mode: mode)
        }
    }

    /// Event mode15 enters a process selected by original event byte16.
    /// Its returned index chooses a second-span transition on completion.
    public static func embeddedProcessID(event: OriginalBlockGraph.Record) throws -> UInt16? {
        let reader = OriginalBytes(event.raw)
        guard try reader.u16(0) == 15 else { return nil }
        return UInt16(reader.bytes[16]) + 23
    }
}
