import XCTest
@testable import HotelDuskDuoKit

final class OriginalBowlingTouchRayTests: XCTestCase {
    private struct CameraTrace: Decodable {
        struct State: Decodable {
            let rawTouchPoint: [Int]?
            let cameraMatrix: [Int32]
            let lanePlaneTemplate20_12: [Int32]
            let laneHitTranslation20_12: [Int32]
            let touchPoint918: [Int32]
        }

        let states: [String: State]
    }

    private struct ProjectionSweep: Decodable {
        struct Sample: Decodable {
            let rawTouchX: Int
            let cameraMatrix: [Int32]
            let processStageAndSubstage: [Int32]
            let touchFlagsAndSelection: [Int32]
            let touchInputWord: Int32
            let ballTransformFixed20_12: [Int32]
            let laneTransformFixed20_12: [Int32]
            let dragDeltaFixed20_12: [Int32]
            let touchPointFixed20_12: [Int32]
            let previousTouchPointFixed20_12: [Int32]
        }

        let rawTouchY: Int
        let samples: [Sample]
    }

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

    func testPlaneTemplatesUseTheLive20_12Translation() {
        let lane = OriginalBowlingTouchRay.translatedVertices(
            OriginalBowlingTouchRay.lanePlaneVertices, byFixed20_12: SIMD3(0, 2_979, 0))
        let ball = OriginalBowlingTouchRay.translatedVertices(
            OriginalBowlingTouchRay.ballPlaneVertices, byFixed20_12: SIMD3(0, 1_556, 10_240))

        XCTAssertEqual(lane[0].y, Float(2_979) / 4_096, accuracy: 0.0001)
        XCTAssertEqual(ball[0].y, Float(1_556) / 4_096 - Float(1_229) / 4_096, accuracy: 0.0001)
        XCTAssertEqual(ball[0].z, 2.5, accuracy: 0.0001)
    }

    func testHeldDragDeltaSubtractsTheBallTransformWithSourceIntegerSemantics() {
        let delta = OriginalBowlingTouchRay.sourceDragDelta20_12(
            touchPoint: SIMD3(-427, 3_145, 11_117),
            ballTransform: SIMD3(0, 1_556, 10_240))

        XCTAssertEqual(delta, SIMD3(-427, 1_589, 877))
        XCTAssertEqual(OriginalBowlingTouchRay.sourceDragDelta20_12(
            touchPoint: SIMD3(Int32.min, 0, 0),
            ballTransform: SIMD3(1, 0, 0)).x, Int32.max)
    }

    func testCapturedTouchRaysReachTheOriginalLaneHitPoints() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(CameraTrace.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/camera-input-trace.json")))

        for name in ["drag-47", "drag-79"] {
            let source = try XCTUnwrap(trace.states[name])
            let rawTouch = try XCTUnwrap(source.rawTouchPoint)
            let camera = try XCTUnwrap(OriginalBowlingCameraBasis(matrixFixed20_12: source.cameraMatrix))
            let pagePoint = try XCTUnwrap(OriginalBowlingTouchRay.pagePoint(
                touchPoint: SIMD2(rawTouch[0], rawTouch[1]), orientation: .unrotated))
            let ray = try XCTUnwrap(OriginalBowlingTouchRay.ray(pagePoint: pagePoint, camera: camera))
            let vertices = OriginalBowlingTouchRay.translatedVertices(
                Self.vertices20_12(source.lanePlaneTemplate20_12),
                byFixed20_12: SIMD3(source.laneHitTranslation20_12[0],
                                    source.laneHitTranslation20_12[1],
                                    source.laneHitTranslation20_12[2]))
            let hit = try XCTUnwrap(OriginalBowlingTouchRay.firstHit(
                origin: ray.origin, direction: ray.direction, vertices: vertices))

            XCTAssertEqual(hit.x, Float(source.touchPoint918[0]) / 4_096, accuracy: 0.1, name)
            XCTAssertEqual(hit.z, Float(source.touchPoint918[2]) / 4_096, accuracy: 0.1, name)
        }
    }

    func testCapturedProjectionSweepRecordsDragAndRollTransition() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let trace = try JSONDecoder().decode(ProjectionSweep.self, from: Data(contentsOf:
            root.appendingPathComponent("Fixtures/Bowling/projection-sweep.json")))

        XCTAssertEqual(trace.rawTouchY, 90)
        XCTAssertEqual(trace.samples.count, 66)
        XCTAssertEqual(trace.samples.map(\.rawTouchX), Array(15..<80) + [87])
        XCTAssertTrue(trace.samples.allSatisfy {
            $0.cameraMatrix.count == 16 &&
                $0.processStageAndSubstage.count == 1 &&
                $0.touchFlagsAndSelection.count == 2 &&
                $0.touchInputWord >= 0 &&
                $0.ballTransformFixed20_12.count == 3 &&
                $0.laneTransformFixed20_12.count == 3 &&
                $0.dragDeltaFixed20_12.count == 6 &&
                $0.previousTouchPointFixed20_12.count == 3
        })
        let initialCamera = try XCTUnwrap(trace.samples.first?.cameraMatrix)
        XCTAssertTrue(trace.samples.allSatisfy { $0.cameraMatrix == initialCamera })
        for rawX in [23, 31, 39, 47, 55, 63, 71] {
            let sample = try XCTUnwrap(trace.samples.first { $0.rawTouchX == rawX })
            XCTAssertEqual(sample.processStageAndSubstage, [65_538])
            let camera = try XCTUnwrap(OriginalBowlingCameraBasis(
                matrixFixed20_12: sample.cameraMatrix))
            let pagePoint = try XCTUnwrap(OriginalBowlingTouchRay.pagePoint(
                touchPoint: SIMD2(rawX, trace.rawTouchY), orientation: .unrotated))
            let ray = try XCTUnwrap(OriginalBowlingTouchRay.ray(
                pagePoint: pagePoint, camera: camera))
            let vertices = OriginalBowlingTouchRay.translatedVertices(
                OriginalBowlingTouchRay.lanePlaneVertices,
                byFixed20_12: SIMD3(sample.laneTransformFixed20_12[0],
                                    sample.laneTransformFixed20_12[1],
                                    sample.laneTransformFixed20_12[2]))
            let hit = try XCTUnwrap(OriginalBowlingTouchRay.firstHit(
                origin: ray.origin, direction: ray.direction, vertices: vertices))

            XCTAssertEqual(hit.x, Float(sample.touchPointFixed20_12[0]) / 4_096,
                           accuracy: 0.1, "raw X \(rawX)")
            XCTAssertEqual(hit.z, Float(sample.touchPointFixed20_12[2]) / 4_096,
                           accuracy: 0.1, "raw X \(rawX)")
        }
        let drag47 = try XCTUnwrap(trace.samples.first { $0.rawTouchX == 47 })
        let roll79 = try XCTUnwrap(trace.samples.first { $0.rawTouchX == 79 })
        let roll87 = try XCTUnwrap(trace.samples.first { $0.rawTouchX == 87 })
        XCTAssertEqual(drag47.touchPointFixed20_12, [-516, 1_556, 8_529])
        XCTAssertEqual(roll79.processStageAndSubstage, [131_074])
        XCTAssertEqual(roll87.processStageAndSubstage, [131_074])
        XCTAssertEqual(roll87.touchPointFixed20_12, roll79.touchPointFixed20_12)
    }

    func testDragAnchorRequiresBallSelectionThenLaneAnchor() throws {
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

    private static func vertices20_12(_ values: [Int32]) -> [SIMD3<Float>] {
        stride(from: 0, to: values.count, by: 3).map { index in
            SIMD3(Float(values[index]), Float(values[index + 1]), Float(values[index + 2])) / 4_096
        }
    }
}
