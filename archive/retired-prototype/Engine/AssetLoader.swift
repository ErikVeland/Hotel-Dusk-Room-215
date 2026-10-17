import Foundation

/// Loads extracted ROM assets, strings, item lists, and room definitions
public final class AssetLoader: Sendable {
    public static let shared = AssetLoader()

    public struct TextCatalog: Codable, Sendable {
        public let systemText: [String: [String]]?
        public let dialogues: [String: [String]]?
        public let items: [String]?
        public let maps: [String]?

        enum CodingKeys: String, CodingKey {
            case systemText = "system_text"
            case dialogues
            case items
            case maps
        }
    }

    public init() {}

    public func loadCatalog() -> TextCatalog? {
        guard let url = Bundle.module.url(forResource: "GameText", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(TextCatalog.self, from: data)
        } catch {
            print("Failed to decode GameText.json: \(error)")
            return nil
        }
    }

    public func loadDefaultRooms() -> [Room] {
        return [
            Room(
                id: "room_215",
                name: "Room 215 (Wish)",
                floor: 2,
                description: "A rundown hotel room with faded floral wallpaper. A single rotary phone sits on the desk.",
                availableItems: ["Room 215 Key", "Old Notebook", "Paper Clip"],
                connections: ["hallway_2f"]
            ),
            Room(
                id: "hallway_2f",
                name: "2F Hallway",
                floor: 2,
                description: "A dim carpeted corridor stretching past locked guest doors. Silence hangs heavy.",
                availableItems: [],
                connections: ["room_215", "room_219", "room_213", "stairs_2f"],
                backgroundCode: "R213" // Verified visually: R213_L/_R are the two directions of the 2F corridor
            ),
            Room(
                id: "room_219",
                name: "Room 219",
                floor: 2,
                description: "Melissa and Kevin Woodward's room.",
                availableItems: [],
                connections: ["hallway_2f"]
            ),
            Room(
                id: "front_desk",
                name: "1F Front Desk",
                floor: 1,
                description: "Dunning Smith leans over the counter, glaring through his glasses.",
                availableItems: ["Hotel Brochure", "Registration card"],
                connections: ["lobby_1f", "office_1f"]
            ),
            Room(
                id: "lobby_1f",
                name: "1F Lobby",
                floor: 1,
                description: "Vintage armchairs, an old jukebox, and the smell of stale coffee.",
                availableItems: ["Puzzle Piece"],
                connections: ["front_desk", "restaurant_1f", "bar_1f", "hallway_2f"]
            ),
            Room(
                id: "bar_1f",
                name: "1F Bar",
                floor: 1,
                description: "Dim bar counter lined with bourbon bottles. The smell of tobacco lingers.",
                availableItems: ["Matches"],
                connections: ["lobby_1f"]
            ),
            Room(
                id: "restaurant_1f",
                name: "1F Restaurant",
                floor: 1,
                description: "Empty checkered tablecloths. Rosa is usually in the kitchen next door.",
                availableItems: ["Menu"],
                connections: ["lobby_1f"]
            ),
            Room(
                id: "room_213",
                name: "Room 213",
                floor: 2,
                description: "Martin Summer's room. Stacks of manuscript papers are scattered about.",
                availableItems: ["Pen"],
                connections: ["hallway_2f"]
            ),
            Room(
                id: "room_214",
                name: "Room 214",
                floor: 2,
                description: "Helen Parker's room. Smells of vintage perfume and lavender.",
                availableItems: ["Spectacles"],
                connections: ["hallway_2f"]
            ),
            Room(
                id: "boiler_room",
                name: "Boiler Room",
                floor: 0,
                description: "Loud hissing steam pipes in the basement depths of the hotel.",
                availableItems: ["Wrench"],
                connections: ["wine_cellar"]
            ),
            Room(
                id: "wine_cellar",
                name: "Wine Cellar",
                floor: 0,
                description: "Cold stone walls stacked with dusty wine racks. A secret door is concealed here.",
                availableItems: ["Old Wine Bottle"],
                connections: ["boiler_room"]
            )
        ]
    }

    public func loadDefaultItems() -> [InventoryItem] {
        let catalog = loadCatalog()
        let itemNames = catalog?.items ?? [
            "Room 215 Key", "Hotel Brochure", "Puzzle Piece", "Registration card",
            "Old Notebook", "Order Sheet", "Paper Clip", "Thin Wire", "Crowbar"
        ]

        return itemNames.prefix(12).map { name in
            InventoryItem(
                id: name.lowercased().replacingOccurrences(of: " ", with: "_"),
                name: name,
                description: "Standard item from Kyle Hyde's collection in Hotel Dusk: \(name)."
            )
        }
    }
}
