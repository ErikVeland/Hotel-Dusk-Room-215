import SwiftUI

struct OriginalTitleMenuView: View {
    @ObservedObject var session: GameSession
    @State private var confirmsNewGame = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HOTEL DUSK · ROOM 215").font(NovelStyle.imprint).tracking(3)
                        .foregroundStyle(NovelStyle.redInk)
                    Text("December 28th,\n1979").font(NovelStyle.title)
                    InkRule().padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let save = session.resumeSave {
                    Button("Continue · Chapter \(save.chapterNumber)") { session.continueSavedGame() }
                    Text(save.savedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(NovelStyle.caption)
                    Text(save.progress == nil
                         ? "Saved walking checkpoint. New progress will also retain conversations and interactions in progress."
                         : "Your place is saved, including conversations and interactions in progress.")
                        .font(NovelStyle.caption)
                }
                if session.canStartOriginalGame {
                    Button("Begin Chapter 1") {
                        if session.resumeSave != nil { confirmsNewGame = true }
                        else { session.startOriginalGame() }
                    }
                }
                if session.resumeSave == nil,
                   let legacy = session.chapterSaves.enumerated().compactMap({ slot, save in
                       save.map { (slot: slot, date: $0.savedAt) }
                   }).max(by: { $0.date < $1.date }) {
                    Button("Continue previous save") { session.loadChapterSave(slot: legacy.slot) }
                }
                Text("Tap to finish the writing, then tap to continue. Drag a page to turn it, hold it partway, or move it back to cancel. Use the movement pad or floor plan to walk. Open Book options for the controls.")
                    .font(NovelStyle.italic)
                    .foregroundStyle(NovelStyle.fadedInk)
                    .padding(.top, 12)
                Text("Work in progress · 29 October 2026")
                    .font(NovelStyle.imprint)
                Text("The checked new-game route completes Chapters 1–4. Later route tests cover Chapters 5–7 and parts of Chapter 8 from saved checkpoints. The full game, some branches and original presentation remain unfinished.")
                    .font(NovelStyle.caption)
                Text("Every step saves immediately, including movement, conversations, puzzle actions and writing. Continue returns to your current place. There are no manual save points.")
                    .font(NovelStyle.caption)
                if let error = session.saveError { Text(error).font(NovelStyle.caption) }
                if session.sourceError != nil {
                    Text("The original game data could not be loaded.").font(NovelStyle.caption)
                }
            }
            .buttonStyle(BookTextButtonStyle())
            .multilineTextAlignment(.leading)
            .padding(.vertical, 24)
        }
        .confirmationDialog("Start a new game? This will replace your current progress immediately.",
                            isPresented: $confirmsNewGame, titleVisibility: .visible) {
            Button("Begin Chapter 1", role: .destructive) { session.startOriginalGame() }
        }
    }
}
