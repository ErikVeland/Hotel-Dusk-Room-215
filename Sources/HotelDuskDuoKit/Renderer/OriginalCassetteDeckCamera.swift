import Foundation
import simd

/**
 * Reconstructs overlay 28's view-projection matrix from its recovered camera vectors.
 */
struct OriginalCassetteDeckCamera: Equatable, Sendable {
    let position: SIMD3<Float>
    let up: SIMD3<Float>
    let target: SIMD3<Float>

    init(positionFixed20_12: SIMD3<Int32>, upFixed20_12: SIMD3<Int32>, targetFixed20_12: SIMD3<Int32>) {
        position = SIMD3(Float(positionFixed20_12.x), Float(positionFixed20_12.y), Float(positionFixed20_12.z)) / 4096
        up = SIMD3(Float(upFixed20_12.x), Float(upFixed20_12.y), Float(upFixed20_12.z)) / 4096
        target = SIMD3(Float(targetFixed20_12.x), Float(targetFixed20_12.y), Float(targetFixed20_12.z)) / 4096
    }

    var viewProjection: simd_float4x4 {
        let back = simd_normalize(position - target)
        let right = simd_normalize(simd_cross(up, back))
        let cameraUp = simd_cross(back, right)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, cameraUp.x, back.x, 0),
            SIMD4(right.y, cameraUp.y, back.y, 0),
            SIMD4(right.z, cameraUp.z, back.z, 0),
            SIMD4(-simd_dot(right, position), -simd_dot(cameraUp, position), -simd_dot(back, position), 1)
        ))
        let near: Float = 0.1
        let far: Float = 60
        let sy: Float = 1 / tan(.pi / 18)
        let sx = sy / Float(bitPattern: 0x3FAAE3DA)
        let projection = simd_float4x4(columns: (
            SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, far / (near - far), -1),
            SIMD4(0, 0, near * far / (near - far), 0)
        ))
        return projection * view
    }
}
