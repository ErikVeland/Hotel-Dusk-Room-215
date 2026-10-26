import SwiftUI

struct OriginalTitleMenuView: View {
    @ObservedObject var session: GameSession
    @State private var confirmsNewGame = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("THE ARRIVAL").font(NovelStyle.imprint).tracking(3)
                        .foregroundStyle(NovelStyle.redInk)
                    Text("December 28th,\n1979").font(NovelStyle.title)
                    InkRule().padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let save = session.resumeSave {
                    Button("Continue · Chapter \(save.chapterNumber)") { session.continueSavedGame() }
                    Text(save.savedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(NovelStyle.caption)
                }
                if session.canStartOriginalGame {
                    Button("Begin Chapter 1") {
                        if session.resumeSave != nil { confirmsNewGame = true }
                        else { session.startOriginalGame() }
                    }
                }
                ForEach(0..<3, id: \.self) { slot in
                    if let save = session.chapterSaves[slot] {
                        Button("Load slot \(slot + 1) · Chapter \(save.chapterNumber)") { session.loadChapterSave(slot: slot) }
                    }
                }
                Text("Tap to finish the writing, then tap to continue or turn the spread. Use the movement pad or floor plan to walk. Open Book options for the controls.")
                    .font(NovelStyle.italic)
                    .foregroundStyle(NovelStyle.fadedInk)
                    .padding(.top, 12)
                Text("Playable through Chapter 1 and part of Chapter 2. Later chapters and some interactions are unfinished.")
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
        .confirmationDialog("Start a new game? Its first checkpoint will replace Continue. Chapter save slots will remain available.",
                            isPresented: $confirmsNewGame, titleVisibility: .visible) {
            Button("Begin Chapter 1", role: .destructive) { session.startOriginalGame() }
        }
    }
}
