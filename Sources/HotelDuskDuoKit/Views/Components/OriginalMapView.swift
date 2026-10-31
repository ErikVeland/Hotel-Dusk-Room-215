import SwiftUI

/**
 * Native page controls forward original coordinates to the session-owned lobby state.
 */
struct OriginalMapView: View {
    @ObservedObject var play: OriginalPlaySession
    @Environment(\.displayScale) private var displayScale
    let screen: UInt8
    @AppStorage("modernNavigation") private var modernNavigation = true
    @AppStorage("hdGraphicsEnabled") private var hdGraphicsEnabled = true
    @State private var showsInventory = false
    @State private var lastLookTranslation: CGFloat = 0

    var body: some View {
        if let lobby = play.lobby {
            if showsInventory, screen == 0 {
                OriginalInventoryView(play: play,
                    onSelect: lobby.mode == .counter ? { item in
                        showsInventory = false
                        play.useItemInSearchView(item)
                    } : nil,
                    onClose: { showsInventory = false })
            } else if modernNavigation, screen == 1, lobby.mode == .walking {
                modernView(lobby)
            } else {
                VStack(spacing: 8) {
                    GeometryReader { proxy in
                        let input = OriginalPageInput(available: CGSize(width: max(0, proxy.size.width - 16),
                                                           height: max(0, proxy.size.height - 36)))
                        ZStack {
                            Color.black
                            if screen == 0, lobby.mode == .walking, let map = play.lobbyMap {
                                OriginalFloorPlanView(image: map, exploration: lobby)
                            } else if let image = play.lobbyImage {
                                Image(decorative: image, scale: 1).resizable()
                                    .interpolation(hdGraphicsEnabled ? .high : .none)
                                    .frame(width: 192, height: 256)
                            }
                            if screen == 1, lobby.mode == .walking, play.roomTransitionOpacity > 0 {
                                (play.roomTransitionIsBright ? Color.white : Color.black)
                                    .opacity(play.roomTransitionOpacity)
                            }
                        }
                        .frame(width: 192, height: 256)
                        .clipped()
                        .scaleEffect(input.scale)
                        .frame(width: input.size.width, height: input.size.height)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                guard lobby.mode == .walking else { return }
                                if screen == 1 {
                                    let delta = value.translation.width - lastLookTranslation
                                    lastLookTranslation = value.translation.width
                                    play.turnFirstPerson(by: -Float(delta) * 0.008)
                                } else if let point = input.point(value.location) {
                                    play.holdLobbyTouch(x: Float(point.x), y: Float(point.y))
                                }
                            }
                            .onEnded { value in
                                if screen == 1 {
                                    lastLookTranslation = 0
                                    play.finishFirstPersonLook()
                                    if OriginalPageInput.isTap(from: value.startLocation, to: value.location),
                                       let point = input.point(value.startLocation) {
                                        play.selectLobbyRoomObject(x: Float(point.x), y: Float(point.y))
                                    }
                                    return
                                }
                                play.releaseLobbyTouch()
                                if lobby.mode == .counter,
                                   OriginalPageInput.isTap(from: value.startLocation, to: value.location),
                                   let point = input.point(value.startLocation) {
                                    play.selectLobbyObject(x: Float(point.x), y: Float(point.y), confirmImmediately: true)
                                }
                            })
                        .notebookPhotograph()
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .accessibilityLabel(lobby.mode == .walking ? (screen == 0 ? "Floor plan. The red marker shows Kyle's position; the arrow and cone show where you are looking. Hold a direction to walk." : "3D view. Drag to look around.") : "Search view")
                        .onChange(of: displayScale * input.scale, initial: true) { _, scale in
                            if screen == 1, lobby.mode == .walking { play.setDisplayScale(scale) }
                        }
                    }
                    if screen == 1, lobby.mode == .walking {
                        Text("Hold a direction on the floor plan to walk.")
                            .font(NovelStyle.caption)
                        interactionButtons
                    }
                    if screen == 0 {
                        if lobby.mode == .walking {
                            interactionButtons
                            HStack {
                                Button("Items") { showsInventory = true }
                                Button("Notebook") { play.openNotebook() }
                            }.buttonStyle(BookTextButtonStyle())
                        } else {
                            Text("Tap an object to interact. Choose an item first to use it.")
                                .font(NovelStyle.caption).foregroundStyle(NovelStyle.fadedInk)
                            if let item = play.searchItem {
                                OriginalInventoryItemLabel(item: item)
                            }
                            Slider(value: Binding(get: { Double(play.lobby?.pan ?? 0) },
                                set: { play.panLobbyCounter(Float($0)) }), in: 0...1)
                                .accessibilityLabel("Look around")
                            HStack {
                                Button("Back") { play.leaveLobbyCounter() }
                                Button("Items") { showsInventory = true }
                                if play.searchItem != nil { Button("Cancel") { play.useItemInSearchView(nil) } }
                            }.buttonStyle(BookTextButtonStyle())
                        }
                    }
                }
                .allowsHitTesting(!play.isBrowsingInventory || screen == 0)
                .disabled(play.isBrowsingInventory && screen == 1)
                .onDisappear { lastLookTranslation = 0; play.releaseLobbyTouch() }
            }
        }
    }

    private func modernView(_ lobby: OriginalMapExploration) -> some View {
        VStack(spacing: 8) {
            Text(OriginalMapExploration.displayName(for: lobby.mapID))
                .font(NovelStyle.imprint)
            GeometryReader { proxy in
                let input = OriginalPageInput(available: proxy.size)
                ZStack(alignment: .bottomLeading) {
                    Color.black
                    if let image = play.lobbyImage {
                        Image(decorative: image, scale: 1)
                            .resizable().interpolation(hdGraphicsEnabled ? .high : .none)
                            .frame(width: input.size.width, height: input.size.height)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    if play.roomTransitionOpacity > 0 {
                        (play.roomTransitionIsBright ? Color.white : Color.black)
                            .opacity(play.roomTransitionOpacity)
                    }
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let delta = value.translation.width - lastLookTranslation
                                lastLookTranslation = value.translation.width
                                play.turnFirstPerson(by: -Float(delta) * 0.008)
                            }
                            .onEnded { value in
                                lastLookTranslation = 0
                                play.finishFirstPersonLook()
                                guard OriginalPageInput.isTap(from: value.startLocation, to: value.location) else { return }
                                let origin = CGPoint(x: (proxy.size.width - input.size.width) / 2,
                                                     y: (proxy.size.height - input.size.height) / 2)
                                if let point = input.point(CGPoint(x: value.startLocation.x - origin.x,
                                                                  y: value.startLocation.y - origin.y)) {
                                    play.selectLobbyRoomObject(x: Float(point.x), y: Float(point.y))
                                }
                            })
                    OriginalNavigationControls(play: play, compact: true)
                        .padding(8)
                        .background(NovelStyle.paper.opacity(0.88), in: Circle())
                        .padding(12)
                }
                .clipped()
                .accessibilityLabel("3D view. Drag to look; use the movement pad to walk.")
                .onChange(of: displayScale * input.scale, initial: true) { _, scale in
                    play.setDisplayScale(scale)
                }
            }
            Text("Drag to look · Hold the pad to walk or move sideways")
                .font(NovelStyle.caption).foregroundStyle(NovelStyle.fadedInk)
            interactionButtons
        }
        .onChange(of: modernNavigation) { _, _ in play.releaseLobbyTouch() }
        .onDisappear { lastLookTranslation = 0; play.releaseLobbyTouch() }
    }

    private var interactionButtons: some View {
        HStack {
            Button(play.nearbyDoor.map { OriginalMapExploration.displayName(for: $0) } ?? "Door") { play.inspectNearbyDoor() }.disabled(play.nearbyDoor == nil)
            Button("Inspect") { play.inspectLobbyCounter() }
                .disabled(play.lobby?.canInspectCounter(in: play.runner.game) != true)
            Button("Talk") { play.talkToNearbyPerson() }
                .disabled(play.lobby?.nearbyPerson(in: play.runner.game) == nil)
        }
        .buttonStyle(BookTextButtonStyle())
    }

}
