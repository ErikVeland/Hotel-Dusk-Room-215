import XCTest
import simd
@testable import HotelDuskDuoKit

final class OriginalBrickWallHitMaskTests: XCTestCase {
    private struct ProcessTapCapture: Decodable {
        struct CapturedObject: Decodable {
            let position: [Float]
            let scale: [Float]

            var model: OriginalBrickWallLayout.Object {
                OriginalBrickWallLayout.Object(
                    position: SIMD3(position[0], position[1], position[2]),
                    scale: SIMD3(scale[0], scale[1], scale[2]))
            }
        }

        let touchView: [Float]
        let selectedObject: Int
        let objects: [CapturedObject]
    }

    private struct ProcessScanCapture: Decodable {
        struct Sample: Decodable {
            let raw: [Int]
            let selected: Int
        }

        let orientationFlag: Bool
        let objects: [ProcessTapCapture.CapturedObject]
        let samples: [Sample]
    }

    private struct ReproducibleScanCapture: Decodable {
        struct Sample: Decodable {
            let raw: [Int]
            let selected: Int
        }

        struct FocusedScan: Decodable {
            let name: String
            let samples: [Sample]
        }

        let orientationFlag: Bool
        let objects: [ProcessTapCapture.CapturedObject]
        let samples: [Sample]
        let focusedScans: [FocusedScan]
    }

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

    func testSourceHitMaskIncludesTheRightSideWhenTheFrontFaceMisses() throws {
        let brick = OriginalBrickWallLayout.Object(
            position: SIMD3(0, 1.5, 0.5), scale: SIMD3(2, 1, 1))
        let point = SIMD2<Float>(38, 213)
        let ray = try XCTUnwrap(OriginalBrickWallTouchRay.ray(at: point))
        let frontZ = brick.position.z + brick.scale.z / 2
        let frontDistance = (frontZ - ray.origin.z) / ray.direction.z
        let frontX = ray.origin.x + ray.direction.x * frontDistance
        let sideX = brick.position.x + brick.scale.x / 2
        let sideDistance = (sideX - ray.origin.x) / ray.direction.x
        let sideY = ray.origin.y + ray.direction.y * sideDistance
        let sideZ = ray.origin.z + ray.direction.z * sideDistance

        XCTAssertGreaterThan(frontX, sideX, "The ray must miss the front face.")
        XCTAssertTrue(
            (brick.position.y - brick.scale.y / 2...brick.position.y + brick.scale.y / 2).contains(sideY))
        XCTAssertTrue(
            (brick.position.z - brick.scale.z / 2...brick.position.z + brick.scale.z / 2).contains(sideZ))
        XCTAssertEqual(OriginalBrickWallHitMask.object(
            at: point, objects: [brick]), 0)
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

    func testProjectedCapturedBrickContainsItsSourceSelectedTap() throws {
        let brick = OriginalBrickWallLayout.Object(
            position: SIMD3(3.874, 6.5, 0.5), scale: SIMD3(2, 1, 1))
        let face = try OriginalBrickWallHitMask.faceVertices.prefix(6).map { vertex in
            try XCTUnwrap(OriginalBrickWallProjection.screenPoint(brick.position + vertex * brick.scale))
        }
        let minX = try XCTUnwrap(face.map(\.x).min())
        let maxX = try XCTUnwrap(face.map(\.x).max())
        let minY = try XCTUnwrap(face.map(\.y).min())
        let maxY = try XCTUnwrap(face.map(\.y).max())
        XCTAssertTrue((minX...maxX).contains(96))
        XCTAssertTrue((minY...maxY).contains(135))
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

    func testDiagnosticMaskMatchesFreshIsolatedProcessTap() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let fixture = root.appendingPathComponent("Fixtures/BrickWall/process-75-one-tap.json")
        let capture = try JSONDecoder().decode(ProcessTapCapture.self, from: Data(contentsOf: fixture))
        let objects = capture.objects.map(\.model)

        XCTAssertEqual(objects.count, OriginalBrickWallLayout.objectCount)
        XCTAssertEqual(OriginalBrickWallHitMask.object(
            at: SIMD2(capture.touchView[0], capture.touchView[1]), objects: objects),
            capture.selectedObject)
    }

    func testFullScreenScanRecordsCurrentMaskFalsePositiveGap() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let fixture = root.appendingPathComponent("Fixtures/BrickWall/process-75-independent-screen-scan.json")
        let capture = try JSONDecoder().decode(ProcessScanCapture.self, from: Data(contentsOf: fixture))
        let objects = capture.objects.map(\.model)
        var sourceHits = 0
        var floatHits = 0
        var floatSourceHitMatches = 0
        var q12Hits = 0
        var q12SourceIDMatches = 0
        var sourceObjectIDs = Set<Int>()

        for sample in capture.samples {
            let raw = SIMD2(Int16(sample.raw[0]), Int16(sample.raw[1]))
            let point = OriginalBrickWallProjection.touchViewPoint(
                fromRawTouch: raw, orientationFlag: capture.orientationFlag)
            let sourceHit = sample.selected >= 0
            let floatHit = OriginalBrickWallHitMask.object(at: point, objects: objects)
            let q12Hit = OriginalBrickWallQ12Probe.object(at: point, objects: objects)
            if sourceHit {
                sourceHits += 1
                sourceObjectIDs.insert(sample.selected)
            }
            if floatHit != nil { floatHits += 1 }
            if sourceHit && floatHit != nil { floatSourceHitMatches += 1 }
            if q12Hit != nil { q12Hits += 1 }
            if q12Hit == sample.selected { q12SourceIDMatches += 1 }
        }

        XCTAssertEqual(capture.samples.count, 768)
        XCTAssertEqual(sourceHits, 68)
        XCTAssertEqual(floatHits, 736)
        XCTAssertEqual(floatSourceHitMatches, sourceHits)
        XCTAssertEqual(q12Hits, 736)
        XCTAssertEqual(q12SourceIDMatches, sourceHits)
        XCTAssertEqual(sourceObjectIDs.count, 16)
        XCTAssertTrue(sourceObjectIDs.allSatisfy { [2, 3].contains($0 % 6) })
    }

    func testReproducibleProcessScanFindsThinSourceHitBand() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let fixture = root.appendingPathComponent("Fixtures/BrickWall/process-75-reproducible-scan.json")
        let capture = try JSONDecoder().decode(ReproducibleScanCapture.self, from: Data(contentsOf: fixture))
        let objects = capture.objects.map(\.model)
        let centre = try XCTUnwrap(capture.focusedScans.first { $0.name == "centre-2px-grid" })
        let vertical = try XCTUnwrap(capture.focusedScans.first { $0.name == "raw-x-sweep-at-centre-raw-y" })
        let centreHits = centre.samples.filter { $0.selected >= 0 }
        let verticalHits = vertical.samples.filter { $0.selected >= 0 }
        let coarseMaskHits = capture.samples.filter { sample in
            let point = OriginalBrickWallProjection.touchViewPoint(
                fromRawTouch: SIMD2(Int16(sample.raw[0]), Int16(sample.raw[1])),
                orientationFlag: capture.orientationFlag)
            return OriginalBrickWallHitMask.object(at: point, objects: objects) != nil
        }

        XCTAssertEqual(capture.samples.count, 768)
        XCTAssertEqual(capture.samples.filter { $0.selected >= 0 }.count, 0)
        XCTAssertEqual(coarseMaskHits.count, 738)
        XCTAssertEqual(centre.samples.count, 221)
        XCTAssertEqual(centreHits.count, 13)
        XCTAssertEqual(Set(centreHits.map { $0.raw[1] }), [96])
        XCTAssertEqual(Set(centreHits.map(\.selected)), [39, 44])
        XCTAssertEqual(vertical.samples.count, 126)
        XCTAssertEqual(verticalHits.count, 108)
        XCTAssertEqual(Set(verticalHits.map(\.selected)), [3, 8, 15, 20, 27, 39, 44, 56, 63, 68, 75, 80, 87])
    }

}
