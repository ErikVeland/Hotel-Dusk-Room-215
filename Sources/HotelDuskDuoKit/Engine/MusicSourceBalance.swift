import Foundation

/// Static gain corrections measured from complete source musical phrases.
/// The manifest hashes prevent stale calibration after a bank or recording change.
struct MusicSourceBalance: Decodable {
    struct Track: Decodable { let id: Int; let nativeGain: Float; let recordedGain: Float }
    let schemaVersion: Int
    let nativeManifestSHA256: String
    let recordedManifestSHA256: String
    let tracks: [Track]

    static func load() throws -> Self {
        let result = try JSONDecoder().decode(Self.self, from: Data(contentsOf: RecordedMusicLibrary.resource("balance.json")))
        let native = try Data(contentsOf: OriginalAudioLibrary.resource("OriginalAudioManifest.json"))
        let recorded = try Data(contentsOf: RecordedMusicLibrary.resource("manifest.json"))
        guard result.schemaVersion == 1, result.tracks.map(\.id) == Array(0..<36),
              result.tracks.allSatisfy({ $0.nativeGain.isFinite && $0.recordedGain.isFinite
                  && $0.nativeGain > 0 && $0.nativeGain <= 1 && $0.recordedGain > 0 && $0.recordedGain <= 1 }),
              result.nativeManifestSHA256 == OriginalAudioLibrary.digest(native),
              result.recordedManifestSHA256 == OriginalAudioLibrary.digest(recorded) else {
            throw OriginalAudioError.invalidManifest
        }
        return result
    }
}
