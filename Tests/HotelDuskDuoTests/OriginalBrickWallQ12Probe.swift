import simd
@testable import HotelDuskDuoKit

/**
 * Replays the ARM9 Q12 hit math against captured Process 75 selections.
 */
enum OriginalBrickWallQ12Probe {
    private typealias Vector = SIMD3<Int64>
    private static let unit: Int64 = 4096
    private static let face: [SIMD3<Float>] = [
        SIMD3(-0.5, -0.5, 0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(-0.5, 0.5, 0.5),
        SIMD3(-0.5, 0.5, 0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(0.5, 0.5, 0.5),
        SIMD3(0.5, -0.5, -0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(0.5, 0.5, -0.5),
        SIMD3(0.5, 0.5, -0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(0.5, 0.5, 0.5)
    ]

    static func object(at point: SIMD2<Float>, objects: [OriginalBrickWallLayout.Object]) -> Int? {
        guard let ray = OriginalBrickWallTouchRay.ray(at: point) else { return nil }
        let origin = vector(ray.origin)
        let direction = normalized(vector(ray.direction))
        let end = add(origin, product(direction, 60 * unit))
        var selected: (index: Int, x: Int64)?

        for (index, object) in objects.enumerated() {
            let vertices = face.map { vector(object.position + $0 * object.scale) }
            for first in stride(from: 0, to: vertices.count, by: 3) {
                guard let hit = intersection(origin: origin, end: end,
                                             a: vertices[first], b: vertices[first + 1],
                                             c: vertices[first + 2]) else { continue }
                if selected == nil || hit.x > selected!.x { selected = (index, hit.x) }
            }
        }
        return selected?.index
    }

    private static func intersection(origin: Vector, end: Vector,
                                     a: Vector, b: Vector, c: Vector) -> Vector? {
        let normal = cross(subtract(b, a), subtract(c, a))
        let direction = subtract(origin, end)
        let denominator = dot(normal, direction)
        guard denominator != 0 else { return nil }
        let numerator = -dot(normal, a) + dot(normal, end)
        let amount = -divide(numerator, denominator)
        guard amount >= 0, amount <= unit else { return nil }
        let hit = add(end, product(subtract(origin, end), amount))
        guard onSegment(origin, end, hit) else { return nil }

        let points = [a, b, c]
        let toHit = points.map { subtract($0, hit) }
        if toHit.contains(where: { length($0) == 0 }) { return hit }
        let winding = [cross(normalized(toHit[0]), normalized(toHit[1])),
                       cross(normalized(toHit[1]), normalized(toHit[2])),
                       cross(normalized(toHit[2]), normalized(toHit[0]))]
        for edge in 0..<3 where length(winding[edge]) == 0 {
            if onSegment(points[edge], points[(edge + 1) % 3], hit) { return hit }
            return nil
        }
        let sides = winding.map(normalized)
        guard dot(sides[0], sides[1]) >= 0,
              dot(sides[1], sides[2]) >= 0,
              dot(sides[2], sides[0]) >= 0 else { return nil }
        return hit
    }

    private static func onSegment(_ start: Vector, _ end: Vector, _ point: Vector) -> Bool {
        let first = normalized(subtract(start, point))
        let second = normalized(subtract(end, point))
        guard abs(unit - abs(dot(first, second))) < 0x10 else { return false }
        let limit = length(subtract(start, end))
        return length(subtract(start, point)) <= limit && length(subtract(end, point)) <= limit
    }

    private static func normalized(_ value: Vector) -> Vector {
        let squared = value.x * value.x + value.y * value.y + value.z * value.z
        guard squared > 0 else { return .zero }
        let squareRoot = integerSquareRoot(squared * 4)
        let reciprocal = (1 << 56) / squared
        let factor = squareRoot * reciprocal
        return Vector(component(value.x, factor), component(value.y, factor), component(value.z, factor))
    }

    private static func component(_ value: Int64, _ factor: Int64) -> Int64 {
        (value * factor + (0x1000 << 32)) >> 45
    }

    private static func length(_ value: Vector) -> Int64 {
        integerSquareRoot((value.x * value.x + value.y * value.y + value.z * value.z) * 4) + 1 >> 1
    }

    private static func integerSquareRoot(_ value: Int64) -> Int64 {
        guard value > 0 else { return 0 }
        var low: Int64 = 1
        var high = min(value, Int64(1) << 32)
        while low <= high {
            let middle = low + (high - low) / 2
            if middle <= value / middle { low = middle + 1 } else { high = middle - 1 }
        }
        return high
    }

    private static func vector(_ value: SIMD3<Float>) -> Vector {
        Vector(Int64((value.x * Float(unit)).rounded()),
               Int64((value.y * Float(unit)).rounded()),
               Int64((value.z * Float(unit)).rounded()))
    }

    private static func add(_ lhs: Vector, _ rhs: Vector) -> Vector {
        Vector(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    private static func subtract(_ lhs: Vector, _ rhs: Vector) -> Vector {
        Vector(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    private static func product(_ lhs: Vector, _ rhs: Int64) -> Vector {
        Vector(multiply(lhs.x, rhs), multiply(lhs.y, rhs), multiply(lhs.z, rhs))
    }

    private static func multiply(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        (lhs * rhs + 0x800) >> 12
    }

    private static func divide(_ numerator: Int64, _ denominator: Int64) -> Int64 {
        let scaled = numerator * unit
        let half = abs(denominator) / 2
        return (scaled + ((scaled < 0) == (denominator < 0) ? half : -half)) / denominator
    }

    private static func dot(_ lhs: Vector, _ rhs: Vector) -> Int64 {
        (lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z + 0x800) >> 12
    }

    private static func cross(_ lhs: Vector, _ rhs: Vector) -> Vector {
        Vector((lhs.y * rhs.z - lhs.z * rhs.y + 0x800) >> 12,
               (lhs.z * rhs.x - lhs.x * rhs.z + 0x800) >> 12,
               (lhs.x * rhs.y - lhs.y * rhs.x + 0x800) >> 12)
    }
}
