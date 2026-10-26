import SwiftUI

/**
 * Forwards page touches to the session-owned toiletTank process.
 */
struct OriginalToiletTankView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                let brightness = play.toiletTankScreenEffects.brightness[0].coefficient
                ZStack {
                    Color.black
                    if let image = play.toiletTankImage {
                        Image(decorative: image, scale: 1).interpolation(.none)
                    }
                    (brightness > 0 ? Color.white : Color.black)
                        .opacity(Double(min(16, abs(brightness))) / 16)
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdToiletTankTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseToiletTankTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Toilet tank")
            }
            Button("Back") { play.quitToiletTank() }
                .disabled(play.toiletTank?.canQuit != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseToiletTankTouch() }
    }
}
