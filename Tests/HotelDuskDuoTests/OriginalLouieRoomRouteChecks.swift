import XCTest
@testable import HotelDuskDuoKit

/**
 * Follows the spoiler-free guide directly from the Left Hallway to Louie's room.
 */
@MainActor
enum OriginalLouieRoomRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in }) throws {
        walk(play, x: 20, y: 128, frames: 100)
        walk(play, x: 96, y: 45, frames: 187)
        walk(play, x: 20, y: 128, frames: 10)
        XCTAssertEqual(play.nearbyDoor, 14, "\(String(describing: play.lobby?.position))")
        play.inspectNearbyDoor()
        drain(play)
        XCTAssertEqual(play.door?.destination, 14)
        try compare(play.runner.game, "chapter-two-louie-room-door/door")
        play.selectDoorComponent(x: 96, y: 160)
        play.confirmDoorComponent()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 14))
        try compare(play.runner.game, "chapter-two-louie-room-enter/page23")
        XCTAssertFalse(play.runner.game.keywordAvailable(13))
        walk(play, x: 20, y: 128, frames: 10)
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 4)
        play.talkToNearbyPerson()
        drain(play)
        guard case .choice(let choices) = play.runner.phase else {
            return XCTFail("Expected Louie's first choice: \(play.runner.phase)")
        }
        XCTAssertTrue(choices.contains { $0.label == "Oh, you'll talk to me." })
    }

    private static func walk(_ play: OriginalPlaySession, x: Float, y: Float, frames: Int) {
        play.holdLobbyTouch(x: x, y: y)
        for _ in 0..<frames { play.advanceFrame() }
        play.releaseLobbyTouch()
    }

    private static func drain(_ play: OriginalPlaySession) {
        for _ in 0..<600 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return
            }
        }
        XCTFail("Louie's conversation did not finish")
    }
}
