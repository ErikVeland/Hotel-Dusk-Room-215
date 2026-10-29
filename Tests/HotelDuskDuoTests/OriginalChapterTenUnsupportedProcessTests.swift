import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalChapterTenUnsupportedProcessTests: XCTestCase {
    func testR304BrickProcessHasThreeSourceReturnBranches() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R304")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            $0.sourceOffset == 672
        })
        XCTAssertEqual(try OriginalEventCompletion.embeddedProcessID(event: event), 75)

        var destinations: [UInt16] = []
        for result in 0...2 {
            let outcome = try OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: program.conditions, processReturn: Int16(result))
            guard case .completed(let completion) = outcome,
                  let transition = completion.transition else {
                XCTFail("Process 75 result \(result) must have a source transition")
                continue
            }
            destinations.append(transition.eventID)
        }

        XCTAssertEqual(destinations, [25, 26, 27])

        let outcomeText = try [25, 26, 27].map { eventID -> String in
            try program.blocks.operations(forEvent: eventID).compactMap { record in
                guard case .dialogue(let textIndex) = try OriginalOperation(record: record) else {
                    return nil
                }
                return program.text.entries[Int(textIndex)].utf8
            }.joined(separator: " ")
        }
        XCTAssertTrue(outcomeText[0].contains("There's a door back there!"))
        XCTAssertTrue(outcomeText[1].contains("Not all the bricks are out of"))
        XCTAssertTrue(outcomeText[2].contains("Ain't ya gonna do nuthin'?"))
        XCTAssertTrue(outcomeText[2].contains("I'm just getting ready to start."))
    }

    func testProcess75BrickModeRunsAndReturnsThroughTheChapterEvent() throws {
        let play = try makeSession(program: "EP10_R304", sourceOffset: 672,
                                   processID: 75, mapID: 43)
        defer { play.stop() }

        XCTAssertNotNil(play.brickWall)
        if case .halted(let halt) = play.runner.phase {
            XCTFail("Process 75 must run its brick puzzle: \(halt.reason)")
        }
        play.leaveBrickWall()
        XCTAssertNil(play.brickWall)
        XCTAssertNotEqual(play.runner.phase, .process(id: 75))
        XCTAssertEqual(play.runner.session.selection.eventID, 27)
    }

    func testProcess85RunsTheAfterConfessSceneBeforeItsStoryReturn() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R305")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            $0.sourceOffset == 1268
        })
        let outcome = try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: program.conditions,
            processReturn: OriginalAfterConfessProcess.result)
        guard case .completed(let completion) = outcome else {
            return XCTFail("AfterConfess result 2 must complete its source event")
        }
        XCTAssertNil(completion.transition, "The source event returns without an explicit event jump")

        let play = try makeSession(program: "EP10_R305", sourceOffset: 1268,
                                   processID: 85, mapID: 44)
        defer { play.stop() }

        XCTAssertNotNil(play.afterConfess)
        for _ in 0..<OriginalAfterConfessProcess.frameCounts.reduce(0, +) {
            play.advanceFrame()
        }
        XCTAssertNil(play.afterConfess)
        XCTAssertNotEqual(play.runner.phase, .process(id: 85))
        if case .halted(let halt) = play.runner.phase {
            XCTAssertFalse(halt.reason.contains("AfterConfess"), halt.reason)
        }
    }

    func testProcess88TouchCompletesAndRunsChapterTenEnding() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R102")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            $0.sourceOffset == 208
        })
        let outcome = try OriginalEventCompletion.stateOnlyExit(
            event: event, conditions: program.conditions,
            processReturn: OriginalVSSceneProcess.result)
        guard case .completed(let completion) = outcome else {
            return XCTFail("The normal Process 88 result must complete its source event")
        }
        XCTAssertEqual(completion.transition?.eventID, 5)

        let play = try makeSession(program: "EP10_R102", sourceOffset: 208,
                                   processID: 88, mapID: 1)
        defer { play.stop() }

        XCTAssertNotNil(play.vsScene)
        XCTAssertNotNil(play.vsSceneImage)
        play.touchVSScene()
        for _ in 0..<OriginalVSSceneProcess.completionFrameCount {
            play.advanceFrame()
        }
        XCTAssertNil(play.vsScene)
        XCTAssertNil(play.vsSceneImage)
        XCTAssertNotEqual(play.runner.phase, .process(id: 88))
        XCTAssertEqual(play.runner.session.selection.modeID, 3)
        XCTAssertEqual(play.runner.session.selection.eventID, 5)
        if case .dialogue = play.runner.phase {
            // Process 88 must return to the source event's Chapter 10 dialogue.
        } else {
            XCTFail("Process 88 did not resume the Chapter 10 story: \(play.runner.phase)")
            return
        }

        for _ in 0..<200 {
            switch play.runner.phase {
            case .dialogue, .itemNotice:
                play.advanceDialogue()
            case .waiting:
                play.advanceFrame()
            case .exploration:
                break
            default:
                XCTFail("The Chapter 10 ending stopped at \(play.runner.phase)")
                return
            }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 1))
    }

    private func makeSession(program name: String, sourceOffset: Int,
                             processID: UInt16, mapID: Int16) throws -> OriginalPlaySession {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram(name)
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            $0.sourceOffset == sourceOffset
        })
        XCTAssertEqual(try OriginalEventCompletion.embeddedProcessID(event: event), processID)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(mapID, previous: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: mapID)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        try audio.applyOriginalCommand(.disableMusic(true))
        try audio.applyOriginalCommand(.disableNewEffects(true))
        return OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
    }
}
