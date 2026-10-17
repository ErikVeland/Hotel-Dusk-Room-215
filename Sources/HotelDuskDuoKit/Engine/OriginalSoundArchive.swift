import Foundation

/// Reads the original banks, wave archives and effect entry points without MIDI conversion.
public struct OriginalSoundArchive: Sendable {
    public struct Effect: Decodable, Sendable, Equatable {
        public let id: Int
        public let symbol: String
        public let eventOffset: Int
        public let bankID: Int
        public let volume: Int
        public let channelPriority: Int
        public let playerPriority: Int
        public let playerID: Int
    }
    public struct SequenceArchive: Decodable, Sendable {
        public let id: Int
        public let symbol: String
        public let fileID: Int
        public let eventDataOffset: Int
        public let sequences: [Effect]
    }
    public struct Bank: Decodable, Sendable {
        public let id: Int
        public let symbol: String
        public let fileID: Int
        public let waveArchiveIDs: [Int?]
    }
    public struct Wave: Decodable, Sendable {
        public let id: Int
        public let offset: Int
        public let encoding: Int
        public let loop: Bool
        public let sampleRate: Int
        public let timer: Int
        public let loopStartWords: Int
        public let loopLengthWords: Int
    }
    public struct WaveArchive: Decodable, Sendable {
        public let id: Int
        public let symbol: String
        public let fileID: Int
        public let waves: [Wave]
    }
    public struct Player: Decodable, Sendable {
        public let id: Int
        public let symbol: String
        public let maxSequences: Int
        public let channelMask: Int
    }
    public struct Instrument: Sendable, Equatable {
        public enum Voice: Sendable, Equatable {
            case pcm(waveArchiveID: Int, waveID: Int)
            case pulse(duty: Int)
            case noise
        }
        public let voice: Voice
        public let rootKey: Int
        public let attack: Int
        public let decay: Int
        public let sustain: Int
        public let release: Int
        public let pan: Int
    }
    public struct Sample: Sendable {
        public let pcm: [Int16]
        public let sampleRate: Int
        public let timer: Int
        public let loopStart: Int?
        public let loopLength: Int?
    }
    private struct File: Decodable {
        let id: Int
        let path: String
        let magic: String
        let length: Int
        let sha256: String
    }
    private struct Inventory: Decodable {
        let schemaVersion: Int
        let sha256: String
        let files: [File]
        let sequenceArchives: [SequenceArchive]
        let banks: [Bank]
        let waveArchives: [WaveArchive]
        let players: [Player]
    }
    public let sequenceArchives: [SequenceArchive]
    public let banks: [Bank]
    public let waveArchives: [WaveArchive]
    public let players: [Player]
    private let files: [Data]

    public static func load() throws -> Self {
        let inventory = try JSONDecoder().decode(Inventory.self, from: Data(contentsOf:
            OriginalAudioLibrary.resource("OriginalSDATInventory.json")))
        let source = try OriginalAudioLibrary.load()
        guard inventory.schemaVersion == 1, inventory.sha256 == source.sourceSDAT_SHA256,
              inventory.files.enumerated().allSatisfy({ $0.offset == $0.element.id }),
              inventory.banks.enumerated().allSatisfy({ $0.offset == $0.element.id }),
              inventory.waveArchives.enumerated().allSatisfy({ $0.offset == $0.element.id }),
              inventory.sequenceArchives.enumerated().allSatisfy({ $0.offset == $0.element.id }) else {
            throw OriginalAudioError.invalidManifest
        }
        let files = try inventory.files.map { file in
            let filename = URL(fileURLWithPath: file.path).lastPathComponent
            let data = try Data(contentsOf: OriginalAudioLibrary.resource("Nitro/" + filename))
            guard data.count == file.length, data.prefix(4) == Data(file.magic.utf8),
                  OriginalAudioLibrary.digest(data) == file.sha256 else {
                throw OriginalAudioError.corruptResource(filename)
            }
            return data
        }
        return Self(sequenceArchives: inventory.sequenceArchives, banks: inventory.banks,
                    waveArchives: inventory.waveArchives, players: inventory.players, files: files)
    }

    public func effect(archiveID: Int, entryID: Int) throws -> Effect {
        guard sequenceArchives.indices.contains(archiveID),
              let effect = sequenceArchives[archiveID].sequences.first(where: { $0.id == entryID }),
              effect.eventOffset >= 0 else {
            throw OriginalAudioError.unknownSequence("SSAR \(archiveID):\(entryID)")
        }
        return effect
    }

    /// Jump and call addresses are relative to this shared SSAR event block.
    public func effectEventData(archiveID: Int) throws -> Data {
        guard sequenceArchives.indices.contains(archiveID) else { throw OriginalAudioError.invalidManifest }
        let archive = sequenceArchives[archiveID]
        let data = try file(archive.fileID)
        return try data.soundBytes(archive.eventDataOffset, count: data.count - archive.eventDataOffset)
    }

    public func instrumentCount(bankID: Int) throws -> Int {
        guard banks.indices.contains(bankID) else { throw OriginalAudioError.invalidManifest }
        return try file(banks[bankID].fileID).soundInteger(0x38, count: 4)
    }

    public func instrument(bankID: Int, program: Int, note: Int) throws -> Instrument? {
        guard banks.indices.contains(bankID), (0...127).contains(note), program >= 0 else {
            throw OriginalAudioError.invalidManifest
        }
        let bank = banks[bankID]
        let data = try file(bank.fileID)
        let count = try data.soundInteger(0x38, count: 4)
        guard program < count else { return nil }
        var kind = try data.soundInteger(0x3C + program * 4, count: 1)
        var offset = try data.soundInteger(0x3D + program * 4, count: 3)
        if kind == 0 { return nil }
        if kind == 16 {
            let low = try data.soundInteger(offset, count: 1)
            let high = try data.soundInteger(offset + 1, count: 1)
            guard (low...high).contains(note) else { return nil }
            offset += 2 + (note - low) * 12
            kind = try data.soundInteger(offset, count: 2)
            offset += 2
        } else if kind == 17 {
            var region: Int?
            for index in 0..<8 {
                let high = try data.soundInteger(offset + index, count: 1)
                if index > 0, high == 0 { break }
                if note <= high { region = index; break }
            }
            guard let region else { return nil }
            offset += 8 + region * 12
            kind = try data.soundInteger(offset, count: 2)
            offset += 2
        }
        let waveID = try data.soundInteger(offset, count: 2)
        let voice: Instrument.Voice
        switch kind {
        case 0: return nil
        case 1:
            let slot = try data.soundInteger(offset + 2, count: 2)
            guard bank.waveArchiveIDs.indices.contains(slot), let archiveID = bank.waveArchiveIDs[slot],
                  waveArchives.indices.contains(archiveID), waveArchives[archiveID].waves.indices.contains(waveID) else {
                throw OriginalAudioError.invalidManifest
            }
            voice = .pcm(waveArchiveID: archiveID, waveID: waveID)
        case 2: voice = .pulse(duty: waveID)
        case 3: voice = .noise
        default: throw OriginalAudioError.unsupportedInstrument(kind)
        }
        return try Instrument(voice: voice, rootKey: data.soundInteger(offset + 4, count: 1),
                              attack: data.soundInteger(offset + 5, count: 1),
                              decay: data.soundInteger(offset + 6, count: 1),
                              sustain: data.soundInteger(offset + 7, count: 1),
                              release: data.soundInteger(offset + 8, count: 1),
                              pan: data.soundInteger(offset + 9, count: 1))
    }

    public func sample(archiveID: Int, waveID: Int) throws -> Sample {
        guard waveArchives.indices.contains(archiveID), waveArchives[archiveID].waves.indices.contains(waveID) else {
            throw OriginalAudioError.invalidManifest
        }
        let archive = waveArchives[archiveID]
        let wave = archive.waves[waveID]
        let data = try file(archive.fileID)
        guard wave.encoding == 2 else { throw OriginalAudioError.unsupportedWaveEncoding(wave.encoding) }
        let encoded = try data.soundBytes(wave.offset + 12, count: (wave.loopStartWords + wave.loopLengthWords) * 4)
        let pcm = try Self.decodeADPCM(encoded)
        let start = (wave.loopStartWords - 1) * 8
        let length = wave.loopLengthWords * 8
        guard !wave.loop || (start >= 0 && start + length <= pcm.count && length > 0) else {
            throw OriginalAudioError.invalidLoop
        }
        return Sample(pcm: pcm, sampleRate: wave.sampleRate, timer: wave.timer,
                      loopStart: wave.loop ? start : nil, loopLength: wave.loop ? length : nil)
    }

    /// Nitro IMA ADPCM uses low nibbles first and saturates at -32767.
    static func decodeADPCM(_ data: Data) throws -> [Int16] {
        var predictor = Int(Int16(bitPattern: UInt16(try data.soundInteger(0, count: 2))))
        var index = try data.soundInteger(2, count: 2) & 0x7F
        guard index <= 88 else { throw OriginalAudioError.invalidManifest }
        let steps = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41,
                     45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190,
                     209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724,
                     796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272,
                     2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
                     7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818,
                     18500, 20350, 22385, 24623, 27086, 29794, 32767]
        let changes = [-1, -1, -1, -1, 2, 4, 6, 8]
        var output: [Int16] = []
        output.reserveCapacity((data.count - 4) * 2)
        for byte in data.dropFirst(4) {
            for nibble in [Int(byte & 15), Int(byte >> 4)] {
                let step = steps[index]
                var delta = step / 8
                if nibble & 1 != 0 { delta += step / 4 }
                if nibble & 2 != 0 { delta += step / 2 }
                if nibble & 4 != 0 { delta += step }
                predictor = min(32767, max(-32767, predictor + (nibble & 8 == 0 ? delta : -delta)))
                index = min(88, max(0, index + changes[nibble & 7]))
                output.append(Int16(predictor))
            }
        }
        return output
    }

    private func file(_ id: Int) throws -> Data {
        guard files.indices.contains(id) else { throw OriginalAudioError.invalidManifest }
        return files[id]
    }
}

private extension Data {
    func soundBytes(_ offset: Int, count: Int) throws -> Data {
        guard offset >= 0, count >= 0, offset <= self.count, count <= self.count - offset else {
            throw OriginalAudioError.invalidManifest
        }
        return subdata(in: offset..<(offset + count))
    }
    func soundInteger(_ offset: Int, count: Int) throws -> Int {
        try soundBytes(offset, count: count).enumerated().reduce(0) { $0 | (Int($1.element) << ($1.offset * 8)) }
    }
}
