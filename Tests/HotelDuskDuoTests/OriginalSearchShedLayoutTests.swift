import XCTest
@testable import HotelDuskDuoKit

final class OriginalSearchShedLayoutTests: XCTestCase {
    func testInitialObjectsMatchOverlayThirtyTransforms() throws {
        let objects = OriginalSearchShedLayout.objects
        XCTAssertEqual(objects.count, 26)
        XCTAssertEqual(objects[0].position, SIMD3(1, 1.5, -0.5))
        XCTAssertEqual(objects[2].scale, SIMD3(1, 1, 2))
        XCTAssertEqual(objects[7].scale, SIMD3(1, 2, 1))
        XCTAssertEqual(objects[9].position, SIMD3(-1, 0.5, -3.5))
        XCTAssertEqual(objects[9].scale, SIMD3(1, 3, 1))
        XCTAssertEqual(objects[15].scale, SIMD3(1, 1, 2))
        XCTAssertEqual(objects[25].position, SIMD3(-1, 0.5, 0.5))
    }
}
