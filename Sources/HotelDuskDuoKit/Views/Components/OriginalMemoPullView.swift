import SwiftUI

/**
 * Forwards page touches to the session-owned memo process.
 */
struct OriginalMemoPullView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                let brightness = play.memoPullScreenEffects.brightness[0].coefficient
                ZStack {
                    Color.black
                    if let image = play.memoPullImage {
                        Image(decorative: image, scale: 1).interpolation(.none)
                    }
                    (brightness > 0 ? Color.white : Color.black)
                        .opacity(Double(min(16, abs(brightness))) / 16)
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdMemoPullTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseMemoPullTouch() })
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Trapped memo")
            }
            Button("Back") { play.quitMemoPull() }
                .disabled(play.memoPull?.canQuit != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseMemoPullTouch() }
    }
}
