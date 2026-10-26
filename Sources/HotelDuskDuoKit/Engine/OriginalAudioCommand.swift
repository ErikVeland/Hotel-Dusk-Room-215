import Foundation

/// Text audio controls from 0x0204370C and the original runtime lookup tables.
struct OriginalDialogueAudio: Decodable {
    struct Music: Decodable { let name: String; let sequenceID: Int }
    struct Sound: Decodable { let code: String; let archiveID: Int; let entryID: Int }
    struct Map: Decodable {
        let mapID: Int16
        let sequenceID: Int
        let footstep: OriginalMapSoundCue?
        let ambient: OriginalMapSoundCue?
    }
    let schemaVersion: Int
    let arm9SHA256: String
    let textHandler: String
    let music: [Music]
    let sounds: [Sound]
    let maps: [Map]
    let mapSoundSHA256: String

    static func load() throws -> Self {
        let data = try Data(contentsOf: OriginalAudioLibrary.resource("OriginalDialogueAudio.json"))
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard result.schemaVersion == 1, result.textHandler == "0204370c",
              result.arm9SHA256 == "b9b7f7e4ddedcb245f7df0d9a953e3fbf5a15cc88436e03b8b3b65cfe872e809",
              result.music.count == 36, result.sounds.count == 197,
              result.mapSoundSHA256 == "50277eb10172d0669e342c401624aa4574f989b153627b17ada0885474cae287",
              result.maps.count == 46 else {
            throw OriginalAudioError.invalidManifest
        }
        return result
    }

    /// Walking music selection from 0x0202DC70, including the bar's saved song.
    func walkingMusic(mapID: Int16, game: OriginalGameState) throws -> OriginalAudioCommand? {
        guard let map = maps.first(where: { $0.mapID == mapID }) else {
            throw OriginalAudioError.invalidManifest
        }
        guard map.sequenceID != -1 else { return nil }
        let sequence: Int
        if mapID == 8, game.value(for: .gameFlag(index: 31)) == true {
            sequence = 5
        } else if map.sequenceID == -2 {
            sequence = 17
        } else {
            let selected = Int(Int16(bitPattern: try OriginalBytes(Data(game.bytes)).u16(0x13BC)))
            sequence = mapID == 5 && selected >= 0 ? selected : map.sequenceID
        }
        return .startMusic(sequenceID: sequence)
    }

    func command(for control: OriginalTextControl) throws -> OriginalAudioCommand? {
        switch control {
        case .music(let mode, let name):
            if mode == 1 { return .stopMusic(fadeFrames: 20) }
            // Other modes only advance the original text pointer.
            guard mode == 0 else { return nil }
            guard let cue = music.first(where: { $0.name == name }) else {
                throw OriginalAudioError.unknownSequence(name)
            }
            return .startMusic(sequenceID: cue.sequenceID)
        case .sound(let code, let mode):
            guard let cue = sounds.first(where: { $0.code == code }) else {
                throw OriginalAudioError.unsupportedEffect(code)
            }
            return mode == 0 ? .startEffect(archiveID: cue.archiveID, entryID: cue.entryID)
                : .stopEffect(archiveID: cue.archiveID, entryID: cue.entryID, fadeFrames: 1)
        default: return nil
        }
    }
}

/// Commands queued by the original BGM and SE cinematic objects.
public enum OriginalAudioCommand: Equatable, Sendable {
    case startMusic(sequenceID: Int)
    case stopMusic(fadeFrames: Int)
    case waitForMusic
    case disableMusic(Bool)
    case musicVolume(target: Int, frames: Int)
    case startEffect(archiveID: Int, entryID: Int)
    case stopEffect(archiveID: Int, entryID: Int, fadeFrames: Int)
    case effectVolume(archiveID: Int, entryID: Int, target: Int, frames: Int)
    case disableNewEffects(Bool)
    case effectPitch(archiveID: Int, entryID: Int, target: Int, frames: Int)
    case waitForEffectPlayer(Int)

    /// Fields begin with the operation at object+4, then signed 16-bit arguments.
    /// ARM9 020A5140 dispatches BGM; 020A51F8 dispatches SE.
    public static func decode(handlerAddress: UInt32, fields: [Int16]) throws -> Self {
        guard let operation = fields.first else { throw OriginalAudioError.invalidCommand }
        func argument(_ index: Int) throws -> Int {
            guard fields.indices.contains(index) else { throw OriginalAudioError.invalidCommand }
            return Int(fields[index])
        }
        switch (handlerAddress, operation) {
        case (0x020A5140, 0): return try .startMusic(sequenceID: argument(1))
        case (0x020A5140, 1): return try .stopMusic(fadeFrames: argument(1))
        case (0x020A5140, 2): return .waitForMusic
        case (0x020A5140, 3): return try .disableMusic(argument(1) != 0)
        case (0x020A5140, 4): return try .musicVolume(target: argument(1), frames: argument(2))
        case (0x020A51F8, 0): return try .startEffect(archiveID: argument(2), entryID: argument(1))
        case (0x020A51F8, 1):
            return try .stopEffect(archiveID: argument(3), entryID: argument(1), fadeFrames: argument(2))
        case (0x020A51F8, 2):
            return try .effectVolume(archiveID: argument(4), entryID: argument(1), target: argument(2), frames: argument(3))
        case (0x020A51F8, 3): return try .disableNewEffects(argument(1) != 0)
        case (0x020A51F8, 4):
            return try .effectPitch(archiveID: argument(4), entryID: argument(1), target: argument(2), frames: argument(3))
        case (0x020A51F8, 5): return try .waitForEffectPlayer(argument(1))
        default: throw OriginalAudioError.invalidCommand
        }
    }
}
