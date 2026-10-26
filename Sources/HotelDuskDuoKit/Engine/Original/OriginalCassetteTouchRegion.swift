import Foundation

/**
 * Maps DS touch points and checks the cassette process's source tap region.
 */
public enum OriginalCassetteTouchRegion {
    private static let minimumX = 108
    private static let maximumX = 120
    private static let minimumY = 100
    private static let maximumY = 192

    /**
     * Maps a raw 256×192 DS point through the input transform used by overlay 25.
     */
    public static func processPoint(rawTouch: SIMD2<Int>, rotated: Bool) -> SIMD2<Int>? {
        guard (0..<256).contains(rawTouch.x), (0..<192).contains(rawTouch.y) else { return nil }
        if rotated {
            return SIMD2(rawTouch.x, 191 - rawTouch.y)
        }
        return SIMD2(255 - rawTouch.x, rawTouch.y)
    }

    /**
     * Returns true when the transformed point is inside the source tap region.
     */
    public static func containsStartTap(_ rawTouch: SIMD2<Int>, rotated: Bool) -> Bool {
        guard let point = processPoint(rawTouch: rawTouch, rotated: rotated) else { return false }
        return (minimumX...maximumX).contains(point.x)
            && (minimumY...maximumY).contains(point.y)
    }
}
