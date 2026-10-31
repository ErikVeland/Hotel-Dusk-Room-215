import SwiftUI

/**
 * Presents one recovered apple painting and its letter acknowledgement.
 */
struct OriginalApplePaintingView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 16) / 256))
                ZStack {
                    Color.black
                    if let image = play.applePaintingImage {
                        Image(decorative: image, scale: 1).resizable().interpolation(.high).frame(width: 192, height: 256)
                    }
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        let distance = value.translation.width.magnitude + value.translation.height.magnitude
                        if distance < 8 {
                            play.touchApplePainting(pageX: Int(value.location.x), pageY: Int(value.location.y))
                        } else {
                            let horizontal = Int((value.translation.width / 4).rounded())
                            let vertical = Int((value.translation.height / 4).rounded())
                            play.moveApplePaintingCamera(horizontalSteps: horizontal,
                                                         verticalSteps: vertical)
                        }
                    })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Apple painting")
            }
            if case .revealed(let letter) = play.applePainting?.phase {
                Text(verbatim: "Letter: \(letter)").font(.headline)
                Button("Continue") { play.acknowledgeApplePaintingLetter() }
            } else {
                Text("Tap the letter hidden in the painting.")
            }
        }
    }
}
