import SwiftUI

/**
 * Forwards page touches to the session-owned coinPuzzle process.
 */
struct OriginalCoinView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                let brightness = play.coinPuzzleScreenEffects.brightness[0].coefficient
                ZStack {
                    Color.black
                    if let image = play.coinPuzzleImage {
                        Image(decorative: image, scale: 1).interpolation(.none)
                    }
                    (brightness > 0 ? Color.white : Color.black)
                        .opacity(Double(min(16, abs(brightness))) / 16)
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdCoinPuzzleTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseCoinPuzzleTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Arrange the six coins")
            }
            Button("Check") { play.checkCoinPuzzle() }
                .disabled(play.coinPuzzle?.canCheck != true)
                .buttonStyle(BookTextButtonStyle())
            Button("Back") { play.quitCoinPuzzle() }
                .disabled(play.coinPuzzle?.canQuit != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseCoinPuzzleTouch() }
    }
}
