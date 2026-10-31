import SwiftUI

/**
 * Forwards page taps to the overlay 29 edge puzzle.
 */
struct OriginalCoinEdgeView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack(spacing: 8) {
            if let puzzle = play.coinEdgePuzzle {
                Text("Remove \(puzzle.drawValue) lines to leave \(puzzle.targetCount) \(puzzle.ruleMode == 0 ? "squares" : "triangles")")
                    .font(.caption)
                Text("\(min(puzzle.selectedCount, puzzle.drawValue)) / \(puzzle.drawValue)")
                    .font(.caption2.monospacedDigit())
            }
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 16) / 256))
                ZStack {
                    Color.black
                    if let image = play.coinEdgePuzzleImage {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 192, height: 256)
                    }
                }
                .frame(width: 192, height: 256)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        play.holdCoinPuzzleTouch(x: Float(value.location.x), y: Float(value.location.y))
                    }
                    .onEnded { _ in play.releaseCoinPuzzleTouch() })
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Select lines to make the requested shapes")
            }
        }
        .onDisappear { play.releaseCoinPuzzleTouch() }
    }
}
