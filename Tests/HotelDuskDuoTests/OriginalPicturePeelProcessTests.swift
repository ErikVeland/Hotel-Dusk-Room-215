import XCTest
@testable import HotelDuskDuoKit

final class OriginalPicturePeelProcessTests: XCTestCase {
    func testBrushUsesRotatedMaskCoordinatesAndRadiusFourCircle() {
        var process = OriginalPicturePeelProcess(mask: [UInt8](repeating: 1, count: 192 * 256))

        let effects = process.update(touch: .init(20, 30))

        XCTAssertEqual(process.mask[20 * 256 + 255 - 30], 0)
        XCTAssertEqual(process.mask[24 * 256 + 255 - 30], 0)
        XCTAssertEqual(process.mask[25 * 256 + 255 - 30], 1)
        XCTAssertEqual(process.mask[20 * 256 + 255 - 35], 1)
        XCTAssertEqual(effects, [.dragging(true), .sound(archive: 50, entry: 0)])
    }

    func testSuccessRequiresMoreThanSourceThresholdAndReturnsTwoOnRelease() {
        var incompleteMask = [UInt8](repeating: 1, count: 192 * 256)
        incompleteMask.replaceSubrange(0..<OriginalPicturePeelProcess.clearedPixelThreshold - 1,
                                       with: repeatElement(UInt8(0), count: OriginalPicturePeelProcess.clearedPixelThreshold - 1))
        var incomplete = OriginalPicturePeelProcess(mask: incompleteMask)

        XCTAssertFalse(incomplete.isComplete)
        _ = incomplete.update(touch: .init(-1, 10))
        _ = incomplete.update()

        XCTAssertNil(incomplete.result)

        let completeMask = [UInt8](repeating: 0, count: 192 * 256)
        var complete = OriginalPicturePeelProcess(mask: completeMask)

        _ = complete.update(touch: .init(20, 20))
        let effects = complete.update()

        XCTAssertEqual(effects, [.dragging(false), .peelCompleted])
        XCTAssertNil(complete.result)
        XCTAssertEqual(complete.requestExit(), .returned(2))
        XCTAssertEqual(complete.result, 2)
    }

    func testStrokeInterpolatesAndStopsWhenTouchLeavesPicture() {
        var process = OriginalPicturePeelProcess(mask: [UInt8](repeating: 1, count: 192 * 256))

        _ = process.update(touch: .init(10, 10))
        let effects = process.update(touch: .init(30, 10), eraseSoundPlaying: true)
        let release = process.update(touch: .init(-1, 10))

        XCTAssertTrue(process.mask[20 * 256 + 255 - 10] == 0)
        XCTAssertEqual(effects, [])
        XCTAssertEqual(release, [.dragging(false)])
    }

    func testEraseCueMatchesTheRecoveredSoundArchive() throws {
        let archive = try OriginalSoundArchive.load()

        XCTAssertEqual(try archive.effect(archiveID: 50, entryID: 0).symbol,
                       "SE_NAZOTOKI_KAZARIMOJI_KEZURU")
        XCTAssertThrowsError(try archive.effect(archiveID: 0, entryID: 50))
    }

    func testExitReturnsTwoBeforeThePeelThresholdIsReached() {
        var process = OriginalPicturePeelProcess(mask: [UInt8](repeating: 1, count: 192 * 256))

        XCTAssertEqual(process.requestExit(), .returned(2))
        XCTAssertEqual(process.result, 2)
        XCTAssertFalse(process.isComplete)
    }
}
