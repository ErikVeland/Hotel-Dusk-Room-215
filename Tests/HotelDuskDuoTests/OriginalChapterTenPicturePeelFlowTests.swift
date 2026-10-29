import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterTenPicturePeelFlowTests: XCTestCase {
    func testProcess61ReturnValuesSelectTheirSourceOutcomes() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R302")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 61
        })
        var eventIDs: [UInt16] = []
        var dialogue: [String] = []

        for returnValue in Int16(0)...2 {
            let result = try OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: program.conditions, processReturn: returnValue)
            guard case .completed(let completion) = result,
                  let transition = completion.transition else {
                return XCTFail("Picture peel result \(returnValue) must select a source event")
            }
            let text: [String] = try program.blocks.operations(forEvent: Int(transition.eventID)).compactMap { record in
                guard case .dialogue(let textIndex) = try OriginalOperation(record: record) else { return nil }
                return program.text.entries[Int(textIndex)].utf8
            }
            eventIDs.append(transition.eventID)
            dialogue.append(text.joined(separator: " "))
        }

        XCTAssertEqual(eventIDs, [9, 10, 11])
        XCTAssertTrue(dialogue[0].contains("Dunning IS Osterzone!"))
        XCTAssertTrue(dialogue[1].contains("I still can't tell."))
        XCTAssertTrue(dialogue[1].contains("I got it!"))
        XCTAssertTrue(dialogue[2].contains("What's up, Hyde?"))
        XCTAssertTrue(dialogue[2].contains("I'm getting ready to go."))
    }

    @MainActor
    func testProcess61StartsThePicturePeelOverlay() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R302")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 61
        })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(41, previous: 40)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 41)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 61))
        XCTAssertEqual(play.picturePeelImage?.width, 192)
        XCTAssertEqual(play.picturePeelImage?.height, 256)
        XCTAssertEqual(play.picturePeelUpperImage?.width, 192)
        XCTAssertEqual(play.picturePeelUpperImage?.height, 256)
        XCTAssertNil(play.typewriter)
    }

    @MainActor
    func testProcess61CompletesThePeelAndReturnsThroughItsSourceBranch() throws {
        let play = try makePicturePeelSession()
        defer { play.stop() }

        for y in stride(from: 2, to: OriginalPicturePeelProcess.height, by: 6) {
            for x in [0, 95, 191] {
                play.holdPicturePeelTouch(x: Float(x), y: Float(y))
                play.advanceFrame()
            }
            if play.picturePeel?.isComplete == true { break }
        }

        XCTAssertGreaterThanOrEqual(play.picturePeel?.clearedPixelCount ?? 0,
                                    OriginalPicturePeelProcess.clearedPixelThreshold)
        play.releasePicturePeelTouch()
        play.advanceFrame()
        play.quitPicturePeel()

        XCTAssertNil(play.picturePeel)
        guard case .dialogue(let packet) = play.runner.phase else {
            return XCTFail("Expected picture peel's return dialogue, got \(play.runner.phase)")
        }
        XCTAssertEqual(packet.sourceOffset, 4500)
    }

    @MainActor
    private func makePicturePeelSession() throws -> OriginalPlaySession {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R302")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 61
        })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(41, previous: 40)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 41)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        audio.isMuted = true
        return OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
    }
}
