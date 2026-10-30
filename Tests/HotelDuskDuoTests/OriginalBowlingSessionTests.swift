import CoreGraphics
import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingSessionTests: XCTestCase {
    @MainActor private final class SessionRenderer: OriginalBowlingRendering {
        private let image: CGImage

        init() throws {
            guard let image = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8,
                bytesPerRow: 192 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage() else {
                throw OriginalDataError.invalid("Bowling test image")
            }
            self.image = image
        }

        func render(_ state: OriginalBowlingRenderer.SceneState) throws -> CGImage { image }
    }

    func testBowlingCommentaryRequestsResolveThroughTheOriginalSystemScene() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let parent = try OriginalEventRunner(program: catalog.loadProgram("EP8_R119"),
            game: OriginalGameState.newGame(defaults: .bundled(), timestamp: 0))

        for requestID: Int16 in 2...15 {
            var response = try parent.processHint(catalog: catalog, pairA: 21, pairB: requestID)
            XCTAssertEqual(response.session.selection.modeID, 20)
            XCTAssertEqual(response.session.selection.pairA, 21)
            XCTAssertEqual(response.session.selection.pairB, requestID)
            guard case .dialogue = response.phase else {
                return XCTFail("Bowling response \(requestID) must start its recovered System dialogue")
            }
            for _ in 0..<10 {
                guard case .dialogue = response.phase else { break }
                response.acknowledgeDialogue()
            }
            XCTAssertEqual(response.phase, .exploration(mapID: parent.game.mapID))
        }
    }

    @MainActor
    func testMutedBowlingFlowWaitsForResultActionThenReachesEventEleven() throws {
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
                .appendingPathComponent(UUID().uuidString)),
            bowlingRendererFactory: { try SessionRenderer() })
        defer { play.stop() }

        XCTAssertEqual(play.bowlingImage?.width, 192)
        XCTAssertEqual(play.bowlingImage?.height, 256)
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
        let firstScoreIndex = try XCTUnwrap(OriginalBowlingResult.slot(for: 0)).scoreOffset / 4
        for _ in 0..<180 where play.bowlingMatch?.results.throwScores[firstScoreIndex] == nil {
            play.advanceFrame()
        }

        XCTAssertEqual(play.bowlingMatch?.results.throwScores[firstScoreIndex], 4)
        XCTAssertEqual(play.bowlingMatch?.phase, .betweenThrows)

        for throwIndex in 1..<OriginalBowlingResult.throwCount {
            if play.bowlingMatch?.phase == .showingResult || play.bowlingMatch?.phase == .presentingResult ||
                play.bowlingMatch?.phase == .completed { break }
            drainBowlingCommentary(in: play)
            play.advanceFrame()
            XCTAssertEqual(play.bowlingMatch?.phase, .ready)
            try playCapturedThrow(throwIndex, in: play)
            let scoreIndex = try XCTUnwrap(OriginalBowlingResult.slot(for: throwIndex)).scoreOffset / 4
            XCTAssertNotNil(play.bowlingMatch?.results.throwScores[scoreIndex])
            drainBowlingCommentary(in: play)
        }

        XCTAssertEqual(play.bowlingMatch?.phase, .showingResult)
        XCTAssertEqual(audio.soundEffectsHistory, ["SE_EVENT_BROKE_UEKIBACHI"])
        XCTAssertNil(play.bowlingMatch?.returnValue)
        for _ in 0..<OriginalBowlingMatchProcess.resultAnimationFrames { play.advanceFrame() }
        XCTAssertEqual(play.bowlingMatch?.phase, .presentingResult)
        for _ in 0..<OriginalBowlingMatchProcess.resultPresentationFrames { play.advanceFrame() }
        XCTAssertEqual(play.bowlingMatch?.phase, .completed)
        XCTAssertEqual(play.bowlingMatch?.returnValue, 2)
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
        let scoreIndex = try XCTUnwrap(OriginalBowlingResult.slot(for: throwIndex)).scoreOffset / 4
        for _ in 0..<1_000 where play.bowlingMatch?.results.throwScores[scoreIndex] == nil {
            play.advanceFrame()
        }
        drainBowlingCommentary(in: play)
    }

    @MainActor
    private func drainBowlingCommentary(in play: OriginalPlaySession) {
        for _ in 0..<40 {
            guard play.bowlingMatch?.nextCommentaryRequest != nil else { return }
            if case .process(id: 44) = play.runner.phase {
                play.advanceFrame()
            }
            switch play.runner.phase {
            case .dialogue, .itemNotice:
                play.advanceDialogue()
            default:
                XCTFail("Expected the recovered bowling commentary dialogue, found \(play.runner.phase)")
                return
            }
        }
        XCTFail("Bowling commentary did not return to the match")
    }
}
