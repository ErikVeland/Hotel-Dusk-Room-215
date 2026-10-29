import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalLabelPeelSessionTests: XCTestCase {
    func testModeledFollowupPeelReturnsToEventTenAndAwardsLabel() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP6_R106")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            $0.sourceOffset == 236
        })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 6)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 46))

        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(
            runner: runner,
            audio: audio,
            catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        for _ in 0..<65 { play.advanceFrame() }
        for y in stride(from: 52, through: 204, by: 8) {
            play.holdLabelPeelTouch(x: 36, y: Float(y))
            play.advanceFrame()
            for x in stride(from: 38, through: 156, by: 2) {
                play.holdLabelPeelTouch(x: Float(x), y: Float(y))
                play.advanceFrame()
            }
            play.releaseLabelPeelTouch()
            play.advanceFrame()
        }
        for _ in 0..<65 where play.labelPeel != nil { play.advanceFrame() }

        guard case .dialogue(let packet) = play.runner.phase else {
            return XCTFail("The cleared label must return to its source follow-up dialogue: \(play.runner.phase)")
        }
        XCTAssertEqual(play.runner.session.selection.eventID, 9)
        XCTAssertTrue(packet.pages.flatMap(\.entries).contains {
            $0.utf8?.contains("How the hell do I peel") == true
        })
        XCTAssertNil(play.labelPeel)
        play.advanceDialogue()
        XCTAssertEqual(play.runner.phase, .process(id: 46))
        XCTAssertEqual(play.runner.session.selection.eventID, 7)
        XCTAssertEqual(play.labelPeel?.stage, .peel)

        for _ in 0..<65 { play.advanceFrame() }
        for _ in 0..<5 {
            play.holdLabelPeelTouch(x: 150, y: 70)
            play.advanceFrame()
            play.holdLabelPeelTouch(x: 132, y: 88)
            play.advanceFrame()
            play.releaseLabelPeelTouch()
            play.advanceFrame()
        }
        for _ in 0..<65 where play.labelPeel != nil { play.advanceFrame() }

        XCTAssertNil(play.labelPeel)
        XCTAssertEqual(play.runner.session.selection.eventID, 10)
        guard case .dialogue = play.runner.phase else {
            return XCTFail("Event 10 should acknowledge the peeled label: \(play.runner.phase)")
        }
        play.advanceDialogue()
        if case .itemNotice(let itemID, _) = play.runner.phase {
            XCTAssertEqual(itemID, 66)
        } else {
            XCTFail("The source story should award the wine label: \(play.runner.phase)")
        }
        if case .halted(let halt) = play.runner.phase {
            XCTFail("Successful peeling must return to the Chapter 6 story: \(halt.reason)")
        }
    }
}
