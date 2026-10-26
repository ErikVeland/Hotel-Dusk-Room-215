import XCTest
@testable import HotelDuskDuoKit

final class OriginalLabelPeelProcessTests: XCTestCase {
    func testLabelPeelRequiresNinetyNinePointFivePercentClear() {
        var mask = [UInt8](repeating: 1, count: OriginalLabelPeelProcess.width * OriginalLabelPeelProcess.height)
        let clearCount = Int((Double(mask.count) * 0.995).rounded(.up)) - 1
        for index in 0..<clearCount { mask[index] = 0 }

        let process = OriginalLabelPeelProcess(mask: mask)

        XCTAssertEqual(process.completionThreshold, 20_378)
        XCTAssertFalse(process.isComplete)
    }

    func testDragAcrossLabelClearsMaskAndCompletesOnRelease() {
        let mask = [UInt8](repeating: 1, count: OriginalLabelPeelProcess.width * OriginalLabelPeelProcess.height)
        var process = OriginalLabelPeelProcess(mask: mask)
        _ = process.update(fadeComplete: true)
        var finalReleaseEffects: [OriginalLabelPeelProcess.Effect] = []

        for y in stride(from: 52, through: 204, by: 8) {
            _ = process.update(pageTouch: SIMD2(36, y))
            for x in stride(from: 38, through: 156, by: 2) {
                _ = process.update(pageTouch: SIMD2(x, y))
            }
            let releaseEffects = process.update()
            if y == 204 { finalReleaseEffects = releaseEffects }
        }

        XCTAssertTrue(process.isComplete)
        XCTAssertTrue(finalReleaseEffects.contains(.fadeOut(60)))
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
    }
}
