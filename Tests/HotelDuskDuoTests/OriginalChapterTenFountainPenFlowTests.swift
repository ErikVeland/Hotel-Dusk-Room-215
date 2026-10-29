import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterTenTypewriterFlowTests: XCTestCase {
    @MainActor
    func testProcess74LoadsTypewriterAssetsFromItsFactoryGroup() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 74
        })
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(40, previous: 39)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: UInt16(event.index), nowTime: game.nowTime, mapID: 40)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        let audio = AudioController()
        _ = try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            puzzleSeed: { 0x00A7 })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .process(id: 74))
        XCTAssertNotNil(play.typewriter)
        XCTAssertEqual(play.typewriterUpperImage?.width, 192)
        XCTAssertEqual(play.typewriterUpperImage?.height, 256)
        XCTAssertEqual(play.typewriterImage?.width, 192)
        XCTAssertEqual(play.typewriterImage?.height, 256)
        XCTAssertNil(play.fountainPen)
    }

    @MainActor
    func testProcess74AcceptsTheRecoveredCipherThroughPageInput() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP10_R301")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 74
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
        _ = try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
                                       puzzleSeed: { 0x00A7 })
        defer { play.stop() }

        let cipher = try XCTUnwrap(play.typewriter?.cipher)
        let shift = cipher.expectedShift
        play.adjustTypewriterShift(by: shift)
        try enter("OSTERZONE IS", into: play, shift: shift)
        let enterKey = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == "e" })
        tap(enterKey, in: play)
        try enter("DUNNING SMITH", into: play, shift: shift)
        tap(enterKey, in: play)

        XCTAssertNil(play.typewriter)
        XCTAssertNotEqual(play.runner.phase, .process(id: 74))
        for _ in 0..<200 {
            switch play.runner.phase {
            case .dialogue, .itemNotice:
                play.advanceDialogue()
            case .waiting:
                play.advanceFrame()
            case .exploration:
                break
            default:
                XCTFail("The typewriter story return stopped at \(play.runner.phase)")
                return
            }
            if case .exploration = play.runner.phase { break }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 40))
    }

    @MainActor
    private func enter(_ answer: String, into play: OriginalPlaySession, shift: Int) throws {
        let amount = shift
        for character in answer {
            let encoded: Character
            if character == " " {
                encoded = "s"
            } else {
                let base = character.isUppercase ? 65 : 97
                let value = (Int(character.asciiValue ?? 0) - base + amount) % 26 + base
                encoded = Character(UnicodeScalar(value)!)
            }
            let key = try XCTUnwrap(OriginalTypewriterKeyboard.keys.first { $0.value == encoded })
            tap(key, in: play)
        }
    }

    @MainActor
    private func tap(_ key: OriginalTypewriterKeyboard.Key, in play: OriginalPlaySession) {
        play.tapTypewriter(pageX: key.y + 1, pageY: 254 - key.x)
    }
}
