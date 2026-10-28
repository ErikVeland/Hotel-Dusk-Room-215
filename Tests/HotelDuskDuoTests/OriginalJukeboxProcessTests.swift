import XCTest
@testable import HotelDuskDuoKit

@MainActor
private final class JukeboxMusicOutput: OriginalMusicOutput {
    var outputVolume: Float = 0
    var isActive = true
    var position: TimeInterval = 0
    func seek(to seconds: TimeInterval) throws { position = seconds }
    func resume() throws { isActive = true }
    func pause() { isActive = false }
    func stop() { isActive = false }
}

final class OriginalJukeboxProcessTests: XCTestCase {
    func testBundledRecordTitlesLoadForTheNativeProcess() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let data = try library.loadNotebookData(path: "trick/jukebox/JK_USA.txt")
        let titles = try OriginalJukeboxProcess.titles(from: data)

        XCTAssertEqual(titles.count, 36)
        XCTAssertTrue(titles.allSatisfy { !$0.isEmpty })
    }

    @MainActor
    func testChapterSixProcess58StartsJukeboxAndReturnsThroughItsStoryEvent() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP6_R105")
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(5)
        game.setMap(5, previous: 17)
        let event = try XCTUnwrap(program.blocks.tables[2].first { $0.sourceOffset == 1696 })
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15, eventID: UInt16(event.index),
            nowTime: game.nowTime, mapID: 5)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 58))

        let output = JukeboxMusicOutput()
        let audio = AudioController(musicOutputFactory: { _, _, _ in output })
        audio.isMuted = true
        _ = try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }

        XCTAssertEqual(play.jukebox?.titles.count, 36)
        play.selectJukeboxRecord(24)
        XCTAssertEqual(play.runner.game.jukeboxSequence, 24)
        play.quitJukebox()

        XCTAssertNil(play.jukebox)
        XCTAssertNotEqual(play.runner.phase, .process(id: 58))
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }
}
