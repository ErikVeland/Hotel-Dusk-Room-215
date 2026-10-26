import Foundation

struct OriginalMapSoundCue: Decodable, Equatable, Sendable {
    let archiveID: Int
    let entryID: Int
}

/// Walking cadence from 0x0202DB50. Distance is measured after collision handling.
struct OriginalFootstepCadence: Equatable {
    private(set) var counter = 0
    private(set) var foot = 0

    mutating func update(distance: Float) -> Int? {
        var speed = distance / 4096 / Float(bitPattern: 0x3D0F5C29)
        if speed < 0 { speed *= Float(bitPattern: 0x3F333333) }
        if speed > 1.5 { counter += 8 }
        else if speed > 0 { counter += 6 }
        else { counter = 200 }
        if counter >= 300 { counter = 0 }
        guard counter == 0 else { return nil }
        foot = (foot + 1) % 2
        return foot
    }

    mutating func update(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Int? {
        // 0x020BCFEC returns a rounded fixed-point integer distance.
        let delta = end - start
        let square = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
        return update(distance: square.squareRoot().rounded())
    }
}

extension OriginalDialogueAudio {
    /// The source starts this room effect only while person slot 3 is in map 6.
    func walkingAmbience(mapID: Int16, game: OriginalGameState) throws -> OriginalMapSoundCue? {
        guard mapID == 6, try OriginalBytes(Data(game.bytes)).u16(0xCB0) == 6 else { return nil }
        return maps.first(where: { $0.mapID == mapID })?.ambient
    }
}
