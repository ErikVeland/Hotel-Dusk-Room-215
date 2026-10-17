import Foundation

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
