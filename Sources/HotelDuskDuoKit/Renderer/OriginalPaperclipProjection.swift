import Foundation
import simd

/**
 * Overlay 9 touch ray at 0x021FF824. Integer operations retain the original intersection rounding.
 */
public enum OriginalPaperclipProjection {
    public static func hit(page: SIMD2<Float>, planeY: Int32 = 0) -> SIMD3<Int32>? {
        guard page.x.isFinite, page.y.isFinite, (0...191).contains(page.x), (0...255).contains(page.y) else { return nil }
        let eye = SIMD3<Int32>(0, 32768, 0)
        let tangent = Float(divide(2048, 3547))
        let horizontal = Int32((page.x - 96) / 96 * tangent)
        let vertical = Int32((128 - page.y) / 96 * tangent)
        let direction = normalise(SIMD3(horizontal, -4096, -vertical))
        let end = eye &+ direction &* SIMD3<Int32>(repeating: 1000)
        let line = eye &- end
        let fraction = divide(Int64(planeY - end.y), Int64(line.y))
        guard (0...4096).contains(fraction) else { return nil }
        let point = end &+ scale(line, Int32(fraction))
        guard abs(point.x) <= 20480, abs(point.z) <= 20480 else { return nil }
        return point
    }

    /**
     * Project original world coordinates onto the rotated 192×256 page.
     */
    public static func page(_ point: SIMD3<Float>) -> SIMD2<Float> {
        let factor = 96 / ((8 - point.y) * tan(Float.pi / 6))
        return SIMD2(96 + point.x * factor, 128 + point.z * factor)
    }

    private static func divide(_ a: Int64, _ b: Int64) -> Int64 {
        ((a << 32) / b + 0x80000) >> 20
    }

    private static func scale(_ value: SIMD3<Int32>, _ amount: Int32) -> SIMD3<Int32> {
        SIMD3((0..<3).map { Int32((Int64(value[$0]) * Int64(amount) + 2048) >> 12) })
    }

    private static func normalise(_ value: SIMD3<Int32>) -> SIMD3<Int32> {
        let square = (0..<3).reduce(Int64(0)) { $0 + Int64(value[$1]) * Int64(value[$1]) }
        guard square > 0 else { return .zero }
        let factor = Int64(Double(square * 4).squareRoot()) * ((1 << 56) / square)
        return SIMD3((0..<3).map { Int32((((factor * Int64(value[$0])) >> 32) + 4096) >> 13) })
    }
}
