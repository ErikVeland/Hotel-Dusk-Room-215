#if os(iOS)
import UIKit
import os.log

/// The outside cover stays fixed to the phone; the open book may rotate normally.
@MainActor
public enum BookOrientationPolicy {
    public private(set) static var coverIsVisible = false
    private static let logger = Logger(subsystem: "com.veland.hoteldusk.duo", category: "Orientation")

    public static var supportedOrientations: UIInterfaceOrientationMask {
        if coverIsVisible { return .portrait }
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    public static func update(coverIsVisible: Bool) {
        self.coverIsVisible = coverIsVisible
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            guard scene.activationState != .unattached else { continue }
            for window in scene.windows {
                var controller = window.rootViewController
                while let current = controller {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    controller = current.presentedViewController
                }
            }
            if coverIsVisible {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                    logger.error("Could not lock cover orientation: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: supportedOrientations)) { error in
                    logger.error("Could not restore book orientations: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}
#endif
