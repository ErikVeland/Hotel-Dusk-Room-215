import SwiftUI

public struct RightPageView: View {
    @ObservedObject public var session: GameSession
    public init(session: GameSession) { self.session = session }
    public var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                BookSettingsMenu(session: session)
            }
            if let play = session.play {
                switch play.runner.phase {
                case .dialogue, .itemNotice, .process, .waiting:
                    OriginalPlayPage(play: play, screen: 0)
                case .questions(let topics):
                    Spacer()
                    OriginalQuestionMenuView(play: play, topics: topics)
                    Spacer()
                case .choice(let choices):
                    Spacer()
                    OriginalChoiceView(play: play, choices: choices)
                    Spacer()
                case .exploration, .halted:
                    Spacer()
                    OriginalPlayStatusView(session: session, play: play)
                    Spacer()
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
                Spacer()
                Text("Native rewrite in progress")
                    .font(NovelStyle.title)
                Text("Only the recovered Chapter 1 opening can be played. The opening cinematic is not ported, so play starts at Kyle's arrival.")
                    .font(NovelStyle.body)
                    .multilineTextAlignment(.center)
                if session.canStartOriginalGame {
                    Button("Begin Chapter 1") { session.startOriginalGame() }
                        .buttonStyle(BookTextButtonStyle())
                }
                if session.sourceError != nil {
                    Text("The original game data could not be loaded.")
                        .font(NovelStyle.caption)
                }
                Spacer()
            }
        }
        .padding(24)
        .foregroundStyle(NovelStyle.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
