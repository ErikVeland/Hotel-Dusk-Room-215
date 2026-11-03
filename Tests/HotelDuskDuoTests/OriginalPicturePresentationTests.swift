import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalPicturePresentationTests: XCTestCase {
    func testBrochurePictureReplacesThePreviouslyAcquiredRoomKey() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: catalog, defaults: .bundled())
        try OriginalPlaySession.fastForward(&runner, until: { $0.phase == .picture(id: 2) })
        XCTAssertEqual(runner.phase, .picture(id: 2))
        let play = OriginalPlaySession(runner: runner, audio: originalRouteTestAudio(), catalog: catalog)
        defer { play.stop() }
        var receivedRoomKey = false
        for _ in 0..<300 {
            if play.runner.phase == .picture(id: 3) { break }
            switch play.runner.phase {
            case .picture: play.activatePicture(pageX: 96, pageY: 215)
            case .itemNotice(1, _):
                receivedRoomKey = true
                XCTAssertNotNil(play.acquiredItemImage)
                play.advanceDialogue()
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return XCTFail("Unexpected registration phase: \(play.runner.phase)")
            }
            play.advanceFrame()
        }
        XCTAssertTrue(receivedRoomKey)
        XCTAssertEqual(play.runner.phase, .picture(id: 3))
        XCTAssertNil(play.acquiredItemImage, "The active picture must receive taps instead of a retained item image")
        XCTAssertNotNil(play.touchPictureImages)
        play.activatePicture(pageX: 96, pageY: 215)
        XCTAssertEqual(play.touchPicture?.phase, .fading)
        for _ in 0..<24 { play.advanceFrame() }
        XCTAssertNotEqual(play.runner.phase, .picture(id: 3))
    }
}
