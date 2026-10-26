import Foundation
import simd

/**
 * Tracks the eleven ornament drops checked by overlay 13.
 */
public struct OriginalChristmasTreeArrangement: Equatable, Sendable {
    public private(set) var decorationAtTarget: [Int?] = Array(repeating: nil, count: 11)

    public init() {}

    public var isComplete: Bool { encodedOrder != nil }
    public var placedCount: Int { decorationAtTarget.compactMap { $0 }.count }

    public func contains(_ decoration: Int) -> Bool { decorationAtTarget.contains(decoration) }

    public var encodedOrder: UInt16? {
        guard decorationAtTarget.allSatisfy({ $0 != nil }) else { return nil }
        return OriginalChristmasTreeLayout.encodedDecorationOrder(decorationAtTarget.compactMap { $0 })
    }

    /**
     * Records a decoration when its released model point is inside a source target.
     */
    @discardableResult
    public mutating func drop(decoration: Int, at position: SIMD2<Float>) -> Int? {
        guard (0..<decorationAtTarget.count).contains(decoration),
              let target = OriginalChristmasTreeLayout.decorationTargets.indices.first(where: {
                  OriginalChristmasTreeLayout.isPlaced(position, at: $0)
              }) else { return nil }

        for index in decorationAtTarget.indices where decorationAtTarget[index] == decoration {
            decorationAtTarget[index] = nil
        }
        decorationAtTarget[target] = decoration
        return target
    }
}
