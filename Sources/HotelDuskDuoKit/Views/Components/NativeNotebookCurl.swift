#if canImport(UIKit)
import SwiftUI

/// Render one sheet across the full spread so its reverse crosses the spine.
/// The same mesh keeps both display surfaces in one page turn.
struct NativeNotebookCurl: View {
    let play: OriginalPlaySession
    @ObservedObject var notebook: DialogueNotebook
    let layout: DialogueNotebookLayout
    let metrics: DialogueSpreadMetrics
    let fontSize: CGFloat
    let reduceMotion: Bool

    var body: some View {
        DesktopNotebookSpread(play: play, notebook: notebook, layout: layout,
                              metrics: metrics, reduceMotion: reduceMotion)
    }
}
#endif
