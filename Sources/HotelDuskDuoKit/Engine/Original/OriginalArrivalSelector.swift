import Foundation

/// Arrival trigger search, 0x0202899C. The map process calls it with the
/// previous map ID before entering the normal talk controller.
public enum OriginalArrivalSelector {
    public static func select(graph: OriginalBlockGraph, previousMapID: Int16,
                              nowTime: UInt16, mapID: Int16, scope: OriginalProgramScope = .normal,
                              evaluate: (OriginalConditionRequest) throws -> OriginalConditions.Result)
        throws -> OriginalEventSelector.Outcome {
        for scene in graph.tables[0] {
            guard try OriginalBytes(scene.raw).u16(0) == 0xFFFF,
                  let blocks = scene.children else { continue }
            for blockIndex in blocks {
                let block = graph.tables[1][blockIndex]
                guard try scope == .system || OriginalBytes(block.raw).u16(2) == nowTime,
                      let events = block.children else { continue }
                for eventIndex in events {
                    let event = graph.tables[2][eventIndex], bytes = OriginalBytes(event.raw)
                    guard try bytes.u16(0) == 3, bytes.bytes[16] == 2,
                          try bytes.u16(18) == UInt16(bitPattern: previousMapID) else { continue }
                    if scope == .system, try bytes.u16(14) != UInt16(bitPattern: mapID) { continue }
                    let candidate = OriginalEventSelector.Selection(sceneIndex: scene.index,
                        blockIndex: block.index, eventIndex: eventIndex, eventSourceOffset: event.sourceOffset)
                    let result = try evaluate(.init(modeID: 3, eventID: bytes.u16(2),
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
