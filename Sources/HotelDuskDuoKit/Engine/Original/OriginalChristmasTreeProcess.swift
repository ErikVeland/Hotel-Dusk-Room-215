import Foundation

/// Overlay 13, process 43's decoration completion and menu exit.
public struct OriginalChristmasTreeProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completed(Int16)
    }

    public private(set) var phase = 0
    public private(set) var result: Int16?
    public let decorationOrder: [Int]
    public private(set) var arrangement = OriginalChristmasTreeArrangement()
    private var menuExitPending = false
    private var fadeOutStarted = false
    private var completionPending = false
    private var activeDrag: Drag?

    private struct Drag: Equatable, Sendable {
        let decoration: Int
        let modelStart: SIMD2<Float>
        let pageStart: SIMD2<Float>
        var modelCurrent: SIMD2<Float>
    }

    public init(savedOrder: UInt16 = 0) {
        decorationOrder = OriginalChristmasTreeLayout.decorationOrder(encodedOrder: savedOrder)
    }

    public var canOpenMenu: Bool {
        phase == 1 && !menuExitPending && !completionPending && !arrangement.isComplete
            && result == nil && activeDrag == nil
    }
    public var canPlaceDecoration: Bool { canOpenMenu }
    public func canPickDecoration(_ decoration: Int) -> Bool {
        canPlaceDecoration && decorationOrder.contains(decoration)
            && !arrangement.contains(decoration)
            && (decoration != 10 || arrangement.placedCount == 10)
    }
    public var draggedDecoration: Int? { activeDrag?.decoration }
    public var draggedModelPosition: SIMD2<Float>? { activeDrag?.modelCurrent }

    /**
     * Begins a drag after the renderer identifies a source ornament hit.
     */
    @discardableResult
    public mutating func beginDecorationDrag(
        _ decoration: Int,
        at modelPosition: SIMD2<Float>,
        pagePoint: SIMD2<Float>
    ) -> Bool {
        guard canPickDecoration(decoration), activeDrag == nil,
              OriginalChristmasTreeLayout.clipPoint(forPagePoint: pagePoint) != nil,
              modelPosition.x.isFinite, modelPosition.y.isFinite else { return false }
        activeDrag = Drag(decoration: decoration, modelStart: modelPosition,
                          pageStart: pagePoint, modelCurrent: modelPosition)
        return true
    }

    /**
     * Updates the selected model point with the overlay's transformed touch delta.
     */
    @discardableResult
    public mutating func dragDecoration(to pagePoint: SIMD2<Float>) -> SIMD2<Float>? {
        guard var activeDrag,
              let position = OriginalChristmasTreeLayout.draggedModelPoint(
                  startingAt: activeDrag.modelStart, from: activeDrag.pageStart, to: pagePoint) else { return nil }
        activeDrag.modelCurrent = position
        self.activeDrag = activeDrag
        return position
    }

    /**
     * Ends the selected drag and records a drop if it reached a source target.
     */
    @discardableResult
    public mutating func endDecorationDrag(at pagePoint: SIMD2<Float>) -> Int? {
        guard activeDrag != nil else { return nil }
        _ = dragDecoration(to: pagePoint)
        guard let drag = activeDrag else { return nil }
        activeDrag = nil
        return arrangement.drop(decoration: drag.decoration, at: drag.modelCurrent)
    }

    public mutating func cancelDecorationDrag() { activeDrag = nil }

    /**
     * Records a model-space drop while the tree scene accepts input.
     */
    @discardableResult
    public mutating func dropDecoration(_ decoration: Int, at position: SIMD2<Float>) -> Int? {
        guard canPickDecoration(decoration), activeDrag == nil else { return nil }
        return arrangement.drop(decoration: decoration, at: position)
    }

    /// The original overlay menu returns process result 2 after a 60-frame fade.
    public mutating func openMenu() {
        if canOpenMenu { menuExitPending = true }
    }

    public mutating func update(fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        if arrangement.isComplete { completionPending = true }
        if completionPending {
            if !fadeOutStarted {
                fadeOutStarted = true
                phase = 2
                return [.fadeOut(60)]
            }
            if fadeComplete {
                result = 2
                return [.completed(2)]
            }
            return []
        }
        if menuExitPending {
            if !fadeOutStarted {
                fadeOutStarted = true
                return [.fadeOut(60)]
            }
            if fadeComplete { result = 2; return [.completed(2)] }
            return []
        }
        if phase == 0 {
            phase = 1
            return [.fadeIn(60)]
        }
        return []
    }
}
