import Foundation

/**
 * Uses the source bitmap's alpha channel as an input mask for an apple painting.
 */
public struct OriginalApplePaintingMask: Sendable {
    public let width: Int
    public let height: Int
    private let opaquePixels: [Bool]

    public init(bitmap: OriginalLinearBitmap) {
        width = bitmap.width
        height = bitmap.height
        opaquePixels = bitmap.indices.map { index in
            bitmap.kind == 1 ? index >> 5 != 0 : index != 0
        }
    }

    /**
     * Returns true when the source-space pixel is visible in the bitmap.
     */
    public func contains(_ point: OriginalAlphabetTouchPoint) -> Bool {
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return opaquePixels[y * width + x]
    }
}
