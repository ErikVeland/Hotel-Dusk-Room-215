import Foundation
import simd

/**
 * Initial object transforms copied from overlay 30 at 0x02201488.
 */
struct OriginalSearchShedLayout: Sendable {
    struct Object: Equatable, Sendable {
        let position: SIMD3<Float>
        let scale: SIMD3<Float>
    }

    static let objects: [Object] = [
        .init(position: .init(1, 1.5, -0.5), scale: .init(1, 1, 1)),
        .init(position: .init(1, -0.5, -0.5), scale: .init(1, 1, 1)),
        .init(position: .init(3, 0.5, -1), scale: .init(1, 1, 2)),
        .init(position: .init(-1, -0.5, -1.5), scale: .init(1, 1, 1)),
        .init(position: .init(0, -0.5, -1.5), scale: .init(1, 1, 1)),
        .init(position: .init(-1, -0.5, -2.5), scale: .init(1, 1, 1)),
        .init(position: .init(0, -0.5, -2.5), scale: .init(1, 1, 1)),
        .init(position: .init(1, 0, -2.5), scale: .init(1, 2, 1)),
        .init(position: .init(0, -0.5, -3.5), scale: .init(1, 1, 1)),
        .init(position: .init(-1, 0.5, -3.5), scale: .init(1, 3, 1)),
        .init(position: .init(2, -0.5, -3.5), scale: .init(1, 1, 1)),
        .init(position: .init(0, -0.5, -0.5), scale: .init(1, 1, 1)),
        .init(position: .init(3, -0.5, -0.5), scale: .init(1, 1, 1)),
        .init(position: .init(1, 0.5, -0.5), scale: .init(1, 1, 1)),
        .init(position: .init(-1, 0.5, -1.5), scale: .init(1, 1, 1)),
        .init(position: .init(3, -0.5, -2), scale: .init(1, 1, 2)),
        .init(position: .init(0, 0.5, -1.5), scale: .init(1, 1, 1)),
        .init(position: .init(2, -0.5, -2.5), scale: .init(1, 1, 1)),
        .init(position: .init(0, 0.5, -3.5), scale: .init(1, 1, 1)),
        .init(position: .init(1, -0.5, -3.5), scale: .init(1, 1, 1)),
        .init(position: .init(-1, 1.5, 0.5), scale: .init(1, 1, 1)),
        .init(position: .init(3, -0.5, 0.5), scale: .init(1, 1, 1)),
        .init(position: .init(-1, -0.5, 0.5), scale: .init(1, 1, 1)),
        .init(position: .init(2, -0.5, 0.5), scale: .init(1, 1, 1)),
        .init(position: .init(3, 0.5, 0.5), scale: .init(1, 1, 1)),
        .init(position: .init(-1, 0.5, 0.5), scale: .init(1, 1, 1))
    ]
}
