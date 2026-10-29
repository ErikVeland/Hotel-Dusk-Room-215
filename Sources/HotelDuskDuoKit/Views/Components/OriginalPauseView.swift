import SwiftUI

struct OriginalPauseView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Paused").font(NovelStyle.title)
                Button("Resume") { session.closePauseMenu() }
                if let save = session.resumeSave {
                    Text("Chapter \(save.chapterNumber) · \(save.savedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(NovelStyle.caption)
                    Button("Recall saved place") { session.continueSavedGame() }
                }
                if let error = session.saveError {
                    Text(error).font(NovelStyle.caption).foregroundStyle(NovelStyle.redInk)
                    Button("Retry save") { session.saveCurrentPlace() }
                }
                Text("Every step saves immediately. Recall returns to your exact conversation, choice, puzzle or notebook page. There are no manual save points.")
                    .font(NovelStyle.caption)
                Toggle("Mute sound", isOn: Binding(get: { session.audioController.isMuted },
                    set: { session.audioController.isMuted = $0 }))
                MusicSourcePicker(audio: session.audioController)
                Slider(value: Binding(get: { Double(session.audioController.volume) },
                    set: { session.audioController.volume = Float($0) }), in: 0...1) {
                    Text("Sound volume")
                }
                .accessibilityLabel("Sound volume")
                if let error = session.audioController.lastError {
                    Text("Sound could not play: \(error)")
                        .font(NovelStyle.caption).foregroundStyle(NovelStyle.redInk)
                }
                Button("Return to title") { session.endOriginalGame() }
                Divider()
                Text("How to play").font(NovelStyle.title)
                Text("Drag the 3D view to look around and hold its pad to move. You can also hold a point on the floor plan to walk. Face a person, door or object to enable Talk, Door or Inspect. Tap an object once to interact. Choose an item first, then tap its target. Tap to finish the writing, then tap to continue or turn the spread. Use the speech-bubble button to interrupt.")
                    .font(NovelStyle.body)
            }
            .buttonStyle(BookTextButtonStyle())
            .multilineTextAlignment(.center)
            .padding(.vertical, 16)
        }

    }
}

struct MusicSourcePicker: View {
    @ObservedObject var audio: AudioController

    var body: some View {
        Picker("Music source", selection: Binding(get: { audio.musicSource },
            set: { audio.selectMusicSource($0) })) {
            ForEach(AudioController.MusicSource.allCases) { source in
                Text(source.title).tag(source)
            }
        }
    }
}
