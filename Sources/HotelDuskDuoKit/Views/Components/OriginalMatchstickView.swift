import SwiftUI

/**
 * Forwards page touches to the session-owned matchsticks process.
 */
struct OriginalMatchstickView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                let brightness = play.matchsticksScreenEffects.brightness[0].coefficient
                ZStack {
                    Color.black
                    if let image = play.matchsticksImage {
                        Image(decorative: image, scale: 1).interpolation(.none)
                    }
                    (brightness > 0 ? Color.white : Color.black)
                        .opacity(Double(min(16, abs(brightness))) / 16)
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdMatchsticksTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseMatchsticksTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Remove matchsticks to leave three shapes")
            }
            Text("Remove \(max(0, (play.matchsticks?.removalLimit ?? 0) - (play.matchsticks?.removed ?? 0))) more")
                .font(.caption)
            Button("Reset") { play.resetMatchsticks() }
                .disabled(play.matchsticks?.canReset != true)
                .buttonStyle(BookTextButtonStyle())
            Button("Back") { play.quitMatchsticks() }
                .disabled(play.matchsticks?.canQuit != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseMatchsticksTouch() }
    }
}
