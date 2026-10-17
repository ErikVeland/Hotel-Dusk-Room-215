import XCTest
@testable import HotelDuskDuoKit

/**
 * Follows the guide's Nile conversation after leaving Dunning's office.
 */
@MainActor
enum OriginalNileRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in }) throws {
        play.holdLobbyTouch(x: 60, y: 70)
        for _ in 0..<43 { play.advanceFrame() }
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<40 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 4)
        play.talkToNearbyPerson()
        drain(play)
        try compare(play.runner.game, "chapter-two-louie-office-talk/page15")
        let beforePause = play.runner.game.bytes
        let pausedPhase = play.runner.phase
        play.pause()
        play.choose(22)
        play.advanceDialogue()
        play.advanceFrame()
        XCTAssertEqual(play.runner.game.bytes, beforePause)
        XCTAssertEqual(play.runner.phase, pausedPhase)
        play.resume()
        try choose("You know...work.", in: play)
        try compare(play.runner.game, "chapter-two-louie-work/page21")
        try choose("Nah, it wasn't about you.", in: play)
        try compare(play.runner.game, "chapter-two-louie-reassure/page23")
        try choose("I guess I can trust him...", in: play)
        try compare(play.runner.game, "chapter-two-louie-nile-interrupt/page4")
        try choose("Knew about that, huh?", in: play)
        try compare(play.runner.game, "chapter-two-louie-sense-interrupt/page4")
        try choose("What makes sense now?", in: play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
        try compare(play.runner.game, "chapter-two-louie-sense-answer/page35")
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 3)
        play.talkToNearbyPerson()
        drain(play)
        try compare(play.runner.game, "chapter-two-rosa-office-interrupt/page3")
        try choose("What's wrong?", in: play)
        try compare(play.runner.game, "chapter-two-rosa-whats-wrong/page13")
        try choose("Yeah, I know him.", in: play)
        try compare(play.runner.game, "chapter-two-rosa-past-choice/page5")
        try choose("Don't tell her anything.", in: play)
        try compare(play.runner.game, "chapter-two-rosa-shifty-interrupt/page3")
        try choose("You think he's shifty?", in: play)
        guard case .questions(let topics) = play.runner.phase else {
            return XCTFail("Expected Rosa's question menu: \(play.runner.phase)")
        }
        XCTAssertEqual(topics.map(\.keyword), [11, 12])
        try compare(play.runner.game, "chapter-two-rosa-pizza-return/page19")
        play.ask(11)
        drain(play)
        try compare(play.runner.game, "chapter-two-rosa-jenny/page11")
        play.ask(12)
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
        try compare(play.runner.game, "chapter-two-rosa-pager/page19")
        try OriginalEdCallRouteChecks.run(play, compare: compare)
    }

    private static func choose(_ label: String, in play: OriginalPlaySession) throws {
        guard case .choice(let choices) = play.runner.phase else {
            return XCTFail("Expected \(label): \(play.runner.phase)")
        }
        let answer = try XCTUnwrap(choices.first { $0.label == label }, "Choices: \(choices)")
        play.choose(answer.id)
        drain(play)
    }

    private static func drain(_ play: OriginalPlaySession) {
        for _ in 0..<400 {
            switch play.runner.phase {
            case .dialogue where play.runner.interruptAvailable: play.interrupt()
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return
            }
        }
        XCTFail("The Nile conversation did not finish")
    }
}
