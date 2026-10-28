import SwiftUI

struct OriginalVSScenePageView: View {
    @ObservedObject var play: OriginalPlaySession
    let screen: UInt8

    var body: some View {
        GeometryReader { proxy in
            let scale = max(0, min((proxy.size.width - 16) / 192,
                                  (proxy.size.height - 16) / 256))
            ZStack {
                Color.black
                if let base = play.lobbyImage {
                    Image(decorative: base, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 192 * scale, height: 256 * scale)
                }
                if screen == 1, let overlay = play.vsSceneImage {
                    Image(decorative: overlay, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 192 * scale, height: 256 * scale)
                }
            }
            .frame(width: 192 * scale, height: 256 * scale)
            .opacity(play.vsScene?.opacity ?? 1)
            .contentShape(Rectangle())
            .onPageTap { _ in
                if screen == 0 { play.touchVSScene() }
            }
            .notebookPhotograph()
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}
