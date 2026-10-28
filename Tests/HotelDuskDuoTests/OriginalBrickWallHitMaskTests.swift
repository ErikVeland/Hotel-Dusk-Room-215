import XCTest
import simd
@testable import HotelDuskDuoKit

final class OriginalBrickWallHitMaskTests: XCTestCase {
    func testRawTouchUsesOverlayCoordinateOrderForBothOrientationFlags() {
        XCTAssertEqual(OriginalBrickWallProjection.touchViewPoint(
            fromRawTouch: SIMD2(36, 18), orientationFlag: false), SIMD2(18, 219))
        XCTAssertEqual(OriginalBrickWallProjection.touchViewPoint(
            fromRawTouch: SIMD2(36, 18), orientationFlag: true), SIMD2(173, 36))
    }

    func testSourceFaceTrianglesProvideFullMaskAndNearestObjectSelection() {
        let objects = [
            OriginalBrickWallLayout.Object(position: SIMD3(4.5, Float(0x699a) / 4096, 0.8),
                                            scale: SIMD3(2, 1, 1)),
            OriginalBrickWallLayout.Object(position: SIMD3(4.5, Float(0x699a) / 4096, 0.5),
                                            scale: SIMD3(2, 1, 1))
        ]

        for point in [SIMD2<Float>(95, 127), SIMD2<Float>(96, 128), SIMD2<Float>(97, 129)] {
            XCTAssertEqual(OriginalBrickWallHitMask.object(at: point, objects: objects), 0)
        }
        XCTAssertNil(OriginalBrickWallHitMask.object(
            at: SIMD2(0, 0), objects: objects))
    }

    func testSourceRayUsesScreenCentreAndRejectsOutOfBoundsPoints() {
        let ray = OriginalBrickWallTouchRay.ray(at: SIMD2(96, 128))
        XCTAssertEqual(ray?.origin.x ?? 0, 4.5, accuracy: 0.0001)
        XCTAssertEqual(ray?.origin.y ?? 0, Float(0x699a) / 4096, accuracy: 0.0001)
        XCTAssertEqual(ray?.direction.x ?? 1, 0, accuracy: 0.0001)
        XCTAssertEqual(ray?.direction.y ?? 1, 0, accuracy: 0.0001)
        XCTAssertEqual(ray?.direction.z ?? 0, -1, accuracy: 0.0001)
        XCTAssertNil(OriginalBrickWallTouchRay.ray(at: SIMD2(-1, 128)))

        let rightEdgeRay = OriginalBrickWallTouchRay.ray(at: SIMD2(191, 128))
        XCTAssertEqual(rightEdgeRay?.direction.x ?? 0, 0.3381, accuracy: 0.0002)
    }

    func testIsolatedProcessTouchSelectsItsCapturedBrickMask() {
        let rawTouch = SIMD2<Int16>(120, 96)
        let viewPoint = OriginalBrickWallProjection.touchViewPoint(
            fromRawTouch: rawTouch, orientationFlag: false)
        let capturedBrick = OriginalBrickWallLayout.Object(
            position: SIMD3(3.874, 6.5, 0.5), scale: SIMD3(2, 1, 1))

        XCTAssertEqual(OriginalBrickWallHitMask.object(at: viewPoint, objects: [capturedBrick]), 0)
    }

    func testSourceSeedAndBorderTouchesMatchTheCapturedBoard() {
        let objects = OriginalBrickWallLayout.objects(seed: 0x0F2B89E1)
        XCTAssertEqual(objects[0].position.x, -0.85, accuracy: 0.0001)
        XCTAssertEqual(objects[6].position.x, -0.196, accuracy: 0.0001)
        XCTAssertEqual(objects[7].position.x, 1.804, accuracy: 0.0001)
        XCTAssertEqual(objects[13].position.x, 1.008, accuracy: 0.0001)
        XCTAssertEqual(objects[56].position.x, 3.968, accuracy: 0.0001)
        XCTAssertEqual(objects[89].position.x, 9.068, accuracy: 0.0001)

        let sourceSelections: [(SIMD2<Int16>, Int)] = [
            (SIMD2(16, 32), 7),
            (SIMD2(28, 32), 7),
            (SIMD2(30, 28), 13),
            (SIMD2(30, 34), 13)
        ]
        var q12ProbeSelections: [Int?] = []
        for (rawTouch, expectedObject) in sourceSelections {
            let point = OriginalBrickWallProjection.touchViewPoint(
                fromRawTouch: rawTouch, orientationFlag: false)
            XCTAssertEqual(OriginalBrickWallHitMask.object(at: point, objects: objects), expectedObject,
                           "Raw touch: \(rawTouch)")
            q12ProbeSelections.append(OriginalBrickWallQ12Probe.object(at: point, objects: objects))
        }
        XCTAssertEqual(q12ProbeSelections, [6, 6, 6, 7],
                       "The Q12 probe uses a floating-point ray approximation")
    }
}
