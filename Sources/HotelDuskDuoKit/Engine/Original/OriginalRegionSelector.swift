import Foundation

/**
 * 0x020285F0 searches all scenes for a mode-3 event with the matching region number.
 */
public enum OriginalRegionSelector {
    public static func select(graph: OriginalBlockGraph, region: UInt16, nowTime: UInt16,
                              evaluate: (OriginalConditionRequest) throws -> OriginalConditions.Result)
        throws -> OriginalEventSelector.Outcome {
        try selectTrigger(graph: graph, kind: 3, value: region, nowTime: nowTime, evaluate: evaluate)
    }

    /**
     * Normal-script departure search at 0x020287B0, before the map changes.
     */
    public static func departure(graph: OriginalBlockGraph, destination: Int16, nowTime: UInt16,
                                 evaluate: (OriginalConditionRequest) throws -> OriginalConditions.Result)
        throws -> OriginalEventSelector.Outcome {
        try selectTrigger(graph: graph, kind: 1, value: UInt16(bitPattern: destination), nowTime: nowTime, evaluate: evaluate)
    }

    private static func selectTrigger(graph: OriginalBlockGraph, kind: UInt8, value: UInt16, nowTime: UInt16,
                                      evaluate: (OriginalConditionRequest) throws -> OriginalConditions.Result)
        throws -> OriginalEventSelector.Outcome {
        for scene in graph.tables[0] {
            guard let blocks = scene.children else { continue }
            for blockIndex in blocks {
                let block = graph.tables[1][blockIndex]
                guard try OriginalBytes(block.raw).u16(2) == nowTime,
                      let events = block.children else { continue }
                for eventIndex in events {
                    let event = graph.tables[2][eventIndex], bytes = OriginalBytes(event.raw)
                    guard try bytes.u16(0) == 3, bytes.bytes[16] == kind,
                          try bytes.u16(18) == value else { continue }
                    let candidate = OriginalEventSelector.Selection(sceneIndex: scene.index,
                        blockIndex: block.index, eventIndex: eventIndex, eventSourceOffset: event.sourceOffset)
                    let result = try evaluate(.init(modeID: 3, eventID: bytes.u16(2),
                        eventKey: Int16(bitPattern: bytes.u16(4)), scope: .normal))
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
