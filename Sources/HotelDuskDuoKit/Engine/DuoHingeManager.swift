import Foundation
import Combine

/// Manages dual-screen foldable sensor inputs and posture configurations for the iPhone Duo.
/// On hardware, `HingeObserverView` feeds it from `UIHingeInteraction`; elsewhere the debug slider does.
@MainActor
public final class DuoHingeManager: ObservableObject {
    public enum FoldState: Sendable {
        case closed, partiallyOpen, fullyOpen
    }

    @Published public private(set) var hingeAngleDegrees: Double = 180.0
    @Published public private(set) var posture: DuoPosture = .bookOpen
    @Published public private(set) var foldState: FoldState = .fullyOpen
    @Published public var handedness: Handedness = .rightHanded
    @Published public var isDualScreenActive: Bool = true
    @Published public private(set) var lastFoldTimestamp: Date?
    /// True once `UIHingeInteraction` has delivered a reading. The debug angle
    /// slider is hidden then, because hardware would overwrite it.
    @Published public private(set) var hasHardwareHinge = false
    @Published public private(set) var isSimulatingFold = false
    private var simulatedFold: Task<Void, Never>?

    /// Posture thresholds. Each band has separate enter and exit angles so that
    /// sensor noise (reported at about ±5°) near a boundary cannot make the posture flicker.
    enum Threshold {
        static let closedEnter = 5.0
        static let closedExit = 15.0
        static let bookEnter = 150.0
        static let bookExit = 140.0
    }

    public init(initialHandedness: Handedness = .rightHanded) {
        self.handedness = initialHandedness
    }

    /// Feed a hardware reading (from `HingeObserverView`).
    public func receiveHardwareAngle(_ degrees: Double) {
        guard degrees.isFinite else { return }
        hasHardwareHinge = true
        setHingeAngle(degrees)
    }

    /// Hardware status is authoritative. A coarse angle must not invent contact
    /// or full opening while UIKit still reports a partially open hinge.
    public func receiveHardwareState(_ state: FoldState, angleDegrees: Double) {
        hasHardwareHinge = true
        let angle: Double
        switch state {
        case .closed: angle = 0
        case .fullyOpen: angle = 180
        case .partiallyOpen:
            angle = angleDegrees.isFinite ? max(0, min(180, angleDegrees)) : hingeAngleDegrees
        }
        updateAngle(angle, hardwareState: state)
    }

    /// Update the physical hinge angle reported by hardware sensors or simulated controls
    public func setHingeAngle(_ degrees: Double) {
        guard degrees.isFinite else { return }
        updateAngle(degrees, hardwareState: nil)
    }

    private func updateAngle(_ degrees: Double, hardwareState: FoldState?) {
        // Any explicit or hardware input takes precedence over a delayed simulation.
        simulatedFold?.cancel()
        simulatedFold = nil
        isSimulatingFold = false
        let clamped = max(0.0, min(180.0, degrees))
        hingeAngleDegrees = clamped

        var next = Self.posture(for: clamped, from: posture)
        if let hardwareState {
            switch hardwareState {
            case .closed: next = .foldedClosed
            case .fullyOpen: next = .bookOpen
            case .partiallyOpen:
                if next == .foldedClosed { next = .tentOrLaptop }
            }
        }
        if next == .foldedClosed && posture != .foldedClosed {
            lastFoldTimestamp = Date()
        }
        if next != posture {
            posture = next
        }
        let nextFold = hardwareState ?? (next == .foldedClosed ? .closed : (clamped == 180 ? .fullyOpen : .partiallyOpen))
        if nextFold != foldState { foldState = nextFold }
    }

    /// Toggles handedness preference to swap left and right displays
    public func toggleHandedness() {
        handedness = (handedness == .rightHanded) ? .leftHanded : .rightHanded
    }

    /// Simulates closing and reopening the device (for the simulator and Mac builds).
    /// Puzzle logic must observe `foldState`, not this completion. A real fold on hardware
    /// does not call this method.
    public func performFoldGesture(completion: (@MainActor () -> Void)? = nil) {
        guard !hasHardwareHinge, simulatedFold == nil else { return }
        setHingeAngle(0.0)
        isSimulatingFold = true
        simulatedFold = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 600_000_000) }
            catch { return }
            guard let self else { return }
            self.simulatedFold = nil
            self.setHingeAngle(180.0)
            completion?()
        }
    }

    deinit { simulatedFold?.cancel() }

    static func posture(for degrees: Double, from current: DuoPosture) -> DuoPosture {
        switch current {
        case .foldedClosed:
            if degrees <= Threshold.closedExit { return .foldedClosed }
        case .bookOpen:
            if degrees >= Threshold.bookExit { return .bookOpen }
        case .tentOrLaptop, .singleDisplay:
            break
        }
        if degrees <= Threshold.closedEnter { return .foldedClosed }
        if degrees >= Threshold.bookEnter { return .bookOpen }
        return .tentOrLaptop
    }
}
