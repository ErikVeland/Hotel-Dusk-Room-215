import XCTest
import AVFoundation
import CryptoKit
@testable import HotelDuskDuoKit

@MainActor
final class OriginalAudioTests: XCTestCase {
    func testDialogueAudioUsesOriginalLookupOrderAndStopSemantics() throws {
        let table = try OriginalDialogueAudio.load()
        XCTAssertEqual(try table.command(for: .music(mode: 0, name: "BGM_36")), .startMusic(sequenceID: 35))
        XCTAssertEqual(try table.command(for: .music(mode: 1, name: "BGM_60")), .stopMusic(fadeFrames: 20))
        XCTAssertNil(try table.command(for: .music(mode: 2, name: "BGM_00")))
        XCTAssertEqual(try table.command(for: .sound(code: "000101", mode: 0)), .startEffect(archiveID: 8, entryID: 0))
        XCTAssertEqual(try table.command(for: .sound(code: "000101", mode: 1)),
                       .stopEffect(archiveID: 8, entryID: 0, fadeFrames: 1))
        // The source contains duplicate codes. Its linear lookup uses the first.
        XCTAssertEqual(try table.command(for: .sound(code: "400101", mode: 0)), .startEffect(archiveID: 0, entryID: 0))
        XCTAssertThrowsError(try table.command(for: .sound(code: "unknown", mode: 0)))
        let archive = try OriginalSoundArchive.load()
        for cue in table.sounds { _ = try archive.effect(archiveID: cue.archiveID, entryID: cue.entryID) }
    }

    func testEveryBundledDialogueAudioControlResolves() throws {
        let table = try OriginalDialogueAudio.load()
        let catalog = try OriginalScriptCatalog.bundled()
        var music = 0, sounds = 0
        for name in catalog.programNames {
            let program = try catalog.loadProgram(name)
            let graph = try program.blocks
            for event in graph.tables[2] {
                let records = try graph.operations(forEvent: event.index)
                var index = 0
                while index < records.count {
                    let record = records[index]
                    if record.raw[0] == 4 {
                        let following = index + 1 < records.count ? records[index + 1] : nil
                        let packet = try OriginalDialoguePacket(record: record, following: following, text: program.text)
                        for token in packet.pages.flatMap(\.tokens) {
                            guard case .control(let control) = token.kind else { continue }
                            switch control {
                            case .music: music += 1
                            case .sound: sounds += 1
                            default: continue
                            }
                            XCTAssertNotNil(try table.command(for: control), "\(name) text \(token.textIndex)")
                        }
                    }
                    index += record.raw[1] == 2 ? 2 : 1
                }
            }
        }
        XCTAssertGreaterThan(music, 400)
        XCTAssertGreaterThan(sounds, 600)
    }

    func testDialogueFadeCompletesOnLiveTimer() async throws {
        let audio = AudioController()
        audio.isMuted = true
        let play = try OriginalPlaySession.chapterOne(audio: audio)
        defer { play.stop() }
        let phase = play.runner.phase
        try audio.applyOriginalCommand(.stopMusic(fadeFrames: 20))
        try await Task.sleep(for: .seconds(1))
        XCTAssertNil(audio.playback)
        XCTAssertEqual(play.runner.phase, phase)
    }

    func testWalkingMusicUsesMapTableFlagAndSavedBarSong() throws {
        let table = try OriginalDialogueAudio.load()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        XCTAssertEqual(try table.walkingMusic(mapID: 2, game: game), .startMusic(sequenceID: 17))
        XCTAssertEqual(try table.walkingMusic(mapID: 26, game: game), .startMusic(sequenceID: 33))
        XCTAssertEqual(try table.walkingMusic(mapID: 5, game: game), .startMusic(sequenceID: 31))
        var bytes = game.bytes
        bytes[0x13BC] = 6; bytes[0x13BD] = 0
        game = try OriginalGameState(snapshot: Data(bytes))
        XCTAssertEqual(try table.walkingMusic(mapID: 5, game: game), .startMusic(sequenceID: 6))
        bytes[0x38] |= 0x80 // Original game flag 31, read by 0x020977CC.
        game = try OriginalGameState(snapshot: Data(bytes))
        XCTAssertEqual(try table.walkingMusic(mapID: 8, game: game), .startMusic(sequenceID: 5))
    }

    func testDialogueFadesAdvanceWithoutAdvancingTextAndPauseWithBook() throws {
        let audio = AudioController()
        audio.isMuted = true
        let play = try OriginalPlaySession.chapterOne(audio: audio)
        defer { play.stop() }
        let phase = play.runner.phase
        XCTAssertEqual(audio.currentSequenceID, 35)
        XCTAssertNil(audio.lastError)
        try audio.applyOriginalCommand(.stopMusic(fadeFrames: 20))
        XCTAssertNotNil(audio.playback)
        play.pause()
        for _ in 0..<40 { play.advanceFrame() }
        XCTAssertNotNil(audio.playback, "Closing the book must suspend the fade")
        play.resume()
        for _ in 0..<19 { play.advanceFrame() }
        XCTAssertNotNil(audio.playback)
        play.advanceFrame()
        XCTAssertNil(audio.playback)
        XCTAssertEqual(play.runner.phase, phase, "Audio updates must not advance dialogue or paused puzzles")
    }

    func testEffectErrorsAreReportedAndEndingGameStopsEffectPlayers() throws {
        let audio = AudioController()
        audio.isMuted = true
        defer { audio.stopAll() }
        XCTAssertThrowsError(try audio.playOriginalEffect(archiveID: -1, entryID: 0))
        XCTAssertNotNil(audio.lastError)
        try audio.playOriginalEffect(archiveID: 8, entryID: 0)
        XCTAssertNil(audio.lastError)
        XCTAssertEqual(audio.soundEffectsHistory.last, "SE_SYSTEM_OK")
        audio.stopAll()
        XCTAssertFalse(try audio.applyOriginalCommand(.waitForEffectPlayer(2)))
        XCTAssertNil(audio.currentSequenceID)
    }

    func testSourceLoopsPreserveIntroductionsAndTerminatingMusic() throws {
        let library = try OriginalAudioLibrary.load()
        XCTAssertEqual(library.sequences.count, 36)
        XCTAssertEqual(library.sourceSDAT_SHA256, "e409838b723198acf3e3b292ce17501ce711ea4c632effbd5547ddf355812891")
        let terminating = library.sequences.filter { $0.tracks.allSatisfy { $0.loop == nil } }
        XCTAssertEqual(terminating.map(\.symbol), ["SEQ_BGM_02", "SEQ_BGM_05", "SEQ_BGM_27"])
        let intro = library.sequences[5]
        XCTAssertEqual(intro.tracks.first?.loop?.startTick, 408)
        XCTAssertEqual(intro.tracks.first?.loop?.endTick, 7320)
        XCTAssertEqual(library.sequences[15].tracks.first?.loop?.startTick, 3072)
    }

    func testEveryRecoveredBankReconstructsAndCorruptCacheRepairs() throws {
        let library = try OriginalAudioLibrary.load()
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: cache) }
        for sequence in library.sequences {
            let file = try library.soundBankURL(for: sequence, cacheDirectory: cache)
            let data = try Data(contentsOf: file)
            XCTAssertEqual(data.prefix(4), Data("RIFF".utf8))
            XCTAssertEqual(OriginalAudioLibrary.digest(data), sequence.repairedDLS_SHA256)
            _ = try library.midiURL(for: sequence)
        }
        let sequence = library.sequences[0]
        let file = try library.soundBankURL(for: sequence, cacheDirectory: cache)
        try Data("stale bank".utf8).write(to: file)
        let repaired = try library.soundBankURL(for: sequence, cacheDirectory: cache)
        XCTAssertEqual(OriginalAudioLibrary.digest(try Data(contentsOf: repaired)), sequence.repairedDLS_SHA256)
    }

    func testUnknownCuesNeverCreateSyntheticAudioOrInventTrackTitles() {
        let controller = AudioController()
        XCTAssertEqual(controller.currentBGMTitle, "")
        controller.playSFX(name: "footstep.wav")
        XCTAssertTrue(controller.soundEffectsHistory.isEmpty)
        XCTAssertNotNil(controller.lastError)
        controller.playBGM(title: "Hotel Dusk - Kyle's Theme")
        XCTAssertNil(controller.currentSequenceID)
        XCTAssertEqual(controller.currentBGMTitle, "")
    }

    func testNativeSequencerLoadsOriginalProgramsAndLoopRanges() throws {
        let library = try OriginalAudioLibrary.load()
        for source in library.sequences {
            let playback: OriginalMusicPlayback
            do {
                playback = try OriginalMusicPlayback(library: library, sequence: source)
            } catch {
                XCTFail("Native load failed for \(source.symbol): \(error)")
                throw error
            }
            XCTAssertEqual(playback.sequencer.tracks.count, source.tracks.filter(\.hasMIDIEvents).count)
            XCTAssertEqual(playback.samplers.count, source.tracks.filter(\.hasNotes).count)
            for (track, original) in zip(playback.sequencer.tracks, source.tracks.filter(\.hasMIDIEvents)) {
                XCTAssertEqual(track.isLoopingEnabled, original.loop != nil)
                if let loop = original.loop {
                    XCTAssertEqual(track.loopRange.start, Double(loop.startTick) / 48, accuracy: 0.00001)
                    XCTAssertEqual(track.loopRange.length, Double(loop.endTick - loop.startTick) / 48, accuracy: 0.00001)
                }
            }
            playback.stop()
        }
    }

    func testNativeSequencerRendersOriginalMusicToPCM() throws {
        let library = try OriginalAudioLibrary.load()
        let playback = try OriginalMusicPlayback(library: library, sequence: library.sequences[0])
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        playback.engine.stop()
        try playback.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096))
        try playback.resume()
        defer { playback.stop() }
        var peak: Float = 0
        for _ in 0..<48 {
            let status = try playback.engine.renderOffline(4096, to: buffer)
            XCTAssertEqual(status, .success)
            let channels = try XCTUnwrap(buffer.floatChannelData)
            for channel in 0..<2 {
                for frame in 0..<Int(buffer.frameLength) {
                    let value = channels[channel][frame]
                    XCTAssertTrue(value.isFinite)
                    peak = max(peak, abs(value))
                }
            }
        }
        XCTAssertGreaterThan(peak, 0.001)
        XCTAssertGreaterThan(playback.sequencer.currentPositionInSeconds, 3.9)
    }

    func testNativeSoundArchivePreservesEffectsAndInstrumentLinks() throws {
        let archive = try OriginalSoundArchive.load()
        XCTAssertEqual(archive.sequenceArchives.count, 89)
        XCTAssertEqual(archive.sequenceArchives.flatMap(\.sequences).count, 186)
        XCTAssertEqual(archive.banks.count, 125)
        XCTAssertEqual(archive.players.count, 17)
        let cue = try archive.effect(archiveID: 8, entryID: 0)
        XCTAssertEqual(cue.symbol, "SE_SYSTEM_OK")
        XCTAssertEqual(cue.bankID, 44)
        XCTAssertEqual(cue.playerID, 2)
        XCTAssertEqual(cue.channelPriority, 96)
        let instrument = try XCTUnwrap(archive.instrument(bankID: cue.bankID, program: 0, note: 72))
        XCTAssertEqual(instrument.voice, .pcm(waveArchiveID: 9, waveID: 3))
        XCTAssertEqual(instrument.rootKey, 60)
        XCTAssertEqual(instrument.attack, 127)
        XCTAssertEqual(instrument.release, 125)
        XCTAssertNil(try archive.instrument(bankID: 44, program: 8, note: 60))
        for bank in archive.banks {
            for program in 0..<(try archive.instrumentCount(bankID: bank.id)) {
                for note in 0...127 {
                    _ = try archive.instrument(bankID: bank.id, program: program, note: note)
                }
            }
        }
        for source in archive.sequenceArchives {
            let events = try archive.effectEventData(archiveID: source.id)
            for cue in source.sequences { XCTAssertTrue(events.indices.contains(cue.eventOffset)) }
        }
    }

    func testAllOriginalWaveSamplesMatchIndependentADPCMRecovery() throws {
        let archive = try OriginalSoundArchive.load()
        var digest = SHA256()
        var sampleCount = 0
        var waveCount = 0
        for source in archive.waveArchives {
            for wave in source.waves {
                let sample = try archive.sample(archiveID: source.id, waveID: wave.id)
                XCTAssertFalse(sample.pcm.isEmpty)
                XCTAssertEqual(sample.loopStart != nil, wave.loop)
                let littleEndian = sample.pcm.map(\.littleEndian)
                littleEndian.withUnsafeBytes { digest.update(bufferPointer: $0) }
                sampleCount += sample.pcm.count
                waveCount += 1
            }
        }
        XCTAssertEqual(waveCount, 291)
        XCTAssertEqual(sampleCount, 11_952_672)
        let hex = digest.finalize().map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, "3263e2c1023852a50bcd94fb95702524b0f9968796b66e39d53c0b03bf4c99cc")
        let saturation = try OriginalSoundArchive.decodeADPCM(Data([0, 128, 88, 0, 255]))
        XCTAssertEqual(saturation, [-32767, -32767])
        XCTAssertThrowsError(try OriginalSoundArchive.decodeADPCM(Data([0, 0, 89, 0])))
    }

    func testRecoveredCinematicAudioCommandArguments() throws {
        XCTAssertEqual(try OriginalAudioCommand.decode(handlerAddress: 0x020A5140, fields: [0, 8]),
                       .startMusic(sequenceID: 8))
        XCTAssertEqual(try OriginalAudioCommand.decode(handlerAddress: 0x020A5140, fields: [1, 48]),
                       .stopMusic(fadeFrames: 48))
        XCTAssertEqual(try OriginalAudioCommand.decode(handlerAddress: 0x020A51F8, fields: [0, 3, 8]),
                       .startEffect(archiveID: 8, entryID: 3))
        XCTAssertEqual(try OriginalAudioCommand.decode(handlerAddress: 0x020A51F8, fields: [2, -1, 100, 30, 8]),
                       .effectVolume(archiveID: 8, entryID: -1, target: 100, frames: 30))
        XCTAssertEqual(try OriginalAudioCommand.decode(handlerAddress: 0x020A51F8, fields: [5, 15]),
                       .waitForEffectPlayer(15))
        XCTAssertThrowsError(try OriginalAudioCommand.decode(handlerAddress: 0x020A5140, fields: [4, 100]))
        XCTAssertThrowsError(try OriginalAudioCommand.decode(handlerAddress: 0, fields: [0, 0]))
    }

    func testSourceEnvelopeRandomAndVolumeRules() throws {
        let driver = try OriginalSoundDriver.load()
        XCTAssertEqual(driver.initialEnvelope, -92_544)
        XCTAssertEqual(driver.driverAlarmInterval, 2728)
        XCTAssertEqual(driver.attackMultiplier(0), 255)
        XCTAssertEqual(driver.attackMultiplier(127), 0)
        XCTAssertEqual(driver.decayReleaseRate(125), 7680)
        XCTAssertEqual(driver.decayReleaseRate(126), 15360)
        XCTAssertEqual(driver.decayReleaseRate(127), 65535)
        XCTAssertEqual(driver.linearGain(volume: 100), 0.616595, accuracy: 0.000001)
        var envelope = OriginalSoundDriver.Envelope(driver: driver, attack: 127, decay: 127, sustain: 127, release: 125)
        envelope.advance()
        XCTAssertEqual(envelope.level, 0)
        XCTAssertEqual(envelope.stage, .decay)
        envelope.advance()
        XCTAssertEqual(envelope.stage, .sustain)
        envelope.release()
        envelope.advance()
        XCTAssertEqual(envelope.attenuation, -60)
        let saved = try JSONEncoder().encode(envelope)
        XCTAssertEqual(try JSONDecoder().decode(OriginalSoundDriver.Envelope.self, from: saved), envelope)
        var random = OriginalSoundDriver.RandomState(driver: driver)
        XCTAssertEqual(random.next(), 0x7543)
        XCTAssertEqual(random.next(), 0xCD30)
    }

    func testOriginalZeroDurationWaitAndRandomEffectDoNotRepeatRecentPitches() throws {
        let driver = try OriginalSoundDriver.load()
        var shared = OriginalSequenceMachine.SharedState(driver: driver)
        var machine = try OriginalSequenceMachine(data: Data([60, 100, 0, 0xFF]))
        XCTAssertEqual(try machine.advanceTick(shared: &shared), [.note(track: 0, key: 60, velocity: 100, duration: -1)])
        XCTAssertTrue(try machine.advanceTick(voiceCounts: [0: 1], shared: &shared).isEmpty)
        XCTAssertTrue(machine.hasActiveTracks)
        XCTAssertEqual(try machine.advanceTick(shared: &shared), [.endTrack(0)])
        XCTAssertFalse(machine.hasActiveTracks)

        let archive = try OriginalSoundArchive.load()
        let events = try archive.effectEventData(archiveID: 86)
        var recent: [Int] = []
        for index in 0..<32 {
            let cue = try archive.effect(archiveID: 86, entryID: index % 2)
            var effect = try OriginalSequenceMachine(data: events, startOffset: cue.eventOffset)
            let emitted = try effect.advanceTick(shared: &shared)
            let keys = emitted.compactMap { event -> Int? in
                if case let .note(_, key, _, _) = event { return key }
                return nil
            }
            let key = try XCTUnwrap(keys.first)
            XCTAssertEqual(keys.count, 1)
            XCTAssertTrue((60...67).contains(key))
            XCTAssertFalse(recent.contains(key))
            recent.append(key)
            if recent.count > 4 { recent.removeFirst() }
        }
    }

    func testEveryOriginalEffectSequenceExecutesInNativeInterpreter() throws {
        let archive = try OriginalSoundArchive.load()
        let driver = try OriginalSoundDriver.load()
        var shared = OriginalSequenceMachine.SharedState(driver: driver)
        var noteCount = 0
        for source in archive.sequenceArchives {
            let data = try archive.effectEventData(archiveID: source.id)
            for cue in source.sequences {
                var sequence = try OriginalSequenceMachine(data: data, startOffset: cue.eventOffset)
                do {
                    for _ in 0..<1_920 where sequence.hasActiveTracks {
                        let events = try sequence.advanceTick(shared: &shared)
                        noteCount += events.filter { if case .note = $0 { return true }; return false }.count
                        _ = shared.random.next()
                    }
                } catch {
                    XCTFail("Original effect \(source.symbol):\(cue.symbol) failed: \(error)")
                    throw error
                }
            }
        }
        XCTAssertGreaterThan(noteCount, 500)
    }

    func testNativeEffectPCMAndStateRestorationPreserveSampleAndEnvelopePhase() throws {
        let archive = try OriginalSoundArchive.load()
        let driver = try OriginalSoundDriver.load()
        let renderer = try OriginalEffectRenderer(archive: archive, driver: driver, archiveID: 8, entryID: 0)
        let first = try renderer.render(frameCount: 4096)
        XCTAssertGreaterThan(first.left.map(abs).max() ?? 0, 0.01)
        let saved = try JSONEncoder().encode(renderer.state)
        let expected = try renderer.render(frameCount: 4096)
        let restored = try OriginalEffectRenderer(archive: archive, driver: driver, archiveID: 8, entryID: 0)
        try restored.restore(JSONDecoder().decode(OriginalEffectRenderer.State.self, from: saved))
        let actual = try restored.render(frameCount: 4096)
        XCTAssertEqual(actual.left, expected.left)
        XCTAssertEqual(actual.right, expected.right)
        _ = try renderer.render(frameCount: 48_000)
        XCTAssertTrue(renderer.isFinished)

        if let directory = ProcessInfo.processInfo.environment["HOTEL_AUDIO_CAPTURE_DIRECTORY"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            for entry in [0, 3] {
                let source = try OriginalEffectRenderer(archive: archive, driver: driver, archiveID: 8, entryID: entry)
                let pcm = try source.render(frameCount: 96_000)
                var output = Data(capacity: 96_000 * 4)
                for frame in pcm.left.indices {
                    for sample in [pcm.left[frame], pcm.right[frame]] {
                        var value = Int16(max(-32768, min(32767, Int((sample * 32768).rounded())))).littleEndian
                        withUnsafeBytes(of: &value) { output.append(contentsOf: $0) }
                    }
                }
                try output.write(to: URL(fileURLWithPath: directory).appendingPathComponent("native-ssar8-entry\(entry).s16le"))
            }
        }
    }
}
