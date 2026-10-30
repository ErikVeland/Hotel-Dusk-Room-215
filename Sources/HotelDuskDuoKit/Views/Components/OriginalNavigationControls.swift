import SwiftUI

/// The pad moves relative to the camera. Releasing it always stops movement.
struct OriginalNavigationControls: View {
    @ObservedObject var play: OriginalPlaySession
    var compact = false
    @GestureState private var touch: CGPoint?
    private let diameter: CGFloat = 112

    private func offset(_ point: CGPoint) -> CGSize {
        let x = point.x - diameter / 2, y = point.y - diameter / 2
        let divisor = max(1, hypot(x, y) / 38)
        return CGSize(width: x / divisor, height: y / divisor)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(NovelStyle.ink.opacity(0.06))
                Circle().strokeBorder(NovelStyle.rule, lineWidth: 1)
                Image(systemName: "arrow.up").offset(y: -40)
                Image(systemName: "arrow.down").offset(y: 40)
                Image(systemName: "arrow.left").offset(x: -40)
                Image(systemName: "arrow.right").offset(x: 40)
                Circle().fill(NovelStyle.ink.opacity(touch == nil ? 0.25 : 0.55))
                    .frame(width: 34, height: 34)
                    .offset(touch.map(offset) ?? .zero)
            }
            .font(.system(size: 12, weight: .semibold))
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .updating($touch) { value, state, _ in state = value.location }
                .onChanged { value in
                    let direction = offset(value.location)
                    play.holdFirstPersonMovement(strafe: Float(direction.width / 38),
                                                 forward: Float(-direction.height / 38))
                }
                .onEnded { _ in play.releaseLobbyTouch() })
            .accessibilityLabel("Movement pad")
            .accessibilityHint("Hold up or down to walk. Hold left or right to move sideways.")
            if !compact {
                Text("Drag the view to look around.\n\nHold the pad to walk or move sideways.")
                    .font(NovelStyle.caption)
            }
        }
        .foregroundStyle(NovelStyle.ink)
        .onDisappear { play.releaseLobbyTouch() }
    }
}
