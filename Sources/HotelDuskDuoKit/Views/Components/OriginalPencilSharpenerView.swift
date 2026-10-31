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
                    .interpolation(image.width > 192 ? .high : .none)
                    .frame(width: input.size.width, height: input.size.height)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard let point = input.point(value.location) else { return }
                            play.holdPencilSharpenerTouch(pageX: Int(point.x.rounded()),
                                                          pageY: Int(point.y.rounded()))
                        }
                        .onEnded { value in
                            play.releasePencilSharpenerTouch()
                            guard OriginalPageInput.isTap(from: value.startLocation,
                                                          to: value.location),
                                  let point = input.point(value.startLocation) else { return }
                            play.tapPencilSharpener(pageX: Int(point.x.rounded()),
                                                    pageY: Int(point.y.rounded()))
                        })
                    .notebookPhotograph()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .onDisappear { play.releasePencilSharpenerTouch() }
    }
}
