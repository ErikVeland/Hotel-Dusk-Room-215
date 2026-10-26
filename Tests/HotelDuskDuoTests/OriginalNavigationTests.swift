import XCTest
import simd
@testable import HotelDuskDuoKit

final class OriginalNavigationTests: XCTestCase {
    func testCameraRelativeMovementAndTurningInPlace() throws {
        let start = try OriginalMapExploration.bundled()
        let (eye, target) = start.camera
        let forward = simd_normalize(target - eye)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), eye - target))
        for (input, expected) in [(SIMD2<Float>(0, 1), forward), (SIMD2<Float>(0, -1), -forward),
                                  (SIMD2<Float>(1, 0), right), (SIMD2<Float>(-1, 0), -right)] {
            var map = start
            map.update(firstPersonMovement: input)
            XCTAssertGreaterThan(simd_dot(map.position - start.position, expected), 0)
            XCTAssertEqual(map.facing, start.facing, "Strafing and reversing must not turn the camera")
        }
        var turned = start
        turned.turnView(by: -.pi / 2)
        XCTAssertEqual(turned.position, start.position)
        XCTAssertEqual(simd_dot(simd_normalize(turned.camera.target - turned.camera.eye), right), 1, accuracy: 0.001)
        turned.update(firstPersonMovement: SIMD2(0, 1))
        XCTAssertGreaterThan(simd_dot(turned.position - start.position, right), 0)
    }

    func testDiagonalSpeedDeadZoneAndWallCollision() throws {
        let start = try OriginalMapExploration.bundled()
        var straight = start, diagonal = start, idle = start
        straight.update(firstPersonMovement: SIMD2(0, 1))
        diagonal.update(firstPersonMovement: SIMD2(1, 1))
        XCTAssertEqual(simd_distance(diagonal.position, start.position),
                       simd_distance(straight.position, start.position), accuracy: 0.1)
        idle.update(firstPersonMovement: SIMD2(0.05, 0.05))
        idle.update(firstPersonMovement: SIMD2(.nan, 1))
        idle.turnView(by: .infinity)
        XCTAssertEqual(idle.position, start.position)
        XCTAssertEqual(idle.facing, start.facing)
        var map = start
        for direction in [SIMD2<Float>(-1, 0), SIMD2(0, 1), SIMD2(1, 0), SIMD2(0, -1)] {
            for _ in 0..<300 {
                map.update(firstPersonMovement: direction)
                XCTAssertEqual(map.collision.resolve(map.position), map.position)
            }
        }
    }
}
