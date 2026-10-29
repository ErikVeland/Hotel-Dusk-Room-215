import SwiftUI

/**
 * Draws the original picture and forwards input in 192×256 page coordinates.
 */
struct OriginalTouchPictureView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        if let images = play.touchPictureImages {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                ZStack(alignment: .topLeading) {
                    Color.clear
                    if let background = images.background { layer(background, x: 0, y: 0, scale: scale) }
                    if let item = play.acquiredItemImage {
                        layer(item, x: 32, y: 64, scale: scale, smooth: true)
                    } else if let picture = play.touchPicture, picture.phase == .selecting {
                        layer(images.foreground, x: images.x, y: images.y, scale: scale)
                        if picture.selected { layer(images.highlight, x: images.x, y: images.y, scale: scale) }
                    }
                }
                .frame(width: 192 * scale, height: 256 * scale)
                .contentShape(Rectangle())
                .onPageTap { point in
                    guard scale > 0 else { return }
                    if play.acquiredItemImage != nil { play.advanceWrittenDialogue() }
                    else { play.activatePicture(pageX: Int(point.x / scale), pageY: Int(point.y / scale)) }
                }
                .notebookPhotograph()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func layer(_ image: CGImage, x: Int, y: Int, scale: CGFloat, smooth: Bool = false) -> some View {
        Image(decorative: image, scale: 1)
            .resizable().interpolation(smooth ? .high : .none)
            .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            .offset(x: CGFloat(x) * scale, y: CGFloat(y) * scale)
            .allowsHitTesting(false)
    }
}
