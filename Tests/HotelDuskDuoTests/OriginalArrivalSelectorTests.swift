import XCTest
@testable import HotelDuskDuoKit

final class OriginalArrivalSelectorTests: XCTestCase {
    func testOriginalHotelArrivalSelectsFirstNarrativeThroughConditionTable() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let graph = try program.blocks, conditions = try program.conditions
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(2, previous: 1)
        var session = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        let selected = try OriginalArrivalSelector.select(graph: graph, previousMapID: game.previousMapID,
            nowTime: game.nowTime, mapID: game.mapID) {
                try session.evaluate($0, conditions: conditions, game: game)
            }
        guard case .selected(let row) = selected else { return XCTFail("Original arrival event was not selected") }
        XCTAssertEqual(row.eventIndex, 0)
        XCTAssertEqual(session.selection.sceneID, .max)
        XCTAssertEqual(session.selection.modeID, 3)
        XCTAssertEqual(session.selection.eventID, 0)
        let operations = try graph.operations(forEvent: row.eventIndex)
        let packet = try OriginalDialoguePacket(record: operations[0], following: operations[1], text: program.text)
        XCTAssertEqual(packet.pages.first?.entries.first?.index, 0)
        XCTAssertEqual(game.previousMapID, 1)
        game.setMap(3, previous: -1)
        XCTAssertEqual(game.previousMapID, 2)
    }

    func testArrivalRequiresOriginalPreviousMapAndSkipsCompletedEvent() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let graph = try program.blocks, conditions = try program.conditions
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(2, previous: 1)
        func result(previous: Int16) throws -> OriginalEventSelector.Outcome {
            try OriginalArrivalSelector.select(graph: graph, previousMapID: previous,
                nowTime: game.nowTime, mapID: game.mapID) {
                    try conditions.evaluatePredicates(eventKey: $0.eventKey, context: game)
                }
        }
        XCTAssertEqual(try result(previous: 999), .noMatch)
        game.markEventCompleted(group: 2, event: 0)
        XCTAssertEqual(try result(previous: 1), .noMatch)
    }
}
