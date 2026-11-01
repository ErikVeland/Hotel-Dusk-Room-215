import SwiftUI

/**
 * Draws the original picture and forwards input in 192×256 page coordinates.
 */
struct OriginalTouchPictureView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        if let item = play.acquiredItemImage {
            GeometryReader { proxy in
                let available = CGSize(width: max(0, proxy.size.width - 48), height: max(0, proxy.size.height - 48))
                let scale = max(0, min(available.width / CGFloat(item.width), available.height / CGFloat(item.height)))
                let size = CGSize(width: CGFloat(item.width) * scale, height: CGFloat(item.height) * scale)
                OriginalZoomableCanvas(contentSize: size) {
                    Image(decorative: item, scale: 1)
                        .resizable().interpolation(.high)
                        .frame(width: size.width, height: size.height)
                        .accessibilityLabel("Acquired item")
                }
                .padding(24)
            }
        } else if let images = play.touchPictureImages {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                OriginalZoomableCanvas(contentSize: CGSize(width: 192 * scale, height: 256 * scale), onTap: { point in
                    guard scale > 0 else { return }
                    play.activatePicture(pageX: Int(point.x / scale), pageY: Int(point.y / scale))
                }) {
                    ZStack(alignment: .topLeading) {
                        Color.clear
                        if let background = images.background { layer(background, x: 0, y: 0, scale: scale) }
                        if play.acquiredItemImage == nil, play.touchPicture == nil || play.touchPicture?.phase == .selecting {
                            layer(images.foreground, x: images.x, y: images.y, scale: scale)
                            if play.touchPicture?.selected == true { layer(images.highlight, x: images.x, y: images.y, scale: scale) }
                        }
                    }
                    .frame(width: 192 * scale, height: 256 * scale)
                    .notebookPhotograph()
                }
            }
        }
    }

    private func layer(_ image: CGImage, x: Int, y: Int, scale: CGFloat, smooth: Bool = false) -> some View {
        Image(decorative: image, scale: 1)
            .resizable().interpolation(smooth || image.width > image.artworkWidth ? .high : .none)
            .frame(width: CGFloat(image.artworkWidth) * scale, height: CGFloat(image.artworkHeight) * scale)
            .offset(x: CGFloat(x) * scale, y: CGFloat(y) * scale)
            .allowsHitTesting(false)
    }
}
