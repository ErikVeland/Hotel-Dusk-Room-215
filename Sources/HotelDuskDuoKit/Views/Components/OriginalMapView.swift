import SwiftUI

/**
 * Native page controls forward original coordinates to the session-owned lobby state.
 */
struct OriginalMapView: View {
    @ObservedObject var play: OriginalPlaySession
    let screen: UInt8
    @State private var showsInventory = false

    var body: some View {
        if let lobby = play.lobby {
            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                    ZStack {
                        Color.black
                        if screen == 0, lobby.mode == .walking, let map = play.lobbyMap {
                            Image(decorative: map, scale: 1).interpolation(.none)
                                .frame(width: 192, height: 256, alignment: .topLeading)
                                .offset(x: CGFloat(lobby.mapBitmapOffset.x), y: CGFloat(lobby.mapBitmapOffset.y))
                            Circle().stroke(.red, lineWidth: 1).frame(width: 10, height: 10)
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.system(size: 10)).foregroundStyle(.red)
                                .rotationEffect(.radians(Double(.pi - lobby.facing)))
                                .offset(x: CGFloat(sin(lobby.facing) * 13), y: CGFloat(cos(lobby.facing) * 13))
                            ForEach(lobby.people(in: play.runner.game), id: \.id) { person in
                                Circle().fill(.blue).frame(width: 5, height: 5)
                                    .position(x: CGFloat(96 + (person.position.x - lobby.position.x) / 4096 * lobby.mapScale),
                                              y: CGFloat(128 + (person.position.z - lobby.position.z) / 4096 * lobby.mapScale))
                                    .allowsHitTesting(false)
                            }
                        } else if let image = play.lobbyImage {
                            Image(decorative: image, scale: 1).interpolation(.none)
                        }
                        if screen == 0, let point = lobby.selectedPoint {
                            Image(systemName: "hand.point.up.fill")
                                .foregroundStyle(.white).shadow(color: .black, radius: 1)
                                .position(x: CGFloat(point.x), y: CGFloat(point.y))
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: 192, height: 256)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard screen == 0, lobby.mode == .walking else { return }
                            play.holdLobbyTouch(x: Float(value.location.x), y: Float(value.location.y))
                        }
                        .onEnded { value in
                            guard screen == 0 else { return }
                            play.releaseLobbyTouch()
                            if lobby.mode == .counter {
                                play.selectLobbyObject(x: Float(value.location.x), y: Float(value.location.y))
                            }
                        })
                    .scaleEffect(scale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .accessibilityLabel(lobby.mode == .walking ? "Floor plan" : "Search view")
                }
                if screen == 0 {
                    if lobby.mode == .walking {
                        HStack {
                            Button("Door") { play.inspectNearbyDoor() }.disabled(play.nearbyDoor == nil)
                            Button("Inspect") { play.inspectLobbyCounter() }.disabled(!lobby.canInspectCounter(in: play.runner.game))
                            Button("Talk") { play.talkToNearbyPerson() }
                                .disabled(lobby.nearbyPerson(in: play.runner.game) == nil)
                        }.buttonStyle(BookTextButtonStyle())
                        Button("Notebook") { play.openNotebook() }.buttonStyle(BookTextButtonStyle())
                    } else {
                        if showsInventory {
                            ForEach((try? play.runner.game.inventory.items) ?? [], id: \.self) { item in
                                Button(play.itemNames[item] ?? String(item)) {
                                    play.useItemInSearchView(item)
                                    showsInventory = false
                                }
                            }
                            Button("Cancel") { showsInventory = false }
                        } else {
                            if let item = play.searchItem {
                                Text(play.itemNames[item] ?? String(item)).font(NovelStyle.caption)
                            }
                            Slider(value: Binding(get: { Double(play.lobby?.pan ?? 0) },
                                set: { play.panLobbyCounter(Float($0)) }), in: 0...1)
                                .accessibilityLabel("Look around")
                            HStack {
                                Button("Back") { play.leaveLobbyCounter() }
                                Button("Items") { showsInventory = true }
                                Button(play.searchItem == nil ? "Look" : "Use") { play.confirmLobbyObject() }
                                    .disabled(lobby.selectedNode == nil)
                                if play.searchItem != nil { Button("Cancel") { play.useItemInSearchView(nil) } }
                            }.buttonStyle(BookTextButtonStyle())
                        }
                    }
                }
            }
            .onDisappear { if screen == 0 { play.releaseLobbyTouch() } }
        }
    }
}
