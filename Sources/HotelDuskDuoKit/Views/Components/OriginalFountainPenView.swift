import SwiftUI

/**
 * Forwards page touches to the session-owned fountainPen process.
 */
struct OriginalFountainPenView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                let brightness = play.fountainPenScreenEffects.brightness[0].coefficient
                ZStack {
                    Color.black
                    if let image = play.fountainPenImage {
                        Image(decorative: image, scale: 1).resizable().interpolation(.high).frame(width: 192, height: 256)
                    }
                    (brightness > 0 ? Color.white : Color.black)
                        .opacity(Double(min(16, abs(brightness))) / 16)
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdFountainPenTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseFountainPenTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Fountain pen")
            }
            if play.fountainPen?.phase == 2 {
                OriginalPuzzleMicrophoneView(play: play, microphone: play.puzzleMicrophone)
            }
            Button("Back") { play.quitFountainPen() }
                .disabled(play.fountainPen?.canQuit != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseFountainPenTouch() }
    }
}
