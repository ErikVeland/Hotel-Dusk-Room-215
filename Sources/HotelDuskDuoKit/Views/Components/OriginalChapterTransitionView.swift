import SwiftUI

/**
 * Forwards save and chapter-title actions to the session.
 */
struct OriginalChapterTransitionView: View {
    @ObservedObject var play: OriginalPlaySession
    let screen: UInt8

    var body: some View {
        if let transition = play.chapterTransition {
            if transition.stage == .title {
                titlePage
            } else if screen == 0 {
                VStack(spacing: 16) {
                    switch transition.stage {
                    case .prompt:
                        Text("Save your game?").font(NovelStyle.title)
                        Button("Yes") { play.answerChapterSave(true) }
                        Button("No") { play.answerChapterSave(false) }
                    case .slots:
                        Text("Save").font(NovelStyle.title)
                        ForEach(0..<3, id: \.self) { slot in
                            Button {
                                play.selectChapterSaveSlot(slot)
                            } label: {
                                HStack {
                                    Text("\(slot + 1)")
                                    Text(transition.slots[slot] == nil ? "There is no data." : "Chapter 2")
                                    Spacer()
                                    if transition.selectedSlot == slot { Image(systemName: "checkmark") }
                                }
                            }
                        }
                        Button("Confirm") { play.confirmChapterSaveSlot() }
                            .disabled(transition.selectedSlot == nil)
                        Button(transition.selectedSlot == nil ? "Back" : "Cancel") { play.cancelChapterSave() }
                    case .overwrite:
                        Text("Replace this saved game?")
                        Button("Yes") { play.confirmChapterOverwrite(true) }
                        Button("No") { play.confirmChapterOverwrite(false) }
                    case .title: EmptyView()
                    }
                    if let error = transition.error { Text(error).font(NovelStyle.caption) }
                }
                .buttonStyle(BookTextButtonStyle())
            } else { Color.clear }
        }
    }

    private var titlePage: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 192, proxy.size.height / 256)
            ZStack(alignment: .topLeading) {
                if let images = play.chapterTitleImages {
                    Image(decorative: screen == 1 ? images.left : images.right, scale: 1)
                        .resizable().interpolation(.none).frame(width: 192, height: 256)
                    if screen == 1 {
                        Text("Chapter 2").font(.system(size: 24, design: .serif)).position(x: 96, y: 76)
                        Image(decorative: images.item, scale: 1).interpolation(.none)
                            .position(x: CGFloat(images.item.width) / 2, y: 128 + CGFloat(images.item.height) / 2)
                    } else {
                        Text("December 28th 1979").font(.system(size: 12, design: .serif))
                            .position(x: 96, y: 44)
                        Image(decorative: images.clock, scale: 1).interpolation(.none)
                            .position(x: 96, y: 112)
                        Text("5:30–6:00 P.M.").font(.system(size: 20, design: .serif))
                            .position(x: 96, y: 204)
                    }
                }
            }
            .foregroundStyle(.black)
            .frame(width: 192, height: 256)
            .contentShape(Rectangle())
            .onTapGesture { play.continueChapterTitle() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(screen == 1 ? "Chapter 2" : "December 28th 1979. 5:30 to 6:00 PM")
            .accessibilityHint("Continue")
            .accessibilityAddTraits(.isButton)
            .scaleEffect(scale)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}
