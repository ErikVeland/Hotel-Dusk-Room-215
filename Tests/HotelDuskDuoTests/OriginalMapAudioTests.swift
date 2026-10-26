import XCTest
@testable import HotelDuskDuoKit

final class OriginalMapAudioTests: XCTestCase {
    @MainActor func testUntouchedInitialIdlePreservesTheSourceFirstStepDelay() throws {
        let audio = AudioController()
        audio.isMuted = true
        defer { audio.stopAll() }
        for _ in 0..<100 { audio.advanceWalkingAudio(mapID: 2, from: .zero, to: .zero, hasInput: false) }
        for _ in 0..<37 { audio.advanceWalkingAudio(mapID: 2, from: .zero, to: .init(246, 0, 0)) }
        XCTAssertTrue(audio.soundEffectsHistory.isEmpty)
        audio.advanceWalkingAudio(mapID: 2, from: .zero, to: .init(246, 0, 0))
        XCTAssertEqual(audio.soundEffectsHistory.count, 1)
    }

    @MainActor func testWalkingHostStartsAlternatingStepsAndOwnsRoomAmbience() throws {
        let audio = AudioController()
        audio.isMuted = true
        defer { audio.stopAll() }
        let origin = SIMD3<Float>.zero
        audio.advanceWalkingAudio(mapID: 2, from: origin, to: origin)
        for _ in 0..<17 { audio.advanceWalkingAudio(mapID: 2, from: origin, to: .init(143, 0, 0)) }
        let archive = try OriginalSoundArchive.load()
        XCTAssertEqual(audio.soundEffectsHistory.last, try archive.effect(archiveID: 16, entryID: 7).symbol)
        for _ in 0..<50 { audio.advanceWalkingAudio(mapID: 2, from: origin, to: .init(143, 0, 0)) }
        XCTAssertEqual(audio.soundEffectsHistory.last, try archive.effect(archiveID: 16, entryID: 6).symbol)
        var snapshot = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0).snapshot
        snapshot[0xCB0] = 6; snapshot[0xCB1] = 0
        let game = try OriginalGameState(snapshot: snapshot)
        audio.playWalkingMusic(mapID: 6, game: game)
        XCTAssertNil(audio.lastError)
        XCTAssertEqual(audio.soundEffectsHistory.last, try archive.effect(archiveID: 12, entryID: 0).symbol)
        let count = audio.soundEffectsHistory.count
        audio.playWalkingMusic(mapID: 6, game: game)
        XCTAssertEqual(audio.soundEffectsHistory.count, count)
        let player = try archive.effect(archiveID: 12, entryID: 0).playerID
        XCTAssertTrue(try audio.applyOriginalCommand(.waitForEffectPlayer(player)))
        audio.stopWalkingAudio()
        for _ in 0..<5 { audio.advanceOriginalFrame() }
        XCTAssertFalse(try audio.applyOriginalCommand(.waitForEffectPlayer(player)))
    }

    func testFootstepsUseDistanceCadenceAndAlternateAfterIdle() {
        var cadence = OriginalFootstepCadence()
        XCTAssertNil(cadence.update(distance: 0))
        for _ in 0..<16 { XCTAssertNil(cadence.update(distance: 143)) }
        XCTAssertEqual(cadence.update(distance: 143), 1)
        for _ in 0..<49 { XCTAssertNil(cadence.update(distance: 143)) }
        XCTAssertEqual(cadence.update(distance: 143), 0)
        XCTAssertNil(cadence.update(distance: 0))
        for _ in 0..<12 { XCTAssertNil(cadence.update(distance: 246)) }
        XCTAssertEqual(cadence.update(distance: 246), 1)
        for _ in 0..<37 { XCTAssertNil(cadence.update(distance: 246)) }
        XCTAssertEqual(cadence.update(distance: 246), 0)
    }

    func testCollisionAndTurningInPlaceDoNotPlayFootsteps() {
        var cadence = OriginalFootstepCadence()
        let position = SIMD3<Float>(100, 12288, 100)
        for _ in 0..<300 { XCTAssertNil(cadence.update(from: position, to: position)) }
        XCTAssertEqual(cadence.counter, 200)
        for _ in 0..<12 { XCTAssertNil(cadence.update(from: position, to: position + SIMD3(246, 0, 0))) }
        XCTAssertEqual(cadence.update(from: position, to: position + SIMD3(246, 0, 0)), 1)
    }

    func testEveryMapStepPairResolvesToOriginalEffects() throws {
        let table = try OriginalDialogueAudio.load()
        let archive = try OriginalSoundArchive.load()
        XCTAssertEqual(table.maps.count, 46)
        for map in table.maps {
            let step = try XCTUnwrap(map.footstep)
            for foot in 0...1 { _ = try archive.effect(archiveID: step.archiveID, entryID: step.entryID + foot) }
            if let cue = map.ambient { _ = try archive.effect(archiveID: cue.archiveID, entryID: cue.entryID) }
        }
        XCTAssertEqual(table.maps[1].footstep, .init(archiveID: 16, entryID: 6))
        XCTAssertEqual(table.maps[7].footstep, .init(archiveID: 16, entryID: 0))
    }

    func testAmbienceRequiresSourceRoomAndPersonSlotEvenWithoutVisibleMarker() throws {
        let table = try OriginalDialogueAudio.load()
        var snapshot = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0).snapshot
        snapshot[0xCB0] = 6; snapshot[0xCB1] = 0
        snapshot[0xCB2] = 0xFF
        let present = try OriginalGameState(snapshot: snapshot)
        XCTAssertNil(present.personMarker(3))
        XCTAssertEqual(try table.walkingAmbience(mapID: 6, game: present), .init(archiveID: 12, entryID: 0))
        XCTAssertNil(try table.walkingAmbience(mapID: 5, game: present))
        snapshot[0xCB0] = 7
        XCTAssertNil(try table.walkingAmbience(mapID: 6, game: OriginalGameState(snapshot: snapshot)))
    }
}
