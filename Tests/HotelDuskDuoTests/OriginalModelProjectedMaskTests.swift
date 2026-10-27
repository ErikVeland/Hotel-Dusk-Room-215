import Foundation
import simd
import XCTest
@testable import HotelDuskDuoKit

final class OriginalModelProjectedMaskTests: XCTestCase {
    func testCassetteMeshesProduceScreenSpaceSilhouetteMasks() throws {
        let models = try OriginalModelLibrary.bundled()
        let projection = simd_float4x4(columns: (
            SIMD4<Float>(0.45, 0, 0, 0), SIMD4<Float>(0, 0.45, 0, 0),
            SIMD4<Float>(0, 0, 0.1, 0), SIMD4<Float>(0, 0, 0, 1)))

        for path in ["trick/cassette/tape.mdf", "trick/cassette/pencil.mdf", "trick/cassette/ballpen.mdf"] {
            let model = try models.load(path: path)
            let mask = try OriginalModelProjectedMask(model: model, viewProjection: projection,
                                                       width: 256, height: 192)
            XCTAssertGreaterThan(mask.triangleCount, 0, path)
            XCTAssertFalse(mask.bounds.isNull, path)
            XCTAssertFalse(mask.contains(SIMD2(-1, -1)), path)

            let startX = max(0, Int(mask.bounds.minX))
            let endX = min(255, Int(mask.bounds.maxX))
            let startY = max(0, Int(mask.bounds.minY))
            let endY = min(191, Int(mask.bounds.maxY))
            let hit = (startY...endY).contains { y in
                (startX...endX).contains { x in mask.contains(SIMD2(Float(x) + 0.5, Float(y) + 0.5)) }
            }
            XCTAssertTrue(hit, path)
        }
    }

    func testProjectedMaskPaddingExpandsEdgesWithoutChangingTheMesh() throws {
        let model = try OriginalModelLibrary.bundled().load(path: "trick/cassette/tape.mdf")
        let projection = simd_float4x4(columns: (
            SIMD4<Float>(0.1, 0, 0, 0), SIMD4<Float>(0, 0.1, 0, 0),
            SIMD4<Float>(0, 0, 0.1, 0), SIMD4<Float>(0, 0, 0, 1)))
        let mask = try OriginalModelProjectedMask(model: model, viewProjection: projection,
                                                  width: 256, height: 192)
        let edge = SIMD2(Float(mask.bounds.minX) - 0.5, Float(mask.bounds.midY))
        XCTAssertFalse(mask.contains(edge))
        XCTAssertTrue(mask.contains(edge, padding: 2))
    }
}
