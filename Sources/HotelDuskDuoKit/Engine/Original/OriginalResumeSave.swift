import Foundation

/// A walking checkpoint, optionally extended with resumable interaction inputs.
public struct OriginalResumeSave: Codable, Equatable, Sendable {
    public let version: Int
    public let savedAt: Date
    public let state: Data
    public let stateSHA256: String
    public let conditionGlobalByte: UInt8?
    public let checkpointFacing: Float
    public let musicSequenceID: Int?
    let progress: OriginalPlayProgress?
    let progressSHA256: String?

    init(game: OriginalGameState, checkpointFacing: Float, musicSequenceID: Int?, savedAt: Date,
         progress: OriginalPlayProgress? = nil) throws {
        version = progress == nil ? 1 : 2
        self.savedAt = savedAt
        state = Data(game.bytes)
        stateSHA256 = OriginalScriptCatalog.digest(state)
        conditionGlobalByte = game.conditionGlobalByte
        self.checkpointFacing = checkpointFacing
        self.musicSequenceID = musicSequenceID
        self.progress = progress
        progressSHA256 = try progress.map { OriginalScriptCatalog.digest(try $0.encoded()) }
        _ = try gameState()
    }

    public func gameState() throws -> OriginalGameState {
        guard version == 1 || version == 2 else { throw OriginalDataError.unsupported("Resume save version") }
        if version == 2 {
            guard let progress, let progressSHA256,
                  OriginalScriptCatalog.digest(try progress.encoded()) == progressSHA256 else {
                throw OriginalDataError.checksum("Interaction progress")
            }
            try progress.validate()
        } else if progress != nil {
            throw OriginalDataError.invalid("Unexpected interaction progress")
        }
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
    private let instantLog: OriginalInstantSaveLog

    public init(directory: URL) {
        self.directory = directory
        instantLog = OriginalInstantSaveLog(directory: directory)
    }

    public static var application: Self {
        Self(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HotelDuskDuo/Resume", isDirectory: true))
    }

    public func load() throws -> OriginalResumeSave? { try instantLog.load() }

    public func save(_ checkpoint: OriginalResumeSave) throws { try instantLog.save(checkpoint) }
}
