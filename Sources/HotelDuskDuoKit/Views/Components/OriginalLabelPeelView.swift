import SwiftUI

/**
 * Forwards a label-peeling drag to the session-owned Chapter 6 process.
 */
struct OriginalLabelPeelView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        GeometryReader { proxy in
            let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 16) / 256))
            let brightness = play.labelPeelScreenEffects.brightness[0].coefficient
            ZStack {
                Color.black
                if let image = play.labelPeelImage {
                    Image(decorative: image, scale: 1).resizable().interpolation(.high).frame(width: 192, height: 256)
                }
                (brightness > 0 ? Color.white : Color.black)
                    .opacity(Double(min(16, abs(brightness))) / 16)
            }
            .frame(width: 192, height: 256)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    play.holdLabelPeelTouch(x: Float(value.location.x), y: Float(value.location.y))
                }
                .onEnded { _ in play.releaseLabelPeelTouch() })
            .scaleEffect(scale)
            .frame(width: 192 * scale, height: 256 * scale)
            .notebookPhotograph()
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .accessibilityLabel("Peel the wine label")
        }
        .onDisappear { play.releaseLabelPeelTouch() }
    }
}
