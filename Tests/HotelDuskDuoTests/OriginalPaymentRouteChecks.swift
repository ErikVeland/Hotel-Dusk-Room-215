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
        walk(play, x: 96, y: 45, frames: 125)
        walk(play, x: 20, y: 128, frames: 28)
        walk(play, x: 96, y: 45, frames: 30)
        XCTAssertEqual(play.nearbyDoor, 39)
        play.inspectNearbyDoor()
        drain(play)
        guard play.lobby?.mapID == 39 else { return XCTFail("Room exit: \(play.runner.phase), \(String(describing: play.lobby?.position))") }
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<400 {
            if (play.lobby?.position.x ?? 0) >= 20700 { break }
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<160 {
            if play.lobby?.mapID != 39 { break }
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        guard play.lobby?.mapID == 17 else { return XCTFail("Stairs: \(play.runner.phase)") }
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<120 {
            if (play.lobby?.position.z ?? 0) >= 4500 { break }
            play.advanceFrame()
        }
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<160 {
            if play.lobby?.mapID != 17 { break }
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        guard play.lobby?.mapID == 3 else { return XCTFail("Lobby: \(play.runner.phase)") }
        walk(play, x: 170, y: 128, frames: 135)
        walk(play, x: 96, y: 210, frames: 69)
        walk(play, x: 170, y: 128, frames: 25)
        XCTAssertEqual(play.nearbyDoor, 15)
        play.inspectNearbyDoor()
        drain(play)
        XCTAssertEqual(play.door?.destination, 15)
        play.selectDoorComponent(x: 96, y: 160)
        play.confirmDoorComponent()
        for _ in 0..<300 {
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
        play.inspectNearbyDoor()
        drain(play)
        play.selectDoorComponent(x: 32, y: 175)
        play.confirmDoorComponent()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 15))
        XCTAssertEqual(play.lobby?.mapID, 15)
        try compare(play.runner.game, "chapter-two-office-arrival/room")
        try OriginalOfficeRouteChecks.run(play, compare: compare, captureImage: captureImage)
    }

    private static func walk(_ play: OriginalPlaySession, x: Float, y: Float, frames: Int) {
        play.holdLobbyTouch(x: x, y: y)
        for _ in 0..<frames { play.advanceFrame() }
        play.releaseLobbyTouch()
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
