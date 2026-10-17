import XCTest
@testable import HotelDuskDuoKit

final class OriginalEntranceProcessTests: XCTestCase {
    private func waitingProcess() -> OriginalEntranceProcess {
        var process = OriginalEntranceProcess()
        for _ in 0..<261 { _ = process.update(); _ = process.draw() }
        return process
    }

    func testApproachMatchesOriginalWaitingPoseAndTouchRegion() throws {
        var process = waitingProcess()
        XCTAssertEqual(process.stage, 1)
        XCTAssertEqual(process.phase, 3)
        XCTAssertEqual(process.movement, 3)
        XCTAssertEqual(process.timer, -1)
        XCTAssertEqual(process.firstSlide, 0)
        XCTAssertEqual(process.secondSlide, 256)
        XCTAssertEqual(process.actorPose, .init(x: 512, y: 12288, z: 24018, facingBits: 0x40490FDB))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/arrival-touch/after-touch-ram.bin")
        if FileManager.default.fileExists(atPath: file.path) {
            let ram = OriginalBytes(try Data(contentsOf: file))
            XCTAssertEqual(try ram.u32(0x2D05E0), 0x021FE038, "Original entrance vtable")
            XCTAssertEqual(try ram.u16(0x2D05E0 + 0x5E8), UInt16(process.movement))
            XCTAssertEqual(try ram.u32(0x27D108 + 8), UInt32(process.actorPose!.z))
            XCTAssertEqual(try ram.u32(0x27D108 + 0x1C), process.actorPose!.facingBits)
        }
        let missed = process.update(.init(newTouch: .init(x: 128, y: 96)))
        XCTAssertEqual(process.movement, 3)
        XCTAssertFalse(missed.effects.contains(.processReturn(0)))
        let tapped = process.update(.init(newTouch: .init(x: 80, y: 92)))
        XCTAssertEqual(process.movement, 4)
        XCTAssertEqual(process.processReturn, 0)
        XCTAssertTrue(tapped.effects.contains(.sound(archive: 51, entry: 0)))
        XCTAssertTrue(tapped.effects.contains(.optionalRumble(1)))
        XCTAssertEqual(process.timer, 0)
    }

    func testOriginalHandleBoundsIncludeHandednessRotation() {
        for point in [(55,84), (105,101)] {
            XCTAssertTrue(OriginalEntranceProcess.hitsHandle(.init(x: point.0, y: point.1), leftHanded: false))
        }
        for point in [(54,84), (106,101), (80,83), (80,102)] {
            XCTAssertFalse(OriginalEntranceProcess.hitsHandle(.init(x: point.0, y: point.1), leftHanded: false))
        }
        XCTAssertTrue(OriginalEntranceProcess.hitsHandle(.init(x: 150, y: 90), leftHanded: true))
        XCTAssertTrue(OriginalEntranceProcess.hitsHandle(.init(x: 200, y: 107), leftHanded: true))
        XCTAssertFalse(OriginalEntranceProcess.hitsHandle(.init(x: 80, y: 92), leftHanded: true))
    }

    func testDoorAnimationWaitsForFadeAndKeepsSourceExitPose() throws {
        var process = waitingProcess()
        _ = process.update(.init(newTouch: .init(x: 80, y: 92)))
        for _ in 0..<53 { _ = process.update() }
        XCTAssertEqual(process.movement, 4)
        let opening = process.update()
        XCTAssertEqual(process.modelFrame, 40.5)
        XCTAssertEqual(process.actorPose?.z, 23964)
        XCTAssertEqual(process.movement, 5)
        XCTAssertEqual(opening.effects.filter { if case .fade = $0 { return true }; return false }.count, 2)
        for _ in 0..<99 { _ = process.update() }
        let poseBeforeFadeCompletes = process.actorPose
        let end = process.update(.init(page0FadeComplete: true))
        XCTAssertEqual(process.actorPose, poseBeforeFadeCompletes)
        XCTAssertEqual(process.phase, 4)
        XCTAssertEqual(process.modelFrame, 0)
        XCTAssertTrue(end.effects.contains(.backgroundMask(screen: 1, mask: 12)))
        _ = process.update(.init(page0FadeComplete: true, backgroundAnimationActive: true))
        XCTAssertEqual(process.phase, 5)
        XCTAssertEqual(process.timer, 0)
        for _ in 0..<100 { XCTAssertEqual(process.update().status, 0) }
        XCTAssertEqual(process.stage, 2)
        XCTAssertEqual(process.update().status, 0)
        XCTAssertEqual(process.update().status, 1)
        XCTAssertEqual(process.update().status, 3)
    }

    func testBookCheckpointPreservesPendingDrawAndTimers() throws {
        var process = waitingProcess()
        _ = process.update(.init(newTouch: .init(x: 80, y: 92)))
        for _ in 0..<27 { _ = process.update() }
        let saved = try JSONEncoder().encode(process)
        var restored = try JSONDecoder().decode(OriginalEntranceProcess.self, from: saved)
        XCTAssertEqual(restored, process)
        XCTAssertEqual(restored.draw(), process.draw())
        for _ in 0..<32 {
            XCTAssertEqual(restored.update(), process.update())
            XCTAssertEqual(restored.draw(), process.draw())
        }
        XCTAssertEqual(restored, process)
    }

    func testCaptureAndSourceImageCopyAlternateOnlyWhenDrawAcknowledges() {
        var process = OriginalEntranceProcess()
        for _ in 0..<6 { _ = process.update() }
        XCTAssertEqual(process.imagePhase, 2)
        XCTAssertEqual(process.imageFrame, 1)
        for _ in 0..<10 { _ = process.update() }
        XCTAssertEqual(process.imageFrame, 1)
        XCTAssertTrue(process.draw().contains(.copyImage(name: "u01.bin", byteCount: 0xC000)))
        for _ in 0..<6 { _ = process.update() }
        XCTAssertTrue(process.draw().contains(.captureScene))
    }
}
