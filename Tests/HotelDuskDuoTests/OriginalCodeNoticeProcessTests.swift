import XCTest
@testable import HotelDuskDuoKit

final class OriginalCodeNoticeProcessTests: XCTestCase {
    func testCodeNoticeFadesThenWaitsForTheSharedExitControl() {
        for processID in [62, 67] {
            var process = OriginalCodeNoticeProcess(processID: processID)

            for _ in 0..<OriginalCodeNoticeProcess.fadeUpdates {
                _ = process.update(pageTouch: .init(19, 240), exitControlFinished: true)
            }

            XCTAssertEqual(process.phase, .awaitingExit)
            XCTAssertNil(process.result)

            XCTAssertEqual(process.update(pageTouch: .init(19, 240)), [])
            XCTAssertEqual(process.phase, .waitingForExitControl)
            XCTAssertNil(process.result)

            XCTAssertEqual(process.update(exitControlFinished: true), [.returned(2)])
            XCTAssertEqual(process.phase, .returned)
            XCTAssertEqual(process.result, 2)
        }

    }

    func testExitCannotSkipTheFadeOrCompleteWithoutControlResponse() {
        var process = OriginalCodeNoticeProcess(processID: 67)

        _ = process.update(pageTouch: .init(19, 240))
        XCTAssertEqual(process.phase, .fadingIn(remainingUpdates: 30))

        for _ in 0..<OriginalCodeNoticeProcess.fadeUpdates - 1 {
            _ = process.update()
        }
        XCTAssertEqual(process.phase, .awaitingExit)

        _ = process.update(pageTouch: .init(19, 240), exitControlFinished: true)
        XCTAssertEqual(process.phase, .waitingForExitControl)
        XCTAssertNil(process.result)
    }

    func testExitMaskCoversTheExitControlAndAdjacentClearMargin() {
        XCTAssertTrue(OriginalCodeNoticeProcess.hitsExitControl(pageX: 35, pageY: 228))
        XCTAssertTrue(OriginalCodeNoticeProcess.hitsExitControl(pageX: 3, pageY: 252))
        XCTAssertTrue(OriginalCodeNoticeProcess.hitsExitControl(pageX: 0, pageY: 224))
        XCTAssertTrue(OriginalCodeNoticeProcess.hitsExitControl(pageX: 19, pageY: 240))
        XCTAssertFalse(OriginalCodeNoticeProcess.hitsExitControl(pageX: 40, pageY: 240))
    }
}
