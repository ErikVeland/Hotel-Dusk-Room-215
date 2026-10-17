#if canImport(UIKit)
import SwiftUI
import UIKit

/// Invisible view that feeds `UIHingeInteraction` updates into a `DuoHingeManager`.
/// Put it in the background of the root view. On devices without a hinge (or before
/// iOS 27.1) it does nothing, and the debug slider stays in control.
struct HingeObserverView: UIViewRepresentable {
    let manager: DuoHingeManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        if #available(iOS 27.1, *) {
            let interaction = UIHingeInteraction { [weak manager] _, update in
                guard let manager, let hinge = update.hinge else { return }
                let state: DuoHingeManager.FoldState
                switch hinge.status {
                case .closed: state = .closed
                case .fullyOpen: state = .fullyOpen
                case .partiallyOpen: state = .partiallyOpen
                default: return // An unavailable reading must not turn a closed puzzle over.
                }
                manager.receiveHardwareState(state, angleDegrees: Self.degrees(for: hinge))
            }
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    /// `status` is the reliable signal; the angle's precision is system policy.
    /// Pin the end states so posture changes do not depend on angle accuracy.
    @available(iOS 27.1, *)
    static func degrees(for hinge: UIHinge) -> Double {
        switch hinge.status {
        case .closed:
            return 0
        case .fullyOpen:
            return 180
        default:
            return Double(hinge.angle) * 180 / .pi
        }
    }
}
#endif
