import Foundation

/**
 * 0x02028E4C scans a person's blocks for a response to the selected inventory item.
 */
public enum OriginalShownItemSelector {
    public static func select(graph: OriginalBlockGraph, person: UInt16, item: UInt8,
                              nowTime: UInt16, scope: OriginalProgramScope = .normal,
                              evaluate: (OriginalConditionRequest) throws -> OriginalConditions.Result)
        throws -> OriginalEventSelector.Outcome {
        for scene in graph.tables[0] {
            guard try OriginalBytes(scene.raw).u16(0) == person, let blocks = scene.children else { continue }
            for blockIndex in blocks {
                let block = graph.tables[1][blockIndex]
                let blockTime = try OriginalBytes(block.raw).u16(2)
                guard scope == .system || blockTime == nowTime,
                      let events = block.children else { continue }
                for eventIndex in events {
                    let event = graph.tables[2][eventIndex], bytes = OriginalBytes(event.raw)
                    let mode = try bytes.u16(0)
                    guard [16, 27].contains(mode), bytes.bytes[16] == item else { continue }
                    let candidate = OriginalEventSelector.Selection(sceneIndex: scene.index,
                        blockIndex: block.index, eventIndex: event.index, eventSourceOffset: event.sourceOffset)
                    let result = try evaluate(.init(modeID: mode, eventID: bytes.u16(2),
                        eventKey: Int16(bitPattern: bytes.u16(4)), scope: scope))
                    switch result {
                    case .pass: return .selected(candidate)
                    case .fail: continue
                    case .unresolvedState, .unrecoveredCondition:
                        return .unresolved(candidate: candidate, condition: result)
                    }
                }
            }
        }
        return .noMatch
    }
}
