import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

/**
 * Uses the hanger wire on the suitcase through ordinary session input.
 */
@MainActor
enum OriginalThickWireRouteChecks {
    static func run(_ play: OriginalPlaySession,
                    compare: (OriginalGameState, String) throws -> Void = { _, _ in },
                    captureImage: (CGImage?, String) throws -> Void = { _, _ in }) throws {
        play.leaveLobbyCounter()
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<98 { play.advanceFrame() }
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<54 { play.advanceFrame() }
        play.releaseLobbyTouch()
        guard play.lobby?.nearbySearchArea == 3 else {
            return XCTFail("Expected suitcase search at \(String(describing: play.lobby?.position)), facing \(String(describing: play.lobby?.facing))")
        }
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.searchAreaID, 3)
        try compare(play.runner.game, "chapter-two-thick-wire-approach/inspect")
        play.useItemInSearchView(16)
        play.selectLobbyObject(x: 130, y: 155)
        play.confirmLobbyObject()
        for _ in 0..<100 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: break
            }
        }
        XCTAssertEqual(play.runner.phase, .process(id: 33))
        XCTAssertEqual(play.thinWire?.variant, .thick)
        for _ in 0..<65 { play.advanceFrame() }
        try compare(play.runner.game, "chapter-two-thick-wire-use/puzzle")
        try captureImage(play.thinWireImage, "thick_wire_insertion")
        play.pause()
        let paused = play.thinWire
        play.holdThinWireTouch(x: 110, y: 240)
        play.quitThinWire()
        for _ in 0..<10 { play.advanceFrame() }
        XCTAssertEqual(play.thinWire, paused)
        play.resume()
        play.holdThinWireTouch(x: 110, y: 240)
        for _ in 0..<3 { play.advanceFrame() }
        for x in stride(from: 30, through: 160, by: 10) {
            play.holdThinWireTouch(x: 100, y: Float(255 - x))
            for _ in 0..<8 { play.advanceFrame() }
        }
        play.releaseThinWireTouch()
        for _ in 0..<240 { play.advanceFrame() }
        XCTAssertEqual(play.thinWire?.phase, 3)
        try captureImage(play.thinWireImage, "thick_wire_pins")
        let first = (138...156).map { SIMD2<Float>(96, Float(255 - $0)) }
        let second = (98...117).map { SIMD2<Float>(Float($0), 128) }
        let third = stride(from: 114, through: 95, by: -1).map { SIMD2<Float>(96, Float(255 - $0)) }
        let points = [first, second, third]
        for (index, path) in points.enumerated() {
            for point in path {
                play.holdThinWireTouch(x: point.x, y: point.y)
                for _ in 0..<3 { play.advanceFrame() }
            }
            play.releaseThinWireTouch()
            for _ in 0..<60 { play.advanceFrame() }
            XCTAssertTrue(play.thinWire?.pins[index].reached == true)
        }
        var capturedOpening = false
        for _ in 0..<1100 {
            if !capturedOpening, play.thinWire?.phase == 4, play.thinWire?.stage == 5 {
                try captureImage(play.thinWireImage, "thick_wire_opening")
                capturedOpening = true
            }
            switch play.runner.phase {
            case .process(33), .waiting: play.advanceFrame()
            case .dialogue, .itemNotice: play.advanceDialogue()
            default: break
            }
        }
        XCTAssertTrue(capturedOpening)
        XCTAssertNil(play.thinWire)
        XCTAssertEqual(play.runner.phase, .process(id: 35))
        try compare(play.runner.game, "chapter-two-thick-wire-opening/returned")
        try captureImage(play.lobbyImage, "thick_wire_returned")
        try OriginalSuitcaseContentsRouteChecks.run(play, compare: compare, captureImage: captureImage)
    }
}
