import XCTest
@testable import HotelDuskDuoKit

final class OriginalShownItemSelectorTests: XCTestCase {
    func testItemResponseScansThePersonsBlocksAtTheCurrentTime() throws {
        let graph = try OriginalScriptCatalog.bundled().loadProgram("EP1_R213").blocks
        var requests: [OriginalConditionRequest] = []
        let outcome = try OriginalShownItemSelector.select(graph: graph, person: 11, item: 3, nowTime: 1) {
            requests.append($0)
            return .pass
        }
        guard case .selected(let selected) = outcome else { return XCTFail("Expected the puzzle-piece response") }
        XCTAssertEqual(selected.eventIndex, 50)
        XCTAssertEqual(requests, [.init(modeID: 27, eventID: 50, eventKey: 50, scope: .normal)])
        for (person, item, time): (UInt16, UInt8, UInt16) in [(11, 3, 0), (11, 87, 1), (17, 3, 1)] {
            XCTAssertEqual(try OriginalShownItemSelector.select(graph: graph, person: person, item: item, nowTime: time) { _ in
                XCTFail("A different person, item or time must not evaluate this response")
                return .pass
            }, .noMatch)
        }
        let shared = try OriginalShownItemSelector.select(graph: graph, person: 11, item: 3, nowTime: 99, scope: .system) {
            XCTAssertEqual($0.scope, .system)
            return .pass
        }
        XCTAssertEqual(shared, outcome)
    }

    func testFailedAndUnresolvedConditionsRemainDistinct() throws {
        let graph = try OriginalScriptCatalog.bundled().loadProgram("EP1_R213").blocks
        XCTAssertEqual(try OriginalShownItemSelector.select(graph: graph, person: 11, item: 3, nowTime: 1) { _ in .fail(sourceOffset: 0) }, .noMatch)
        let unresolved = OriginalConditions.Result.unresolvedState(.eventFlag(group: 39, index: 50), sourceOffset: 0)
        let outcome = try OriginalShownItemSelector.select(graph: graph, person: 11, item: 3, nowTime: 1) { _ in unresolved }
        guard case .unresolved(let candidate, let condition) = outcome else { return XCTFail("An unresolved condition must stop selection") }
        XCTAssertEqual(candidate.eventIndex, 50)
        XCTAssertEqual(condition, unresolved)
    }

    func testShownItemClearsOnlyItsPersonsMarkerAndRejectsInvalidIndices() throws {
        let initial = [UInt8](repeating: 255, count: OriginalGameState.byteCount)
        var game = try OriginalGameState(snapshot: Data(initial))
        game.markItemShown(3, person: 11)
        let offset = 0x13E4 + 11 * 11
        XCTAssertEqual(game.bytes[offset], 247)
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != initial[$0] }, [offset])
        let changed = game.bytes
        game.markItemShown(3, person: -1)
        game.markItemShown(3, person: 18)
        game.markItemShown(88, person: 11)
        XCTAssertEqual(game.bytes, changed)
        game.markItemShown(87, person: 17)
        XCTAssertEqual(game.bytes[0x13E4 + 17 * 11 + 10], 127)
    }
}
