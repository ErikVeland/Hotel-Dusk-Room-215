import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalSharedConversationSessionTests: XCTestCase {
    private func session() throws -> OriginalPlaySession {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(2, previous: 1)
        try game.apply(.keywordAvailable([0, 1, 2]))
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: game,
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")),
            selection: .init(sceneID: 2, blockID: 4, modeID: 8, eventID: 28,
                nowTime: game.nowTime, mapID: 2))
        let audio = AudioController()
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableMusic(true))
        try audio.applyOriginalCommand(.disableNewEffects(true))
        return OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
    }

    func testShowingTheSuitcaseKeyReturnsToTheSameDunningQuestionMenu() throws {
        let play = try session()
        defer { play.stop() }
        let original = play.runner.phase
        guard case .questions = original else { return XCTFail("The question menu did not open") }
        for _ in 0..<2 {
            play.showItemInConversation(21)
            XCTAssertEqual(play.runner.program.name, "System")
            XCTAssertEqual(play.runner.eventIndex, 32)
            for _ in 0..<10 {
                guard case .dialogue = play.runner.phase else { break }
                play.advanceDialogue()
            }
            XCTAssertEqual(play.runner.program.name, "EP1_R102")
            XCTAssertEqual(play.runner.phase, original)
            XCTAssertTrue(try play.runner.game.inventory.items.contains(21))
        }
        play.ask(0)
        guard case .dialogue = play.runner.phase else {
            return XCTFail("The original conversation cannot continue: \(play.runner.phase)")
        }
    }

    func testSavedInputReplayRetainsTheParentConversationAcrossSharedResponses() throws {
        let original = try session(), replay = try session()
        defer { original.stop(); replay.stop() }
        let inputs: [OriginalProgressInput] = [.showItemInConversation(item: 21), .advanceDialogue]
        let decoded = try JSONDecoder().decode([OriginalProgressInput].self, from: JSONEncoder().encode(inputs))
        for input in inputs { original.applyProgressInput(input) }
        for input in decoded { replay.applyProgressInput(input) }
        XCTAssertEqual(replay.runner.phase, original.runner.phase)
        XCTAssertEqual(replay.runner.game.bytes, original.runner.game.bytes)
        XCTAssertEqual(replay.runner.program.name, "EP1_R102")
        guard case .questions = replay.runner.phase else { return XCTFail("Replay lost the question menu") }
    }
}
