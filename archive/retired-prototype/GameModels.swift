import Foundation

/// Represents a physical room or location inside Hotel Dusk
public struct Room: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let floor: Int
    public let description: String
    public let availableItems: [String]
    public let connections: [String]
    /// ROM talk-background code (for example "R213" for `R213_L.png` / `R213_R.png`).
    /// `nil` until the room is matched to its ROM area code.
    public let backgroundCode: String?

    public init(id: String, name: String, floor: Int, description: String, availableItems: [String], connections: [String], backgroundCode: String? = nil) {
        self.id = id
        self.name = name
        self.floor = floor
        self.description = description
        self.availableItems = availableItems
        self.connections = connections
        self.backgroundCode = backgroundCode
    }
}

/// Represents an item in Kyle Hyde's inventory
public struct InventoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let canExamine: Bool
    public let iconSymbol: String

    public init(id: String, name: String, description: String, canExamine: Bool = true, iconSymbol: String = "shippingbox.fill") {
        self.id = id
        self.name = name
        self.description = description
        self.canExamine = canExamine
        self.iconSymbol = iconSymbol
    }
}

/// Represents a character encountered in the hotel
public struct Character: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let title: String
    public let roomNumber: String?
    public let portraitCode: String

    public init(id: String, name: String, title: String, roomNumber: String? = nil, portraitCode: String) {
        self.id = id
        self.name = name
        self.title = title
        self.roomNumber = roomNumber
        self.portraitCode = portraitCode
    }
}

/// Dialogue node for branching interrogations
public struct DialogueNode: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let speaker: String
    public let text: String
    public let choices: [DialogueChoice]
    public let isInterrogationQuestion: Bool

    public init(id: String, speaker: String, text: String, choices: [DialogueChoice] = [], isInterrogationQuestion: Bool = false) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.choices = choices
        self.isInterrogationQuestion = isInterrogationQuestion
    }
}

public struct DialogueChoice: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let prompt: String
    public let targetNodeId: String
    public let triggersSuspicion: Bool

    public init(id: String = UUID().uuidString, prompt: String, targetNodeId: String, triggersSuspicion: Bool = false) {
        self.id = id
        self.prompt = prompt
        self.targetNodeId = targetNodeId
        self.triggersSuspicion = triggersSuspicion
    }
}

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
