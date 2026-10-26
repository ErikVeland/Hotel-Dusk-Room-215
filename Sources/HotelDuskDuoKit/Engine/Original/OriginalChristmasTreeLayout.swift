import Foundation
import simd

/**
 * Stores the ornament positions and placement threshold from overlay 13.
 */
public enum OriginalChristmasTreeLayout {
    public static let decorationTargets: [SIMD2<Float>] = [
        SIMD2(48, 306), SIMD2(121, 200), SIMD2(108, 104), SIMD2(119, 334),
        SIMD2(187, 189), SIMD2(62, 167), SIMD2(197, 294), SIMD2(191, 349),
        SIMD2(92, 272), SIMD2(141, 141), SIMD2(128, 24)
    ]

    /**
     * Converts the raw target points as overlay 13 initialises them at 0x021FCC5C.
     */
    public static let modelDecorationTargets = decorationTargets.map { target in
        SIMD2((target.x - 128) / 96, (384 - target.y) / 128)
    }

    /**
     * Fits the overlay's 256×384 target plane to the native 192×256 page.
     */
    public static let pageDecorationTargets = decorationTargets.map { target in
        SIMD2(target.x * 0.75, target.y * (256.0 / 384.0))
    }

    /**
     * Returns the nearest target within the visible ornament's touch margin.
     */
    public static func decorationTarget(at point: SIMD2<Float>, margin: Float = 12) -> Int? {
        guard point.x.isFinite, point.y.isFinite, margin.isFinite, margin >= 0 else { return nil }
        let marginSquared = margin * margin
        return pageDecorationTargets.indices
            .map { ($0, simd_distance_squared(point, pageDecorationTargets[$0])) }
            .filter { $0.1 <= marginSquared }
            .min { $0.1 < $1.1 }?.0
    }

    /**
     * Converts a 192×256 page touch to the clip coordinates used by overlay 13.
     * Source helpers 0x021FD3F8 and 0x021FD43C apply these transforms.
     */
    public static func clipPoint(forPagePoint point: SIMD2<Float>) -> SIMD2<Float>? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return SIMD2(point.x / 96 - 1, 1 - point.y / 128)
    }

    /**
     * Applies the overlay's page-touch delta to a selected model position.
     */
    public static func draggedModelPoint(
        startingAt modelPoint: SIMD2<Float>,
        from startPagePoint: SIMD2<Float>,
        to pagePoint: SIMD2<Float>
    ) -> SIMD2<Float>? {
        guard let start = clipPoint(forPagePoint: startPagePoint),
              let current = clipPoint(forPagePoint: pagePoint),
              modelPoint.x.isFinite, modelPoint.y.isFinite else { return nil }
        return modelPoint + current - start
    }

    /**
     * Decodes the source ordering from game-state offset 0x13DA.
     * Overlay helper 0x02201830 reads +0xDA from the state pointer at 0x0211148C
     * and uses three swap bits and four packed indices.
     */
    public static func decorationOrder(encodedOrder: UInt16) -> [Int] {
        guard encodedOrder != 0 else { return Array(0..<11) }
        let firstPair = encodedOrder & 1 == 0 ? [0, 1] : [1, 0]
        let secondPair = encodedOrder & 2 == 0 ? [2, 3] : [3, 2]
        let finalPair = encodedOrder & 4 == 0 ? [8, 9] : [9, 8]
        let middle = (0..<4).map { shift in
            Int((encodedOrder >> UInt16(8 + shift * 2)) & 3) + 4
        }
        return firstPair + secondPair + middle + finalPair + [10]
    }

    /**
     * Encodes a completed ornament order using overlay callback 0x02201778.
     */
    public static func encodedDecorationOrder(_ order: [Int]) -> UInt16? {
        guard order.count == 11, Set(order) == Set(0..<11), order[10] == 10,
              Set(order[0..<2]) == Set([0, 1]), Set(order[2..<4]) == Set([2, 3]),
              Set(order[8..<10]) == Set([8, 9]) else { return nil }

        var encoded: UInt16 = 0
        if order[0] == 1 { encoded |= 1 }
        if order[2] == 3 { encoded |= 2 }
        if order[8] == 9 { encoded |= 4 }
        for index in 0..<4 {
            encoded |= UInt16(order[index + 4] - 4) << UInt16(8 + index * 2)
        }
        return encoded
    }

    /**
     * Checks the source squared-distance threshold of 0.0625.
     */
    public static func isPlaced(_ position: SIMD2<Float>, at targetIndex: Int) -> Bool {
        guard modelDecorationTargets.indices.contains(targetIndex),
              position.x.isFinite, position.y.isFinite else { return false }
        let offset = position - modelDecorationTargets[targetIndex]
        return simd_length_squared(offset) < 0.0625
    }
}
