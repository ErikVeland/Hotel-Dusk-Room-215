import Foundation

/// Handedness preference for the iPhone Duo book-mode screen mapping
public enum Handedness: String, Codable, CaseIterable, Sendable {
    case rightHanded = "Right-Handed" // Left screen = 3D / Scene, Right screen = Touch / Dialogue
    case leftHanded = "Left-Handed"   // Left screen = Touch / Dialogue, Right screen = 3D / Scene
}

/// Posture state of the dual-screen foldable iPhone Duo
public enum DuoPosture: String, Codable, Sendable {
    case bookOpen = "Book Mode (180° Flat)"
    case tentOrLaptop = "Laptop/Console Mode (90°-135°)"
    case foldedClosed = "Folded Closed (0° - Fold Action)"
    case singleDisplay = "Adaptive Single Display"
}
