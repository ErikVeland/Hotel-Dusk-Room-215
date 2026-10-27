import XCTest
@testable import HotelDuskDuoKit

final class OriginalCassetteDeckProcessTests: XCTestCase {
    func testRecoveredNormalInputPathReturnsProcessValueTwo() {
        var process = OriginalCassetteDeckProcess()
        process.update(touch: SIMD2(76, 156), pressedTouch: SIMD2(76, 156), sceneHit: true)
        XCTAssertEqual(process.phase, .dragging)

        for y in stride(from: 155, through: 108, by: -1) {
            process.update(touch: SIMD2(76, y), pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(process.phase, .turning)
        for _ in 0..<OriginalCassetteDeckProcess.controlsTransitionUpdates {
            process.update(touch: SIMD2(76, 108), pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(process.phase, .controlsReady)

        process.update(touch: SIMD2(47, 47), pressedTouch: SIMD2(47, 47), sceneHit: false)
        XCTAssertEqual(process.selectedSelector, 0)
        process.activateSelectedControl()
        XCTAssertEqual(process.phase, .playing)

        process.update(touch: SIMD2(15, 177), pressedTouch: SIMD2(15, 177), sceneHit: false)
        for _ in 0..<OriginalCassetteDeckProcess.exitFadeUpdates {
            process.update(touch: nil, pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.returnedProcessValue, 2)
    }

    func testCassetteDeckDoesNotStartWithoutAProjectedSceneHit() {
        var process = OriginalCassetteDeckProcess()
        process.update(touch: SIMD2(76, 156), pressedTouch: SIMD2(76, 156), sceneHit: false)
        XCTAssertEqual(process.phase, .opening)
    }
}
