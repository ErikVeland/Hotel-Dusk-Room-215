import SwiftUI

/**
 * Draws the original picture and forwards input in 192×256 page coordinates.
 */
struct OriginalTouchPictureView: View {
    @ObservedObject var play: OriginalPlaySession
    @State private var pressStarted = false
    @State private var noticePress = false

    var body: some View {
        if let images = play.touchPictureImages {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                ZStack(alignment: .topLeading) {
                    Color.clear
                    if let background = images.background { layer(background, x: 0, y: 0, scale: scale) }
                    if let item = play.acquiredItemImage {
                        layer(item, x: 32, y: 64, scale: scale)
                    } else if let picture = play.touchPicture, picture.phase == .selecting {
                        layer(images.foreground, x: images.x, y: images.y, scale: scale)
                        if picture.selected { layer(images.highlight, x: images.x, y: images.y, scale: scale) }
                    }
                }
                .frame(width: 192 * scale, height: 256 * scale)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard scale > 0 else { return }
                        if !pressStarted {
                            pressStarted = true
                            noticePress = play.acquiredItemImage != nil
                        }
                        play.touchPicture(pageX: Int(value.location.x / scale), pageY: Int(value.location.y / scale))
                    }
                    .onEnded { _ in
                        play.releasePicture()
                        if noticePress { play.advanceDialogue() }
                        pressStarted = false
                        noticePress = false
                    })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func layer(_ image: CGImage, x: Int, y: Int, scale: CGFloat) -> some View {
        Image(decorative: image, scale: 1)
            .resizable().interpolation(.none)
            .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            .offset(x: CGFloat(x) * scale, y: CGFloat(y) * scale)
            .allowsHitTesting(false)
    }
}
