import Foundation
import simd

/**
 * Tracks overlay 30's 26 search objects and tree-box result.
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
    private var activeDrag: Drag?
    private var menuExitPending = false
    private var fadeOutStarted = false
    private var foundTreeBox = false

    private struct Drag: Equatable, Sendable {
        let object: Int
        let offset: SIMD2<Int32>
    }

    private static let treeBoxIndex = 9
    private static let fixedUnit = 4_096.0
    private static let sourcePositionsAndScales: [(SIMD3<Float>, SIMD3<Float>)] = [
        (SIMD3(1, 1.5, -0.5), SIMD3(repeating: 1)),
        (SIMD3(1, -0.5, -0.5), SIMD3(repeating: 1)),
        (SIMD3(3, 0.5, -1), SIMD3(1, 1, 2)),
        (SIMD3(-1, -0.5, -1.5), SIMD3(repeating: 1)),
        (SIMD3(0, -0.5, -1.5), SIMD3(repeating: 1)),
        (SIMD3(-1, -0.5, -2.5), SIMD3(repeating: 1)),
        (SIMD3(0, -0.5, -2.5), SIMD3(repeating: 1)),
        (SIMD3(1, 0, -2.5), SIMD3(1, 2, 1)),
        (SIMD3(0, -0.5, -3.5), SIMD3(repeating: 1)),
        (SIMD3(-1, 0.5, -3.5), SIMD3(1, 3, 1)),
        (SIMD3(2, -0.5, -3.5), SIMD3(repeating: 1)),
        (SIMD3(0, -0.5, -0.5), SIMD3(repeating: 1)),
        (SIMD3(3, -0.5, -0.5), SIMD3(repeating: 1)),
        (SIMD3(1, 0.5, -0.5), SIMD3(repeating: 1)),
        (SIMD3(-1, 0.5, -1.5), SIMD3(repeating: 1)),
        (SIMD3(3, -0.5, -2), SIMD3(1, 1, 2)),
        (SIMD3(0, 0.5, -1.5), SIMD3(repeating: 1)),
        (SIMD3(2, -0.5, -2.5), SIMD3(repeating: 1)),
        (SIMD3(0, 0.5, -3.5), SIMD3(repeating: 1)),
        (SIMD3(1, -0.5, -3.5), SIMD3(repeating: 1)),
        (SIMD3(-1, 1.5, 0.5), SIMD3(repeating: 1)),
        (SIMD3(3, -0.5, 0.5), SIMD3(repeating: 1)),
        (SIMD3(-1, -0.5, 0.5), SIMD3(repeating: 1)),
        (SIMD3(2, -0.5, 0.5), SIMD3(repeating: 1)),
        (SIMD3(3, 0.5, 0.5), SIMD3(repeating: 1)),
        (SIMD3(-1, 0.5, 0.5), SIMD3(repeating: 1))
    ]

    public init() {
        objects = Self.sourcePositionsAndScales.enumerated().map { index, item in
            let position = item.0 * Float(Self.fixedUnit)
            return Object(type: index == Self.treeBoxIndex ? 3 : 0,
                positionFixed: SIMD3(Int32(position.x), Int32(position.y), Int32(position.z)),
                scale: item.1)
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
        guard let activeDrag, activeDrag.object != Self.treeBoxIndex, phase == .arranging else { return }
        objects[activeDrag.object].positionFixed.x = point.x + activeDrag.offset.x
        objects[activeDrag.object].positionFixed.z = point.y + activeDrag.offset.y
    }

    /**
     * Accepts a tap on object 9 when no other object blocks it.
     */
    public mutating func endDrag() -> Bool {
        guard let activeDrag else { return false }
        self.activeDrag = nil
        guard activeDrag.object == Self.treeBoxIndex, !treeBoxIsBlocked else {
            return false
        }
        foundTreeBox = true
        phase = .found
        return true
    }

    private var treeBoxIsBlocked: Bool {
        let target = objects[Self.treeBoxIndex].positionFixed
        return objects.indices.contains { index in
            guard index != Self.treeBoxIndex else { return false }
            let other = objects[index].positionFixed
            let deltaX = Double(Int64(other.x) - Int64(target.x)) / Self.fixedUnit
            let deltaZ = Double(Int64(other.z) - Int64(target.z)) / Self.fixedUnit
            return deltaX * deltaX < 0.1 && deltaZ * deltaZ < 2.56
        }
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
        let returnValue: Int16 = foundTreeBox ? 0 : 2
        result = returnValue
        return [.completed(returnValue)]
    }
}
