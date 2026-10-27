import SwiftUI

/**
 * Shows the Chapter 9 CPR prompt and the software fold control.
 */
struct OriginalCPRView: View {
    @ObservedObject var hingeManager: DuoHingeManager
    let screen: UInt8

    var body: some View {
        VStack(spacing: 16) {
            Text(screen == 0 ? "Mila needs help." : "CPR")
                .font(.headline)
            if screen == 0 {
                Text("Close and reopen the Duo to perform CPR.")
                    .multilineTextAlignment(.center)
                if !hingeManager.hasHardwareHinge {
                    Button("Perform CPR") {
                        hingeManager.performFoldGesture()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
