import SwiftUI

/**
 * Draws the brightness blend for process fades on the rendered screen.
 */
struct OriginalProcessBrightnessOverlay: View {
    let coefficient: Int

    var body: some View {
        (coefficient > 0 ? Color.white : Color.black)
            .opacity(Double(min(16, abs(coefficient))) / 16)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
