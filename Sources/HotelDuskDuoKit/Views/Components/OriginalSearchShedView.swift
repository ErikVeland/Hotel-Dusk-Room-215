import SwiftUI

/**
 * Shows the recovered storage scene and forwards box drags to the session.
 */
struct OriginalSearchShedView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                let brightness = play.searchShedScreenEffects.brightness[0].coefficient
                ZStack {
                    Color.black
                    if let image = play.searchShedImage {
                        Image(decorative: image, scale: 1).interpolation(.none)
                    }
                    (brightness > 0 ? Color.white : Color.black)
                        .opacity(Double(min(16, abs(brightness))) / 16)
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdSearchShedTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseSearchShedTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Search the storage shed for the Christmas tree box")
            }
            if play.searchShed?.canOpenFoundBox == true {
                Button("Open tree box") { play.openSearchShedTreeBox() }
                    .buttonStyle(BookTextButtonStyle())
            }
            Button("Menu") { play.openSearchShedMenu() }
                .disabled(play.searchShed?.canOpenMenu != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseSearchShedTouch() }
    }
}
