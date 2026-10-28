import SwiftUI

struct OriginalAfterConfessPageView: View {
    @ObservedObject var play: OriginalPlaySession
    let screen: UInt8

    var body: some View {
        GeometryReader { proxy in
            let image = screen == 0 ? play.afterConfessTouchImage : play.afterConfessUpperImage
            let scale = max(0, min((proxy.size.width - 16) / 192,
                                  (proxy.size.height - 16) / 256))
            ZStack {
                Color.black
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 192 * scale, height: 256 * scale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
