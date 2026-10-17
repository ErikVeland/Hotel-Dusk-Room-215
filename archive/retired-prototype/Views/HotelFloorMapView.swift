import SwiftUI

/// A printed hotel plan, marked in ink at Kyle's current location.
public struct HotelFloorMapView: View {
    @ObservedObject public var session: GameSession
    @State private var selectedFloor = 2

    public init(session: GameSession) { self.session = session }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("HOTEL DUSK").font(NovelStyle.heading).tracking(2)
            HStack(spacing: 16) {
                floorButton(2, "Second floor")
                floorButton(1, "First floor")
                floorButton(0, "Basement")
            }
            VStack(spacing: 12) {
                if selectedFloor == 2 {
                    HStack(spacing: 6) {
                        room("room_215", "215\nWish")
                        room("room_213", "213")
                        room("room_211", "211")
                        room("linens_2f", "Linen")
                    }
                    room("hallway_2f", "Second-floor hallway")
                    HStack(spacing: 6) {
                        room("room_214", "214")
                        room("room_212", "212")
                        room("room_216", "216")
                        room("stairs_2f", "Stairs")
                    }
                } else if selectedFloor == 1 {
                    HStack(spacing: 6) {
                        room("front_desk", "Front desk")
                        room("office_1f", "Office")
                        room("restaurant_1f", "Restaurant")
                    }
                    room("lobby_1f", "Lobby")
                    HStack(spacing: 6) {
                        room("bar_1f", "Bar")
                        room("kitchen_1f", "Kitchen")
                        room("entrance_1f", "Entrance")
                    }
                } else {
                    Text("Restricted access").font(NovelStyle.italic)
                    HStack(spacing: 6) {
                        room("boiler_room", "Boiler room")
                        room("wine_cellar", "Wine cellar")
                        room("secret_room", "Unknown")
                    }
                }
            }
            .padding(12)
            .overlay(Rectangle().strokeBorder(NovelStyle.rule, lineWidth: 1))
            Text("You are here: \(session.currentRoom.name)")
                .font(NovelStyle.italic)
            Text("Touch a named room to go there. Unavailable rooms are faint.")
                .font(NovelStyle.caption)
                .foregroundStyle(NovelStyle.fadedInk)
        }
        .foregroundStyle(NovelStyle.ink)
    }

    private func floorButton(_ floor: Int, _ title: String) -> some View {
        Button {
            selectedFloor = floor
            session.audioController.playSFX(name: "page_turn.wav")
        } label: {
            Text(title)
                .font(NovelStyle.label)
                .underline(selectedFloor == floor)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedFloor == floor ? .isSelected : [])
    }

    private func room(_ id: String, _ title: String) -> some View {
        let current = session.currentRoom.id == id
        let available = session.allRooms.contains { $0.id == id }
        return Button { session.navigateTo(roomId: id) } label: {
            Text(title)
                .font(NovelStyle.caption)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(current ? NovelStyle.ink.opacity(0.1) : .clear)
                .overlay(Rectangle().strokeBorder(NovelStyle.ink.opacity(current ? 0.8 : 0.35), lineWidth: current ? 1.5 : 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.4)
        .accessibilityLabel(current ? "\(title), current location" : title)
    }
}
