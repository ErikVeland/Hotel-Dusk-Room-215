import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingTurnProcessTests: XCTestCase {
    func testCapturedCentreRollDragLaunchesWithGroundPlaneVelocity() throws {
        var process = OriginalBowlingTurnProcess(ballPositionFixed20_12: SIMD3(0, 1_556, 10_240))
        let camera = try XCTUnwrap(OriginalBowlingCameraBasis(matrixFixed20_12: [
            0, 12_288, 21_709, 0, 2_048, -43_827, 0, 0,
            0, -4_096, 0, 0, 0, 4_096, 0, 0
        ]))

        XCTAssertTrue(process.beginDrag(pagePoint: SIMD2(90, 240), camera: camera, ballHit: true))
        for rawX in stride(from: 23, through: 119, by: 8) {
            process.moveDrag(pagePoint: SIMD2(90, Float(255 - rawX)), camera: camera)
        }
        process.moveDrag(pagePoint: SIMD2(90, 130), camera: camera)

        XCTAssertEqual(process.latestDragDeltas, [SIMD3(-82, 1_467, -2_341), SIMD3(-61, 1_467, -1_755)])
        XCTAssertTrue(process.endDrag())
        XCTAssertEqual(process.phase, .rolling)
        XCTAssertEqual(process.simulation.ballMotion.state.velocityFixed20_12, SIMD3(-71, 0, -819))
    }

    func testBallMaskMissDoesNotBeginDrag() throws {
        var process = OriginalBowlingTurnProcess(ballPositionFixed20_12: SIMD3(0, 1_556, 10_240))
        let camera = try XCTUnwrap(OriginalBowlingCameraBasis(matrixFixed20_12: [
            0, 12_288, 21_709, 0, 2_048, -43_827, 0, 0,
            0, -4_096, 0, 0, 0, 4_096, 0, 0
        ]))

        XCTAssertFalse(process.beginDrag(pagePoint: SIMD2(40, 30), camera: camera, ballHit: false))
        XCTAssertEqual(process.phase, .ready)
    }
}
