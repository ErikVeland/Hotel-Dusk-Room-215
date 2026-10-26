import Foundation

/// A native checkpoint taken only after control returns to walking.
/// It does not serialize a partially executed conversation or puzzle.
public struct OriginalResumeSave: Codable, Equatable, Sendable {
    public let version: Int
    public let savedAt: Date
    public let state: Data
    public let stateSHA256: String
    public let conditionGlobalByte: UInt8?
    public let checkpointFacing: Float
    public let musicSequenceID: Int?

    init(game: OriginalGameState, checkpointFacing: Float, musicSequenceID: Int?, savedAt: Date) throws {
        version = 1
        self.savedAt = savedAt
        state = Data(game.bytes)
        stateSHA256 = OriginalScriptCatalog.digest(state)
        conditionGlobalByte = game.conditionGlobalByte
        self.checkpointFacing = checkpointFacing
        self.musicSequenceID = musicSequenceID
        _ = try gameState()
    }

    public func gameState() throws -> OriginalGameState {
        guard version == 1 else { throw OriginalDataError.unsupported("Resume save version") }
        guard OriginalScriptCatalog.digest(state) == stateSHA256 else {
            throw OriginalDataError.checksum("Resume save")
        }
        let game = try OriginalGameState(snapshot: state, conditionGlobalByte: conditionGlobalByte)
        guard game.chapter < 10, OriginalMapExploration.supportedMaps[game.mapID] != nil,
              game.facing.isFinite, checkpointFacing.isFinite,
              game.mapPosition.x.isFinite, game.mapPosition.y.isFinite, game.mapPosition.z.isFinite else {
            throw OriginalDataError.unsupported("Resume save location")
        }
        return game
    }

    public var chapterNumber: Int { (try? Int(gameState().chapter) + 1) ?? 1 }
}

public protocol OriginalResumeSaveStore {
    func load() throws -> OriginalResumeSave?
    func save(_ checkpoint: OriginalResumeSave) throws
}

public struct OriginalResumeFileStore: OriginalResumeSaveStore {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public static var application: Self {
        Self(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HotelDuskDuo/Resume", isDirectory: true))
    }

    public func load() throws -> OriginalResumeSave? {
        let file = directory.appendingPathComponent("resume.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let checkpoint = try JSONDecoder().decode(OriginalResumeSave.self, from: Data(contentsOf: file))
        _ = try checkpoint.gameState()
        return checkpoint
    }

    public func save(_ checkpoint: OriginalResumeSave) throws {
        _ = try checkpoint.gameState()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(checkpoint).write(to: directory.appendingPathComponent("resume.json"), options: .atomic)
    }
}
