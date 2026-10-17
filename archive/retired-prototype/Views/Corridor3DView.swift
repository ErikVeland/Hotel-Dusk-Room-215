import SwiftUI
import SceneKit

/// 3D Hotel Viewport rendering the interactive SceneKit corridor in SwiftUI
public struct Corridor3DView: View {
    @ObservedObject public var session: GameSession
    @State private var dragOffset: CGSize = .zero
    @Environment(\.scenePhase) private var scenePhase

    private var sceneManager: HotelScene3DManager { session.sceneManager }
    private var isRendering: Bool {
        !session.isBookClosed && !session.isJigsawPuzzleOpen && scenePhase == .active
    }

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        ZStack {
            // Interactive 3D SceneKit View
            SceneView(
                scene: sceneManager.scene,
                pointOfView: sceneManager.cameraNode,
                options: isRendering ? [.rendersContinuously] : []
            )
            .saturation(session.isNoirFilterEnabled ? 0.25 : 1)
            .contrast(session.isNoirFilterEnabled ? 1.15 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        guard isRendering else { return }
                        let delta = CGSize(width: val.translation.width - dragOffset.width,
                                           height: val.translation.height - dragOffset.height)
                        dragOffset = val.translation
                        let yaw = CGFloat(-delta.width * 0.003)
                        let forward = CGFloat(delta.height * 0.008)
                        sceneManager.panCamera(deltaYaw: yaw, deltaZ: forward)
                    }
                    .onEnded { _ in dragOffset = .zero }
            )
            .onChange(of: isRendering, initial: true) { _, active in
                sceneManager.scene.isPaused = !active
                if !active { dragOffset = .zero }
            }

            VStack {
                HStack(alignment: .top) {
                    Text(session.currentRoom.name)
                        .font(NovelStyle.heading)
                        .foregroundStyle(NovelStyle.lightPaper)
                        .padding(12)
                        .background(.black.opacity(0.5))
                    Spacer(minLength: 8)
                    Button {
                        sceneManager.resetToRoom215()
                        session.navigateTo(roomId: "room_215")
                    } label: {
                        Text("Return to room")
                            .font(NovelStyle.caption)
                            .underline()
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .foregroundStyle(NovelStyle.lightPaper)
                            .background(.black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                Spacer()
                Text("Drag to look around and walk.")
                    .font(NovelStyle.italic)
                    .foregroundStyle(NovelStyle.lightPaper.opacity(0.85))
                    .padding(12)
                    .background(.black.opacity(0.45))
                    .allowsHitTesting(false)
            }
        }
        .background(Color.black)
    }
}
