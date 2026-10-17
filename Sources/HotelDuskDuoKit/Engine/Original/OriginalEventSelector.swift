import Foundation

/// Inputs read by the original selector at 0x020551B8. Names without a proven
/// story meaning retain their session-field role instead of inventing one.
public struct OriginalEventSelectionContext: Equatable, Codable, Sendable {
    public var sceneID: UInt16
    public var blockID: UInt16
    public var modeID: UInt16
    public var eventID: UInt16
    public var nowTime: UInt16
    public var mapID: Int16
    public var upViewID: Int16 = 0
    public var areaID: UInt16 = 0
    public var subareaID: UInt16 = 0
    public var checkItemID: Int16 = 0
    public var checkItemOnly = false
    public var pairA: Int16 = 0
    public var pairB: Int16 = 0
    public var parameter56: Int16 = 0
    public var parameter58: Int16 = 0
    public var parameter60: Int16 = 0
    public var debugEventSelection = false

    public init(sceneID: UInt16, blockID: UInt16, modeID: UInt16, eventID: UInt16,
                nowTime: UInt16, mapID: Int16) {
        self.sceneID = sceneID
        self.blockID = blockID
        self.modeID = modeID
        self.eventID = eventID
        self.nowTime = nowTime
        self.mapID = mapID
    }
}

public enum OriginalProgramScope: Equatable, Codable, Sendable { case normal, system }

public struct OriginalConditionRequest: Equatable, Sendable {
    public let modeID: UInt16
    public let eventID: UInt16
    public let eventKey: Int16
    public let scope: OriginalProgramScope
}

public enum OriginalEventSelectionEffect: Equatable, Sendable {
    /// The original calls 0x020283B0 after the condition attempt, even on failure.
    /// Its saved-context restoration must be applied by the session owner.
    case restoreCloseupContext
    /// Session byte 0x3E is cleared before searching a mode-16 event.
    case consumeItemOnlyCheck
}

/// Traverses original BLK records. Condition evaluation and its session writes
/// are injected so an unresolved condition can stop at the exact candidate.
public enum OriginalEventSelector {
    public struct Selection: Equatable, Sendable {
        public let sceneIndex: Int
        public let blockIndex: Int
        public let eventIndex: Int
        public let eventSourceOffset: Int
    }
    public enum Outcome: Equatable, Sendable {
        case selected(Selection)
        case noMatch
        case unresolved(candidate: Selection, condition: OriginalConditions.Result)
    }

    public static func select(
        graph: OriginalBlockGraph,
        context: OriginalEventSelectionContext,
        scope: OriginalProgramScope = .normal,
        evaluate: (OriginalConditionRequest) throws -> OriginalConditions.Result,
        applyEffect: (OriginalEventSelectionEffect) throws -> Void = { _ in }
    ) throws -> Outcome {
        var sceneID = context.sceneID
        let mode = context.modeID
        let system = scope == .system
        let closeup = sceneID == 0xFFFE
        let upView = closeup ? Int(context.upViewID) : 0
        let area = closeup ? context.areaID : 0
        let subarea = closeup ? context.subareaID : 0
        if mode == 16 { try applyEffect(.consumeItemOnlyCheck) }
        if mode == 20 { sceneID = 202 }
        if mode == 31 { sceneID = 203 }

        for scene in graph.tables[0] {
            let sceneBytes = OriginalBytes(scene.raw)
            guard try sceneBytes.u16(0) == sceneID || context.debugEventSelection,
                  let blocks = scene.children else { continue }
            for blockIndex in blocks {
                let candidateBlock = graph.tables[1][blockIndex]
                let blockBytes = OriginalBytes(candidateBlock.raw)
                let correctTime = try blockBytes.u16(2) == context.nowTime
                let correctBlock = try blockBytes.u16(0) == context.blockID
                guard (correctBlock && correctTime) || system ||
                        (sceneID == 0xFFFE && correctTime) || context.debugEventSelection else { continue }
                // System scripts select from the scene's first block, even when
                // the surrounding loop has reached a later block.
                let block = graph.tables[1][system ? blocks.lowerBound : blockIndex]
                guard let events = block.children else { continue }
                for eventIndex in events {
                    let event = graph.tables[2][eventIndex]
                    let bytes = OriginalBytes(event.raw)
                    let rowMode = try bytes.u16(0)
                    let rowEvent = try bytes.u16(2)
                    let key = Int16(bitPattern: try bytes.u16(4))
                    let selection = Selection(sceneIndex: scene.index, blockIndex: block.index,
                                              eventIndex: event.index, eventSourceOffset: event.sourceOffset)
                    if context.debugEventSelection {
                        if UInt16(bitPattern: key) == context.eventID { return .selected(selection) }
                        continue
                    }
                    guard rowMode == mode else { continue }
                    var conditionEvent = context.eventID
                    var conditionScope = scope
                    var restoreCloseup = false
                    switch mode {
                    case 16:
                        guard Int(bytes.bytes[16]) == Int(context.checkItemID) else { continue }
                        if !context.checkItemOnly {
                            if area == 0xFFFF || area == 0 || (context.checkItemID == 0 && subarea == 0) {
                                guard try bytes.u16(18) == subarea else { continue }
                            } else {
                                guard UInt16(bytes.bytes[17]) == area,
                                      try bytes.u16(18) == subarea else { continue }
                                if system, Int(try bytes.u16(14)) != Int(context.mapID) { continue }
                            }
                        }
                    case 20:
                        if Int(bytes.bytes[16]) == Int(context.pairA),
                           Int(bytes.bytes[17]) == Int(context.pairB) { return .selected(selection) }
                        continue
                    case 10...14:
                        if upView >= 0 {
                            guard [11, 12, 14].contains(mode),
                                  Int(try bytes.u16(16)) == upView else { continue }
                        } else {
                            let packed = try bytes.u16(16)
                            guard mode == 10 || mode == 13,
                                  Int(packed >> 8) == Int(context.mapID),
                                  packed & 255 == area,
                                  try bytes.u16(18) == subarea else { continue }
                        }
                        restoreCloseup = !system
                    case 1, 26:
                        let position = mode == 1 ? 18 : 16
                        guard Int(try bytes.u16(position)) == Int(context.parameter56) else { continue }
                        conditionEvent = rowEvent
                        conditionScope = .normal
                    case 29:
                        guard Int(bytes.bytes[16]) == Int(context.parameter58) else { continue }
                        conditionScope = .normal
                    case 30:
                        if Int(try bytes.u16(16)) == Int(context.pairA),
                           Int(try bytes.u16(18)) == Int(context.pairB) { return .selected(selection) }
                        continue
                    case 31:
                        guard Int(bytes.bytes[16]) == Int(context.parameter60) else { continue }
                        conditionEvent = rowEvent
                        conditionScope = .system
                    case 32:
                        conditionEvent = rowEvent
                        conditionScope = .normal
                    default:
                        if sceneID == 0xFFFE, mode != 15, mode != 3 { continue }
                        if (!system || mode != 0), rowEvent != context.eventID { continue }
                    }
                    let result = try evaluate(OriginalConditionRequest(modeID: mode,
                        eventID: conditionEvent, eventKey: key, scope: conditionScope))
                    if restoreCloseup { try applyEffect(.restoreCloseupContext) }
                    switch result {
                    case .pass: return .selected(selection)
                    case .fail: continue
                    case .unresolvedState, .unrecoveredCondition:
                        return .unresolved(candidate: selection, condition: result)
                    }
                }
            }
        }
        return .noMatch
    }
}
