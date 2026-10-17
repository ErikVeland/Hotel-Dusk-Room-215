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

}
