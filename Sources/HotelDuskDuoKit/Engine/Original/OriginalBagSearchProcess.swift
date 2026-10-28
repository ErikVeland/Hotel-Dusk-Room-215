import Foundation
import simd

/**
 * Tracks the 20 drag objects and found state from overlay 3.
 */
public struct OriginalBagSearchProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeOut(Int)
        case completed(Int16)
    }

    public enum Phase: Equatable, Sendable {
        case arranging
        case found
        case exiting
    }

    public struct Object: Equatable, Sendable {
        public let type: Int?
        public var positionFixed: SIMD3<Int32>
        public let scale: SIMD3<Float>
    }

    public private(set) var objects: [Object]
    public private(set) var phase: Phase = .arranging
    public private(set) var result: Int16?
    public let targetPositionFixed: SIMD2<Int32>
    private var activeDrag: Drag?
    private var menuExitPending = false
    private var fadeOutStarted = false

    private struct Drag: Equatable, Sendable {
        let object: Int
        let offset: SIMD2<Int32>
    }

    private static let sourceTypes: [Int?] = [1, 3, nil, 1, nil, nil, nil, nil, 1, 2,
                                               nil, 1, nil, 0, 0, nil, 0, nil, nil, 0]
    private static let sourceStepFixed: Int32 = 2_048
    private static let rowStepFixed: Int32 = 5_120
    private static let inactivePosition: Int32 = -40_960

    public init() {
        // The process factory clears the payload before the overlay starts.
        targetPositionFixed = .zero
        objects = Self.sourceTypes.enumerated().map { index, type in
            guard let type else {
                return Object(type: nil,
                    positionFixed: SIMD3(Self.inactivePosition, 0, Self.inactivePosition),
                    scale: .zero)
            }
            let column = Int32(index % 4) - 2
            let row = Int32(index / 4)
            let width: Float = type == 2 || type == 3 ? 1 : 0.5
            let depth: Float = type == 1 || type == 3 ? 1 : 0.5
            return Object(type: type,
                positionFixed: SIMD3(column * Self.sourceStepFixed, 0, row * Self.rowStepFixed),
                scale: SIMD3(width, 0.5, depth))
        }
    }

    public var draggedObject: Int? { activeDrag?.object }
    public var canOpenMenu: Bool { (phase == .arranging || phase == .found) && result == nil && activeDrag == nil }

    /**
     * Starts a drag after the renderer hits an active model's triangles.
     */
    public mutating func beginDrag(object index: Int, at point: SIMD2<Int32>) {
        guard phase == .arranging, result == nil, objects.indices.contains(index),
              objects[index].type != nil else { return }
        let position = objects[index].positionFixed
        activeDrag = Drag(object: index,
            offset: SIMD2(position.x - point.x, position.z - point.y))
    }

    /**
     * Moves the selected object on the source horizontal plane.
     */
    public mutating func drag(to point: SIMD2<Int32>) {
        guard let activeDrag, phase == .arranging else { return }
        objects[activeDrag.object].positionFixed.x = point.x + activeDrag.offset.x
        objects[activeDrag.object].positionFixed.z = point.y + activeDrag.offset.y
    }

    /**
     * Checks the source type-3 target condition when the touch is released.
     */
    public mutating func endDrag() -> Bool {
        guard let activeDrag else { return false }
        self.activeDrag = nil
        let object = objects[activeDrag.object]
        guard object.type == 3,
              object.positionFixed.x == targetPositionFixed.x,
              object.positionFixed.z == targetPositionFixed.y else {
            return false
        }
        phase = .found
        return true
    }

    public mutating func openMenu() {
        guard canOpenMenu else { return }
        phase = .exiting
        menuExitPending = true
    }

    /**
     * Advances the original menu fade and returns its process result.
     */
    public mutating func update(fadeComplete: Bool = false) -> [Effect] {
        guard result == nil, menuExitPending else { return [] }
        if !fadeOutStarted {
            fadeOutStarted = true
            return [.fadeOut(60)]
        }
        guard fadeComplete else { return [] }
        result = 2
        return [.completed(2)]
    }
}
