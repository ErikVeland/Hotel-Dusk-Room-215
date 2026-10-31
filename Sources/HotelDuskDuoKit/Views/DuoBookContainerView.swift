import SwiftUI

/// Main Dual-Screen Book Container for the iPhone Duo
public struct DuoBookContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject public var session: GameSession

    public init(session: GameSession? = nil) {
        _session = StateObject(wrappedValue: session ?? GameSession())
    }

    public var body: some View {
        GeometryReader { proxy in
            // Measure safe areas before extending the book to the display edges.
            // Insetting the whole book would move its spine away from the hinge.
            GeometryReader { display in
                pageLayout(in: display.size, safeArea: proxy.safeAreaInsets)
                    .frame(width: display.size.width, height: display.size.height)
            }
            .ignoresSafeArea()
        }
        .background(PaperSurface())
        .onChange(of: scenePhase) { _, phase in session.setApplicationActive(phase == .active) }
        .onAppear { session.setApplicationActive(scenePhase == .active) }
        #if canImport(UIKit)
        #if os(iOS)
        .onAppear { BookOrientationPolicy.update(coverIsVisible: session.isBookClosed) }
        .onChange(of: session.hingeManager.foldState) { _, state in
            BookOrientationPolicy.update(coverIsVisible: state == .closed)
        }
        #endif
        .background(HingeObserverView(manager: session.hingeManager))
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        #endif
    }

    private func pageLayout(in size: CGSize, safeArea: EdgeInsets) -> some View {
        let layout = DuoBookLayout(size: size, safeArea: safeArea,
                                   handedness: session.hingeManager.handedness,
                                   stacked: session.hingeManager.hasHardwareHinge && size.height > size.width)
        return ZStack {
            // Keep both pages mounted. A cover or puzzle must not destroy local
            // scroll position, selected floor, focus, or unfinished interactions.
            AnyLayout(layout.stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))) {
                ForEach(Array(layout.pages.enumerated()), id: \.element) { index, page in
                    PaperbackPageSurface(hingeManager: session.hingeManager,
                                         side: index == 0 ? .left : .right,
                                         isVisible: !session.isJigsawPuzzleOpen && !session.isBookClosed) {
                        // The paper reaches the glass edge. Safe areas protect only
                        // the printed content, never the physical page surface.
                        Group {
                            switch page {
                            case .exploration: LeftPageView(session: session)
                            case .touch: RightPageView(session: session)
                            }
                        }
                        .padding(layout.insets(at: index))
                    }
                    .frame(width: layout.frame(at: index).width, height: layout.frame(at: index).height)
                    .clipped()
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .opacity(session.isJigsawPuzzleOpen || session.isBookClosed || isReadingDialogue ? 0 : 1)
            .disabled(session.isJigsawPuzzleOpen || session.isBookClosed || isReadingDialogue)
            .allowsHitTesting(!session.isJigsawPuzzleOpen && !session.isBookClosed && !isReadingDialogue)
            .accessibilityHidden(session.isJigsawPuzzleOpen || session.isBookClosed || isReadingDialogue)

            if isReadingDialogue, let play = session.play {
                let metrics = DialogueSpreadMetrics(size: size, safeArea: safeArea, stacked: layout.stacked)
                NotebookDialogueSpread(play: play, notebook: play.dialogueNotebook, safeArea: safeArea,
                                       stacked: layout.stacked, isVisible: !session.isBookClosed && !session.isJigsawPuzzleOpen)
                    .overlay(alignment: .topTrailing) {
                        HStack {
                            if session.isReviewingConversations {
                                Button("Return to game") { session.closeConversationHistory() }
                                    .font(NovelStyle.caption).buttonStyle(.plain)
                                    .frame(minHeight: 44)
                            }
                            BookSettingsMenu(session: session)
                        }
                        .padding(.top, metrics.top - 12)
                        .padding(.trailing, metrics.margin - 8)
                    }
                    .opacity(session.isBookClosed || session.isJigsawPuzzleOpen ? 0 : 1)
                    .allowsHitTesting(!session.isBookClosed && !session.isJigsawPuzzleOpen)
                    .accessibilityHidden(session.isBookClosed || session.isJigsawPuzzleOpen)
            }

            if session.isJigsawPuzzleOpen {
                JigsawPuzzleView(session: session, puzzleManager: session.jigsawPuzzleManager,
                                safeArea: safeArea)
                    .opacity(session.isBookClosed ? 0 : 1)
                    .disabled(session.isBookClosed)
                    .allowsHitTesting(!session.isBookClosed)
                    .accessibilityHidden(session.isBookClosed)
            }

            if !isReadingDialogue {
                BookSpineView(angleDegrees: session.hingeManager.hingeAngleDegrees, horizontal: layout.stacked)
            }

            if session.isBookClosed {
                CoverScreenView(session: session, safeArea: safeArea)
            }
        }
    }

    private var isReadingDialogue: Bool {
        if session.isReviewingConversations { return true }
        guard let play = session.play, !session.isPauseMenuOpen,
              play.chapterTransition == nil, play.notebook == nil else { return false }
        switch play.runner.phase {
        case .dialogue, .itemNotice: return true
        case .waiting: return !play.dialogueNotebook.ink.isEmpty
        default: return false
        }
    }
}

/// Settings belong to the touch page so no controls sit over the physical crease.
struct BookSettingsMenu: View {
    @ObservedObject var session: GameSession
    var tint: Color = NovelStyle.ink
    @AppStorage("modernNavigation") private var modernNavigation = true
    @AppStorage("pencilCharacterAnimations") private var pencilCharacterAnimations = true

    var body: some View {
        Menu {
            if session.isReviewingConversations {
                Button("Return to game") { session.closeConversationHistory() }
            } else if let play = session.play {
                Button("Previous conversations") { session.reviewConversations() }
                    .disabled(!play.canReviewConversations)
            }
            if session.play != nil {
                Button("Pause game") { session.openPauseMenu() }
                Toggle("Modern navigation", isOn: $modernNavigation)
            }
            MusicSourcePicker(audio: session.audioController)
            Toggle("Pencil character animations", isOn: $pencilCharacterAnimations)
            Button {
                session.hingeManager.toggleHandedness()
            } label: {
                Text("Swap pages (\(session.hingeManager.handedness.rawValue))")
            }
            #if DEBUG
            Menu("Development previews") {
                Button("Original Kyle animation") { try? session.openAnimationPreview("Hy_hanas_") }
                Button("Jigsaw assembly") { session.isJigsawPuzzleOpen = true }
                Button("Notebook") { session.isMemoPadOpen = true }
            }
            if !session.hingeManager.hasHardwareHinge {
                Menu("Simulated hinge") {
                    Button("Open flat") { session.hingeManager.setHingeAngle(180) }
                    Button("Partly open book") { session.hingeManager.setHingeAngle(110) }
                    Button("Fold and reopen") { session.hingeManager.performFoldGesture() }
                }
            }
            #endif
        } label: {
            Text("Book options")
                .font(NovelStyle.caption)
                .italic()
                .underline()
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .foregroundColor(tint)
        .accessibilityLabel("Book settings")
    }
}
