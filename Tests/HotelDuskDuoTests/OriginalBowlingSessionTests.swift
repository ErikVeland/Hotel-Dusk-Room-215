import Metal
import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingSessionTests: XCTestCase {
    @MainActor
    func testBowlingInputReturnsItsRecoveredSuccessResultToEventEleven() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is unavailable in this test environment.")
        }
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP8_R119")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            try OriginalEventCompletion.embeddedProcessID(event: $0) == 44
        })
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        var selection = OriginalEventSelectionContext(
            sceneID: .max, blockID: 0, modeID: 15,
            eventID: try OriginalBytes(event.raw).u16(4), nowTime: game.nowTime, mapID: game.mapID)
        selection.debugEventSelection = true
        let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
        XCTAssertEqual(runner.phase, .process(id: 44))

        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }

        XCTAssertEqual(play.bowlingImage?.width, 192)
        XCTAssertEqual(play.bowlingImage?.height, 256)
        XCTAssertEqual(play.bowlingMatch?.phase, .ready)
        play.advanceFrame()
        XCTAssertEqual(play.bowlingMatch?.phase, .ready)

        try holdRawTouch(SIMD2(15, 90), for: 1, in: play)
        XCTAssertEqual(play.bowlingMatch?.phase, .ready)
        for _ in 0..<7 { play.advanceFrame() }
        try holdRawTouch(SIMD2(23, 90), for: 8, in: play)
        guard play.bowlingMatch?.phase == .dragging else {
            XCTFail("The captured movement must start the bowling drag.")
            return
        }
        for rawX in stride(from: 31, through: 119, by: 8) {
            try holdRawTouch(SIMD2(rawX, 90), for: 8, in: play)
        }
        try holdRawTouch(SIMD2(125, 90), for: 8, in: play)
        play.releaseBowlingTouch()
        XCTAssertEqual(play.bowlingMatch?.phase, .rolling,
                       "The captured drag should launch from \(String(describing: play.bowlingMatch?.turn.ballPositionFixed20_12))")
        for _ in 0..<180 where play.bowlingMatch?.results.throwScores[0] == nil {
            play.advanceFrame()
        }

        XCTAssertEqual(play.bowlingMatch?.results.throwScores[0], 4)
        XCTAssertEqual(play.bowlingMatch?.phase, .betweenThrows)

        for throwIndex in 1..<OriginalBowlingResult.throwCount {
            if play.bowlingMatch?.phase == .completed { break }
            play.advanceFrame()
            XCTAssertEqual(play.bowlingMatch?.phase, .ready)
            try playCapturedThrow(throwIndex, in: play)
            XCTAssertNotNil(play.bowlingMatch?.results.throwScores[throwIndex])
        }

        XCTAssertEqual(play.bowlingMatch?.phase, .completed)
        play.advanceFrame()
        XCTAssertNil(play.bowlingMatch)
        XCTAssertNotEqual(play.runner.phase, .process(id: 44))
        XCTAssertEqual(play.runner.session.selection.eventID, 11)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
    }

    @MainActor
    private func holdRawTouch(_ rawPoint: SIMD2<Int>, for frames: Int,
                              in play: OriginalPlaySession) throws {
        let pagePoint = try XCTUnwrap(OriginalBowlingTouchRay.pagePoint(
            touchPoint: rawPoint, orientation: .unrotated))
        for _ in 0..<frames {
            play.holdBowlingTouch(pageX: pagePoint.x, pageY: pagePoint.y)
            play.advanceFrame()
        }
    }

    @MainActor
    private func playCapturedThrow(_ throwIndex: Int, in play: OriginalPlaySession) throws {
        try holdRawTouch(SIMD2(15, 90), for: 1, in: play)
        XCTAssertEqual(play.bowlingMatch?.phase, .ready)
        for _ in 0..<7 { play.advanceFrame() }
        try holdRawTouch(SIMD2(23, 90), for: 8, in: play)
        guard play.bowlingMatch?.phase == .dragging else {
            XCTFail("The captured movement must start the bowling drag.")
            return
        }
        for rawX in stride(from: 31, through: 119, by: 8) {
            try holdRawTouch(SIMD2(rawX, 90), for: 8, in: play)
        }
        try holdRawTouch(SIMD2(125, 90), for: 8, in: play)
        play.releaseBowlingTouch()
        XCTAssertEqual(play.bowlingMatch?.phase, .rolling)
        for _ in 0..<1_000 where play.bowlingMatch?.results.throwScores[throwIndex] == nil {
            play.advanceFrame()
        }
    }
}
