import Foundation

/**
 * Overlay 4 cut selection and wire-length rules, independent of the cutting animation.
 */
public struct OriginalHangerCuts: Equatable, Sendable {
    public struct Cut: Equatable, Sendable {
        public let region: Int
        public let position: SIMD2<Int32>
    }

    public private(set) var cuts: [Cut] = []
    public private(set) var lastTouch = SIMD2<Int32>.zero

    /**
     * Initial hit quads produced by 0x022005FC, in its original fixed-point vertex order.
     */
    static let hitQuads: [[SIMD2<Int32>]] = [
        [.init(-2580, -195), .init(-2580, -850), .init(-860, -174), .init(-860, 481)],
        [.init(860, 481), .init(860, -174), .init(2580, -850), .init(2580, -195)],
        [.init(-2408, -532), .init(-2408, -1188), .init(0, -1188), .init(0, -532)],
        [.init(0, -532), .init(0, -1188), .init(2408, -1188), .init(2408, -532)]
    ]

    public init() {}

    /**
     * 0x021FD644 accepts a new press only when it is more than 16 pixels from the last cut.
     * The process controller must call this only while the cutting animation is idle.
     */
    @discardableResult
    public mutating func cut(at page: SIMD2<Float>) -> Cut? {
        guard cuts.count < 2, page.x.isFinite, page.y.isFinite,
              (0..<192).contains(page.x), (0..<256).contains(page.y) else { return nil }
        let touch = SIMD2(Int32(page.x), min(223, max(31, Int32(page.y))))
        let delta = touch &- lastTouch
        guard delta.x * delta.x + delta.y * delta.y > 256 else { return nil }
        let point = SIMD2((Float(touch.x) - 96) / 96, (128 - Float(touch.y)) / 96)
        var selected: Int?
        for (index, quad) in Self.hitQuads.enumerated() {
            let inside = quad.indices.allSatisfy { i in
                let a = SIMD2<Float>(quad[i]) / 4096
                let b = SIMD2<Float>(quad[(i + 1) % quad.count]) / 4096
                return (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x) >= 0
            }
            if inside { selected = index }
        }
        guard let region = selected else { return nil }
        let result = Cut(region: region, position: Self.cutPoint(x: point.x, region: region))
        cuts.append(result)
        lastTouch = touch
        return result
    }

    /**
     * 0x022030C8 rejects an upper cut or a piece shorter than half a world unit.
     */
    public var producesUsableWire: Bool {
        guard cuts.count == 2 else { return false }
        let maximumY = Double(bitPattern: 0xBFC47AE13999999A)
        guard cuts.allSatisfy({ Double(Float($0.position.y) / 4096) <= maximumY }) else { return false }
        let distance = Float(cuts[0].position.x - cuts[1].position.x) / 4096
        return distance * distance >= 0.25
    }

    /**
     * 0x02202C74 projects a cut onto the hanger centre line. Halfway values round away from zero.
     * The six floats at 0x02203F60 define the apex and the two lower corners.
     */
    private static func cutPoint(x: Float, region: Int) -> SIMD2<Int32> {
        let top = SIMD2<Float>(0, Float(bitPattern: 0x3DF5C28F))
        let left = SIMD2<Float>(Float(bitPattern: 0xBF570A3D), Float(bitPattern: 0xBE570A3D))
        let right = SIMD2<Float>(Float(bitPattern: 0x3F570A3D), left.y)
        let point: SIMD2<Float>
        if region == 0 {
            let t = (x - left.x) / (top.x - left.x)
            point = left - t * (left - top)
        } else if region == 1 {
            let t = (x - top.x) / (right.x - top.x)
            point = top - t * (top - right)
        } else {
            point = SIMD2(x, left.y)
        }
        func fixed(_ value: Float) -> Int32 {
            Int32(value > 0 ? value * 4096 + 0.5 : value * 4096 - 0.5)
        }
        return SIMD2(fixed(point.x), fixed(point.y))
    }
}
