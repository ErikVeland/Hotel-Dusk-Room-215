import SwiftUI

/**
 * Presents the session's clock image while the original transition runs.
 */
struct OriginalClockView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        GeometryReader { proxy in
            let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
            ZStack {
                Color.black
                if let image = play.clockImage {
                    Image(decorative: image, scale: 1).interpolation(.none)
                }
            }
            .frame(width: 192, height: 256)
            .scaleEffect(scale)
            .frame(width: 192 * scale, height: 256 * scale)
            .notebookPhotograph()
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .accessibilityLabel(play.clock?.label ?? "")
        }
    }
}
