import Foundation
import CryptoKit

/// Source identifiers and loop positions recovered from the original SDAT.
public struct OriginalAudioLibrary: Decodable, Sendable {
    public struct Loop: Decodable, Sendable, Equatable {
        public let startTick: Int
        public let endTick: Int
    }
    public struct Track: Decodable, Sendable {
        public let trackID: Int
        public let hasNotes: Bool
        public let hasMIDIEvents: Bool
        public let program: Int
        public let endTick: Int
        public let loop: Loop?
    }
    public struct Sequence: Decodable, Sendable, Identifiable {
        public let id: Int
        public let symbol: String
        public let bankSymbol: String
        public let volume: Int
        public let midiSHA256: String
        public let repairedDLS_SHA256: String
        public let tracks: [Track]
    }
    public let schemaVersion: Int
    public let sourceSDAT_SHA256: String
    public let ticksPerBeat: Int
    public let wavePoolSHA256: String
    public let sequences: [Sequence]
    public let limitations: [String]

    public static func load() throws -> OriginalAudioLibrary {
        let data = try Data(contentsOf: resource("OriginalAudioManifest.json"))
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard result.schemaVersion == 1, result.ticksPerBeat == 48 else {
            throw OriginalAudioError.invalidManifest
        }
        return result
    }

    public static func resource(_ name: String) throws -> URL {
        guard let root = Bundle.module.url(forResource: "Audio", withExtension: nil) else {
            throw OriginalAudioError.missingResource("Audio")
        }
        let url = root.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OriginalAudioError.missingResource(name)
        }
        return url
    }

    /// Rebuild a bank from shared PCM and its original instrument definitions.
    public func soundBankURL(for sequence: Sequence, cacheDirectory: URL? = nil) throws -> URL {
        let directory = try cacheDirectory ?? FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("HotelDusk/OriginalAudio", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(sequence.bankSymbol + ".dls")
        if let current = try? Data(contentsOf: destination),
           Self.digest(current) == sequence.repairedDLS_SHA256 {
            return destination
        }
        let pool = try Data(contentsOf: Self.resource("OriginalWavePool.bin"))
        guard Self.digest(pool) == wavePoolSHA256 else {
            throw OriginalAudioError.corruptResource("OriginalWavePool.bin")
        }
        var data = try Data(contentsOf: Self.resource(sequence.bankSymbol + ".prefix"))
        data.append(pool)
        data.append(try Data(contentsOf: Self.resource(sequence.bankSymbol + ".suffix")))
        guard Self.digest(data) == sequence.repairedDLS_SHA256 else {
            throw OriginalAudioError.corruptResource(sequence.bankSymbol)
        }
        try data.write(to: destination, options: .atomic)
        return destination
    }

    public func midiURL(for sequence: Sequence) throws -> URL {
        let url = try Self.resource(sequence.symbol + ".mid")
        guard Self.digest(try Data(contentsOf: url)) == sequence.midiSHA256 else {
            throw OriginalAudioError.corruptResource(sequence.symbol)
        }
        return url
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public enum OriginalAudioError: Error, LocalizedError, Equatable {
    case invalidManifest
    case missingResource(String)
    case corruptResource(String)
    case unknownSequence(String)
    case unsupportedEffect(String)
    case invalidTrackCount
    case invalidLoop
    case unsupportedInstrument(Int)
    case unsupportedWaveEncoding(Int)
    case invalidCommand
    case invalidSequence
    case unsupportedSequenceCommand(Int, Int)

    public var errorDescription: String? {
        switch self {
        case .invalidManifest: return "The original audio manifest is invalid."
        case .missingResource(let name): return "Original audio resource is missing: \(name)."
        case .corruptResource(let name): return "Original audio resource failed its checksum: \(name)."
        case .unknownSequence(let name): return "No original sequence has this identifier: \(name)."
        case .unsupportedEffect(let name): return "Original effect playback is not implemented for \(name)."
        case .invalidTrackCount: return "The MIDI tracks do not match the original sequence."
        case .invalidLoop: return "The source loop range is invalid."
        case .unsupportedInstrument(let kind): return "Unsupported original instrument type: \(kind)."
        case .unsupportedWaveEncoding(let kind): return "Unsupported original wave encoding: \(kind)."
        case .invalidCommand: return "The original audio command is invalid."
        case .invalidSequence: return "The original sound sequence is invalid."
        case .unsupportedSequenceCommand(let command, let offset):
            return String(format: "Unsupported original sequence command %02X at %06X.", command, offset)
        }
    }
}
