import SwiftUI

/**
 * Shows the Chapter 10 brick wall and forwards continuous touches to the process.
 */
struct OriginalBrickWallView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack {
            GeometryReader { proxy in
                let scale = max(0, min((proxy.size.width - 16) / 192, (proxy.size.height - 36) / 256))
                ZStack {
                    Color.black
                    Canvas { context, _ in
                        guard let process = play.brickWall else { return }
                        for object in process.objects.sorted(by: { $0.position.z < $1.position.z }) {
                            let vertices = OriginalBrickWallHitMask.faceVertices.map {
                                object.position + $0 * object.scale
                            }
                            for (isSideFace, indices) in [(false, [0, 1, 5, 2]), (true, [6, 7, 11, 8])] {
                                let projected = indices.compactMap {
                                    OriginalBrickWallProjection.screenPoint(vertices[$0])
                                }
                                guard projected.count == indices.count else { continue }
                                var path = Path()
                                path.move(to: CGPoint(x: CGFloat(projected[0].x), y: CGFloat(projected[0].y)))
                                for point in projected.dropFirst() {
                                    path.addLine(to: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
                                }
                                path.closeSubpath()
                                context.fill(path, with: .color(
                                    isSideFace ? Color(red: 0.32, green: 0.13, blue: 0.08)
                                               : Color(red: 0.55, green: 0.25, blue: 0.13)))
                                context.stroke(path, with: .color(.black.opacity(0.8)), lineWidth: 1)
                            }
                        }
                    }
                    .frame(width: 192, height: 256)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            play.holdBrickWallTouch(x: Float(value.location.x), y: Float(value.location.y))
                        }
                        .onEnded { _ in play.releaseBrickWallTouch() })
                }
                .frame(width: 192, height: 256)
                .scaleEffect(scale)
                .frame(width: 192 * scale, height: 256 * scale)
                .notebookPhotograph()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .accessibilityLabel("Move bricks with the Hammer to uncover the doorway")
            }
            Button("Back") { play.leaveBrickWall() }
                .buttonStyle(BookTextButtonStyle())
        }
        .onDisappear { play.releaseBrickWallTouch() }
    }
}
