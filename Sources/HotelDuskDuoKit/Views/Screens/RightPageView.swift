import SwiftUI

public struct RightPageView: View {
    @ObservedObject public var session: GameSession
    public init(session: GameSession) { self.session = session }
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("FIELD NOTES")
                    .font(NovelStyle.imprint).tracking(2)
                    .foregroundStyle(NovelStyle.redInk)
                Spacer()
                BookSettingsMenu(session: session)
            }
            InkRule()
            if session.play != nil, session.saveError != nil, !session.isPauseMenuOpen {
                Button("Progress not saved · Details") { session.openPauseMenu() }
                    .font(NovelStyle.caption)
                    .foregroundStyle(NovelStyle.redInk)
            }
            if let notice = session.recoveryNotice, !session.isPauseMenuOpen {
                Button(notice) { session.dismissRecoveryNotice() }
                    .font(NovelStyle.caption)
                    .foregroundStyle(NovelStyle.redInk)
            }
            if let play = session.play {
                if play.isGameOverPresented { OriginalGameOverView(session: session) }
                else if session.isPauseMenuOpen { OriginalPauseView(session: session) }
                else if play.chapterTransition != nil { OriginalChapterTransitionView(play: play, screen: 0) }
                else if play.notebook != nil { OriginalNotebookView(play: play) }
                else {
                    switch play.runner.phase {
                    case .dialogue, .itemNotice, .picture, .process, .waiting:
                        OriginalPlayPage(play: play, hingeManager: session.hingeManager, screen: 0)
                    case .questions(let topics):
                        OriginalQuestionMenuView(play: play, topics: topics)
                    case .choice(let choices):
                        ScrollView { OriginalChoiceView(play: play, choices: choices) }
                    case .exploration where play.lobby != nil:
                        OriginalPlayPage(play: play, hingeManager: session.hingeManager, screen: 0)
                    case .exploration, .halted:
                        Spacer()
                        OriginalPlayStatusView(session: session, play: play)
                        Spacer()
                    }
                }
            } else if session.isMemoPadOpen {
                MemoPadView(session: session)
            } else if let frame = session.animationPreview {
                Spacer()
                Text("Original animation preview").font(NovelStyle.title)
                Text("Frame \(frame.frameIndex + 1)").font(NovelStyle.caption)
                Button("Next frame") { try? session.advanceAnimationPreview() }
                    .buttonStyle(BookTextButtonStyle())
                Button("Close preview") { session.closeAnimationPreview() }
                    .buttonStyle(BookTextButtonStyle())
                Spacer()
            } else {
                OriginalTitleMenuView(session: session)
            }
        }
        .padding(24)
        .foregroundStyle(NovelStyle.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OriginalGameOverView: View {
    @ObservedObject var session: GameSession
    @State private var selectedChoice: Choice?

    private enum Choice: Equatable {
        case retry
        case title
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 192, proxy.size.height / 256)
            ZStack {
                Color.black
                if let images = OriginalGameOverImages.bundled() {
                    ZStack {
                        Image(decorative: selectedLowerImage(images), scale: 1)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 192 * scale, height: 256 * scale)
                            .accessibilityHidden(true)
                        Button { activate(.retry) } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                        .frame(width: 100 * scale, height: 34 * scale)
                        .position(x: 142 * scale, y: 192 * scale)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Retry")
                        .accessibilityValue(selectedChoice == .retry ? "Selected" : "Not selected")
                        .accessibilityHint(selectedChoice == .retry
                            ? "Activate again to confirm."
                            : "Select Retry, then activate again to confirm.")
                        Button { activate(.title) } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                        .frame(width: 112 * scale, height: 34 * scale)
                        .position(x: 136 * scale, y: 231 * scale)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to Title")
                        .accessibilityValue(selectedChoice == .title ? "Selected" : "Not selected")
                        .accessibilityHint(selectedChoice == .title
                            ? "Activate again to confirm."
                            : "Select Back to Title, then activate again to confirm.")
                    }
                    .frame(width: 192 * scale, height: 256 * scale)
                } else {
                    VStack(spacing: 18) {
                        Text("GAME OVER")
                            .font(NovelStyle.title)
                            .foregroundStyle(NovelStyle.redInk)
                        Text("Choose how to continue.")
                            .font(NovelStyle.body)
                        Button(selectedChoice == .retry ? "Retry ✓" : "Retry") { activate(.retry) }
                            .buttonStyle(BookTextButtonStyle())
                        Button(selectedChoice == .title ? "Back to Title ✓" : "Back to Title") {
                            activate(.title)
                        }
                            .buttonStyle(BookTextButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func activate(_ choice: Choice) {
        guard selectedChoice == choice else {
            selectedChoice = choice
            return
        }
        switch choice {
        case .retry:
            session.retryOriginalGameOver()
        case .title:
            session.returnToTitleAfterGameOver()
        }
    }

    private func selectedLowerImage(_ images: OriginalGameOverImages) -> CGImage {
        switch selectedChoice {
        case .retry: images.retrySelectedLower
        case .title: images.titleSelectedLower
        case nil: images.lower
        }
    }
}
