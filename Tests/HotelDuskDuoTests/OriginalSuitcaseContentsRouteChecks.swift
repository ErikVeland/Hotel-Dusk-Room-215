import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

/**
 * Takes the cash through native compartment selection, pencil dragging and dialogue input.
 */
@MainActor
enum OriginalSuitcaseContentsRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in },
                    captureImage: (CGImage?, String) throws -> Void = { _, _ in }) throws {
        for _ in 0..<70 { play.advanceFrame() }
        XCTAssertEqual(play.suitcaseContents?.phase, 1)
        XCTAssertEqual(play.suitcaseContents?.stage, 3)
        try captureImage(play.suitcaseContentsImage, "suitcase_overview")
        play.pause()
        let paused = play.suitcaseContents
        play.holdSuitcaseContentsTouch(x: 96, y: 160)
        play.leaveSuitcaseContents()
        for _ in 0..<10 { play.advanceFrame() }
        XCTAssertEqual(play.suitcaseContents, paused)
        play.resume()
        play.holdSuitcaseContentsTouch(x: 96, y: 160)
        play.advanceFrame()
        play.releaseSuitcaseContentsTouch()
        for _ in 0..<160 { play.advanceFrame() }
        XCTAssertEqual(play.suitcaseContents?.phase, 3)
        XCTAssertEqual(play.suitcaseContents?.stage, 1)
        try compare(play.runner.game, "chapter-two-suitcase-open/lower")
        try captureImage(play.suitcaseContentsImage, "suitcase_lower")
        play.holdSuitcaseContentsTouch(x: 40, y: 232)
        play.advanceFrame()
        play.holdSuitcaseContentsTouch(x: 140, y: 232)
        for _ in 0..<31 { play.advanceFrame() }
        play.releaseSuitcaseContentsTouch()
        play.advanceFrame()
        XCTAssertEqual(play.suitcaseContents?.contents.lowerPositions[5].x, 100.98660278320312)
        try captureImage(play.suitcaseContentsImage, "suitcase_pencil_moved")
        for _ in 0..<2 {
            play.holdSuitcaseContentsTouch(x: 20, y: 235)
            play.advanceFrame()
            play.releaseSuitcaseContentsTouch()
            play.advanceFrame()
        }
        var capturedItem = false
        for _ in 0..<300 {
            if !capturedItem, play.suitcaseContents?.awaitingResponse == true {
                try captureImage(play.suitcaseContentsImage, "suitcase_cash")
                capturedItem = true
            }
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .process(35), .waiting: play.advanceFrame()
            default: break
            }
        }
        XCTAssertTrue(capturedItem)
        XCTAssertEqual(play.suitcaseContents?.stage, 1)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(23))
        try compare(play.runner.game, "chapter-two-suitcase-cash/cash_advance2")
        try captureImage(play.suitcaseContentsImage, "suitcase_cash_taken")
        play.leaveSuitcaseContents()
        for _ in 0..<150 { play.advanceFrame() }
        XCTAssertEqual(play.suitcaseContents?.phase, 1)
        play.leaveSuitcaseContents()
        for _ in 0..<250 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            default: play.advanceFrame()
            }
        }
        XCTAssertNil(play.suitcaseContents)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try compare(play.runner.game, "chapter-two-suitcase-exit/returned")
        play.useItemInSearchView(49)
        play.selectLobbyObject(x: 130, y: 155)
        play.confirmLobbyObject()
        for _ in 0..<100 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: break
            }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertFalse(try play.runner.game.inventory.items.contains(49))
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 51)), true)
        try compare(play.runner.game, "chapter-two-suitcase-store/page5")
        try OriginalPaymentRouteChecks.run(play, compare: compare, captureImage: captureImage)
    }
}
