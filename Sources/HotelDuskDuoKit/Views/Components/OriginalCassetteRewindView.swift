import SwiftUI

/**
 * Forwards page touches to the cassette rewind process.
 */
struct OriginalCassetteRewindView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 16) / 256))
                ZStack {
                    Color.black
                    if let image = play.cassetteImage {
                        Image(decorative: image, scale: 1).resizable().interpolation(.high).frame(width: 192, height: 256).opacity(play.cassetteOpacity)
                    }
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdCassetteTouch(pageX: Int(value.location.x), pageY: Int(value.location.y))
                    }
                    .onEnded { _ in play.releaseCassetteTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Cassette")
            }
            if let deck = play.cassetteDeck {
                switch deck.phase {
                case .controlsReady:
                    HStack {
                        Text(deck.selectedSelector == nil ? "Select a cassette control." : "Control selected.")
                        Button("Play selection") { play.activateCassetteDeckControl() }
                            .disabled(deck.selectedSelector == nil)
                    }
                case .playing:
                    Button("Return to story") { play.exitCassetteDeck() }
                default:
                    EmptyView()
                }
            }
        }
        .onDisappear { play.releaseCassetteTouch() }
    }
}
