import SwiftUI

/// Kyle's gameplay page. Dialogue is presented by the shared book spread.
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
                NotebookTitleLeaf()
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
            else { retainedNotes }
        } else { content }
    }

    @ViewBuilder private var content: some View {
        switch play.runner.phase {
        case .dialogue(let packet):
            if screen == 0, play.suitcaseContents != nil {
                ZStack {
                    OriginalSuitcaseContentsView(play: play, interactive: false)
                    if let page = packet.pages.first(where: { $0.page == screen }), !OriginalDialogueLines(page: page).isEmpty {
                        textPage().background(NovelStyle.paper.opacity(0.85))
                    }
                }
            } else if screen == 0, play.closeup != nil {
                ZStack {
                    OriginalSearchCloseupView(play: play, interactive: false)
                    if let page = packet.pages.first(where: { $0.page == screen }), !OriginalDialogueLines(page: page).isEmpty {
                        textPage().background(NovelStyle.paper.opacity(0.85))
                    }
                }
            } else if screen == 0, play.door != nil {
                ZStack {
                    OriginalDoorView(play: play, interactive: false)
                    if let page = packet.pages.first(where: { $0.page == screen }), !OriginalDialogueLines(page: page).isEmpty {
                        textPage().background(NovelStyle.paper.opacity(0.85))
                    }
                }
            } else { textPage() }
        case .itemNotice:
            if screen == 0, play.acquiredItemImage != nil { OriginalTouchPictureView(play: play) }
            else { textPage() }
        case .picture:
            if screen == 0 { OriginalTouchPictureView(play: play) }
            else { retainedNotes }
        case .exploration where play.closeup != nil:
            if screen == 0 { OriginalSearchCloseupView(play: play) }
            else { retainedNotes }
        case .exploration where play.door != nil:
            if screen == 0 { OriginalDoorView(play: play) }
            else { retainedNotes }
        case .exploration where play.lobby != nil:
            if screen == 0 || play.lobby?.mode == .walking {
                OriginalMapView(play: play, screen: screen)
            } else {
                retainedNotes
            }
        case .process:
            if play.clock != nil {
                if screen == 0 { OriginalClockView(play: play) }
                else { retainedNotes }
            } else if play.cabinetDial != nil {
                if screen == 0 { OriginalCabinetDialView(play: play) }
                else { retainedNotes }
            } else if play.crowbar != nil {
                if screen == 0 { OriginalCrowbarView(play: play) }
                else { retainedNotes }
            } else if play.memoDrawing != nil {
                if screen == 0 { OriginalMemoDrawingView(play: play) }
                else { retainedNotes }
            } else if play.memoPull != nil {
                if screen == 0 { OriginalMemoPullView(play: play) }
                else { retainedNotes }
            } else if play.paperclip != nil {
                if screen == 0 { OriginalPaperclipView(play: play) }
                else { retainedNotes }
            } else if play.fountainPen != nil {
                if screen == 0 { OriginalFountainPenView(play: play) }
                else { retainedNotes }
            } else if play.differences != nil {
                if screen == 0 { OriginalDifferencesView(play: play) }
                else { retainedNotes }
            } else if play.toiletTank != nil {
                if screen == 0 { OriginalToiletTankView(play: play) }
                else { retainedNotes }
            } else if play.linenWagon != nil {
                if screen == 0 { OriginalLinenWagonView(play: play) }
                else { retainedNotes }
            } else if play.matchsticks != nil {
                if screen == 0 { OriginalMatchstickView(play: play) }
                else { retainedNotes }
            } else if play.jukebox != nil {
                if screen == 0 { OriginalJukeboxView(play: play) }
                else { retainedNotes }
            } else if play.coinPuzzle != nil {
                if screen == 0 { OriginalCoinView(play: play) }
                else { retainedNotes }
            } else if play.dollRepair != nil {
                if screen == 0 { OriginalDollRepairView(play: play) }
                else { retainedNotes }
            } else if play.bookmarkBox != nil {
                if screen == 0 { OriginalBookmarkBoxView(play: play) }
                else { retainedNotes }
            } else if play.switchboard != nil {
                if screen == 0 { OriginalSwitchboardView(play: play) }
                else { retainedNotes }
            } else if play.thinWire != nil {
                if screen == 0 { OriginalThinWireView(play: play) }
                else { retainedNotes }
            } else if play.hanger != nil {
                if screen == 0 { OriginalHangerView(play: play) }
                else { retainedNotes }
            } else if play.suitcaseContents != nil {
                if screen == 0 { OriginalSuitcaseContentsView(play: play) }
                else { retainedNotes }
            } else if play.suitcaseKey != nil {
                if screen == 0 { OriginalSuitcaseKeyView(play: play) }
                else { retainedNotes }
            } else if play.jigsaw != nil {
                if screen == 0 || play.jigsaw?.variant == .reverse { OriginalJigsawPageView(play: play, upper: screen == 1) }
                else { retainedNotes }
            } else if play.sign != nil {
                if screen == 0 { OriginalSignPageView(play: play, upper: false) }
                else { retainedNotes }
            } else if play.bell != nil {
                if screen == 0 { OriginalBellPageView(play: play, upper: false) }
                else { retainedNotes }
            } else {
                OriginalEntrancePanelView(play: play, upper: screen == 1)
            }
        default:
            retainedNotes
        }
    }

    @ViewBuilder private var retainedNotes: some View {
        if !play.dialogueNotebook.ink.isEmpty {
            NotebookDialogueView(play: play, notebook: play.dialogueNotebook, screen: screen)
        } else {
            Color.clear
        }
    }

    private func textPage() -> some View {
        NotebookDialogueView(play: play, notebook: play.dialogueNotebook, screen: screen)
    }
}
