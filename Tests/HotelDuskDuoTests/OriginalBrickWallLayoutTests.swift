import XCTest
@testable import HotelDuskDuoKit

final class OriginalBrickWallLayoutTests: XCTestCase {
    func testOverlay40BuildsNinetySeededBrickTransforms() {
        let objects = OriginalBrickWallLayout.objects(seed: 0x12345678)

        XCTAssertEqual(objects.count, 90)
        XCTAssertEqual(objects[0].position.x, -0.818, accuracy: 0.00001)
        XCTAssertEqual(objects[8].position.x, 3.826, accuracy: 0.00001)
        XCTAssertEqual(objects[8].position.y, 0.5)
        XCTAssertEqual(objects[8].position.z, 0.5)
        XCTAssertEqual(objects[8].scale, SIMD3(2, 1, 1))
    }

    func testOverlay40MovesFourSourceCellsAndModeZeroMaskCells() {
        let objects = OriginalBrickWallLayout.objects(seed: 0x12345678,
                                                       modeZeroFixedCells: [0x01])

        for index in [0, 32, 43, 49, 51] {
            XCTAssertEqual(objects[index].position.y, -1.1, accuracy: 0.00001)
            XCTAssertEqual(objects[index].position.z, 1.1, accuracy: 0.00001)
        }
        XCTAssertEqual(objects[72].position.y, 11.5)
        XCTAssertEqual(objects[72].position.z, 0.5)
    }

    func testDoorwayGateRequiresAllFortyEightSourceCheckedBricksBelowTheWall() {
        let startingObjects = OriginalBrickWallLayout.objects(seed: 0x12345678)
        XCTAssertEqual(OriginalBrickWallLayout.doorwayIndices.count, 48)
        XCTAssertFalse(OriginalBrickWallLayout.doorwayIsClear(startingObjects))

        var movedObjects = startingObjects
        for index in OriginalBrickWallLayout.doorwayIndices {
            let position = movedObjects[index].position
            movedObjects[index] = OriginalBrickWallLayout.Object(
                position: SIMD3(position.x, -1.06, position.z),
                scale: movedObjects[index].scale)
        }
        XCTAssertTrue(OriginalBrickWallLayout.doorwayIsClear(movedObjects))

        movedObjects[44] = startingObjects[44]
        XCTAssertFalse(OriginalBrickWallLayout.doorwayIsClear(movedObjects))
    }
}
