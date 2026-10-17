import SwiftUI

/**
 * Forwards page touches to the session-owned cabinet dial process.
 */
struct OriginalCabinetDialView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                let brightness = play.cabinetDialScreenEffects.brightness[0].coefficient
                ZStack {
                    Color.black
                    if let image = play.cabinetDialImage {
                        Image(decorative: image, scale: 1).interpolation(.none)
                    }
                    (brightness > 0 ? Color.white : Color.black)
                        .opacity(Double(min(16, abs(brightness))) / 16)
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdCabinetDialTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseCabinetDialTouch() })
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Cabinet number wheels")
            }
            Button("Back") { play.quitCabinetDial() }
                .disabled(play.cabinetDial?.canQuit != true)
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseCabinetDialTouch() }
    }
}
