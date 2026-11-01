import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

/**
 * Follows the walkthrough route from the stored client list to Dunning's office door.
 */
@MainActor
enum OriginalPaymentRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in },
                    captureImage: (CGImage?, String) throws -> Void = { _, _ in }) throws {
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        try OriginalChapterThreeRouteChecks.exit(play, to: 39)
        try OriginalChapterThreeRouteChecks.exit(play, to: 17)
        try OriginalChapterThreeRouteChecks.exit(play, to: 3)
        try OriginalChapterThreeRouteChecks.exit(play, to: 15, expectArrival: false)
        XCTAssertEqual(play.door?.destination, 15)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        for _ in 0..<300 {
            if case .choice = play.runner.phase { break }
            if play.runner.interruptAvailable { play.interrupt(); break }
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return XCTFail("Expected Dunning's apology: \(play.runner.phase)")
            }
        }
        drain(play)
        guard case .choice(let choices) = play.runner.phase else {
            return XCTFail("Expected Dunning's apology choices: \(play.runner.phase)")
        }
        XCTAssertEqual(choices.map(\.id), [20, 21])
        try compare(play.runner.game, "chapter-two-payment-apology-ready/choice")
        play.choose(21)
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(23))
        XCTAssertNil(play.door)
        XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 4)), false)
        try compare(play.runner.game, "chapter-two-payment-paid-follow/returned")
        try OriginalChapterThreeRouteChecks.exit(play, to: 15, expectArrival: false)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 2, interrupt: true)
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 15))
        XCTAssertEqual(play.lobby?.mapID, 15)
        try compare(play.runner.game, "chapter-two-office-arrival/room")
        try OriginalOfficeRouteChecks.run(play, compare: compare, captureImage: captureImage)
    }

    private static func drain(_ play: OriginalPlaySession) {
        for _ in 0..<300 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return
            }
        }
        XCTFail("Dunning's response did not finish")
    }
}
