import XCTest
@testable import HotelDuskDuoKit

/**
 * Continues the ordinary Chapter 2 route from the collected magazine.
 */
@MainActor
enum OriginalHelenRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in }) throws {
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<20 { play.advanceFrame() }
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<90 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.nearbyDoor, 39)
        play.inspectNearbyDoor()
        for _ in 0..<1500 {
            switch play.runner.phase {
            case .dialogue: play.advanceDialogue()
            case .waiting, .process: play.advanceFrame()
            default: break
            }
            if case .exploration = play.runner.phase { break }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(play.runner.game.nowTime, 1)
        try compare(play.runner.game, "chapter-two-linens-exit/corridor")
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<17 { play.advanceFrame() }
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<100 {
            if case .exploration = play.runner.phase { play.advanceFrame() }
        }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.runner.eventIndex, 33)
        for _ in 0..<300 {
            switch play.runner.phase {
            case .dialogue: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: break
            }
            if case .exploration = play.runner.phase { break }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 39, index: 34)), true)
        try compare(play.runner.game, "chapter-two-helen-arrival/page120")
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<135 { play.advanceFrame() }
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<20 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.nearbyDoor, 28)
        play.inspectNearbyDoor()
        drain(play)
        XCTAssertEqual(play.door?.destination, 28)
        play.selectDoorComponent(x: 96, y: 135)
        play.confirmDoorComponent()
        drain(play)
        guard case .questions(let topics) = play.runner.phase else {
            return XCTFail("Expected Helen's questions: \(play.runner.phase)")
        }
        XCTAssertEqual(topics.map(\.keyword), [9])
        try compare(play.runner.game, "chapter-two-helen-door/page20")
        play.ask(9)
        drain(play)
        guard case .questions(let memories) = play.runner.phase else {
            return XCTFail("Expected Helen's memories: \(play.runner.phase)")
        }
        XCTAssertEqual(memories.map(\.keyword), [10])
        try compare(play.runner.game, "chapter-two-helen-memories/stay")
        play.ask(10)
        drain(play)
        try compare(play.runner.game, "chapter-two-helen-memories/memories")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertNil(play.door)
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<20 { play.advanceFrame() }
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<350 { play.advanceFrame() }
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<20 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.nearbyDoor, 31)
        play.inspectNearbyDoor()
        drain(play)
        play.selectDoorComponent(x: 160, y: 175)
        play.confirmDoorComponent()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try compare(play.runner.game, "chapter-two-room215-enter/room")
    }

    private static func drain(_ play: OriginalPlaySession) {
        for _ in 0..<300 {
            switch play.runner.phase {
            case .dialogue: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return
            }
        }
        XCTFail("Helen's conversation did not finish")
    }
}
