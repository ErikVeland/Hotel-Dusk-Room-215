import Foundation
import simd

/**
 * Builds the source transforms for overlay 40's brick-wall board.
 */
struct OriginalBrickWallLayout: Sendable {
    struct Object: Equatable, Sendable {
        let position: SIMD3<Float>
        let scale: SIMD3<Float>
    }

    static let objectCount = 90
    static let doorwayIndices = (0..<12).flatMap { row in
        (1..<5).map { row * 6 + $0 }
    }
    private static let specialIndices = [32, 43, 49, 51]
    private static let randomMultiplier: UInt32 = 0x5D588B65
    private static let randomIncrement: UInt32 = 0x00269EC3
    private static let randomRadius = Float(bitPattern: 0x3B03126F)
    private static let specialY = Float(bitPattern: 0xBF8CCCCD)
    private static let specialZ = Float(bitPattern: 0x3F8CCCCD)

    /**
     * Returns source transforms for the given random state and fixed-cell mask.
     * The mode-0 mask contains nine bytes. A set bit marks a fixed cell.
     */
    static func objects(seed: UInt32, modeZeroFixedCells: [UInt8] = []) -> [Object] {
        var random = seed
        var objects: [Object] = []
        objects.reserveCapacity(objectCount)

        for row in 0..<15 {
            random = random &* randomMultiplier &+ randomIncrement
            let randomHundred = ((random >> 16) * 100) >> 16
            let radius = Float(randomHundred) * randomRadius

            for column in 0..<6 {
                let index = row * 6 + column
                let horizontal = 2 * column
                let rowOffset = row.isMultiple(of: 2) ? -1 + radius : -radius
                objects.append(Object(
                    position: SIMD3(Float(horizontal) + rowOffset,
                                    Float(row) - 0.5, 0.5),
                    scale: SIMD3(2, 1, 1)))

                let isModeZeroFixed = index < 72 &&
                    modeZeroFixedCells.indices.contains(index / 8) &&
                    modeZeroFixedCells[index / 8] & (1 << (index % 8)) != 0
                if specialIndices.contains(index) || isModeZeroFixed {
                    objects[index] = Object(
                        position: SIMD3(objects[index].position.x, specialY, specialZ),
                        scale: objects[index].scale)
                }
            }
        }
        return objects
    }

    /**
     * Returns true when every source-checked doorway brick has moved below the wall.
     */
    static func doorwayIsClear(_ objects: [Object]) -> Bool {
        guard objects.count == objectCount else { return false }
        return doorwayIndices.allSatisfy { objects[$0].position.y < -1 }
    }
}
