import XCTest
@testable import HotelDuskDuoKit

final class OriginalEventCompletionTests: XCTestCase {
    func testUnrecoveredLateChapterInspectionCounterStaysExplicit() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R205")
        var bytes = Data(repeating: 0, count: OriginalGameState.byteCount)
        bytes[0] = 9
        bytes[4] = 40
        let result = try OriginalEventCompletion.stateOnlyExit(event: program.blocks.tables[2][16],
            conditions: program.conditions, game: OriginalGameState(snapshot: bytes))
        XCTAssertEqual(result, .requiresOriginalHandler(mode: 10))
    }

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

    func testEmbeddedProcessRetainsItsStoryCallerContextUntilReturn() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 56
        })
        let reader = OriginalBytes(event.raw)
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: try reader.u16(4),
            nowTime: game.nowTime, mapID: game.mapID)
        selection.debugEventSelection = true
        var runner = try OriginalEventRunner(program: program, game: game, selection: selection)

        XCTAssertEqual(runner.phase, OriginalEventRunner.Phase.process(id: 56))
        let invocation = try XCTUnwrap(runner.embeddedProcessInvocation)
        XCTAssertEqual(invocation.processID, 56)
        XCTAssertEqual(invocation.programName, program.name)
        XCTAssertEqual(invocation.eventIndex, event.index)
        XCTAssertEqual(invocation.eventSourceOffset, event.sourceOffset)
        XCTAssertEqual(invocation.eventBytes, event.raw)
        XCTAssertEqual(invocation.selection, selection)

        runner.finishProcess(returnValue: 2)

        XCTAssertNil(runner.embeddedProcessInvocation)
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

    func testChapterSevenTreeProcessResultTwoSelectsItsScriptTransition() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP7_R122")
        let graph = try program.blocks
        let treeEvents = try graph.tables[2].filter {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 43
        }
        XCTAssertEqual(treeEvents.count, 1)
        let event = try XCTUnwrap(treeEvents.first)

        guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: program.conditions, processReturn: 2) else {
            return XCTFail("The tree process result must select its original event transition")
        }
        XCTAssertNotNil(completion.transition)
    }

    func testChapterSevenBagProcessResultTwoSelectsItsScriptTransition() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP7_R122")
        let events = try program.blocks.tables[2].filter {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 55
        }
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)

        guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: program.conditions, processReturn: 2) else {
            return XCTFail("The bag process result must select its original event transition")
        }
        XCTAssertNotNil(completion.transition)
    }

    func testChapterEightBowlingProcessHasRecoveredReturnTransitions() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP8_R119")
        let events = try program.blocks.tables[2].filter {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 44
        }
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)

        for (result, expectedEvent) in [(Int16(0), UInt16(9)), (1, 10), (2, 11)] {
            guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: program.conditions, processReturn: result) else {
                return XCTFail("Bowling process result \(result) must select an original transition")
            }
            XCTAssertEqual(completion.transition?.sourceOffset, 368 + Int(result) * 16)
            XCTAssertEqual(completion.transition?.sceneID, 4)
            XCTAssertEqual(completion.transition?.modeID, 3)
            XCTAssertEqual(completion.transition?.eventID, expectedEvent)
        }
    }

    func testChapterEightBowlingProcess52HasRecoveredReturnTransitions() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP8_R114")
        let events = try program.blocks.tables[2].filter {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 52
        }
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)

        for (result, expectedEvent) in [(Int16(0), UInt16(16)), (1, 17), (2, 17), (3, 18)] {
            guard case .completed(let completion) = try OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: program.conditions, processReturn: result) else {
                return XCTFail("Bowling result \(result) must select an original transition")
            }
            XCTAssertEqual(completion.transition?.sourceOffset, 832 + Int(result) * 16)
            XCTAssertEqual(completion.transition?.sceneID, UInt16.max - 1)
            XCTAssertEqual(completion.transition?.modeID, 3)
            XCTAssertEqual(completion.transition?.eventID, expectedEvent)
        }
    }
}
