import XCTest
@testable import HotelDuskDuoKit

final class OriginalEventSelectorTests: XCTestCase {
    func testOriginalOpeningCandidateUsesAllThreeTables() throws {
        let graph = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102").blocks
        let context = OriginalEventSelectionContext(sceneID: 0xFFFF, blockID: 0,
            modeID: 3, eventID: 0, nowTime: 0, mapID: 2)
        var requests: [OriginalConditionRequest] = []
        let outcome = try OriginalEventSelector.select(graph: graph, context: context) {
            requests.append($0)
            return .pass
        }
        guard case .selected(let selected) = outcome else { return XCTFail("Original candidate not selected") }
        XCTAssertEqual(selected.eventIndex, 0)
        XCTAssertEqual(selected.eventSourceOffset, 544)
        XCTAssertEqual(selected.blockIndex, 0)
        XCTAssertEqual(requests, [.init(modeID: 3, eventID: 0, eventKey: 0, scope: .normal)])
        XCTAssertEqual(try graph.operations(forEvent: selected.eventIndex).count, 14)
    }

    func testOriginalSelectorDoesNotSkipAnUnresolvedCandidate() throws {
        let graph = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102").blocks
        let context = OriginalEventSelectionContext(sceneID: 0xFFFF, blockID: 0,
            modeID: 3, eventID: 0, nowTime: 0, mapID: 2)
        let unresolved = OriginalConditions.Result.unresolvedState(.eventFlag(group: 2, index: 0), sourceOffset: 1440)
        var count = 0
        let outcome = try OriginalEventSelector.select(graph: graph, context: context) { _ in
            count += 1
            return unresolved
        }
        guard case .unresolved(let candidate, let condition) = outcome else { return XCTFail("Unresolved event advanced") }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(candidate.eventIndex, 0)
        XCTAssertEqual(condition, unresolved)
    }

    func testCloseupSelectionRetainsTheNonzeroSubareaStackArgument() throws {
        let graph = try OriginalScriptCatalog.bundled().loadProgram("EP10_R108").blocks
        var context = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 99,
            modeID: 10, eventID: 77, nowTime: 0, mapID: 8)
        context.upViewID = -1
        context.areaID = 1
        context.subareaID = 21
        var effects: [OriginalEventSelectionEffect] = []
        let outcome = try OriginalEventSelector.select(graph: graph, context: context,
            evaluate: { request in
                XCTAssertEqual(request.eventKey, 1)
                XCTAssertEqual(request.eventID, 77)
                return .pass
            }, applyEffect: { effects.append($0) })
        guard case .selected(let selected) = outcome else { return XCTFail("Original closeup not selected") }
        XCTAssertEqual(selected.eventIndex, 1)
        XCTAssertEqual(effects, [.restoreCloseupContext])
        context.subareaID = 20
        let mismatch = try OriginalEventSelector.select(graph: graph, context: context) { _ in
            XCTFail("Condition must not run for a different closeup")
            return .pass
        }
        XCTAssertEqual(mismatch, .noMatch)
    }

    func testOriginalItemTargetAndSystemModeHaveDifferentSelectionRules() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var item = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0,
            modeID: 16, eventID: 0, nowTime: 0, mapID: 8)
        item.checkItemID = 77
        item.areaID = 1
        item.subareaID = 21
        var effects: [OriginalEventSelectionEffect] = []
        let result = try OriginalEventSelector.select(graph: catalog.loadProgram("EP10_R108").blocks,
            context: item, evaluate: { _ in .pass }, applyEffect: { effects.append($0) })
        guard case .selected(let selected) = result else { return XCTFail("Original item event not selected") }
        XCTAssertEqual(selected.eventIndex, 10)
        XCTAssertEqual(effects, [.consumeItemOnlyCheck])

        var system = OriginalEventSelectionContext(sceneID: 999, blockID: 99,
            modeID: 20, eventID: 999, nowTime: 99, mapID: 39)
        system.pairA = 1
        system.pairB = 0
        let result2 = try OriginalEventSelector.select(graph: catalog.loadProgram("System").blocks,
            context: system, scope: .system) { _ in
                XCTFail("Mode20 accepts the original pair without CHK")
                return .pass
            }
        guard case .selected(let selected2) = result2 else { return XCTFail("System pair not selected") }
        XCTAssertEqual(selected2.eventIndex, 1449)
    }
}
