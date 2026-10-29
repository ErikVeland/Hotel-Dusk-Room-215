import Foundation
import simd

/**
 * Owns the Chapter 10 brick board and its source return conditions.
 */
public struct OriginalBrickWallProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case completed(Int16)
    }

    private(set) var objects: [OriginalBrickWallLayout.Object]
    private(set) var selectedObject: Int?
    private(set) var result: Int16?
    private var dragOrigin: SIMD2<Float>?
    private var selectedStartX: Float = 0
    private var selectedStartY: Float = 0

    public init(seed: UInt32 = 0x0F2B89E1, modeZeroFixedCells: [UInt8] = []) {
        objects = OriginalBrickWallLayout.objects(seed: seed, modeZeroFixedCells: modeZeroFixedCells)
    }

    var isComplete: Bool { OriginalBrickWallLayout.doorwayIsClear(objects) }

    /**
     * Selects the brick under the touch using its full front and side faces.
     */
    @discardableResult
    public mutating func beginDrag(at point: SIMD2<Float>, hammerAvailable: Bool) -> Bool {
        guard result == nil, hammerAvailable,
              let object = OriginalBrickWallHitMask.object(at: point, objects: objects),
              objects.indices.contains(object) else { return false }
        selectedObject = object
        dragOrigin = point
        selectedStartX = objects[object].position.x
        selectedStartY = objects[object].position.y
        return true
    }

    /**
     * Moves the selected brick down the wall while keeping it clear of other bricks.
     */
    public mutating func drag(to point: SIMD2<Float>) {
        guard let selectedObject, let dragOrigin,
              objects.indices.contains(selectedObject), result == nil else { return }
        let horizontalDelta = max(-12, min(12, (point.x - dragOrigin.x) / 12))
        let verticalDelta = max(-16, min(16, (point.y - dragOrigin.y) / 8))
        let old = objects[selectedObject]
        let candidate = OriginalBrickWallLayout.Object(
            position: SIMD3(selectedStartX + horizontalDelta, selectedStartY - verticalDelta, old.position.z),
            scale: old.scale)
        guard !objects.enumerated().contains(where: { index, other in
            index != selectedObject && abs(candidate.position.x - other.position.x) < 1.92 &&
                abs(candidate.position.y - other.position.y) < 0.96 &&
                abs(candidate.position.z - other.position.z) < 0.96
        }) else { return }
        objects[selectedObject] = candidate
    }

    /**
     * Ends the current drag and returns zero when the doorway is clear.
     */
    @discardableResult
    public mutating func endDrag() -> [Effect] {
        selectedObject = nil
        dragOrigin = nil
        guard result == nil, isComplete else { return [] }
        result = 0
        return [.completed(0)]
    }

    /**
     * Returns the recovered incomplete-wall branch when the player leaves the board.
     */
    @discardableResult
    public mutating func leave() -> Int16? {
        guard result == nil, selectedObject == nil else { return nil }
        result = 2
        return 2
    }
}
