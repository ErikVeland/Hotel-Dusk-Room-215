import Foundation

/**
 * Process 34 drawing, toolbar entry and exit from overlay 14.
 */
public struct OriginalMemoDrawingProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int)
        case fadeOut(Int)
        case startSound
        case soundVolume(Int)
        case stopSound
        case completed(Int16)
    }
    public private(set) var drawing: OriginalMemoDrawing
    public private(set) var phase = 1
    public private(set) var toolbarStage = 0
    public private(set) var toolbarY = 256
    public private(set) var result: Int16?
    private var started = false
    private var exitStarted = false
    private var trailingTouch = SIMD2<Int>.zero

    public init(drawing: OriginalMemoDrawing) { self.drawing = drawing }
    public var canQuit: Bool { phase == 1 && toolbarStage == 1 }

    public mutating func clear() {
        guard canQuit else { return }
        drawing.clear()
    }

    public mutating func quit() {
        guard canQuit else { return }
        phase = 3
        toolbarStage = 2
        drawing.release()
    }

    @discardableResult
    public mutating func update(touch: SIMD2<Int>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        var effects: [Effect] = []
        if !started { started = true; effects.append(.fadeIn(60)) }
        if toolbarStage == 0 {
            if toolbarY < 229 { toolbarStage = 1 }
            else { toolbarY -= 1 }
        } else if toolbarStage == 2 { toolbarY = min(256, toolbarY + 1) }
        if phase == 3 {
            if !exitStarted { exitStarted = true; return [.stopSound, .fadeOut(60)] }
            if fadeComplete { result = 2; return [.completed(2)] }
            return effects
        }
        guard let touch else {
            if drawing.previousTouch != nil { effects.append(.stopSound) }
            drawing.release()
            return effects
        }
        guard (0..<192).contains(touch.x), (0..<256).contains(touch.y) else { return effects }
        let previous = drawing.previousTouch ?? touch
        if drawing.previousTouch == nil { effects.append(.startSound) }
        let delta = previous &- trailingTouch
        effects.append(.soundVolume(delta.x * delta.x + delta.y * delta.y < 10 || !drawing.accepts(touch) ? 0 : 127))
        trailingTouch = previous
        drawing.touch(x: touch.x, y: touch.y)
        return effects
    }
}
