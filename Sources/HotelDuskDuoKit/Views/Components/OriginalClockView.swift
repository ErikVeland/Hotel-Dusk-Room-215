import SwiftUI

/**
 * Presents the session's clock image while the original transition runs.
 */
struct OriginalClockView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 192, proxy.size.height / 256)
            ZStack {
                Color.black
                if let image = play.clockImage {
                    Image(decorative: image, scale: 1).interpolation(.none)
                }
            }
            .frame(width: 192, height: 256)
            .scaleEffect(scale)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .accessibilityLabel(play.clock?.label ?? "")
        }
    }
}
