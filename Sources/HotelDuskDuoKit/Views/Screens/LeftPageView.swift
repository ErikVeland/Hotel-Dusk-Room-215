import SwiftUI

/// Kyle's page. In paired dialogue, original screen 1 holds Kyle's text; that
/// screen is the left page in the right-handed book.
public struct LeftPageView: View {
    @ObservedObject public var session: GameSession
    public init(session: GameSession) { self.session = session }
    public var body: some View {
        Group {
            if let play = session.play {
                OriginalPlayPage(play: play, screen: 1)
                    .padding(24)
            } else if let frame = session.animationPreview {
                OriginalAnimationFrameView(frame: frame)
            } else {
                VStack(spacing: 20) {
                    Text("HOTEL DUSK")
                        .font(NovelStyle.heading).tracking(3)
                    Text("Room 215")
                        .font(NovelStyle.title)
                }
            }
        }
        .foregroundStyle(NovelStyle.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One original screen of the running game, drawn on a book page.
struct OriginalPlayPage: View {
    @ObservedObject var play: OriginalPlaySession
    /// Original screen index: 1 is the left page, 0 the right (touch) page.
    let screen: UInt8

    var body: some View {
        if play.chapterTransition != nil {
            OriginalChapterTransitionView(play: play, screen: screen)
        } else if play.notebook != nil {
            if screen == 0 { OriginalNotebookView(play: play) }
            else { Color.clear }
        } else { content }
    }

    @ViewBuilder private var content: some View {
        switch play.runner.phase {
        case .dialogue(let packet):
            if screen == 0, play.suitcaseContents != nil {
                ZStack {
                    OriginalSuitcaseContentsView(play: play, interactive: false)
                    if let page = packet.pages.first(where: { $0.page == screen }), !OriginalDialogueLines(page: page).isEmpty {
                        textPage(page).background(NovelStyle.paper.opacity(0.85))
                    }
                }
            } else if screen == 0, play.closeup != nil {
                ZStack {
                    OriginalSearchCloseupView(play: play, interactive: false)
                    if let page = packet.pages.first(where: { $0.page == screen }), !OriginalDialogueLines(page: page).isEmpty {
                        textPage(page).background(NovelStyle.paper.opacity(0.85))
                    }
                }
            } else if screen == 0, play.door != nil {
                ZStack {
                    OriginalDoorView(play: play, interactive: false)
                    if let page = packet.pages.first(where: { $0.page == screen }), !OriginalDialogueLines(page: page).isEmpty {
                        textPage(page).background(NovelStyle.paper.opacity(0.85))
                    }
                }
            } else { textPage(packet.pages.first(where: { $0.page == screen })) }
        case .itemNotice(_, let page):
            if screen == 0, play.acquiredItemImage != nil { OriginalTouchPictureView(play: play) }
            else { textPage(page.page == screen ? page : nil) }
        case .picture:
            if screen == 0 { OriginalTouchPictureView(play: play) }
            else { Color.clear }
        case .exploration where play.closeup != nil:
            if screen == 0 { OriginalSearchCloseupView(play: play) }
            else { Color.clear }
        case .exploration where play.door != nil:
            if screen == 0 { OriginalDoorView(play: play) }
            else { Color.clear }
        case .exploration where play.lobby != nil:
            if screen == 0 || play.lobby?.mode == .walking {
                OriginalMapView(play: play, screen: screen)
            } else {
                Color.clear
            }
        case .process:
            if play.clock != nil {
                if screen == 0 { OriginalClockView(play: play) }
                else { Color.clear }
            } else if play.cabinetDial != nil {
                if screen == 0 { OriginalCabinetDialView(play: play) }
                else { Color.clear }
            } else if play.crowbar != nil {
                if screen == 0 { OriginalCrowbarView(play: play) }
                else { Color.clear }
            } else if play.memoDrawing != nil {
                if screen == 0 { OriginalMemoDrawingView(play: play) }
                else { Color.clear }
            } else if play.memoPull != nil {
                if screen == 0 { OriginalMemoPullView(play: play) }
                else { Color.clear }
            } else if play.paperclip != nil {
                if screen == 0 { OriginalPaperclipView(play: play) }
                else { Color.clear }
            } else if play.thinWire != nil {
                if screen == 0 { OriginalThinWireView(play: play) }
                else { Color.clear }
            } else if play.hanger != nil {
                if screen == 0 { OriginalHangerView(play: play) }
                else { Color.clear }
            } else if play.suitcaseContents != nil {
                if screen == 0 { OriginalSuitcaseContentsView(play: play) }
                else { Color.clear }
            } else if play.suitcaseKey != nil {
                if screen == 0 { OriginalSuitcaseKeyView(play: play) }
                else { Color.clear }
            } else if play.jigsaw != nil {
                OriginalJigsawPageView(play: play, upper: screen == 1)
            } else if play.sign != nil {
                OriginalSignPageView(play: play, upper: screen == 1)
            } else if play.bell != nil {
                OriginalBellPageView(play: play, upper: screen == 1)
            } else {
                OriginalEntrancePanelView(play: play, upper: screen == 1)
            }
        default:
            EmptyView()
        }
    }

    private func textPage(_ shown: OriginalDialoguePacket.Page?) -> some View {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // A page without visible text still carries portrait and cue
                // controls, and the original still waits for a tap there.
                if let page = shown {
                    OriginalDialoguePageView(page: page)
                    HStack {
                        Spacer()
                        Text("▾").font(NovelStyle.caption).foregroundStyle(NovelStyle.fadedInk)
                    }
                    .padding(.top, 8)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { play.advanceDialogue() }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Continue")
            .overlay(alignment: .bottomLeading) {
                if screen == 0, play.runner.interruptAvailable {
                    // The original pulses an icon on the touch screen
                    // (0x02041C34) for as long as an interrupt is armed.
                    Button { play.interrupt() } label: {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NovelStyle.redInk)
                            .symbolEffect(.pulse)
                            .frame(minWidth: 56, minHeight: 56)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Interrupt")
                }
            }
    }
}
