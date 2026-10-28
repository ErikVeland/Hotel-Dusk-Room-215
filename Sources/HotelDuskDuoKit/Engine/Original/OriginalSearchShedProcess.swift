import Foundation
import simd

/**
 * Owns the recovered object positions and completion rule for overlay 40.
 * Touch projection and scene drawing stay at the renderer boundary.
 */
public struct OriginalSearchShedProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int)
        case fadeOut(Int)
        case foundTreeBox
        case completed(Int16)
    }

    public private(set) var objects: [Object]
    public private(set) var phase: Phase = .entering
    public private(set) var result: Int16?
    private var activeDrag: Drag?
    private var menuExitPending = false
    private var fadeOutStarted = false

    public struct Object: Equatable, Sendable {
        public var position: SIMD3<Float>
        public let scale: SIMD3<Float>
    }

    public enum Phase: Equatable, Sendable {
        case entering
        case arranging
        case found
        case exiting
    }

    private struct Drag: Equatable, Sendable {
        let object: Int
        let offset: SIMD2<Float>
    }

    public init() {
        objects = OriginalSearchShedLayout.objects.map {
            Object(position: $0.position, scale: $0.scale)
        }
    }

    public var draggedObject: Int? { activeDrag?.object }
    public var canOpenMenu: Bool { (phase == .arranging || phase == .found) && activeDrag == nil && result == nil }
    public var canOpenFoundBox: Bool { phase == .found && activeDrag == nil && result == nil }

    /**
     * Starts a drag after the renderer reports an original object hit.
     */
    public mutating func beginDrag(object: Int, at point: SIMD2<Float>) {
        guard phase == .arranging, result == nil, objects.indices.contains(object),
              point.x.isFinite, point.y.isFinite else { return }
        let position = objects[object].position
        activeDrag = Drag(object: object, offset: SIMD2(position.x, position.z) - point)
    }

    /**
     * Moves the selected object on the horizontal plane used by the overlay.
     */
    public mutating func drag(to point: SIMD2<Float>) {
        guard let activeDrag, point.x.isFinite, point.y.isFinite else { return }
        objects[activeDrag.object].position.x = point.x + activeDrag.offset.x
        objects[activeDrag.object].position.z = point.y + activeDrag.offset.y
    }

    public mutating func endDrag() { activeDrag = nil }

    /**
     * The original process accepts object 9 when its ray check finds no
     * intervening object. The renderer supplies that hit-test result.
     */
    public mutating func select(object: Int, targetIsUnobstructed: Bool) -> [Effect] {
        guard phase == .arranging, activeDrag == nil, result == nil, object == 9,
              targetIsUnobstructed else { return [] }
        phase = .found
        return [.foundTreeBox]
    }

    /**
     * Completes the recovered tree-box search after the player confirms it.
     */
    @discardableResult
    public mutating func openFoundBox() -> [Effect] {
        guard canOpenFoundBox else { return [] }
        phase = .exiting
        result = 0
        return [.completed(0)]
    }

    public mutating func openMenu() {
        guard canOpenMenu else { return }
        phase = .exiting
        menuExitPending = true
    }

    /**
     * Advances the source fade and returns process result 0 after the menu exit.
     */
    public mutating func update(fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        if menuExitPending {
            if !fadeOutStarted {
                fadeOutStarted = true
                return [.fadeOut(60)]
            }
            if fadeComplete {
                result = 0
                return [.completed(0)]
            }
            return []
        }
        if phase == .entering {
            phase = .arranging
            return [.fadeIn(60)]
        }
        return []
    }

}
