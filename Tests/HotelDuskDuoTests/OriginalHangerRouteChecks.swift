import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

/**
 * Walks from the Chapter 2 room arrival to the original hanger close-up.
 */
@MainActor
enum OriginalHangerRouteChecks {
    static func exerciseRetries(_ play: OriginalPlaySession,
                                compare: (OriginalGameState, String) throws -> Void) throws {
        for (name, points, quit) in [
            ("quit-untouched", [SIMD2<Float>](), true),
            ("quit-cut", [SIMD2<Float>(45, 148)], true),
            ("short", [SIMD2<Float>(45, 148), .init(75, 148)], false),
            ("upper-right", [SIMD2<Float>(145, 138), .init(45, 148)], false)
        ] {
            play.useItemInCloseup(15)
            play.selectCloseupComponent(x: 80, y: 105)
            play.confirmCloseupComponent()
            XCTAssertEqual(play.runner.phase, .process(id: 32), name)
            for _ in 0..<65 { play.advanceFrame() }
            for point in points {
                play.holdHangerTouch(x: point.x, y: point.y)
                play.advanceFrame()
                play.releaseHangerTouch()
                for _ in 0..<200 { play.advanceFrame() }
            }
            if quit { play.quitHanger() }
            for _ in 0..<450 {
                switch play.runner.phase {
                case .process(32), .waiting: play.advanceFrame()
                case .dialogue, .itemNotice: play.advanceDialogue()
                default: break
                }
            }
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 31), name)
            XCTAssertNil(play.closeup, name)
            XCTAssertNil(play.hanger, name)
            XCTAssertFalse(try play.runner.game.inventory.items.contains(16), name)
            try compare(play.runner.game, "chapter-two-hanger-\(name)/returned")
            play.selectLobbyObject(x: 80, y: 105)
            play.confirmLobbyObject()
            for _ in 0..<100 {
                switch play.runner.phase {
                case .dialogue: play.advanceDialogue()
                case .waiting: play.advanceFrame()
                default: break
                }
            }
            XCTAssertEqual(play.closeup?.view.id, 258, name)
        }
    }

    static func cut(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in },
                    captureImage: (CGImage?, String) throws -> Void = { _, _ in }) throws {
        play.useItemInCloseup(15)
        play.selectCloseupComponent(x: 80, y: 105)
        play.confirmCloseupComponent()
        XCTAssertEqual(play.runner.phase, .process(id: 32))
        XCTAssertNotNil(play.hanger)
        for _ in 0..<65 { play.advanceFrame() }
        try compare(play.runner.game, "chapter-two-hanger-use/puzzle")
        try captureImage(play.hangerImage, "hanger_puzzle")
        play.holdHangerTouch(x: 45, y: 148)
        play.advanceFrame()
        play.releaseHangerTouch()
        for _ in 0..<70 { play.advanceFrame() }
        XCTAssertEqual(play.hanger?.stage, 3)
        try captureImage(play.hangerImage, "hanger_cutting")
        play.pause()
        let paused = play.hanger, fade = play.hangerScreenEffects
        play.holdHangerTouch(x: 145, y: 148)
        play.quitHanger()
        for _ in 0..<10 { play.advanceFrame() }
        XCTAssertEqual(play.hanger, paused)
        XCTAssertEqual(play.hangerScreenEffects, fade)
        play.resume()
        for _ in 0..<200 { play.advanceFrame() }
        XCTAssertEqual(play.hanger?.phase, 1)
        XCTAssertEqual(play.hanger?.cutting.cuts.count, 1)
        try captureImage(play.hangerImage, "hanger_cut_once")
        play.holdHangerTouch(x: 145, y: 148)
        play.advanceFrame()
        play.releaseHangerTouch()
        for _ in 0..<400 {
            switch play.runner.phase {
            case .process(32), .waiting: play.advanceFrame()
            case .dialogue, .itemNotice: play.advanceDialogue()
            default: break
            }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertNil(play.hanger)
        XCTAssertNil(play.closeup)
        XCTAssertEqual(play.lobby?.mode, .counter)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(16))
        try compare(play.runner.game, "chapter-two-hanger-cut/returned")
        try captureImage(play.lobbyImage, "hanger_removed")
    }

    static func inspect(_ play: OriginalPlaySession,
                        compare: (OriginalGameState, String) throws -> Void = { _, _ in },
                        captureImage: (CGImage?, String) throws -> Void = { _, _ in }) throws {
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<6 { play.advanceFrame() }
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<20 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 4)
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.searchAreaID, 4)
        try captureImage(play.lobbyImage, "hanger_search")
        play.selectLobbyObject(x: 80, y: 105)
        XCTAssertEqual(play.lobby?.selectedNode, "obj02")
        play.confirmLobbyObject()
        for _ in 0..<100 {
            switch play.runner.phase {
            case .dialogue: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: break
            }
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.closeup?.view.id, 258)
        try compare(play.runner.game, "chapter-two-hanger-inspect/hanger")
        try captureImage(play.closeupImage?.image, "hanger_closeup")
        play.useItemInCloseup(15)
        XCTAssertEqual(play.searchItem, 15)
        XCTAssertNil(play.closeup?.selected)
        play.selectCloseupComponent(x: 80, y: 105)
        XCTAssertEqual(play.closeup?.selectedEvent, 259)
        play.pause()
        play.useItemInCloseup(nil)
        XCTAssertEqual(play.searchItem, 15)
        play.resume()
        play.useItemInCloseup(nil)
        XCTAssertNil(play.searchItem)
        XCTAssertNil(play.closeup?.selected)
        play.useItemInCloseup(255)
        XCTAssertNil(play.searchItem)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try compare(play.runner.game, "chapter-two-hanger-inspect/hanger")
    }
}
