import XCTest
@testable import HotelDuskDuoKit

final class OriginalLabelPeelProcessTests: XCTestCase {
    func testSourceWordRestoresTheFollowupPeelPosition() {
        XCTAssertEqual(OriginalLabelPeelProcess.sourcePosition(from: 0), 1_475)
        XCTAssertEqual(OriginalLabelPeelProcess.sourcePosition(from: 0x15C3), 1_475)
        XCTAssertEqual(OriginalLabelPeelProcess.sourcePosition(from: 0x0900), -1_516)

        let process = OriginalLabelPeelProcess(mask: [], stage: .peel, sourceStateWord: 0x15C3)
        XCTAssertEqual(process.sourcePosition, 1_475)
    }

    func testSourceFollowupHitRegionUsesTheRecoveredDynamicExtent() {
        let aboveBoundary = OriginalLabelPeelProcess.projectedHitRegion(position: 1_000,
                                                                         previousPosition: 900)
        XCTAssertEqual(aboveBoundary, .init(minimumX: 1_000, maximumX: 2_638,
                                            minimumY: 900, maximumY: 2_538))
        XCTAssertTrue(aboveBoundary.contains(SIMD2(1_001, 901)))
        XCTAssertFalse(aboveBoundary.contains(SIMD2(1_000, 901)))
        XCTAssertFalse(aboveBoundary.contains(SIMD2(2_638, 901)))

        let belowBoundary = OriginalLabelPeelProcess.projectedHitRegion(position: 500,
                                                                         previousPosition: 490)
        XCTAssertEqual(belowBoundary, .init(minimumX: 500, maximumX: 2_375,
                                            minimumY: 490, maximumY: 2_365))
        XCTAssertTrue(belowBoundary.contains(SIMD2(501, 491)))
        XCTAssertFalse(belowBoundary.contains(SIMD2(2_375, 2_000)))
    }

    func testFollowupTouchUsesSourceCoordinateQuantisationAndProjection() {
        XCTAssertEqual(OriginalLabelPeelProcess.projectedTouch(SIMD2(150, 75)), SIMD2(2_218, 2_389))
        XCTAssertEqual(OriginalLabelPeelProcess.projectedTouch(SIMD2(145, 75)), SIMD2(2_048, 2_389))
        XCTAssertEqual(OriginalLabelPeelProcess.projectedTouch(SIMD2(132, 75)), SIMD2(1_536, 2_389))
    }

    func testFollowupPeelTracksProjectedPositionAndUsesSourceBoundary() {
        var process = OriginalLabelPeelProcess(mask: [], stage: .peel, sourceStateWord: 0x15C3)
        _ = process.update()

        XCTAssertEqual(process.update(pageTouch: SIMD2(150, 75)), [.dragging(true)])
        _ = process.update(pageTouch: SIMD2(145, 75))
        XCTAssertEqual(process.sourcePosition, 1_305)
        XCTAssertFalse(process.isPeelComplete)
        XCTAssertEqual(process.update(), [.dragging(false)])

        _ = process.update(pageTouch: SIMD2(150, 75))
        _ = process.update(pageTouch: SIMD2(132, 75))
        XCTAssertEqual(process.sourcePosition, 623)
        XCTAssertTrue(process.isPeelComplete)
        XCTAssertEqual(process.update(), [.dragging(false), .fadeOut(60)])
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(0)])
    }

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
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
        XCTAssertTrue(process.update(fadeComplete: true).isEmpty)
        XCTAssertEqual(process.result, 2)
    }

    func testPeelStageAcceptsRepeatedPullsAndReturnsSuccess() {
        let mask = [UInt8](repeating: 1, count: OriginalLabelPeelProcess.width * OriginalLabelPeelProcess.height)
        var process = OriginalLabelPeelProcess(mask: mask, stage: .peel)
        _ = process.update()

        _ = process.update(pageTouch: SIMD2(150, 75))
        _ = process.update(pageTouch: SIMD2(132, 88))
        let firstReleaseEffects = process.update()
        XCTAssertEqual(firstReleaseEffects, [.dragging(false)])
        _ = process.update(pageTouch: SIMD2(150, 75))
        _ = process.update(pageTouch: SIMD2(130, 88))
        let releaseEffects = process.update()

        XCTAssertTrue(process.isPeelComplete)
        XCTAssertEqual(releaseEffects, [.dragging(false), .fadeOut(60)])
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(0)])
        XCTAssertEqual(process.result, 0)
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
