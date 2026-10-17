import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

/**
 * Shared ordinary-input route used by the checkpoint comparison and new-game layout check.
 */
@MainActor
enum OriginalLinensRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in },
                    captureImage: (CGImage?, String) throws -> Void = { _, _ in }) throws {
        func advance(_ play: OriginalPlaySession) {
            for _ in 0..<200 {
                switch play.runner.phase {
                case .dialogue, .itemNotice: play.advanceDialogue()
                case .waiting: play.advanceFrame()
                default: return
                }
            }
            XCTFail("The conversation did not finish")
        }
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<30 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 4)
        play.talkToNearbyPerson()
        advance(play)
        guard case .choice(let opening) = play.runner.phase else { return XCTFail("Expected Louie's opening choices: \(play.runner.phase)") }
        XCTAssertEqual(opening.map(\.id), [8, 9])
        try compare(play.runner.game, "chapter-two-louie-choice/page6")
        play.choose(8)
        var louieInterrupts: Set<UInt16> = []
        for _ in 0..<300 {
            switch play.runner.phase {
            case .dialogue where play.runner.interruptAvailable && !louieInterrupts.contains(play.runner.interrupt.event):
                louieInterrupts.insert(play.runner.interrupt.event)
                play.interrupt()
            case .dialogue: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            case .choice(let choices):
                XCTAssertEqual(choices.map(\.id), [10, 11])
                try compare(play.runner.game, "chapter-two-louie-cleaning/choice")
                play.choose(10)
            case .questions(let topics):
                XCTAssertEqual(topics.map(\.keyword), [2, 3])
                break
            default: return XCTFail("Louie's opening stopped: \(play.runner.phase)")
            }
            if case .questions = play.runner.phase { break }
        }
        XCTAssertEqual(louieInterrupts, [5])
        try compare(play.runner.game, "chapter-two-louie-cleaning/page110")
        var louieQuestions: [Int16] = []
        var louieAnswers: [UInt16] = []
        for _ in 0..<700 {
            switch play.runner.phase {
            case .dialogue where play.runner.interruptAvailable && !louieInterrupts.contains(play.runner.interrupt.event):
                louieInterrupts.insert(play.runner.interrupt.event)
                play.interrupt()
            case .dialogue: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            case .questions(let topics):
                if louieQuestions.last == 3 { try compare(play.runner.game, "chapter-two-louie-stories/page60") }
                if louieQuestions.last == 4 { try compare(play.runner.game, "chapter-two-louie-incident/when") }
                if louieQuestions.last == 5 { try compare(play.runner.game, "chapter-two-louie-incident/incident") }
                if louieQuestions.last == 6 { try compare(play.runner.game, "chapter-two-louie-incident/girl") }
                guard let topic = [Int16(3), 4, 5, 6, 7, 8, 2].compactMap({ id in topics.first { $0.keyword == id } }).first else {
                    return XCTFail("Unexpected Louie question")
                }
                louieQuestions.append(topic.keyword)
                play.ask(topic.keyword)
            case .choice(let choices):
                guard let answer = choices.first(where: { [UInt16(15), 17, 18].contains($0.id) }) else { return XCTFail("Unexpected Louie answer") }
                if answer.id == 15 { try compare(play.runner.game, "chapter-two-louie-bankrupt/choice") }
                if answer.id == 17 { try compare(play.runner.game, "chapter-two-louie-mila/choice") }
                if answer.id == 18 { try compare(play.runner.game, "chapter-two-louie-understand/choice") }
                louieAnswers.append(answer.id)
                play.choose(answer.id)
            case .exploration: break
            default: return XCTFail("Louie's route stopped: \(play.runner.phase)")
            }
            if case .exploration = play.runner.phase { break }
        }
        XCTAssertEqual(louieQuestions, [3, 4, 5, 6, 7, 8, 2])
        XCTAssertEqual(louieAnswers, [15, 17, 18])
        XCTAssertEqual(louieInterrupts, [5, 20, 24, 32])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 37))
        XCTAssertNil(play.runner.game.personMarker(4))
        try compare(play.runner.game, "chapter-two-louie-understand/page40")
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<30 { play.advanceFrame() }
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<20 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.mode, .counter)
        XCTAssertEqual(play.lobby?.searchAreaID, 1)
        try captureImage(play.lobbyImage, "linens_locker")
        play.selectLobbyObject(x: 96, y: 120)
        play.confirmLobbyObject()
        advance(play)
        XCTAssertEqual(play.closeup?.view.id, 295, "\(play.runner.phase)")
        try compare(play.runner.game, "chapter-two-linens-tools/locker")
        try captureImage(play.closeupImage?.image, "linens_locker_closeup")
        play.selectCloseupComponent(x: 95, y: 130)
        play.confirmCloseupComponent()
        advance(play)
        XCTAssertEqual(play.closeup?.view.id, 305, "\(play.runner.phase)")
        try compare(play.runner.game, "chapter-two-linens-tools/toolbox")
        try captureImage(play.closeupImage?.image, "linens_toolbox")
        for (point, item) in [(SIMD2(141, 172), UInt8(15)), (.init(60, 141), 10), (.init(40, 177), 65)] {
            play.selectCloseupComponent(x: point.x, y: point.y)
            play.confirmCloseupComponent()
            advance(play)
            XCTAssertTrue(try play.runner.game.inventory.items.contains(item), "Item \(item), \(play.runner.phase)")
            let checkpoint = item == 15 ? "pliers" : item == 10 ? "crowbar" : "screwdriver"
            try compare(play.runner.game, "chapter-two-linens-tools/" + checkpoint)
        }
        try captureImage(play.closeupImage?.image, "linens_toolbox_empty")
        play.leaveSearchCloseup()
        XCTAssertEqual(play.closeup?.view.id, 295)
        play.selectCloseupComponent(x: 95, y: 130)
        play.confirmCloseupComponent()
        advance(play)
        XCTAssertEqual(play.closeup?.view.id, 305)
        XCTAssertEqual(try play.closeup?.visibility(game: play.runner.game), [true, true, false, false, false])
        play.leaveSearchCloseup()
        play.leaveSearchCloseup()
        XCTAssertNil(play.closeup)
        play.leaveLobbyCounter()
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<20 { play.advanceFrame() }
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<90 { play.advanceFrame() }
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<20 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3, "\(String(describing: play.lobby?.position))")
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.searchAreaID, 3)
        try captureImage(play.lobbyImage, "linens_magazine_shelves")
        play.selectLobbyObject(x: 95, y: 153)
        play.confirmLobbyObject()
        advance(play)
        XCTAssertEqual(play.closeup?.view.id, 313)
        try compare(play.runner.game, "chapter-two-linens-magazine/magazine")
        try captureImage(play.closeupImage?.image, "linens_magazine")
        play.selectCloseupComponent(x: 96, y: 128)
        play.confirmCloseupComponent()
        advance(play)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(11))
        XCTAssertFalse(play.runner.game.objectVisible(5))
        try compare(play.runner.game, "chapter-two-linens-magazine/collected")
        try captureImage(play.closeupImage?.image, "linens_magazine_collected")
    }
}
