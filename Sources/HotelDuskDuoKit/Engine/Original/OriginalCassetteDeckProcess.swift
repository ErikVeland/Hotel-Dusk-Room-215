import Foundation
import simd

/**
 * Runs the recovered scene-to-controls-to-playback path for process 52.
 */
public struct OriginalCassetteDeckProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case opening
        case dragging
        case turning
        case controlsReady
        case playing
        case exiting
        case complete
    }

    public static let controlsTransitionUpdates = 180
    public static let exitFadeUpdates = 60

    public private(set) var phase = Phase.opening
    public private(set) var selectedSelector: Int?
    public private(set) var returnedProcessValue: Int16?

    private var lastPoint: SIMD2<Int>?
    private var upwardDrag = 0
    private var transitionUpdates = 0
    private var exitUpdates = 0

    public init() {}

    var camera: OriginalCassetteDeckCamera {
        switch phase {
        case .opening, .dragging, .turning:
            return .init(positionFixed20_12: SIMD3(16794, 12288, 49971),
                         upFixed20_12: SIMD3(-4096, 0, 0),
                         targetFixed20_12: SIMD3(2048, 6554, 0))
        case .controlsReady, .playing, .exiting, .complete:
            let position: SIMD3<Int32> = phase == .controlsReady
                ? SIMD3(-5325, 22118, 15974) : SIMD3(0, 0, 16384)
            let target: SIMD3<Int32> = phase == .controlsReady
                ? SIMD3(-5325, 6554, 0) : SIMD3(0, 0, 0)
            return .init(positionFixed20_12: position, upFixed20_12: SIMD3(-4096, 0, 0),
                         targetFixed20_12: target)
        }
    }

    var sceneState: OriginalCassetteDeckRenderer.SceneState {
        let radioRotation = phase == .opening || phase == .dragging || phase == .turning
            ? SIMD3<Float>(0, 180, 0) : SIMD3<Float>(0, 180, 179.67654)
        return .init(
            radio: .init(rotationDegrees: radioRotation, translation: SIMD3(3.55, -1, 0)),
            front: .init(rotationDegrees: .zero, translation: .zero),
            tape: .init(rotationDegrees: .zero, translation: SIMD3(1.45, 0.9, -0.65))
        )
    }

    var opacity: Double {
        phase == .exiting
            ? max(0, 1 - Double(exitUpdates) / Double(Self.exitFadeUpdates))
            : 1
    }

    /**
     * Advances one source update from a held point, a new press and the scene mesh hit result.
     */
    public mutating func update(touch: SIMD2<Int>?, pressedTouch: SIMD2<Int>?, sceneHit: Bool) {
        switch phase {
        case .opening:
            guard let touch, sceneHit else { return }
            lastPoint = touch
            upwardDrag = 0
            phase = .dragging
        case .dragging:
            guard let touch, (0..<256).contains(touch.x), (0..<192).contains(touch.y) else {
                lastPoint = nil
                upwardDrag = 0
                phase = .opening
                return
            }
            if let previous = lastPoint { upwardDrag += max(0, previous.y - touch.y) }
            lastPoint = touch
            if upwardDrag >= 48 {
                phase = .turning
                transitionUpdates = Self.controlsTransitionUpdates
            }
        case .turning:
            transitionUpdates -= 1
            if transitionUpdates <= 0 {
                phase = .controlsReady
                lastPoint = nil
            }
        case .controlsReady:
            guard let pressedTouch, let selector = Self.selector(at: pressedTouch) else { return }
            selectedSelector = selector
        case .playing:
            guard let pressedTouch, Self.isBackTap(pressedTouch) else { return }
            phase = .exiting
            exitUpdates = 0
        case .exiting:
            exitUpdates += 1
            if exitUpdates >= Self.exitFadeUpdates {
                returnedProcessValue = 2
                phase = .complete
            }
        case .complete:
            break
        }
    }

    public mutating func activateSelectedControl() {
        guard phase == .controlsReady, selectedSelector != nil else { return }
        phase = .playing
    }

    public mutating func requestExit() {
        guard phase == .playing else { return }
        phase = .exiting
        exitUpdates = 0
    }

    private static func selector(at rawTouch: SIMD2<Int>) -> Int? {
        guard (31...63).contains(rawTouch.x) else { return nil }
        if (16...80).contains(rawTouch.y) { return 0 }
        if (112...176).contains(rawTouch.y) { return 1 }
        return nil
    }

    private static func isBackTap(_ rawTouch: SIMD2<Int>) -> Bool {
        (0..<32).contains(rawTouch.x) && (160..<192).contains(rawTouch.y)
    }
}
