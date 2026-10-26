import SwiftUI
import ImageIO

/// The original jigsaw artwork uses both facing pages. Only the assembled puzzle
/// can turn over, and the reverse is visible on the first open-hinge report.
public struct JigsawPuzzleView: View {
    @ObservedObject public var session: GameSession
    @ObservedObject public var puzzleManager: JigsawPuzzleManager
    private let safeArea: EdgeInsets

    public init(session: GameSession, puzzleManager: JigsawPuzzleManager, safeArea: EdgeInsets = EdgeInsets()) {
        self.session = session
        self.puzzleManager = puzzleManager
        self.safeArea = safeArea
    }

    public var body: some View {
        GeometryReader { display in
            let book = DuoBookLayout(size: display.size, safeArea: safeArea,
                                     handedness: session.hingeManager.handedness)
            HStack(spacing: 0) {
                ForEach(Array(book.pages.enumerated()), id: \.element) { index, role in
                    PaperbackPageSurface(hingeManager: session.hingeManager,
                                         side: index == 0 ? .left : .right,
                                         isVisible: !session.isBookClosed) {
                        page(role: role)
                            .padding(pageInsets(at: index))
                    }
                        .frame(width: book.frame(at: index).width, height: display.size.height)
                        .clipped()
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .foregroundStyle(NovelStyle.ink)
    }

    private func page(role: DuoBookLayout.Page) -> some View {
        VStack(spacing: 8) {
            HStack {
                if role == .exploration {
                    BookSettingsMenu(session: session)
                    Spacer()
                } else if puzzleManager.phase == .assembling {
                    rotationButton(clockwise: false)
                    Spacer(minLength: 0)
                    rotationButton(clockwise: true)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 44)

            GeometryReader { space in
                let scale = max(0, min((space.size.width - 32) / puzzleManager.manifest.boardWidth,
                                      (space.size.height - 36) / puzzleManager.manifest.boardHeight))
                let stageSize = CGSize(width: puzzleManager.manifest.boardWidth * scale,
                                       height: puzzleManager.manifest.boardHeight * scale)
                Group {
                    if role == .touch && puzzleManager.phase == .assembling {
                        assembly(scale: scale)
                    } else {
                        artwork(named: stageImage(for: role))
                            .accessibilityLabel(stageLabel(for: role))
                    }
                }
                .frame(width: stageSize.width, height: stageSize.height)
                .notebookPhotograph()
                .position(x: space.size.width / 2, y: space.size.height / 2)
            }

            HStack {
                Spacer()
                if role == .touch {
                    Button("Back") { session.isJigsawPuzzleOpen = false }
                }
            }
            .buttonStyle(BookTextButtonStyle())
            .frame(height: 44)
            .padding(.horizontal, 8)
        }
    }

    private func assembly(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            artwork(named: puzzleManager.manifest.trayImage)
                .accessibilityHidden(true)
            ForEach(puzzleManager.manifest.pieces) { piece in
                if let placement = puzzleManager.placements[piece.id] {
                    JigsawPieceView(manager: puzzleManager, piece: piece, placement: placement,
                                    scale: scale, interactionEnabled: !session.isBookClosed)
                    .zIndex(placement.isPlaced ? 0 : (puzzleManager.selectedPieceID == piece.id ? 2 : 1))
                }
            }
        }
        .coordinateSpace(name: "jigsaw-stage")
        .clipped()
    }

    private func rotateSelected(clockwise: Bool) {
        if let id = puzzleManager.selectedPieceID {
            puzzleManager.rotatePiece(id, clockwise: clockwise)
        }
    }

    private func rotationButton(clockwise: Bool) -> some View {
        Button { rotateSelected(clockwise: clockwise) } label: {
            artwork(named: clockwise ? puzzleManager.manifest.rotateRightImage : puzzleManager.manifest.rotateLeftImage)
                .frame(width: 32, height: 32)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(puzzleManager.selectedPieceID == nil)
        .opacity(puzzleManager.selectedPieceID == nil ? 0.45 : 1)
        .accessibilityLabel(clockwise ? "Turn piece right" : "Turn piece left")
    }

    private func pageInsets(at index: Int) -> EdgeInsets {
        // Equal outer clearances keep both original stages reflected about the
        // hinge even if a camera cutout affects only one side of the display.
        let outer = max(12, safeArea.leading, safeArea.trailing)
        return EdgeInsets(top: max(12, safeArea.top),
                          leading: index == 0 ? outer : 16,
                          bottom: max(12, safeArea.bottom),
                          trailing: index == 0 ? 16 : outer)
    }

    private func stageImage(for role: DuoBookLayout.Page) -> String {
        let art = puzzleManager.manifest
        switch puzzleManager.phase {
        case .assembling:
            return art.tableImage
        case .assembled, .folded:
            return role == .exploration ? art.frontImage : art.foldTrayImage
        case .reverseRevealed:
            return role == .touch ? art.reverseImage : art.foldTrayImage
        }
    }

    private func stageLabel(for role: DuoBookLayout.Page) -> String {
        if puzzleManager.phase == .reverseRevealed && role == .touch {
            return "The back of Melissa's jigsaw. Good-bye, Melissa."
        }
        if (puzzleManager.phase == .assembled || puzzleManager.phase == .folded) && role == .exploration {
            return "The completed Pinkie Rabbit jigsaw."
        }
        return "Tabletop"
    }

    private func artwork(named name: String) -> some View {
        Group {
            if let image = JigsawArt.image(named: name) {
                Image(decorative: image, scale: 1)
                    .resizable().interpolation(.none)
            }
        }
    }
}

private struct JigsawPieceView: View {
    @ObservedObject var manager: JigsawPuzzleManager
    let piece: JigsawManifest.Piece
    let placement: JigsawPuzzleManager.Placement
    let scale: CGFloat
    let interactionEnabled: Bool
    @State private var dragOrigin: CGPoint?

    var body: some View {
        Group {
            if let image = JigsawArt.image(named: piece.image) {
                Image(decorative: image, scale: 1)
                    .resizable().interpolation(.none)
            }
        }
        .frame(width: piece.width * scale, height: piece.height * scale)
        .rotationEffect(.degrees(Double(placement.quarterTurns) * 90))
        .shadow(color: manager.selectedPieceID == piece.id ? .black.opacity(0.3) : .clear,
                radius: 2, x: 0, y: 2)
        .contentShape(Rectangle())
        .position(x: placement.centre.x * scale, y: placement.centre.y * scale)
        .onTapGesture { manager.selectPiece(piece.id) }
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named("jigsaw-stage"))
                .onChanged { value in
                    guard interactionEnabled, !placement.isPlaced, scale > 0 else { return }
                    if dragOrigin == nil { dragOrigin = placement.centre }
                    guard let origin = dragOrigin else { return }
                    manager.movePiece(piece.id,
                                      to: CGPoint(x: origin.x + value.translation.width / scale,
                                                  y: origin.y + value.translation.height / scale))
                }
                .onEnded { _ in
                    if interactionEnabled { manager.releasePiece(piece.id) }
                    dragOrigin = nil
                }
        )
        .onChange(of: interactionEnabled) { _, enabled in
            if !enabled { dragOrigin = nil }
        }
        .allowsHitTesting(!placement.isPlaced && interactionEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jigsaw piece \(piece.id)")
        .accessibilityValue(placement.isPlaced ? "Placed" : "\(placement.quarterTurns * 90) degrees")
        .accessibilityAddTraits(manager.selectedPieceID == piece.id ? .isSelected : [])
        .accessibilityAction(named: "Select") { manager.selectPiece(piece.id) }
        .accessibilityAction(named: "Turn left") { manager.rotatePiece(piece.id, clockwise: false) }
        .accessibilityAction(named: "Turn right") { manager.rotatePiece(piece.id) }
    }
}

@MainActor
enum JigsawArt {
    private static var cache: [String: CGImage] = [:]

    static func image(named name: String) -> CGImage? {
        if let image = cache[name] { return image }
        let basename = (name as NSString).deletingPathExtension
        guard let url = Bundle.module.url(forResource: basename, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache[name] = image
        return image
    }
}
