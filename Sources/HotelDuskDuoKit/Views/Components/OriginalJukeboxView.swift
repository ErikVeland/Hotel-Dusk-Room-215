import SwiftUI

/**
 * Lists the jukebox records with their original titles. The source draws a rotating
 * 3D record rack instead; selection and playback follow the session-owned process.
 */
struct OriginalJukeboxView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack(spacing: 8) {
            if let jukebox = play.jukebox {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(jukebox.titles.indices, id: \.self) { record in
                            Button {
                                play.selectJukeboxRecord(record)
                            } label: {
                                HStack {
                                    Text(String(format: "%02d", record + 1)).monospacedDigit()
                                    Text(jukebox.titles[record])
                                    Spacer()
                                    if jukebox.playing == record { Image(systemName: "speaker.wave.2") }
                                }
                            }
                            .buttonStyle(BookTextButtonStyle())
                            .accessibilityAddTraits(jukebox.playing == record ? .isSelected : [])
                        }
                    }
                }
            }
            Button("Back") { play.quitJukebox() }
                .buttonStyle(BookTextButtonStyle())
        }
        .padding(.horizontal, 16)
    }
}
