import Foundation

/**
 * Native chapter checkpoints retain original game bytes before process 9 starts.
 */
public struct OriginalChapterSave: Codable, Equatable, Sendable {
    public let version: Int
    public let savedAt: Date
    public let state: Data
    public let conditionGlobalByte: UInt8?
    public let stateSHA256: String

    public init(game: OriginalGameState, savedAt: Date) throws {
        try Self.validate(game)
        version = 1
        self.savedAt = savedAt
        state = Data(game.bytes)
        conditionGlobalByte = game.conditionGlobalByte
        stateSHA256 = OriginalScriptCatalog.digest(state)
    }

    public func gameState() throws -> OriginalGameState {
        guard version == 1 else { throw OriginalDataError.unsupported("Chapter save version") }
        guard OriginalScriptCatalog.digest(state) == stateSHA256 else { throw OriginalDataError.checksum("Chapter save") }
        let game = try OriginalGameState(snapshot: state, conditionGlobalByte: conditionGlobalByte)
        try Self.validate(game)
        return game
    }

    public var chapterNumber: Int { (try? Int(gameState().chapter) + 1) ?? 1 }

    private static func validate(_ game: OriginalGameState) throws {
        guard (1..<10).contains(game.chapter), game.nowTime == 0,
              OriginalMapExploration.supportedMaps[game.mapID] != nil, OriginalMapExploration.supportedMaps[game.previousMapID] != nil,
              game.facing.isFinite, game.mapPosition.x.isFinite, game.mapPosition.y.isFinite, game.mapPosition.z.isFinite,
              game.bytes[0x137B] == 1 else {
            throw OriginalDataError.unsupported("Chapter save checkpoint")
        }
    }
}

/**
 * Storage is injected so save failures and restore use the same session path.
 */
public protocol OriginalChapterSaveStore {
    func load(slot: Int) throws -> OriginalChapterSave?
    func save(_ checkpoint: OriginalChapterSave, slot: Int) throws
}

/**
 * Each slot is replaced atomically in the application's local support directory.
 */
public struct OriginalChapterFileStore: OriginalChapterSaveStore {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public static var application: Self {
        Self(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HotelDuskDuo/ChapterSaves", isDirectory: true))
    }

    private func file(slot: Int) throws -> URL {
        guard (0..<3).contains(slot) else { throw OriginalDataError.invalid("Save slot") }
        return directory.appendingPathComponent("slot-\(slot + 1).json")
    }

    public func load(slot: Int) throws -> OriginalChapterSave? {
        let url = try file(slot: slot)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let result = try JSONDecoder().decode(OriginalChapterSave.self, from: Data(contentsOf: url))
        _ = try result.gameState()
        return result
    }

    public func save(_ checkpoint: OriginalChapterSave, slot: Int) throws {
        let url = try file(slot: slot)
        _ = try checkpoint.gameState()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(checkpoint).write(to: url, options: .atomic)
    }
}

/**
 * Processes 140 and 120 return before the chapter title (process 9).
 */
public struct OriginalChapterTransition {
    public enum Stage: Equatable { case prompt, slots, overwrite, title }
    public var stage: Stage = .prompt
    public var selectedSlot: Int?
    public var slots: [OriginalChapterSave?] = Array(repeating: nil, count: 3)
    public var error: String?
}
