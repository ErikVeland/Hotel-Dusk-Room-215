import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingMatchProcessTests: XCTestCase {
    private struct DragUpdateTrace: Decodable {
        struct Sample: Decodable { let touchPointFixed20_12: [Int32] }
        let initialPositionTargetFixed20_12: [Int32]
        let samples: [Sample]
    }

    func testThrowsAlternateAndEarlyFinishUsesTheRecoveredCondition() throws {
        let trace = try dragUpdateTrace()
        var match = OriginalBowlingMatchProcess()
        var commentary: [Int16] = []

        XCTAssertFalse(match.beginDrag(at: Self.vector(trace.initialPositionTargetFixed20_12), ballWasHit: false))

        for index in 0..<5 {
            try playCapturedThrow(trace, in: &match)
            XCTAssertEqual(match.results.nextThrow, index + 1)
            while let request = match.nextCommentaryRequest {
                commentary.append(request)
                XCTAssertTrue(match.finishCommentaryResponse())
            }
            if index < 4 { XCTAssertTrue(match.beginNextThrow()) }
        }

        XCTAssertEqual(match.results.throwScores.compactMap { $0 }, [4, 4, 4, 4, 4])
        XCTAssertEqual(commentary, [2, 4, 5, 9, 2, 4, 5, 12, 2, 4])
        XCTAssertEqual(match.phase, .showingResult)
        XCTAssertNil(match.returnValue)
        completeResultPresentation(&match)
        XCTAssertEqual(match.phase, .completed)
        XCTAssertEqual(match.returnValue, 2)
    }

    func testResultModelRecognisesACompletedLossWithoutEarlyFinish() throws {
        var result = OriginalBowlingResult()
        for score: Int32 in [2, 10, 2, 10, 2, 10] { XCTAssertNotNil(result.record(score)) }
        XCTAssertFalse(result.shouldFinish)
        XCTAssertNil(result.nextThrow)
    }

    func testThrowSpeedSelectsTheRecoveredRouteResultRanges() {
        XCTAssertEqual(OriginalBowlingLaunch.routeResult(for: -409), 0)
        XCTAssertEqual(OriginalBowlingLaunch.routeResult(for: -410), 1)
        XCTAssertEqual(OriginalBowlingLaunch.routeResult(for: -614), 1)
        XCTAssertEqual(OriginalBowlingLaunch.routeResult(for: -615), 2)
    }

    func testSixthThrowCompletesAfterPlayerZeroLosesTwoRounds() throws {
        let trace = try dragUpdateTrace()
        var results = OriginalBowlingResult()
        for score: Int32 in [4, 5, 4, 5, 4] { XCTAssertNotNil(results.record(score)) }
        XCTAssertFalse(results.shouldFinish)

        var match = OriginalBowlingMatchProcess(results: results)
        try playCapturedThrow(trace, in: &match)

        XCTAssertEqual(match.phase, .presentingResult)
        XCTAssertEqual(match.results.roundStatuses, [2, 2, 3])
        XCTAssertNil(match.results.nextThrow)
        XCTAssertEqual(match.nextCommentaryRequest, 5)
        XCTAssertTrue(match.finishCommentaryResponse())
        XCTAssertEqual(match.nextCommentaryRequest, 15)
        drainCommentary(&match)
        completeResultPresentation(&match)
        XCTAssertEqual(match.returnValue, 2)
    }

    func testThrowRecordsOnceAndWaitsForTheResultPresentationBeforeReset() throws {
        let trace = try dragUpdateTrace()
        var match = OriginalBowlingMatchProcess()

        try playCapturedThrow(trace, in: &match)
        XCTAssertEqual(match.phase, .betweenThrows)
        XCTAssertEqual(match.results.throwScores[0], 4)
        XCTAssertEqual(match.nextCommentaryRequest, 2)
        XCTAssertNil(match.results.throwScores[1])
        XCTAssertFalse(match.beginDrag(at: Self.vector(trace.initialPositionTargetFixed20_12), ballWasHit: true))

        for _ in 0..<10 { match.advanceOneUpdate() }

        XCTAssertEqual(match.results.throwScores[0], 4)
        XCTAssertFalse(match.beginNextThrow())
        XCTAssertTrue(match.finishCommentaryResponse())
        XCTAssertEqual(match.nextCommentaryRequest, 4)
        XCTAssertFalse(match.beginNextThrow())
        XCTAssertTrue(match.finishCommentaryResponse())
        XCTAssertNil(match.nextCommentaryRequest)
        XCTAssertTrue(match.beginNextThrow())
        XCTAssertEqual(match.phase, .ready)
        XCTAssertEqual(match.throwIndex, 1)
        XCTAssertEqual(match.turn.simulation.ballMotion.state.positionFixed20_12,
                       OriginalBowlingMatchProcess.initialBallPositionFixed20_12)
    }

    private func dragUpdateTrace() throws -> DragUpdateTrace {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(DragUpdateTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/drag-update-probe.json")))
    }

    private func playCapturedThrow(_ trace: DragUpdateTrace,
                                   in match: inout OriginalBowlingMatchProcess) throws {
        XCTAssertTrue(match.beginDrag(at: Self.vector(trace.initialPositionTargetFixed20_12), ballWasHit: true))
        for sample in trace.samples {
            match.updateDrag(to: Self.vector(sample.touchPointFixed20_12))
        }
        XCTAssertEqual(match.phase, .rolling)
        XCTAssertEqual(match.turn.ballPositionFixed20_12, SIMD3(-712, 1_556, 3_088),
                       "The captured touch path should reach the ROM auto-launch position")
        XCTAssertEqual(match.turn.simulation.ballMotion.state.velocityFixed20_12,
                       SIMD3(-71, 0, -819),
                       "The captured touch path should produce the ROM launch velocity")
        XCTAssertEqual(match.turn.routeResult, 2,
                       "The captured launch speed should select the source repeat result")
        for _ in 0..<5_000 where match.phase == .rolling { match.advanceOneUpdate() }
        XCTAssertTrue([.betweenThrows, .showingResult, .presentingResult, .completed].contains(match.phase))
    }

    private func completeResultPresentation(_ match: inout OriginalBowlingMatchProcess) {
        if match.phase == .showingResult {
            XCTAssertEqual(match.presentationFramesRemaining, OriginalBowlingMatchProcess.resultAnimationFrames)
            for _ in 0..<OriginalBowlingMatchProcess.resultAnimationFrames {
                match.advanceOneUpdate()
            }
            XCTAssertEqual(match.phase, .presentingResult)
        }
        XCTAssertEqual(match.presentationFramesRemaining, OriginalBowlingMatchProcess.resultPresentationFrames)
        for _ in 0..<(OriginalBowlingMatchProcess.resultPresentationFrames - 1) {
            match.advanceOneUpdate()
        }
        XCTAssertEqual(match.phase, .presentingResult)
        XCTAssertNil(match.returnValue)
        match.advanceOneUpdate()
        XCTAssertEqual(match.phase, .completed)
    }

    private func drainCommentary(_ match: inout OriginalBowlingMatchProcess) {
        while match.finishCommentaryResponse() {}
    }

    private static func vector(_ values: [Int32]) -> SIMD3<Int32> {
        SIMD3(values[0], values[1], values[2])
    }
}
