import XCTest
@testable import HotelDuskDuoKit

final class OriginalCassetteDeckProcessTests: XCTestCase {
    func testRecoveredNormalInputPathReturnsProcessValueTwo() {
        var process = makeReadyProcess(selectedControl: SIMD2(47, 47))
        _ = process.activateSelectedControl()
        _ = process.update(touch: SIMD2(15, 177), pressedTouch: SIMD2(15, 177), sceneHit: false)
        for _ in 0..<OriginalCassetteDeckProcess.exitFadeUpdates {
            _ = process.update(touch: nil, pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.returnedProcessValue, 2)
    }

    func testSideBSelectsTheStoryContinuationReturn() {
        var process = makeReadyProcess(selectedControl: SIMD2(47, 143))
        _ = process.activateSelectedControl()
        _ = process.update(touch: SIMD2(15, 177), pressedTouch: SIMD2(15, 177), sceneHit: false)
        for _ in 0..<OriginalCassetteDeckProcess.exitFadeUpdates {
            _ = process.update(touch: nil, pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(process.returnedProcessValue, 0)
    }

    func testFactoryVariantsSelectTheirSourceMusicSequence() {
        XCTAssertEqual(OriginalCassetteDeckProcess().sourceMusicSequenceID, 0x34)
        XCTAssertEqual(OriginalCassetteDeckProcess(variant: .sideB).sourceMusicSequenceID, 0x59)
    }

    func testCassetteDeckDoesNotStartWithoutAProjectedSceneHit() {
        var process = OriginalCassetteDeckProcess()
        _ = process.update(touch: SIMD2(76, 156), pressedTouch: SIMD2(76, 156), sceneHit: false)
        XCTAssertEqual(process.phase, .opening)
    }

    func testDeckActionsEmitTheRecoveredHandlingSounds() {
        var process = OriginalCassetteDeckProcess()
        let open = process.update(touch: SIMD2(76, 156), pressedTouch: SIMD2(76, 156), sceneHit: true)
        XCTAssertEqual(open, [.sound(archiveID: 48, entryID: 0)])

        var dragEffects: [OriginalCassetteDeckProcess.Effect] = []
        for y in stride(from: 155, through: 108, by: -1) {
            dragEffects = process.update(touch: SIMD2(76, y), pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(dragEffects, [.sound(archiveID: 48, entryID: 1)])

        var closeEffects: [OriginalCassetteDeckProcess.Effect] = []
        for _ in 0..<OriginalCassetteDeckProcess.controlsTransitionUpdates {
            closeEffects = process.update(touch: SIMD2(76, 108), pressedTouch: nil, sceneHit: false)
        }
        XCTAssertEqual(closeEffects, [.sound(archiveID: 48, entryID: 2)])

        let switchEffects = process.update(touch: nil, pressedTouch: SIMD2(47, 143), sceneHit: false)
        XCTAssertEqual(switchEffects, [.sound(archiveID: 48, entryID: 3)])
        XCTAssertEqual(process.update(touch: nil, pressedTouch: SIMD2(47, 143), sceneHit: false),
                       [.sound(archiveID: 48, entryID: 3)])
        XCTAssertEqual(process.activateSelectedControl(), [.sound(archiveID: 48, entryID: 4)])
    }

    private func makeReadyProcess(selectedControl: SIMD2<Int>) -> OriginalCassetteDeckProcess {
        var process = OriginalCassetteDeckProcess()
        _ = process.update(touch: SIMD2(76, 156), pressedTouch: SIMD2(76, 156), sceneHit: true)
        for y in stride(from: 155, through: 108, by: -1) {
            _ = process.update(touch: SIMD2(76, y), pressedTouch: nil, sceneHit: false)
        }
        for _ in 0..<OriginalCassetteDeckProcess.controlsTransitionUpdates {
            _ = process.update(touch: SIMD2(76, 108), pressedTouch: nil, sceneHit: false)
        }
        _ = process.update(touch: selectedControl, pressedTouch: selectedControl, sceneHit: false)
        return process
    }
}
