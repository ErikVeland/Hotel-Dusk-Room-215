import SwiftUI

struct DialogueSpreadMetrics: Equatable {
    let pageSize: CGSize
    let margin: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    var textOrigin: CGPoint { CGPoint(x: margin, y: top + 36) }
    var textSize: CGSize {
        CGSize(width: max(0, pageSize.width - margin * 2),
               height: max(0, pageSize.height - textOrigin.y - bottom - 56))
    }
    init(size: CGSize, safeArea: EdgeInsets = EdgeInsets()) {
        pageSize = CGSize(width: size.width / 2, height: size.height)
        margin = max(36, safeArea.leading + 20, safeArea.trailing + 20)
        top = max(32, safeArea.top + 16)
        bottom = max(20, safeArea.bottom + 12)
    }
}

/// The spread owns pagination and the only writing clock. Gameplay handedness
/// never changes physical reading order.
struct NotebookDialogueSpread: View {
    @ObservedObject var play: OriginalPlaySession
    @ObservedObject var notebook: DialogueNotebook
    var safeArea = EdgeInsets()
    var isVisible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 18

    private struct LayoutKey: Equatable {
        let size: CGSize
        let font: CGFloat
        let ink: [OriginalDialogueLines.Run]
        let visible: Bool
    }
    private struct WritingKey: Equatable {
        let end: Int
        let paused: Bool
        let instant: Bool
        let turning: Bool
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = DialogueSpreadMetrics(size: proxy.size, safeArea: safeArea)
            let key = LayoutKey(size: metrics.textSize, font: fontSize, ink: notebook.ink, visible: isVisible && scenePhase == .active)
            let writing = WritingKey(end: notebook.reader.spreadEnd,
                paused: play.isPaused || notebook.isReviewing || scenePhase != .active || !isVisible,
                instant: reduceMotion || voiceOver, turning: notebook.isTurning)
            Group {
                if let layout = notebook.layout {
                    #if canImport(UIKit)
                    NativeNotebookCurl(play: play, notebook: notebook, layout: layout,
                                       metrics: metrics, fontSize: fontSize, reduceMotion: reduceMotion)
                    #else
                    DesktopNotebookSpread(play: play, notebook: notebook, layout: layout,
                                          metrics: metrics, reduceMotion: reduceMotion)
                    #endif
                } else {
                    HStack(spacing: 0) { PaperSurface(); PaperSurface(side: .right) }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { value in
                guard isVisible, !play.isPaused || notebook.isReviewing,
                      abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width > 60, play.canReviewConversations { notebook.turnBack() }
                else if value.translation.width < -60 { notebook.turnForward() }
            })
            .onChange(of: key, initial: true) { _, value in
                guard value.visible else { return }
                notebook.configure(DialogueNotebookLayout(runs: value.ink, size: value.size, fontSize: value.font))
            }
            .task(id: writing) {
                guard !writing.paused, !writing.turning else { return }
                if writing.instant { notebook.finishWriting(); return }
                while notebook.reader.isWriting {
                    do { try await Task.sleep(for: .milliseconds(30)) }
                    catch { return }
                    guard !Task.isCancelled, !play.isPaused, !notebook.isTurning,
                          isVisible, scenePhase == .active, !notebook.isReviewing else { return }
                    notebook.write()
                }
            }
            .onDisappear { notebook.finishTurn(revision: notebook.turnRevision) }
        }
    }
}

struct NotebookDialogueLeaf: View {
    @ObservedObject var play: OriginalPlaySession
    @ObservedObject var notebook: DialogueNotebook
    let layout: DialogueNotebookLayout
    let metrics: DialogueSpreadMetrics
    let pageIndex: Int

    private var interactive: Bool {
        if notebook.isReviewing { return false }
        switch play.runner.phase {
        case .dialogue, .itemNotice: return true
        default: return false
        }
    }

    var body: some View {
        let page = notebook.reader.page(at: pageIndex)
        let right = pageIndex % 2 == 1
        ZStack(alignment: .topLeading) {
            PaperSurface(side: right ? .right : .left)
            Text(right ? "FIELD NOTES" : "HOTEL DUSK")
                .font(NovelStyle.imprint).tracking(2)
                .foregroundStyle(NovelStyle.fadedInk)
                .lineLimit(1).minimumScaleFactor(0.7)
                .position(x: metrics.margin + 53, y: metrics.top + 10)
                .accessibilityHidden(true)
            Canvas { context, _ in
                context.withCGContext { layout.draw(page: page, revealedEnd: notebook.reader.revealedEnd, in: $0) }
            }
            .frame(width: metrics.textSize.width, height: metrics.textSize.height)
            .contentShape(Rectangle())
            .onTapGesture { if interactive { play.advanceWrittenDialogue() } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(layout.accessibleText(page: page))
            .offset(x: metrics.textOrigin.x, y: metrics.textOrigin.y)

            HStack(spacing: 12) {
                Text(String(format: "%03d", pageIndex + 1))
                    .font(NovelStyle.imprint).foregroundStyle(NovelStyle.fadedInk)
                    .accessibilityLabel("Page \(pageIndex + 1)")
                if right, !notebook.isReviewing, let item = play.acquiredItemImage {
                    Image(decorative: item, scale: 1)
                        .resizable().interpolation(.none).scaledToFit()
                        .frame(width: 32, height: 32)
                        .padding(3).background(NovelStyle.paper)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .accessibilityLabel("Acquired item")
                }
                if right, !notebook.isReviewing, play.runner.interruptAvailable {
                    Button { play.interrupt() } label: {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .foregroundStyle(NovelStyle.redInk).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain).disabled(notebook.isTurning)
                    .accessibilityLabel("Interrupt")
                }
                if !right {
                    Button("‹  Previous pages") { notebook.turnBack() }
                        .font(NovelStyle.caption)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .disabled(!notebook.canTurnBack || !play.canReviewConversations)
                }
                Spacer(minLength: 0)
                if right, notebook.isReviewing {
                    Button("Next pages  ›") { notebook.turnForward() }
                        .font(NovelStyle.caption)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .disabled(!notebook.canTurnForward)
                } else if right, interactive {
                    Button { play.advanceWrittenDialogue() } label: {
                        Text(notebook.tapLabel + "  ›")
                            .font(NovelStyle.caption).foregroundStyle(NovelStyle.fadedInk)
                            .lineLimit(1).minimumScaleFactor(0.8).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain).disabled(notebook.isTurning)
                }
            }
            .frame(width: metrics.textSize.width, height: 44)
            .offset(x: metrics.margin, y: metrics.pageSize.height - metrics.bottom - 44)
        }
        .frame(width: metrics.pageSize.width, height: metrics.pageSize.height)
        .clipped()
    }
}

/// Retained ink on an otherwise unused gameplay page. It does not run another
/// clock or repaginate the book when a puzzle or question menu is shown.
struct NotebookDialogueView: View {
    @ObservedObject var play: OriginalPlaySession
    @ObservedObject var notebook: DialogueNotebook
    let screen: UInt8
    var body: some View {
        GeometryReader { proxy in
            if let layout = notebook.layout, layout.size.width > 0, layout.size.height > 0 {
                let page = notebook.reader.page(at: notebook.reader.leftIndex + (screen == 1 ? 0 : 1))
                let scale = min(proxy.size.width / layout.size.width, proxy.size.height / layout.size.height)
                Canvas { context, _ in
                    context.withCGContext { layout.draw(page: page, revealedEnd: notebook.reader.revealedEnd, in: $0) }
                }
                .frame(width: layout.size.width, height: layout.size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(layout.accessibleText(page: page))
            }
        }
    }
}
