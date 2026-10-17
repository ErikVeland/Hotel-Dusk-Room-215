import Foundation

/**
 * Overlay 6 touch ray and translated paper rectangle at 0x021FFCDC and 0x021FFECC.
 */
public enum OriginalMemoPullProjection {
    public static let eye = SIMD3<Int32>(4014, 6472, -6758)
    public static let target = SIMD3<Int32>(-451, 1761, 0)

    public static func touch(page: SIMD2<Float>, paper: SIMD3<Int32>) -> OriginalMemoPullProcess.Touch? {
        guard page.x.isFinite, page.y.isFinite, (0...191).contains(page.x),
              (0...255).contains(page.y) else { return nil }
        let forward = target &- eye
        let right = normalise(cross(forward, SIMD3(0, 0, -4096)))
        let up = normalise(cross(forward, SIMD3(-4096, 4096, 0)))
        /**
         * The original 10° lookup selects sine/cosine pair 113 at 0x020E272C.
         */
        let tangent = Float(divide(706, 4035))
        let horizontal = Int32((page.x - 96) / 96 * tangent)
        let vertical = Int32((128 - page.y) / 96 * tangent)
        let direction = normalise(normalise(forward) &+ scale(right, horizontal) &+ scale(up, vertical))
        let end = eye &+ direction &* SIMD3<Int32>(repeating: 1000)
        let plane = intersect(end: end, centre: .zero, minimum: SIMD2(-20480, -20480), maximum: SIMD2(20480, 20480))
        let hit = intersect(end: end, centre: paper, minimum: SIMD2(-573, -819), maximum: SIMD2(1065, 819))
        return .init(paper: hit, plane: plane)
    }

    private static func intersect(end: SIMD3<Int32>, centre: SIMD3<Int32>,
                                  minimum: SIMD2<Int32>, maximum: SIMD2<Int32>) -> SIMD3<Int32>? {
        let line = eye &- end
        let normal = (Int64(maximum.x - minimum.x) * Int64(maximum.y - minimum.y) + 2048) >> 12
        let denominator = (normal * Int64(line.z) + 2048) >> 12
        guard denominator != 0 else { return nil }
        let plane = -((normal * Int64(centre.z) + 2048) >> 12)
        let numerator = plane + ((normal * Int64(end.z) + 2048) >> 12)
        let fraction = -divide(numerator, denominator)
        guard (0...4096).contains(fraction) else { return nil }
        let point = end &+ scale(line, Int32(fraction))
        guard (centre.x + minimum.x...centre.x + maximum.x).contains(point.x),
              (centre.y + minimum.y...centre.y + maximum.y).contains(point.y) else { return nil }
        return point
    }

    private static func divide(_ a: Int64, _ b: Int64) -> Int64 {
        ((a << 32) / b + 0x80000) >> 20
    }

    private static func scale(_ value: SIMD3<Int32>, _ amount: Int32) -> SIMD3<Int32> {
        SIMD3((0..<3).map { Int32((Int64(value[$0]) * Int64(amount) + 2048) >> 12) })
    }

    private static func cross(_ a: SIMD3<Int32>, _ b: SIMD3<Int32>) -> SIMD3<Int32> {
        SIMD3((0..<3).map { axis in
            let j = (axis + 1) % 3, k = (axis + 2) % 3
            return Int32((Int64(a[j]) * Int64(b[k]) - Int64(a[k]) * Int64(b[j]) + 2048) >> 12)
        })
    }

    private static func normalise(_ value: SIMD3<Int32>) -> SIMD3<Int32> {
        let square = (0..<3).reduce(Int64(0)) { $0 + Int64(value[$1]) * Int64(value[$1]) }
        guard square > 0 else { return .zero }
        let factor = Int64(Double(square * 4).squareRoot()) * ((1 << 56) / square)
        return SIMD3((0..<3).map { Int32((((factor * Int64(value[$0])) >> 32) + 4096) >> 13) })
    }
}
