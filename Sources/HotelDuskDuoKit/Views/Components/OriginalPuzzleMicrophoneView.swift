import SwiftUI

struct OriginalPuzzleMicrophoneView: View {
    @ObservedObject var play: OriginalPlaySession
    @ObservedObject var microphone: OriginalMicrophoneInput

    var body: some View {
        VStack(spacing: 4) {
            Button(microphone.isRunning ? "Turn microphone off" : "Enable microphone") {
                if microphone.isRunning { microphone.stop() }
                else { Task { await play.enablePuzzleMicrophone() } }
            }
            .buttonStyle(BookTextButtonStyle())
            if let error = microphone.error {
                Text(error).font(.caption).multilineTextAlignment(.center)
            }
        }
    }
}
