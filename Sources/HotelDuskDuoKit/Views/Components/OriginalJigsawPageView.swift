import SwiftUI

/**
 * Chapter 1 process 26. The session owns placement, rotation, hints and completion.
 */
struct OriginalJigsawPageView: View {
    @ObservedObject var play: OriginalPlaySession
    let upper: Bool

    var body: some View {
        if let puzzle = play.jigsaw, !upper {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                ZStack(alignment: .topLeading) {
                    artwork("JigsawTray")
                        .frame(width: 192 * scale, height: 256 * scale)
                    if !upper {
                        pieces(puzzle, scale: scale)
                        if puzzle.selected != nil, !puzzle.holding {
                            rotationButton(increasing: false, scale: scale)
                                .position(x: 16 * scale, y: 16 * scale)
                            rotationButton(increasing: true, scale: scale)
                                .position(x: 176 * scale, y: 16 * scale)
                        }
                        Button("Back") { play.quitJigsaw() }
                            .font(.system(size: 12 * scale))
                            .buttonStyle(.bordered)
                            .disabled(puzzle.phase != 1)
                            .position(x: 172 * scale, y: 240 * scale)
                    }
                }
                .frame(width: 192 * scale, height: 256 * scale)
                .clipped()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private func pieces(_ puzzle: OriginalJigsawProcess, scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(puzzle.pieces.indices, id: \.self) { index in
                let piece = puzzle.pieces[index]
                let centre = OriginalJigsawProjection.centre(piece)
                let extent = CGFloat(OriginalJigsawProjection.pixelsPerUnit) * scale
                // The right-edge source textures are 51 pixels wide after rotation.
                artwork(OriginalJigsawProjection.imageName(index))
                    .frame(width: (index % 4 == 0 ? 51.0 / 64 : 1) * extent, height: extent)
                    .frame(width: extent, height: extent, alignment: .leading)
                    .rotationEffect(.radians(Double(piece.angle - 1.5) * .pi))
                    .position(x: CGFloat(centre.x) * scale, y: CGFloat(centre.y) * scale)
                    .zIndex(Double(piece.depth))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 192 * scale, height: 256 * scale)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                play.dragJigsaw(pageX: Float(value.location.x / scale), pageY: Float(value.location.y / scale))
            }
            .onEnded { _ in play.releaseJigsaw() })
    }

    private func rotationButton(increasing: Bool, scale: CGFloat) -> some View {
        Button { play.rotateJigsaw(increasing: increasing) } label: {
            artwork(increasing ? "JigsawRotateRight" : "JigsawRotateLeft")
                .frame(width: 32 * scale, height: 32 * scale)
        }
        .buttonStyle(.plain)
        .disabled(play.jigsaw?.acceptsInput != true)
        .accessibilityLabel(increasing ? "Turn piece right" : "Turn piece left")
    }

    private func artwork(_ name: String) -> some View {
        Group {
            if let image = JigsawArt.image(named: name) {
                Image(decorative: image, scale: 1).resizable().interpolation(.none)
            }
        }
    }
}
