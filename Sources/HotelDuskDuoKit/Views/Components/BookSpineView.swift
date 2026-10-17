import SwiftUI

/// The Metal binding valley stretches and deepens with the physical hinge.
struct BookSpineView: View {
    let angleDegrees: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { display in
            let closedAmount = CGFloat(1 - max(0, min(180, angleDegrees)) / 180)
            let curve = pow(closedAmount, 0.75)
            let width = min(display.size.width * 0.14, 28 + curve * 92)
            MetalBookMaterial(pass: .spine, angle: angleDegrees)
                .frame(width: width, height: display.size.height)
                .position(x: display.size.width / 2, y: display.size.height / 2)
                .animation(reduceMotion ? nil : .linear(duration: 0.12), value: angleDegrees)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
