import SwiftUI
import HotelDuskDuoKit

@main
@MainActor
struct HotelDuskDuoApp: App {
    // A hinge transition can replace the display's window. Keep the game above
    // that window so the cover and inner displays share the same session.
    @StateObject private var session = GameSession(audioController: AudioController(preferences: .standard))

    var body: some Scene {
        WindowGroup("Hotel Dusk: Room 215 — iPhone Duo Edition") {
            DuoBookContainerView(session: session)
                #if os(macOS)
                .frame(minWidth: 700, minHeight: 500)
                #endif
        }
    }
}
