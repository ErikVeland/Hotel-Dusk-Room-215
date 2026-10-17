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
        switch play.runner.phase {
        case .dialogue(let packet):
            textPage(packet.pages.first(where: { $0.page == screen }))
        case .itemNotice(_, let page):
            textPage(page.page == screen ? page : nil)
        case .process:
            if play.sign != nil {
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
