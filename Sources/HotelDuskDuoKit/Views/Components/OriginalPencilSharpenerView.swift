import SwiftUI

/**
 * Shows the original pencil-sharpener scene and handles its quit icon.
 */
struct OriginalPencilSharpenerView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        GeometryReader { proxy in
            let input = OriginalPageInput(available: CGSize(width: max(0, proxy.size.width - 16),
                                                            height: max(0, proxy.size.height - 68)))
            let progress = play.pencilSharpener?.powderProgressFraction ?? 0
            if let image = play.pencilSharpenerImage {
                VStack(spacing: 10) {
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
                        .accessibilityLabel("Pencil sharpener. Drag the pencil back and forth to sharpen it.")

                    VStack(spacing: 4) {
                        Text("Drag the pencil back and forth to sharpen it")
                            .font(.caption)
                        ProgressView(value: progress)
                            .tint(.brown)
                            .accessibilityLabel("Sharpening progress")
                            .accessibilityValue("\(Int((progress * 100).rounded())) percent")
                    }
                    .frame(maxWidth: max(0, min(280, proxy.size.width - 32)))
                }
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .onDisappear { play.releasePencilSharpenerTouch() }
    }
}
