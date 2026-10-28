import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingResultTests: XCTestCase {
    private struct TurnTrace: Decodable {
        struct State: Decodable {
            let processStage: Int16
            let processSubstage: Int16
            let bowlingState: Int16
            let throwIndex: Int16
            let scores: [Int32]
            let roundStatuses: [Int16]
        }
        let states: [String: State]
    }

    func testThrowSlotsInterleaveTwoPlayersAcrossThreeRounds() {
        let slots = (0..<OriginalBowlingResult.throwCount).compactMap(OriginalBowlingResult.slot(for:))

        XCTAssertEqual(slots.map(\.player), [0, 1, 0, 1, 0, 1])
        XCTAssertEqual(slots.map(\.round), [0, 0, 1, 1, 2, 2])
        XCTAssertEqual(slots.map(\.scoreOffset), [0, 12, 4, 16, 8, 20])
        XCTAssertNil(OriginalBowlingResult.slot(for: -1))
        XCTAssertNil(OriginalBowlingResult.slot(for: OriginalBowlingResult.throwCount))
    }

    func testRecordingResultsFollowsTheSourceTurnOrder() {
        var result = OriginalBowlingResult()

        XCTAssertEqual(result.nextThrow, 0)
        for score in 0..<OriginalBowlingResult.throwCount {
            XCTAssertEqual(result.record(Int32(score))?.scoreOffset, [0, 12, 4, 16, 8, 20][score])
        }

        XCTAssertNil(result.nextThrow)
        XCTAssertNil(result.record(10))
        XCTAssertEqual(result.throwScores, [0, 1, 2, 3, 4, 5])
    }

    func testOnlyPinCountsFromZeroThroughTenCanBeRecorded() {
        var result = OriginalBowlingResult()

        XCTAssertNil(result.record(-1))
        XCTAssertNil(result.record(11))
        XCTAssertEqual(result.nextThrow, 0)
        XCTAssertNotNil(result.record(OriginalBowlingResult.maximumScore))
        XCTAssertEqual(result.throwScores[0], 10)
    }

    func testFinalSourceCheckRequiresThreePlayerZeroScoresAndFewerThanTwoStatusTwos() {
        XCTAssertFalse(OriginalBowlingResult.shouldFinish(
            playerZeroScores: [-1, 8, 7], roundStatuses: [0, 0, 0]))
        XCTAssertTrue(OriginalBowlingResult.shouldFinish(
            playerZeroScores: [8, 7, 9], roundStatuses: [2, 1, 0]))
        XCTAssertFalse(OriginalBowlingResult.shouldFinish(
            playerZeroScores: [8, 7, 9], roundStatuses: [2, 2, 0]))
    }

    func testRoundStatusesCompareTheTwoScoresInEachRound() {
        var result = OriginalBowlingResult()
        [9, 4, 3, 8, 6, 6].forEach { _ = result.record(Int32($0)) }

        XCTAssertEqual(result.roundStatuses, [1, 2, 3])
        XCTAssertTrue(result.shouldFinish)
    }

    func testRoundStatusAndCompletionWaitForBothScoresAndRejectTwoPlayerOneWins() {
        var incomplete = OriginalBowlingResult()
        _ = incomplete.record(9)
        _ = incomplete.record(4)
        XCTAssertEqual(incomplete.roundStatuses, [1, nil, nil])
        XCTAssertFalse(incomplete.shouldFinish)

        var result = OriginalBowlingResult()
        [4, 9, 3, 8, 6, 6].forEach { _ = result.record(Int32($0)) }
        XCTAssertEqual(result.roundStatuses, [2, 2, 3])
        XCTAssertFalse(result.shouldFinish)
    }

    func testSourceCanFinishAfterPlayerZeroRecordsTheirThirdScore() {
        var result = OriginalBowlingResult()
        [6, 5, 6, 5, 6].forEach { _ = result.record(Int32($0)) }

        XCTAssertEqual(result.nextThrow, 5)
        XCTAssertEqual(result.roundStatuses, [1, 1, nil])
        XCTAssertTrue(result.shouldFinish)
    }

    func testSourceContinuesAfterPlayerZeroLosesTwoRounds() {
        var result = OriginalBowlingResult()
        [5, 6, 5, 6, 6].forEach { _ = result.record(Int32($0)) }

        XCTAssertEqual(result.roundStatuses, [2, 2, nil])
        XCTAssertFalse(result.shouldFinish)
    }

    func testEarlyFinishMatchesTheOriginalFifthThrowCapture() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(TurnTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/turn-phase-probe.json")))
        let source = try XCTUnwrap(trace.states["after-throw-5"])
        let finish = try XCTUnwrap(trace.states["completed-process-stage"])
        let reset = try XCTUnwrap(trace.states["after-result-phase"])

        XCTAssertEqual(source.bowlingState, 10)
        XCTAssertEqual(source.throwIndex, 5)
        XCTAssertEqual(source.scores, [6, 6, 6, 5, 5, -1])
        XCTAssertEqual(source.roundStatuses, [1, 1, 0])
        XCTAssertEqual(finish.processStage, 3)
        XCTAssertEqual(finish.processSubstage, 1)
        XCTAssertEqual(reset.processStage, 1)
        XCTAssertEqual(reset.throwIndex, 0)
        XCTAssertEqual(reset.scores, Array(repeating: -1, count: OriginalBowlingResult.throwCount))

        var result = OriginalBowlingResult()
        [6, 5, 6, 5, 6].forEach { _ = result.record(Int32($0)) }
        XCTAssertEqual(result.roundStatuses.map { $0 ?? 0 }, source.roundStatuses)
        XCTAssertTrue(result.shouldFinish)
    }

    func testResultModelMatchesTwoInterleavedThrowsFromTheOriginalProcess() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(TurnTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/turn-phase-probe.json")))
        let firstThrow = try XCTUnwrap(trace.states["dialogue-advance-03"])
        let secondThrow = try XCTUnwrap(trace.states["second-dialogue-advance-03"])

        XCTAssertEqual(firstThrow.throwIndex, 1)
        XCTAssertEqual(firstThrow.scores, [6, -1, -1, -1, -1, -1])
        XCTAssertEqual(secondThrow.throwIndex, 2)
        XCTAssertEqual(secondThrow.scores, [6, -1, -1, 5, -1, -1])
        XCTAssertEqual(secondThrow.roundStatuses, [1, 0, 0])

        var result = OriginalBowlingResult()
        XCTAssertEqual(result.record(6)?.scoreOffset, 0)
        XCTAssertEqual(result.record(5)?.scoreOffset, 12)
        XCTAssertEqual(result.roundStatuses, [1, nil, nil])
        XCTAssertEqual(result.roundStatuses[0], secondThrow.roundStatuses[0])
    }
}
