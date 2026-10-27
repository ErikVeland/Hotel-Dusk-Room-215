import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingTouchRayTests: XCTestCase {
    func testCameraBasisUsesProcessFixedPointPositionTargetAndHints() throws {
        let camera = try XCTUnwrap(OriginalBowlingCameraBasis(matrixFixed20_12: [
            0, 12_288, 21_709, 0, 2_048, -43_827, 0, 0,
            0, -4_096, 0, 0, 0, 4_096, 0, 0
        ]))

        XCTAssertEqual(camera.origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(camera.origin.y, 3, accuracy: 0.0001)
        XCTAssertEqual(camera.origin.z, 5.3, accuracy: 0.001)
        XCTAssertEqual(camera.right.x, 1, accuracy: 0.0001)
        XCTAssertEqual(camera.up.y, 0.987, accuracy: 0.002)
        XCTAssertEqual(camera.forward.z, -0.988, accuracy: 0.002)
    }

    func testCameraBasisTracksTheSecondSourceCameraMode() throws {
        let camera = try XCTUnwrap(OriginalBowlingCameraBasis(matrixFixed20_12: [
            0, 8_192, -12_288, 0, 0, -22_528, 0, 0,
            0, -4_096, 0, 0, 0, 4_096, 0, 0
        ]))

        XCTAssertEqual(camera.origin.y, 2, accuracy: 0.0001)
        XCTAssertEqual(camera.origin.z, -3, accuracy: 0.0001)
        XCTAssertEqual(camera.forward.y, -0.625, accuracy: 0.002)
        XCTAssertEqual(camera.forward.z, -0.781, accuracy: 0.002)
        XCTAssertEqual(camera.right.x, 1, accuracy: 0.0001)
        XCTAssertEqual(camera.up.y, 0.781, accuracy: 0.002)
        XCTAssertEqual(camera.up.z, -0.625, accuracy: 0.002)
    }

    func testCameraMatrixProducesAWorldSpaceTouchRay() throws {
        let camera = try XCTUnwrap(OriginalBowlingCameraBasis(matrixFixed20_12: [
            0, 12_288, 21_709, 0, 2_048, -43_827, 0, 0,
            0, -4_096, 0, 0, 0, 4_096, 0, 0
        ]))
        let ray = try XCTUnwrap(OriginalBowlingTouchRay.ray(pagePoint: SIMD2(96, 128), camera: camera))

        XCTAssertEqual(ray.origin, camera.origin)
        XCTAssertEqual(ray.direction.x, camera.forward.x, accuracy: 0.0001)
        XCTAssertEqual(ray.direction.y, camera.forward.y, accuracy: 0.0001)
        XCTAssertEqual(ray.direction.z, camera.forward.z, accuracy: 0.0001)
    }

    func testRawTouchCoordinatesMapToPortraitPageByScreenOrientation() throws {
        let rotated = try XCTUnwrap(OriginalBowlingTouchRay.pagePoint(
            touchPoint: SIMD2(10, 105), orientation: .rotated))
        let unrotated = try XCTUnwrap(OriginalBowlingTouchRay.pagePoint(
            touchPoint: SIMD2(10, 105), orientation: .unrotated))

        XCTAssertEqual(rotated, SIMD2(86, 10))
        XCTAssertEqual(unrotated, SIMD2(105, 245))
    }

    func testRawTouchCoordinateMappingRejectsPointsOutsideTheDSDisplay() {
        XCTAssertNil(OriginalBowlingTouchRay.pagePoint(
            touchPoint: SIMD2(256, 0), orientation: .rotated))
        XCTAssertNil(OriginalBowlingTouchRay.pagePoint(
            touchPoint: SIMD2(0, 192), orientation: .unrotated))
    }

    func testRawTouchBuildsRayThroughTheMappedPortraitPoint() throws {
        let fromRawTouch = try XCTUnwrap(OriginalBowlingTouchRay.direction(
            touchPoint: SIMD2(96, 127), orientation: .unrotated,
            right: SIMD3(1, 0, 0), up: SIMD3(0, 1, 0), forward: SIMD3(0, 0, -1)))
        let fromPagePoint = try XCTUnwrap(OriginalBowlingTouchRay.direction(
            pagePoint: SIMD2(127, 159), right: SIMD3(1, 0, 0),
            up: SIMD3(0, 1, 0), forward: SIMD3(0, 0, -1)))

        XCTAssertEqual(fromRawTouch.x, fromPagePoint.x, accuracy: 0.0001)
        XCTAssertEqual(fromRawTouch.y, fromPagePoint.y, accuracy: 0.0001)
        XCTAssertEqual(fromRawTouch.z, fromPagePoint.z, accuracy: 0.0001)
    }

    func testCentreTouchFollowsCameraForward() {
        let ray = OriginalBowlingTouchRay.direction(
            pagePoint: SIMD2(96, 128), right: SIMD3(1, 0, 0),
            up: SIMD3(0, 1, 0), forward: SIMD3(0, 0, -1))

        XCTAssertEqual(ray?.x ?? 1, 0, accuracy: 0.0001)
        XCTAssertEqual(ray?.y ?? 1, 0, accuracy: 0.0001)
        XCTAssertEqual(ray?.z ?? 1, -1, accuracy: 0.0001)
    }

    func testTopAndRightEdgesFollowViewportAndAspect() throws {
        let top = try XCTUnwrap(OriginalBowlingTouchRay.direction(
            pagePoint: SIMD2(96, 0), right: SIMD3(1, 0, 0),
            up: SIMD3(0, 1, 0), forward: SIMD3(0, 0, -1)))
        let right = try XCTUnwrap(OriginalBowlingTouchRay.direction(
            pagePoint: SIMD2(192 - 0.01, 128), right: SIMD3(1, 0, 0),
            up: SIMD3(0, 1, 0), forward: SIMD3(0, 0, -1)))

        XCTAssertGreaterThan(top.y, 0)
        XCTAssertGreaterThan(right.x, 0)
        XCTAssertGreaterThan(top.y, right.x)
        let length = sqrt(right.x * right.x + right.y * right.y + right.z * right.z)
        XCTAssertEqual(length, 1, accuracy: 0.0001)
    }

    func testRejectsPointsOutsideOriginalViewport() {
        XCTAssertNil(OriginalBowlingTouchRay.direction(
            pagePoint: SIMD2(192, 128), right: SIMD3(1, 0, 0),
            up: SIMD3(0, 1, 0), forward: SIMD3(0, 0, -1)))
    }

    func testRayFindsTheFirstOfTheTwoSourceHitTriangles() {
        let vertices = [
            SIMD3<Float>(-1, -1, -4), SIMD3<Float>(1, -1, -4), SIMD3<Float>(-1, 1, -4),
            SIMD3<Float>(1, -1, -4), SIMD3<Float>(1, 1, -4), SIMD3<Float>(-1, 1, -4)
        ]
        let hit = OriginalBowlingTouchRay.firstHit(
            origin: .zero, direction: SIMD3(0, 0, -1), vertices: vertices)

        XCTAssertEqual(hit?.x ?? 9, 0, accuracy: 0.0001)
        XCTAssertEqual(hit?.y ?? 9, 0, accuracy: 0.0001)
        XCTAssertEqual(hit?.z ?? 9, -4, accuracy: 0.0001)
    }

    func testRayMissesOutsideTrianglesAndBehindTheOrigin() {
        let vertices = [
            SIMD3<Float>(-1, -1, -4), SIMD3<Float>(1, -1, -4), SIMD3<Float>(-1, 1, -4),
            SIMD3<Float>(1, -1, -4), SIMD3<Float>(1, 1, -4), SIMD3<Float>(-1, 1, -4)
        ]
        XCTAssertNil(OriginalBowlingTouchRay.firstHit(
            origin: .zero, direction: SIMD3(2, 0, -1), vertices: vertices))
        XCTAssertNil(OriginalBowlingTouchRay.firstHit(
            origin: .zero, direction: SIMD3(0, 0, 1), vertices: vertices))
    }

    func testRecoveredLaneAndBallPlanesAcceptTheirCentralHit() {
        let laneHit = OriginalBowlingTouchRay.firstHit(
            origin: SIMD3<Float>(0, 2, 0), direction: SIMD3(0, -1, 0),
            vertices: OriginalBowlingTouchRay.lanePlaneVertices)
        let ballHit = OriginalBowlingTouchRay.firstHit(
            origin: SIMD3<Float>(0, 0, 1), direction: SIMD3(0, 0, -1),
            vertices: OriginalBowlingTouchRay.ballPlaneVertices)

        XCTAssertEqual(laneHit?.y ?? 9, 0, accuracy: 0.0001)
        XCTAssertEqual(ballHit?.z ?? 9, 0, accuracy: 0.0001)
    }

    func testDragAnchorRequiresLaneThenBallPlaneHits() throws {
        let lane: [SIMD3<Float>] = [
            SIMD3(-1, 0, 0), SIMD3(1, 0, 0), SIMD3(-1, 0, 1),
            SIMD3(1, 0, 0), SIMD3(-1, 0, 1), SIMD3(1, 0, 1)
        ]
        let ball: [SIMD3<Float>] = [
            SIMD3(-1, -1, 0.5), SIMD3(1, -1, 0.5), SIMD3(-1, 1, 0.5),
            SIMD3(1, -1, 0.5), SIMD3(-1, 1, 0.5), SIMD3(1, 1, 0.5)
        ]
        let anchor = try XCTUnwrap(OriginalBowlingTouchRay.dragAnchor(
            origin: SIMD3(0, 2, 2), direction: SIMD3(0, -1, -1),
            laneVertices: lane, ballVertices: ball))

        XCTAssertEqual(anchor.lanePoint.x, 0, accuracy: 0.0001)
        XCTAssertEqual(anchor.lanePoint.y, 0, accuracy: 0.0001)
        XCTAssertEqual(anchor.lanePoint.z, 0, accuracy: 0.0001)
        XCTAssertEqual(anchor.ballPoint.x, 0, accuracy: 0.0001)
        XCTAssertEqual(anchor.ballPoint.y, 0.5, accuracy: 0.0001)
        XCTAssertEqual(anchor.ballPoint.z, 0.5, accuracy: 0.0001)
    }

    func testDragAnchorRejectsTouchOutsideTheLaneEvenIfItHitsBallPlane() {
        let lane = OriginalBowlingTouchRay.lanePlaneVertices
        let ball: [SIMD3<Float>] = [
            SIMD3(-30, -30, 0.5), SIMD3(30, -30, 0.5), SIMD3(-30, 30, 0.5),
            SIMD3(30, -30, 0.5), SIMD3(-30, 30, 0.5), SIMD3(30, 30, 0.5)
        ]

        XCTAssertNil(OriginalBowlingTouchRay.dragAnchor(
            origin: SIMD3(20, 2, 2), direction: SIMD3(0, -1, -1),
            laneVertices: lane, ballVertices: ball))
    }
}
