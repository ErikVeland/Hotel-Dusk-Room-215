import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalPencilSharpenerProcessTests: XCTestCase {
    func testCapturedQuitTouchStartsTheExitAnimation() {
        var process = OriginalPencilSharpenerProcess()

        XCTAssertTrue(process.tap(pageX: 19, pageY: 15))
        XCTAssertEqual(process.phase, .exitAnimation)
        XCTAssertNil(process.returnedProcessValue)
    }

    func testCapturedRawExitTouchMapsToThePortraitMask() throws {
        let pagePoint = try XCTUnwrap(OriginalPencilSharpenerProcess.pagePoint(rawTouch: SIMD2(15, 172)))
        XCTAssertEqual(pagePoint, SIMD2(19, 15))
        XCTAssertTrue(OriginalPencilSharpenerProcess.containsExitMask(pageX: pagePoint.x, pageY: pagePoint.y))
        XCTAssertNil(OriginalPencilSharpenerProcess.pagePoint(rawTouch: SIMD2(256, 172)))
    }

    func testExitReturnsSourceValueTwoAfterSixtyUpdates() {
        var process = OriginalPencilSharpenerProcess()
        XCTAssertTrue(process.tap(pageX: 19, pageY: 15))

        for _ in 0..<(OriginalPencilSharpenerProcess.exitAnimationFrames - 1) {
            process.updateOneFrame()
        }
        XCTAssertNil(process.returnedProcessValue)

        process.updateOneFrame()
        XCTAssertEqual(process.phase, .complete)
        XCTAssertEqual(process.returnedProcessValue, 2)
    }

    func testRoundedExitMaskRejectsPointsOutsideTheIcon() {
        XCTAssertTrue(OriginalPencilSharpenerProcess.containsExitMask(pageX: 19, pageY: 15))
        XCTAssertFalse(OriginalPencilSharpenerProcess.containsExitMask(pageX: 3, pageY: 3))
        XCTAssertFalse(OriginalPencilSharpenerProcess.containsExitMask(pageX: 36, pageY: 15))
        XCTAssertFalse(OriginalPencilSharpenerProcess.containsExitMask(pageX: 19, pageY: 28))
    }

    func testRendererLoadsTheCapturedPortraitScene() throws {
        let renderer = try OriginalPencilSharpenerRenderer()
        XCTAssertEqual(renderer.image.width, 192)
        XCTAssertEqual(renderer.image.height, 256)
    }

}
