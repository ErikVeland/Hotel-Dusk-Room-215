import XCTest
@testable import HotelDuskDuoKit

final class OriginalCassetteDeckProcessTests: XCTestCase {
    func testRecoveredNormalInputPathReturnsProcessValueTwo() {
        var process = makeReadyProcess(selectedControl: SIMD2(47, 47))
        process.activateSelectedControl()
        process.update(touch: SIMD2(15, 177), pressedTouch: SIMD2(15, 177), sceneHit: false)
        for _ in 0..<OriginalCassetteDeckProcess.exitFadeUpdates {
            process.update(touch: nil, pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.returnedProcessValue, 2)
    }

    func testSideBSelectsTheStoryContinuationReturn() {
        var process = makeReadyProcess(selectedControl: SIMD2(47, 143))
        process.activateSelectedControl()
        process.update(touch: SIMD2(15, 177), pressedTouch: SIMD2(15, 177), sceneHit: false)
        for _ in 0..<OriginalCassetteDeckProcess.exitFadeUpdates {
            process.update(touch: nil, pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(process.returnedProcessValue, 0)
    }

    func testCassetteDeckDoesNotStartWithoutAProjectedSceneHit() {
        var process = OriginalCassetteDeckProcess()
        process.update(touch: SIMD2(76, 156), pressedTouch: SIMD2(76, 156), sceneHit: false)
        XCTAssertEqual(process.phase, .opening)
    }

    private func makeReadyProcess(selectedControl: SIMD2<Int>) -> OriginalCassetteDeckProcess {
        var process = OriginalCassetteDeckProcess()
        process.update(touch: SIMD2(76, 156), pressedTouch: SIMD2(76, 156), sceneHit: true)
        for y in stride(from: 155, through: 108, by: -1) {
            process.update(touch: SIMD2(76, y), pressedTouch: nil, sceneHit: false)
        }
        for _ in 0..<OriginalCassetteDeckProcess.controlsTransitionUpdates {
            process.update(touch: SIMD2(76, 108), pressedTouch: nil, sceneHit: false)
        }
        process.update(touch: selectedControl, pressedTouch: selectedControl, sceneHit: false)
        return process
    }
}
