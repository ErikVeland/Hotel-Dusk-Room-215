import SwiftUI

/// Main Dual-Screen Book Container for the iPhone Duo
public struct DuoBookContainerView: View {
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
        #if canImport(UIKit)
        .background(HingeObserverView(manager: session.hingeManager))
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        #endif
    }

    private func pageLayout(in size: CGSize, safeArea: EdgeInsets) -> some View {
        let layout = DuoBookLayout(size: size, safeArea: safeArea,
                                   handedness: session.hingeManager.handedness)
        return ZStack {
            // Keep both pages mounted. A cover or puzzle must not destroy local
            // scroll position, selected floor, focus, or unfinished interactions.
            HStack(spacing: 0) {
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
                    .frame(width: layout.frame(at: index).width, height: size.height)
                    .clipped()
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .opacity(session.isJigsawPuzzleOpen || session.isBookClosed ? 0 : 1)
            .disabled(session.isJigsawPuzzleOpen || session.isBookClosed)
            .allowsHitTesting(!session.isJigsawPuzzleOpen && !session.isBookClosed)
            .accessibilityHidden(session.isJigsawPuzzleOpen || session.isBookClosed)

            if session.isJigsawPuzzleOpen {
                JigsawPuzzleView(session: session, puzzleManager: session.jigsawPuzzleManager,
                                safeArea: safeArea)
                    .opacity(session.isBookClosed ? 0 : 1)
                    .disabled(session.isBookClosed)
                    .allowsHitTesting(!session.isBookClosed)
                    .accessibilityHidden(session.isBookClosed)
            }

            BookSpineView(angleDegrees: session.hingeManager.hingeAngleDegrees)

            if session.isBookClosed {
                CoverScreenView(session: session, safeArea: safeArea)
            }
        }
    }
}

/// Settings belong to the touch page so no controls sit over the physical crease.
struct BookSettingsMenu: View {
    @ObservedObject var session: GameSession
    var tint: Color = NovelStyle.ink

    var body: some View {
        Menu {
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
