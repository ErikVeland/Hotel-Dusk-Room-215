import SwiftUI

/**
 * Shows chapter titles without the original manual save prompts.
 */
struct OriginalChapterTransitionView: View {
    @ObservedObject var play: OriginalPlaySession
    let screen: UInt8

    var body: some View {
        if let transition = play.chapterTransition {
            if transition.stage == .title {
                if let chapter {
                    titlePage(chapter)
                } else {
                    Button("Continue") { play.continueChapterTitle() }
                        .accessibilityLabel("Chapter title unavailable. Continue")
                }
            } else if screen == 0 {
                Text("Your progress saves automatically.")
                    .font(NovelStyle.caption)
                    .task { play.enableInstantSaves() }
            } else { Color.clear }
        }
    }

    private var chapter: OriginalChapter? { try? OriginalChapter(play.runner.game.chapter) }

    private func titlePage(_ chapter: OriginalChapter) -> some View {
        GeometryReader { proxy in
            let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
            ZStack(alignment: .topLeading) {
                if let images = play.chapterTitleImages {
                    Image(decorative: screen == 1 ? images.left : images.right, scale: 1)
                        .resizable().interpolation(.none).frame(width: 192, height: 256)
                    if screen == 1 {
                        Text(chapter.title).font(.system(size: 24, design: .serif)).position(x: 96, y: 76)
                        Image(decorative: images.item, scale: 1).resizable().interpolation(.high)
                            .frame(width: CGFloat(images.item.artworkWidth), height: CGFloat(images.item.artworkHeight))
                            .position(x: CGFloat(images.item.artworkWidth) / 2, y: 128 + CGFloat(images.item.artworkHeight) / 2)
                    } else {
                        Text(chapter.dateLabel).font(.system(size: 12, design: .serif))
                            .position(x: 96, y: 44)
                        Image(decorative: images.clock, scale: 1).resizable().interpolation(.high)
                            .frame(width: CGFloat(images.clock.artworkWidth), height: CGFloat(images.clock.artworkHeight))
                            .position(x: 96, y: 112)
                        Text(chapter.timeRange).font(.system(size: 20, design: .serif))
                            .position(x: 96, y: 204)
                    }
                }
            }
            .foregroundStyle(.black)
            .frame(width: 192, height: 256)
            .contentShape(Rectangle())
            .onTapGesture { play.continueChapterTitle() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(screen == 1 ? chapter.title : "\(chapter.dateLabel). \(chapter.timeRange)")
            .accessibilityHint("Continue")
            .accessibilityAddTraits(.isButton)
            .scaleEffect(scale)
            .frame(width: 192 * scale, height: 256 * scale)
            .notebookPhotograph()
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}
