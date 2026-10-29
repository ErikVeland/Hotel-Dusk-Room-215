import SwiftUI
import HotelDuskDuoKit
#if os(iOS)
import UIKit

final class BookAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        BookOrientationPolicy.supportedOrientations
    }
}
#endif

@main
@MainActor
struct HotelDuskDuoApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(BookAppDelegate.self) private var appDelegate
    #endif
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
