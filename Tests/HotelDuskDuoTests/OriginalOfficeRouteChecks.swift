import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

/**
 * Follows the office search through red-box acquisition, then continues with Louie and Rosa.
 */
@MainActor
enum OriginalOfficeRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in },
                    captureImage: (CGImage?, String) throws -> Void = { _, _ in }) throws {
        try captureImage(play.lobbyImage, "office_arrival")
        walk(play, x: 170, y: 128, frames: 26)
        walk(play, x: 96, y: 45, frames: 83)
        walk(play, x: 20, y: 128, frames: 29)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 4)
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.searchAreaID, 4)
        try captureImage(play.lobbyImage, "office_cabinet")
        play.selectLobbyObject(x: 130, y: 165)
        play.confirmLobbyObject()
        drain(play)
        XCTAssertEqual(play.closeup?.view.id, 127)
        try compare(play.runner.game, "chapter-two-office-records-drawer/ready")
        play.selectCloseupComponent(x: 95, y: 155)
        play.confirmCloseupComponent()
        for _ in 0..<100 {
            if play.closeupDetailImage != nil { break }
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return XCTFail("Expected the guest ledger: \(play.runner.phase)")
            }
        }
        XCTAssertNotNil(play.closeupDetailImage)
        XCTAssertEqual(play.runner.session.selection.modeID, 12)
        try captureImage(play.closeupDetailImage?.image, "office_guest_ledger")
        play.pause()
        let paused = play.runner.game.bytes
        play.advanceDialogue()
        play.leaveSearchCloseup()
        XCTAssertEqual(play.runner.game.bytes, paused)
        XCTAssertNotNil(play.closeupDetailImage)
        play.resume()
        drain(play)
        XCTAssertNil(play.closeupDetailImage)
        XCTAssertEqual(play.closeup?.view.id, 127)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 15))
        try compare(play.runner.game, "chapter-two-office-ledger-return/returned")
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        walk(play, x: 96, y: 210, frames: 61)
        walk(play, x: 170, y: 128, frames: 96)
        walk(play, x: 96, y: 210, frames: 15)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.searchAreaID, 1)
        try captureImage(play.lobbyImage, "office_desk")
        play.selectLobbyObject(x: 145, y: 200)
        play.confirmLobbyObject()
        drain(play)
        XCTAssertEqual(play.closeup?.view.id, 133)
        try compare(play.runner.game, "chapter-two-office-desk-items/ready")
        play.selectCloseupComponent(x: 90, y: 190)
        play.confirmCloseupComponent()
        drain(play)
        try compare(play.runner.game, "chapter-two-office-card-log/card")
        play.selectCloseupComponent(x: 120, y: 65)
        play.confirmCloseupComponent()
        drain(play)
        XCTAssertNil(play.closeupDetailImage)
        try compare(play.runner.game, "chapter-two-office-card-log/log")
        play.leaveSearchCloseup()
        play.selectLobbyObject(x: 60, y: 150)
        play.confirmLobbyObject()
        drain(play)
        XCTAssertEqual(play.closeup?.view.id, 130)
        try compare(play.runner.game, "chapter-two-office-calendar/ready")
        play.selectCloseupComponent(x: 110, y: 75)
        play.confirmCloseupComponent()
        drain(play)
        XCTAssertNil(play.closeupDetailImage)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 15))
        try compare(play.runner.game, "chapter-two-office-calendar-date/returned")
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        walk(play, x: 20, y: 128, frames: 64)
        walk(play, x: 96, y: 210, frames: 15)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 95, y: 220)
        try captureImage(play.lobbyImage, "office_memo_cabinet")
        XCTAssertEqual(play.lobby?.selectedNode, "obj02", "Position \(String(describing: play.lobby?.position)), pan \(String(describing: play.lobby?.pan))")
        play.confirmLobbyObject()
        drain(play)
        XCTAssertEqual(play.closeup?.view.id, 119)
        try compare(play.runner.game, "chapter-two-memo-inspect/closeup")
        play.selectCloseupComponent(x: 100, y: 220)
        play.confirmCloseupComponent()
        drain(play)
        XCTAssertEqual(play.runner.phase, .process(id: 27))
        try compare(play.runner.game, "chapter-two-memo-pull-ready/page9")
        for _ in 0..<65 { play.advanceFrame() }
        try captureImage(play.memoPullImage, "office_memo_pull")
        play.holdMemoPullTouch(x: 106, y: 162)
        for _ in 0..<2 { play.advanceFrame() }
        let held = play.memoPull
        play.pause()
        play.quitMemoPull()
        play.advanceFrame()
        XCTAssertEqual(play.memoPull, held)
        play.resume()
        play.holdMemoPullTouch(x: 106, y: 162)
        for index in 0...12 {
            play.holdMemoPullTouch(x: index % 2 == 0 ? 102 : 110, y: 162)
            play.advanceFrame()
        }
        play.releaseMemoPullTouch()
        XCTAssertEqual(play.memoPull?.returnValue, 0)
        for _ in 0..<300 where play.memoPull != nil { play.advanceFrame() }
        XCTAssertNil(play.memoPull)
        try compare(play.runner.game, "chapter-two-memo-torn-return/returned")
        play.advanceDialogue()
        try compare(play.runner.game, "chapter-two-memo-torn-return/page0")
        drain(play)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(7))
        XCTAssertEqual(play.runner.phase, .process(id: 34))
        for _ in 0..<65 { play.advanceFrame() }
        XCTAssertNotNil(play.memoDrawing)
        try captureImage(play.memoDrawingImage, "office_memo_drawing")
        try compare(play.runner.game, "chapter-two-memo-torn-return/page15")
        play.holdMemoDrawingTouch(x: 40, y: 105)
        play.advanceFrame()
        play.releaseMemoDrawingTouch()
        XCTAssertTrue(play.memoDrawing?.drawing.pixels.contains(0xE0) == true)
        play.pause()
        let ink = play.memoDrawing?.drawing.pixels
        play.clearMemoDrawing()
        play.quitMemoDrawing()
        play.advanceFrame()
        XCTAssertEqual(play.memoDrawing?.drawing.pixels, ink)
        play.resume()
        play.clearMemoDrawing()
        XCTAssertTrue(play.memoDrawing?.drawing.pixels.allSatisfy { $0 == 0 } == true)
        play.quitMemoDrawing()
        for _ in 0..<100 where play.memoDrawing != nil { play.advanceFrame() }
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 15))
        XCTAssertNil(play.memoDrawing)
        try compare(play.runner.game, "chapter-two-memo-drawing-quit/finished")
        XCTAssertNil(play.closeup)
        let savedState = play.runner.game.bytes
        play.useItemInSearchView(7)
        XCTAssertEqual(play.runner.phase, .process(id: 34))
        for _ in 0..<65 { play.advanceFrame() }
        XCTAssertTrue(play.memoDrawing?.drawing.pixels.allSatisfy { $0 == 0 } == true)
        XCTAssertEqual(play.runner.game.bytes, savedState)
        try compare(play.runner.game, "chapter-two-memo-drawing-reopen/reopened")
        play.quitMemoDrawing()
        for _ in 0..<100 where play.memoDrawing != nil { play.advanceFrame() }
        drain(play)
        XCTAssertNil(play.memoDrawing)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 15))
        XCTAssertNil(play.searchItem)
        try compare(play.runner.game, "chapter-two-memo-drawing-reopen-return/finished")
        play.selectLobbyObject(x: 85, y: 222)
        XCTAssertEqual(play.lobby?.selectedNode, "obj07")
        play.confirmLobbyObject()
        drain(play)
        XCTAssertEqual(play.closeup?.view.id, 124)
        try compare(play.runner.game, "chapter-two-crowbar-closeup/torn")
        play.useItemInCloseup(10)
        play.selectCloseupComponent(x: 70, y: 145)
        play.confirmCloseupComponent()
        drain(play)
        XCTAssertEqual(play.runner.phase, .process(id: 30))
        try compare(play.runner.game, "chapter-two-crowbar-entry/ready")
        for _ in 0..<65 { play.advanceFrame() }
        try captureImage(play.crowbarImage, "office_crowbar")
        let idle = play.crowbar
        play.pause()
        play.holdCrowbarTouch(x: 115, y: 93)
        play.quitCrowbar()
        play.advanceFrame()
        XCTAssertEqual(play.crowbar, idle)
        play.resume()
        play.holdCrowbarTouch(x: 115, y: 93)
        for _ in 0..<2 { play.advanceFrame() }
        for point in [SIMD2<Float>(112,105), .init(108,125), .init(103,145), .init(98,165),
                      .init(93,185), .init(88,205), .init(83,225)] {
            play.holdCrowbarTouch(x: point.x, y: point.y)
            for _ in 0..<20 { play.advanceFrame() }
        }
        play.releaseCrowbarTouch()
        for _ in 0..<120 { play.advanceFrame() }
        XCTAssertEqual(play.crowbar?.stage, 3)
        try captureImage(play.crowbarImage, "office_crowbar_placed")
        play.holdCrowbarTouch(x: 112, y: 88)
        for _ in 0..<3 { play.advanceFrame() }
        for point in [SIMD2<Float>(116,95), .init(120,102), .init(124,109), .init(128,116),
                      .init(132,123), .init(136,130), .init(140,137)] {
            play.holdCrowbarTouch(x: point.x, y: point.y)
            for _ in 0..<3 { play.advanceFrame() }
        }
        play.releaseCrowbarTouch()
        XCTAssertEqual(play.crowbar?.returnValue, 0)
        for _ in 0..<600 where play.crowbar != nil { play.advanceFrame() }
        XCTAssertNil(play.crowbar)
        try compare(play.runner.game, "chapter-two-crowbar-lift/returned")
        drain(play)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(13))
        XCTAssertEqual(play.runner.phase, .process(id: 34))
        for _ in 0..<180 { play.advanceFrame() }
        try captureImage(play.memoDrawingImage, "office_joined_memo")
        try compare(play.runner.game, "chapter-two-memo-joined-ready/finished")
        play.quitMemoDrawing()
        for _ in 0..<100 where play.memoDrawing != nil { play.advanceFrame() }
        drain(play)
        XCTAssertNil(play.memoDrawing)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 15))
        try compare(play.runner.game, "chapter-two-memo-joined-return/finished")
        play.selectLobbyObject(x: 85, y: 18)
        play.confirmLobbyObject()
        drain(play)
        XCTAssertEqual(play.closeup?.view.id, 116)
        try compare(play.runner.game, "chapter-two-cabinet-keypad/ready")
        play.selectCloseupComponent(x: 135, y: 40)
        play.confirmCloseupComponent()
        drain(play)
        XCTAssertEqual(play.runner.phase, .process(id: 31))
        try compare(play.runner.game, "chapter-two-cabinet-combination-entry/ready")
        for _ in 0..<65 { play.advanceFrame() }
        try captureImage(play.cabinetDialImage, "office_cabinet_dials")
        let idleDial = play.cabinetDial
        play.pause()
        play.holdCabinetDialTouch(x: 30, y: 130)
        play.quitCabinetDial()
        play.advanceFrame()
        XCTAssertEqual(play.cabinetDial, idleDial)
        play.resume()
        let target = try XCTUnwrap(play.cabinetDial?.target)
        for wheel in 0..<3 {
            let x = Float([30, 94, 156][wheel])
            for _ in 0..<10 {
                let current = try XCTUnwrap(play.cabinetDial?.digits[wheel])
                if current == target[wheel] { break }
                let down = (target[wheel] - current + 10) % 10 <= 5
                play.holdCabinetDialTouch(x: x, y: 130)
                for _ in 0..<3 { play.advanceFrame() }
                play.holdCabinetDialTouch(x: x, y: down ? 220 : 40)
                for _ in 0..<3 { play.advanceFrame() }
                play.releaseCabinetDialTouch()
                for _ in 0..<90 { play.advanceFrame() }
            }
        }
        XCTAssertEqual(play.cabinetDial?.digits, target)
        XCTAssertEqual(play.cabinetDial?.returnValue, 0)
        for _ in 0..<600 where play.cabinetDial != nil { play.advanceFrame() }
        XCTAssertNil(play.cabinetDial)
        try compare(play.runner.game, "chapter-two-cabinet-unlock/returned")
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 15))
        try compare(play.runner.game, "chapter-two-cabinet-unlock/page11")
        play.selectLobbyObject(x: 65, y: 85)
        XCTAssertEqual(play.lobby?.selectedNode, "obj08")
        play.confirmLobbyObject()
        drain(play)
        XCTAssertEqual(play.closeup?.view.id, 122)
        try compare(play.runner.game, "chapter-two-red-box-closeup/ready")
        play.selectCloseupComponent(x: 145, y: 95)
        play.confirmCloseupComponent()
        drain(play)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(14))
        try captureImage(play.closeupImage?.image, "office_red_box_taken")
        try compare(play.runner.game, "chapter-two-red-box-take/page13")
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        XCTAssertNil(play.closeup)
        XCTAssertEqual(play.lobby?.mode, .walking)
        try compare(play.runner.game, "chapter-two-office-after-box/walking")
        walk(play, x: 20, y: 128, frames: 100)
        XCTAssertNotNil(play.nearbyDoor)
        play.inspectNearbyDoor()
        drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
        try compare(play.runner.game, "chapter-two-office-exit-approach/page9")
        try OriginalNileRouteChecks.run(play, compare: compare)
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
        XCTFail("The office response did not finish")
    }
}
