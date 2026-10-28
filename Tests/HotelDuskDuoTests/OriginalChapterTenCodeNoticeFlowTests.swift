import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterTenCodeNoticeFlowTests: XCTestCase {
    func testCodeNoticeReturnsSelectTheirOriginalChapterTenTransitions() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")

        for processID: UInt16 in [62, 67] {
            let event = try XCTUnwrap(program.blocks.tables[2].first {
                try OriginalEventCompletion.embeddedProcessID(event: $0) == processID
            })
            var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
            game.setMap(40, previous: 39)
            var selection = OriginalEventSelectionContext(
                sceneID: .max, blockID: 0, modeID: 15,
                eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 40)
            selection.debugEventSelection = true
            var runner = try OriginalEventRunner(program: program, game: game, selection: selection)

            XCTAssertEqual(runner.phase, .process(id: processID))
            var process = OriginalCodeNoticeProcess(processID: Int(processID))
            for _ in 0..<OriginalCodeNoticeProcess.fadeUpdates { _ = process.update() }
            _ = process.update(pageTouch: .init(19, 240))
            _ = process.update(exitControlFinished: true)
            runner.finishProcess(returnValue: try XCTUnwrap(process.result))

            XCTAssertEqual(runner.phase, .exploration(mapID: 40))
            if case .halted(let halt) = runner.phase { XCTFail(halt.reason) }
        }
    }

    @MainActor
    func testCodeNoticeSessionLoadsArtworkAndContinuesOnNormalMaskedTouch() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")

        for processID: UInt16 in [62, 67] {
            let event = try XCTUnwrap(program.blocks.tables[2].first {
                try OriginalEventCompletion.embeddedProcessID(event: $0) == processID
            })
            var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
            game.setMap(40, previous: 39)
            var selection = OriginalEventSelectionContext(
                sceneID: .max, blockID: 0, modeID: 15,
                eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 40)
            selection.debugEventSelection = true
            let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
            let audio = AudioController()
            audio.isMuted = true
            var playedEffects: [String] = []
            let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
                originalEffectPlayer: { archive, entry in
                    playedEffects.append("\(archive):\(entry)")
                })
            defer { play.stop() }

            XCTAssertNotNil(play.codeNoticeImage)
            XCTAssertTrue(try XCTUnwrap(play.codeNoticeCaption).isEmpty)
            for _ in 0..<OriginalCodeNoticeProcess.fadeUpdates { play.advanceFrame() }
            XCTAssertEqual(play.codeNotice?.phase, .awaitingExit)

            play.touchCodeNotice(pageX: 100, pageY: 100)
            play.advanceFrame()
            XCTAssertEqual(play.codeNotice?.phase, .awaitingExit)

            play.touchCodeNotice(pageX: 19, pageY: 240)
            play.advanceFrame()
            XCTAssertEqual(play.codeNotice?.phase, .waitingForExitControl)
            XCTAssertEqual(playedEffects, [])
            play.advanceFrame()

            XCTAssertNil(play.codeNotice)
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
        }
    }
}
