import SwiftUI

/**
 * Forwards page touches to the session-owned suitcase process.
 */
struct OriginalSuitcaseKeyView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                ZStack {
                    Color.black
                    if let image = play.suitcaseImage {
                        Image(decorative: image, scale: 1).interpolation(.none)
                    }
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdSuitcaseTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseSuitcaseTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Suitcase lock")
            }
            Button("Back") { play.quitSuitcaseKey() }
                .disabled(play.suitcaseKey?.canQuit != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseSuitcaseTouch() }
    }
}
