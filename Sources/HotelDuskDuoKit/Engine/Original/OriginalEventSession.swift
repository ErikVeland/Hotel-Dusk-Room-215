import Foundation

/// Session fields used by 0x02028268 and 0x020283B0. This state belongs to event
/// selection, separate from the persistent game flags and inventory.
public struct OriginalEventSession: Equatable, Codable, Sendable {
    public struct Frame: Equatable, Codable, Sendable {
        public var blockID: UInt16
        public var modeID: UInt16
        public var eventID: UInt16
        public var operationIndex: Int16
        public init(blockID: UInt16, modeID: UInt16, eventID: UInt16, operationIndex: Int16) {
            self.blockID = blockID; self.modeID = modeID
            self.eventID = eventID; self.operationIndex = operationIndex
        }
    }
    public var selection: OriginalEventSelectionContext
    public var operationIndex: Int16
    public var eventCommitted: Bool
    public var savedFrames: [Frame]
    public var restoreOverride: Int16
    public var restoredFromNonDialogue: Bool

    public init(selection: OriginalEventSelectionContext, operationIndex: Int16,
                eventCommitted: Bool, savedFrames: [Frame], restoreOverride: Int16,
                restoredFromNonDialogue: Bool) {
        self.selection = selection; self.operationIndex = operationIndex
        self.eventCommitted = eventCommitted; self.savedFrames = savedFrames
        self.restoreOverride = restoreOverride; self.restoredFromNonDialogue = restoredFromNonDialogue
    }

    /// Zero allocation plus original map-session initializer 0x02028160.
    /// An arrival trigger must select the event before executing any text.
    public static func mapSession(nowTime: UInt16, mapID: Int16) -> Self {
        Self(selection: .init(sceneID: .max, blockID: 0, modeID: .max,
                              eventID: .max, nowTime: nowTime, mapID: mapID),
             operationIndex: 0, eventCommitted: false, savedFrames: [],
             restoreOverride: 0, restoredFromNonDialogue: false)
    }

    /// Decode an observed session. Saved frames are supplied from the original
    /// pointer at +0x2CC; the snapshot does not dereference native memory pointers.
    public init(snapshot: Data, stack: Data, nowTime: UInt16, mapID: Int16) throws {
        let reader = OriginalBytes(snapshot)
        guard snapshot.count >= 0x2DB else { throw OriginalDataError.invalid("Original session snapshot") }
        var selection = try OriginalEventSelectionContext(sceneID: UInt16(truncatingIfNeeded: reader.u32(0x18)),
            blockID: reader.u16(0x2A), modeID: reader.u16(0x28), eventID: reader.u16(0x26),
            nowTime: nowTime, mapID: mapID)
        selection.areaID = try reader.u16(0x2C); selection.subareaID = try reader.u16(0x2E)
        selection.upViewID = Int16(bitPattern: try reader.u16(0x30))
        selection.checkItemID = Int16(bitPattern: try reader.u16(0x32))
        selection.pairA = Int16(bitPattern: try reader.u16(0x34))
        selection.pairB = Int16(bitPattern: try reader.u16(0x36))
        selection.parameter56 = Int16(bitPattern: try reader.u16(0x38))
        selection.parameter58 = Int16(bitPattern: try reader.u16(0x3A))
        selection.parameter60 = Int16(bitPattern: try reader.u16(0x3C))
        selection.checkItemOnly = reader.bytes[0x3E] != 0
        let count = Int(try reader.u32(0x2D0)), frames = OriginalBytes(stack)
        guard count <= stack.count / 8 else { throw OriginalDataError.invalid("Original event stack") }
        let saved = try (0..<count).map { index in
            let offset = index * 8
            return Frame(blockID: try frames.u16(offset), modeID: try frames.u16(offset + 2),
                         eventID: try frames.u16(offset + 4),
                         operationIndex: Int16(bitPattern: try frames.u16(offset + 6)))
        }
        self.init(selection: selection, operationIndex: Int16(bitPattern: try reader.u16(0x40)),
                  eventCommitted: reader.bytes[0x44] != 0, savedFrames: saved,
                  restoreOverride: Int16(bitPattern: try reader.u16(0x2D8)),
                  restoredFromNonDialogue: reader.bytes[0x2DA] != 0)
    }

    public mutating func commit(_ frame: Frame) {
        selection.blockID = frame.blockID; selection.modeID = frame.modeID
        selection.eventID = frame.eventID; operationIndex = frame.operationIndex
        eventCommitted = true
    }

    public mutating func evaluate(_ request: OriginalConditionRequest, conditions: OriginalConditions,
                                  game: some OriginalConditionContext) throws -> OriginalConditions.Result {
        try conditions.evaluate(eventKey: request.eventKey, context: game) {
            commit(Frame(blockID: selection.blockID, modeID: request.modeID,
                         eventID: request.eventID, operationIndex: operationIndex))
        }
    }

    @discardableResult
    public mutating func restoreCloseupContext() -> Bool {
        var result = eventCommitted
        if restoreOverride == 0, let frame = savedFrames.popLast() {
            let previousMode = selection.modeID
            commit(frame)
            result = true
            restoredFromNonDialogue = previousMode != 5
        } else { restoredFromNonDialogue = false }
        restoreOverride = 0
        eventCommitted = false
        return result
    }

    public mutating func apply(_ effect: OriginalEventSelectionEffect) {
        switch effect {
        case .consumeItemOnlyCheck: selection.checkItemOnly = false
        case .restoreCloseupContext: restoreCloseupContext()
        }
    }
}
