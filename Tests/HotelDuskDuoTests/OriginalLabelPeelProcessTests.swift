import XCTest
@testable import HotelDuskDuoKit

final class OriginalLabelPeelProcessTests: XCTestCase {
    func testChapterSixPeelEventHasFourSourceReturnBranches() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP6_R106")
        let event = try XCTUnwrap(program.blocks.tables[2].first {
            $0.sourceOffset == 236
        })
        XCTAssertEqual(try OriginalEventCompletion.embeddedProcessID(event: event), 46)

        var destinations: [UInt16] = []
        for result in 0...3 {
            let outcome = try OriginalEventCompletion.stateOnlyExit(
                event: event, conditions: program.conditions, processReturn: Int16(result))
            guard case .completed(let completion) = outcome,
                  let transition = completion.transition else {
                XCTFail("Process 46 result \(result) must have a source transition")
                continue
            }
            destinations.append(transition.eventID)
        }

        XCTAssertEqual(destinations, [10, 8, 9, 11])
    }

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
        XCTAssertEqual(process.update(fadeComplete: true), [.followupInteractionRequired])
        XCTAssertTrue(process.update(fadeComplete: true).isEmpty)
        XCTAssertNil(process.result)
    }

    func testSourceBrushUsesTenPixelRadiusAfterTheFirstTouchFrame() {
        let mask = [UInt8](repeating: 1, count: OriginalLabelPeelProcess.width * OriginalLabelPeelProcess.height)
        var process = OriginalLabelPeelProcess(mask: mask)
        _ = process.update()

        _ = process.update(pageTouch: SIMD2(96, 128))
        XCTAssertEqual(process.mask[80 * OriginalLabelPeelProcess.width + 64], 1)

        _ = process.update(pageTouch: SIMD2(96, 128))
        XCTAssertEqual(process.mask[80 * OriginalLabelPeelProcess.width + 74], 129)
        XCTAssertEqual(process.mask[80 * OriginalLabelPeelProcess.width + 75], 1)
    }

    func testSourceStrokePlacesThreeBrushesAndDoesNotStampTheInitialTouch() {
        let mask = [UInt8](repeating: 1, count: OriginalLabelPeelProcess.width * OriginalLabelPeelProcess.height)
        var process = OriginalLabelPeelProcess(mask: mask)
        _ = process.update()

        _ = process.update(pageTouch: SIMD2(52, 128))
        _ = process.update(pageTouch: SIMD2(112, 128))

        XCTAssertEqual(process.mask[80 * OriginalLabelPeelProcess.width + 40], 129)
        XCTAssertEqual(process.mask[80 * OriginalLabelPeelProcess.width + 60], 129)
        XCTAssertEqual(process.mask[80 * OriginalLabelPeelProcess.width + 80], 129)
        XCTAssertEqual(process.mask[80 * OriginalLabelPeelProcess.width + 20], 1)
    }
}
