import SwiftUI

/**
 * Presents notebook ink and forwards page, pen and eraser input to the session.
 */
struct OriginalNotebookView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        if let notebook = play.notebook {
            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                    ZStack {
                        Color.clear
                        if let image = play.notebookImage {
                            Image(decorative: image, scale: 1).resizable().interpolation(.none)
                        }
                    }
                    .frame(width: 192 * scale, height: 256 * scale)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard scale > 0 else { return }
                            play.holdNotebookTouch(x: Int(value.location.x / scale), y: Int(value.location.y / scale))
                        }
                        .onEnded { _ in play.releaseNotebook() })
                    .notebookPhotograph()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .accessibilityLabel("Notebook page \(notebook.page + 1)")
                }
                if notebook.canEdit {
                    HStack {
                        Button("Clear") { play.clearNotebookPage() }
                        Button(notebook.erasing ? "Pen" : "Eraser") { play.toggleNotebookEraser() }
                        Button("Undo") { play.undoNotebookEdit() }
                    }.buttonStyle(BookTextButtonStyle())
                }
                HStack {
                    Button("Previous") { play.turnNotebookPage(forward: false) }
                    Text("\(notebook.page + 1)/\(notebook.pageCount)").font(NovelStyle.caption)
                    Button("Next") { play.turnNotebookPage(forward: true) }
                    Button("Back") { play.closeNotebook() }
                }.buttonStyle(BookTextButtonStyle())
            }
            .foregroundStyle(NovelStyle.ink)
            .onDisappear { play.releaseNotebook() }
        }
    }
}
