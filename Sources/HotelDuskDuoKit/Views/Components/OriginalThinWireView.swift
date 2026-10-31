import SwiftUI

/**
 * Forwards page touches to the session-owned wire-lock process.
 */
struct OriginalThinWireView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                ZStack {
                    Color.black
                    if let image = play.thinWireImage {
                        Image(decorative: image, scale: 1).resizable().interpolation(.high).frame(width: 192, height: 256)
                    }
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdThinWireTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseThinWireTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel(play.thinWire?.variant.isDoor == true ? "Door lock" : "Suitcase lock")
            }
            Button("Back") { play.quitThinWire() }
                .disabled(play.thinWire?.canQuit != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseThinWireTouch() }
    }
}
