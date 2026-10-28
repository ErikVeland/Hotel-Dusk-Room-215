import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalLabelPeelSessionTests: XCTestCase {
    func testPeelFadeStopsAtUnrecoveredFollowupWithoutReturningToStory() throws {
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

        guard case .halted(let halt) = play.runner.phase else {
            return XCTFail("The peel must not return to the story before its follow-up interaction")
        }
        XCTAssertTrue(halt.reason.contains("wine-label follow-up interaction"))
        XCTAssertNil(play.labelPeel)
    }
}
