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
        // The normal component hit runs the knock and door transition in one action.
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 14))
        XCTAssertEqual(play.runner.program.name, "EP2_R114")
        try compare(play.runner.game, "chapter-two-louie-room-knock/page23")
        XCTAssertFalse(play.runner.game.keywordAvailable(13))
        walk(play, x: 20, y: 128, frames: 10)
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 4)
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] {
            try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("louie"))
                .save(play.walkingCheckpoint())
        }
        try finishConversation(play)
    }

    static func finishConversation(_ play: OriginalPlaySession) throws {
        play.talkToNearbyPerson()
        drain(play, takeInterrupt: true)
        guard case .choice(let choices) = play.runner.phase else {
            return XCTFail("Expected Louie's first choice: \(play.runner.phase)")
        }
        XCTAssertTrue(choices.contains { $0.label == "Oh, you'll talk to me." })
        try choose(play, "Oh, you'll talk to me.", interrupt: true)
        try choose(play, "That's what LAPD says.", interrupt: true)
        try choose(play, "Did you take the money?")
        for keyword: Int16 in [15, 14, 17, 18, 19, 16, 20] {
            guard case .questions(let topics) = play.runner.phase,
                  topics.contains(where: { $0.keyword == keyword }) else {
                throw OriginalDataError.invalid("Louie topic \(keyword): \(play.runner.phase)")
            }
            play.ask(keyword)
            drain(play, takeInterrupt: true)
            if case .choice = play.runner.phase {
                try choose(play, keyword == 16 ? "'Cause Danny got killed." : "I don't think it was you.")
            }
        }
        XCTAssertEqual(play.runner.phase, .picture(id: 23))
        XCTAssertEqual(play.touchPicture?.contains(pageX: 55, pageY: 181), true)
        play.activatePicture(pageX: 55, pageY: 181)
        for _ in 0..<24 { play.advanceFrame() }
        drain(play)
        XCTAssertEqual(play.runner.game.mapID, 19, "Louie's ending must follow the scripted map request")
        try choose(play, "Iris")
        XCTAssertEqual(play.runner.reviewQuestionIndex, 0, "A wrong review answer must retry the question")
        for answer in ["Mila", "Ten years ago", "A small red box", "Nile was after him", "Danny"] {
            try choose(play, answer)
        }
        XCTAssertTrue(play.chapterTransition?.stage == .prompt || play.chapterTransition?.stage == .title)
        XCTAssertEqual(play.runner.game.chapter, 2)
        if play.chapterTransition?.stage == .prompt { play.answerChapterSave(false) }
        XCTAssertEqual(play.chapterTransition?.stage, .title)
        play.continueChapterTitle()
        drain(play)
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] {
            try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter3-entry")).save(play.walkingCheckpoint())
        }
    }

    private static func choose(_ play: OriginalPlaySession, _ label: String, interrupt: Bool = false) throws {
        guard case .choice(let choices) = play.runner.phase,
              let choice = choices.first(where: { $0.label == label }) else {
            throw OriginalDataError.invalid("Missing choice \(label): \(play.runner.phase)")
        }
        play.choose(choice.id)
        drain(play, takeInterrupt: interrupt)
    }

    private static func walk(_ play: OriginalPlaySession, x: Float, y: Float, frames: Int) {
        play.holdLobbyTouch(x: x, y: y)
        for _ in 0..<frames { play.advanceFrame() }
        play.releaseLobbyTouch()
    }

    private static func drain(_ play: OriginalPlaySession, takeInterrupt: Bool = false) {
        var interrupted = false
        for _ in 0..<600 {
            if takeInterrupt && !interrupted && play.runner.interruptAvailable {
                play.interrupt()
                interrupted = true
                continue
            }
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return
            }
        }
        XCTFail("Louie's conversation did not finish")
    }
}
