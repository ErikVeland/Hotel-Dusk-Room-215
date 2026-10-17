import XCTest
@testable import HotelDuskDuoKit

/**
 * Returns to Room 215 after Rosa's pager reminder and follows Ed's call.
 */
@MainActor
enum OriginalEdCallRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in }) throws {
        walk(play, x: 96, y: 45, frames: 68)
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<240 {
            if play.lobby?.mapID != 3 { break }
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        try compare(play.runner.game, "chapter-two-ed-return-upstairs/central")
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<200 {
            if play.lobby?.mapID != 17 { break }
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        try compare(play.runner.game, "chapter-two-ed-return-upstairs/upstairs")
        walk(play, x: 20, y: 128, frames: 270)
        walk(play, x: 96, y: 210, frames: 40)
        XCTAssertEqual(play.nearbyDoor, 31, "Position \(String(describing: play.lobby?.position)), facing \(String(describing: play.lobby?.facing))")
        play.inspectNearbyDoor()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try compare(play.runner.game, "chapter-two-ed-door-approach/door")
        walk(play, x: 20, y: 128, frames: 95)
        walk(play, x: 96, y: 210, frames: 72)
        walk(play, x: 20, y: 128, frames: 20)
        walk(play, x: 96, y: 210, frames: 16)
        walk(play, x: 20, y: 128, frames: 60)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1, "\(String(describing: play.lobby?.position))")
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.searchAreaID, 1)
        try compare(play.runner.game, "chapter-two-ed-dresser/inspect")
        play.selectLobbyObject(x: 86, y: 165)
        XCTAssertEqual(play.lobby?.selectedNode, "obj01")
        play.confirmLobbyObject()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.game.nowTime, 3)
        XCTAssertEqual(play.lobby?.mode, .walking, "Requests \(play.runner.processRequests.suffix(12))")
        try compare(play.runner.game, "chapter-two-ed-phone-finish/returned")
        walk(play, x: 170, y: 128, frames: 100)
        walk(play, x: 96, y: 45, frames: 100)
        XCTAssertEqual(play.nearbyDoor, 39)
        play.inspectNearbyDoor()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<400 {
            if (play.lobby?.position.x ?? 0) >= 20700 { break }
            play.advanceFrame()
        }
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<160 {
            if play.lobby?.mapID != 39 { break }
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        walk(play, x: 96, y: 210, frames: 68)
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        XCTAssertFalse(play.lobby?.people(in: play.runner.game).isEmpty ?? true,
                       "Position \(String(describing: play.lobby?.position)), time \(play.runner.game.nowTime), region \(String(describing: play.lobby?.eventRegion))")
        try compare(play.runner.game, "chapter-two-dunning-arrival/page19")
        walk(play, x: 96, y: 45, frames: 28)
        walk(play, x: 20, y: 128, frames: 20)
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 2)
        play.talkToNearbyPerson()
        drain(play)
        guard case .questions(let topics) = play.runner.phase else {
            return XCTFail("Expected Dunning's questions: \(play.runner.phase)")
        }
        try compare(play.runner.game, "chapter-two-dunning-talk/page9")
        XCTAssertTrue(topics.contains { $0.keyword == 13 })
        play.ask(13)
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        try compare(play.runner.game, "chapter-two-dunning-louie/page34")
        walk(play, x: 20, y: 128, frames: 15)
        XCTAssertEqual(play.nearbyDoor, 19)
        play.inspectNearbyDoor()
        drain(play)
        XCTAssertEqual(play.door?.destination, 19)
        play.selectDoorComponent(x: 32, y: 175)
        play.confirmDoorComponent()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 19))
        try compare(play.runner.game, "chapter-two-left-hallway-entry/entered")
        try OriginalLouieRoomRouteChecks.run(play, compare: compare)
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
            case .waiting, .process(126): play.advanceFrame()
            default: return
            }
        }
        XCTFail("Ed's call did not finish")
    }
}
