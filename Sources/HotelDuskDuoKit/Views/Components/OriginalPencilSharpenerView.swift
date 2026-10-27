import SwiftUI

/**
 * Shows the original pencil-sharpener scene and handles its quit icon.
 */
struct OriginalPencilSharpenerView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        GeometryReader { proxy in
            let input = OriginalPageInput(available: CGSize(width: max(0, proxy.size.width - 16),
                                                            height: max(0, proxy.size.height - 36)))
            if let image = play.pencilSharpenerImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: input.size.width, height: input.size.height)
                    .onPageTap { location in
                        guard let point = input.point(location) else { return }
                        play.tapPencilSharpener(pageX: Int(point.x), pageY: Int(point.y))
                    }
                    .notebookPhotograph()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }
}
