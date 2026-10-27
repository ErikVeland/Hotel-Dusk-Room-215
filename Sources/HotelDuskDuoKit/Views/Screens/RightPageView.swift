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
            if let play = session.play {
                if session.isPauseMenuOpen { OriginalPauseView(session: session) }
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
