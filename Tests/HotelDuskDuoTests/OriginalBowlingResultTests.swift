import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingResultTests: XCTestCase {
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
}
