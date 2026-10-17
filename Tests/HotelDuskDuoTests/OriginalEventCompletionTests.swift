import XCTest
@testable import HotelDuskDuoKit

final class OriginalEventCompletionTests: XCTestCase {
    func testOriginalNarrativeLaunchesItsEmbeddedProcessAndReturnsToItsNextEvent() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let graph = try program.blocks, conditions = try program.conditions
        var session = OriginalEventSession(selection: .init(sceneID: .max, blockID: 0, modeID: 3,
            eventID: 0, nowTime: 0, mapID: 2), operationIndex: 14, eventCommitted: false,
            savedFrames: [], restoreOverride: 0, restoredFromNonDialogue: false)
        let result = try OriginalEventCompletion.stateOnlyExit(event: graph.tables[2][0], conditions: conditions)
        guard case .completed(let completion) = result else { return XCTFail("Original narrative exit") }
        XCTAssertEqual(completion.transition?.sourceOffset, 1456)
        completion.apply(to: &session)
        XCTAssertEqual(session.selection.sceneID, .max)
        XCTAssertEqual(session.selection.modeID, 15)
        XCTAssertEqual(session.selection.eventID, 1)
        XCTAssertEqual(session.operationIndex, 0)
        XCTAssertEqual(try OriginalEventCompletion.embeddedProcessID(event: graph.tables[2][1]), 56)
        guard case .completed(let returned) = try OriginalEventCompletion.stateOnlyExit(
            event: graph.tables[2][1], conditions: conditions, processReturn: 0) else {
            return XCTFail("Original process return")
        }
        returned.apply(to: &session)
        XCTAssertEqual(session.selection.modeID, 3)
        XCTAssertEqual(session.selection.eventID, 2)
    }

    func testOriginalProcessOutcomeSelectsItsOwnTransition() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let event = try program.blocks.tables[2][4], conditions = try program.conditions
        for (resultIndex, expectedEvent) in [7,5,6].enumerated() {
            guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: conditions, processReturn: Int16(resultIndex)) else {
                return XCTFail("Process return must use CHK records")
            }
            XCTAssertEqual(completion.transition?.sceneID, 0xFFFE)
            XCTAssertEqual(completion.transition?.modeID, 3)
            XCTAssertEqual(completion.transition?.eventID, UInt16(expectedEvent))
        }
        XCTAssertThrowsError(try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: conditions, processReturn: 3))
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.markEventCompleted(group: 2, event: 4)
        XCTAssertEqual(game.value(for: .eventFlag(group: 2, index: 4)), true)
        XCTAssertEqual(game.bytes[0x14CC + 2 * 32] & 16, 16)
        let unchanged = game
        game.markEventCompleted(group: -1, event: 4)
        game.markEventCompleted(group: 47, event: 4)
        game.markEventCompleted(group: 2, event: 256)
        XCTAssertEqual(game, unchanged)
    }
}
