import SwiftUI

/**
 * Forwards suitcase touches to the session-owned process.
 */
struct OriginalSuitcaseContentsView: View {
    @ObservedObject var play: OriginalPlaySession
    var interactive = true

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                let brightness = play.suitcaseContentsScreenEffects.brightness[0].coefficient
                ZStack {
                    Color.black
                    if let image = play.suitcaseContentsImage {
                        Image(decorative: image, scale: 1).interpolation(.none)
                    }
                    (brightness > 0 ? Color.white : Color.black)
                        .opacity(Double(min(16, abs(brightness))) / 16)
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if interactive { play.holdSuitcaseContentsTouch(x: Float(value.location.x), y: Float(value.location.y)) }
                    }
                    .onEnded { _ in play.releaseSuitcaseContentsTouch() })
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Suitcase contents")
            }
            if interactive {
                Button("Back") { play.leaveSuitcaseContents() }
                    .disabled(play.suitcaseContents?.canGoBack != true)
                    .buttonStyle(BookTextButtonStyle())
            }
        }
        .onDisappear { play.releaseSuitcaseContentsTouch() }
    }
}
