import SwiftUI

/**
 * Shows the recovered bowling scene and forwards held page touches.
 */
struct OriginalBowlingView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        GeometryReader { proxy in
            let input = OriginalPageInput(available: CGSize(width: max(0, proxy.size.width - 16),
                                                            height: max(0, proxy.size.height - 36)))
            if let image = play.bowlingImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: input.size.width, height: input.size.height)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard let point = input.point(value.location) else { return }
                            play.holdBowlingTouch(pageX: Float(point.x), pageY: Float(point.y))
                        }
                        .onEnded { _ in play.releaseBowlingTouch() })
                    .notebookPhotograph()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .accessibilityLabel("Bowling lane")
            }
        }
        .onDisappear { play.releaseBowlingTouch() }
    }
}
