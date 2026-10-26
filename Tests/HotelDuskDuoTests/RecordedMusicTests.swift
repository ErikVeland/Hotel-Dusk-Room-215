import AVFoundation
import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class RecordedMusicTests: XCTestCase {
    private final class SimulatedMusicOutput: OriginalMusicOutput {
        var outputVolume: Float = 1
        private var storedPosition: TimeInterval = 0
        private var resumedAt: TimeInterval?
        private(set) var isActive = false

        var position: TimeInterval {
            storedPosition + (resumedAt.map { ProcessInfo.processInfo.systemUptime - $0 } ?? 0)
        }

        func seek(to seconds: TimeInterval) throws {
            storedPosition = seconds
            if isActive { resumedAt = ProcessInfo.processInfo.systemUptime }
        }

        func resume() throws {
            guard !isActive else { return }
            resumedAt = ProcessInfo.processInfo.systemUptime
            isActive = true
        }

        func pause() {
            guard isActive else { return }
            storedPosition = position
            resumedAt = nil
            isActive = false
        }

        func stop() {
            pause()
            storedPosition = 0
        }
    }

    func testSwitchReusesOnlyTheCurrentCuesAlternateBackend() async throws {
        let audio = AudioController(musicOutputFactory: { _, _, _ in SimulatedMusicOutput() })
        try audio.playOriginalSequence(id: 17)
        let native = try XCTUnwrap(audio.musicOutput)
        XCTAssertTrue(audio.selectMusicSource(.recordings))
        let recorded = try XCTUnwrap(audio.musicOutput)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(audio.selectMusicSource(.native))
        XCTAssertTrue(audio.musicOutput === native)
        // Rapid switches can finish and reuse the pending crossfade too.
        XCTAssertTrue(audio.selectMusicSource(.recordings))
        XCTAssertTrue(audio.musicOutput === recorded)
        try audio.playOriginalSequence(id: 5)
        XCTAssertFalse(native.isActive)
        XCTAssertFalse(recorded.isActive)
        audio.stopAll()
        XCTAssertNil(audio.musicOutput)
    }

    func testControllerAppliesMeasuredLevelBalanceForBothSourcesWithoutPlayingAudio() async throws {
        let table = try MusicSourceBalance.load()
        XCTAssertEqual(table.tracks.count, 36)
        XCTAssertTrue(table.tracks.allSatisfy { $0.nativeGain < $0.recordedGain })
        var outputs: [SimulatedMusicOutput] = []
        let audio = AudioController { _, _, _ in
            let output = SimulatedMusicOutput()
            outputs.append(output)
            return output
        }
        audio.volume = 1
        defer { audio.stopAll() }
        try audio.playOriginalSequence(id: 17)
        let sequence = try XCTUnwrap(OriginalAudioLibrary.load().sequences.first { $0.id == 17 })
        let baseGain = try OriginalSoundDriver.load().linearGain(volume: sequence.volume)
        XCTAssertEqual(audio.currentOutputGain, table.tracks[17].nativeGain, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(audio.musicOutput?.outputVolume), baseGain * table.tracks[17].nativeGain, accuracy: 0.0001)
        XCTAssertTrue(audio.selectMusicSource(.recordings))
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(audio.currentOutputGain, table.tracks[17].recordedGain, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(audio.musicOutput?.outputVolume), baseGain * table.tracks[17].recordedGain, accuracy: 0.0001)
        XCTAssertEqual(outputs.count, 2)
    }

    func testEveryRecordingDecodesAndMatchesNativeLoopTiming() throws {
        try AudioTestSupport.requireAppleSampler()
        let recordings = try RecordedMusicLibrary.load()
        let native = try OriginalAudioLibrary.load()
        XCTAssertEqual(recordings.tracks.filter { $0.loopStartFrame == nil }.map(\.id), [1, 4, 26])
        for track in recordings.tracks {
            let output = try RecordedMusicPlayback(track: track)
            defer { output.stop() }
            let original = try OriginalMusicPlayback(library: native, sequence: native.sequences[track.id])
            defer { original.stop() }
            if let loop = native.sequences[track.id].tracks.compactMap(\.loop).first {
                XCTAssertEqual(try XCTUnwrap(track.nativeLoopStartSeconds),
                               original.sequencer.seconds(forBeats: Double(loop.startTick) / 48), accuracy: 0.0001)
                XCTAssertEqual(try XCTUnwrap(track.nativeLoopEndSeconds),
                               original.sequencer.seconds(forBeats: Double(loop.endTick) / 48), accuracy: 0.0001)
            }
            XCTAssertEqual(track.symbol, native.sequences[track.id].symbol)
        }
    }

    func testRecordingPCMContinuesAcrossLoopWithoutPlayingAlbumFade() throws {
        try AudioTestSupport.requireAudioFilePlayer()
        let track = try RecordedMusicLibrary.load().track(id: 0)
        let output = try RecordedMusicPlayback(track: track)
        defer { output.stop() }
        let end = try XCTUnwrap(track.loopEndFrame)
        let start = try XCTUnwrap(track.loopStartFrame)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        output.engine.stop()
        try output.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try output.seek(to: track.nativePosition(for: end - 4410))
        try output.resume()
        let pcm = try render(output.engine, frames: 22_050)
        XCTAssertTrue(pcm.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(pcm.map(abs).max() ?? 0, 0.01)
        XCTAssertGreaterThan(pcm[5000..<10000].map(abs).max() ?? 0, 0.01)
        XCTAssertEqual(output.recordingFrame, start + 17_640, accuracy: 2)
        XCTAssertTrue(output.isActive)
        // A large discontinuity at the join would create a click.
        let jump = abs(pcm[4410] - pcm[4409])
        XCTAssertLessThan(jump, 0.1)
    }

    func testLiveSwitchKeepsPositionAndFinishesCrossfade() async throws {
        var outputs: [SimulatedMusicOutput] = []
        let audio = AudioController(musicOutputFactory: { _, _, _ in
            let output = SimulatedMusicOutput()
            outputs.append(output)
            return output
        })
        defer { audio.stopAll() }
        try audio.playOriginalSequence(id: 17)
        try audio.musicOutput?.seek(to: 12)
        let before = try XCTUnwrap(audio.musicOutput?.position)
        let sequence = try XCTUnwrap(OriginalAudioLibrary.load().sequences.first { $0.id == 17 })
        let baseGain = try OriginalSoundDriver.load().linearGain(volume: sequence.volume)
        XCTAssertTrue(audio.selectMusicSource(.recordings), audio.lastError ?? "Switch failed")
        XCTAssertEqual(audio.musicSource, .recordings)
        XCTAssertTrue(audio.musicOutput is SimulatedMusicOutput)
        XCTAssertEqual(audio.currentSequenceID, 17)
        XCTAssertEqual(try XCTUnwrap(audio.musicOutput?.position), before, accuracy: 0.15)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(try XCTUnwrap(audio.musicOutput?.outputVolume),
                       0.8 * baseGain * audio.currentOutputGain, accuracy: 0.0001)
        XCTAssertEqual(outputs[0].outputVolume, 0, accuracy: 0.0001)
        XCTAssertTrue(audio.selectMusicSource(.native), audio.lastError ?? "Switch failed")
        XCTAssertEqual(audio.musicSource, .native)
        XCTAssertTrue(audio.musicOutput is SimulatedMusicOutput)
        XCTAssertEqual(try XCTUnwrap(audio.musicOutput?.position), before + 0.25, accuracy: 0.1)
    }

    func testPausedSwitchRetainsPositionAndPendingMusicFade() throws {
        let audio = AudioController(musicOutputFactory: { _, _, _ in SimulatedMusicOutput() })
        defer { audio.stopAll() }
        try audio.playOriginalSequence(id: 5)
        try audio.musicOutput?.seek(to: 12)
        audio.pause()
        let before = try XCTUnwrap(audio.musicOutput?.position)
        try audio.applyOriginalCommand(.musicVolume(target: 30, frames: 10))
        XCTAssertTrue(audio.selectMusicSource(.recordings), audio.lastError ?? "Switch failed")
        let recorded = try XCTUnwrap(audio.musicOutput as? SimulatedMusicOutput)
        XCTAssertFalse(recorded.isActive)
        XCTAssertEqual(recorded.position, before, accuracy: 0.001)
        XCTAssertTrue(audio.selectMusicSource(.native), audio.lastError ?? "Switch failed")
        XCTAssertEqual(try XCTUnwrap(audio.musicOutput?.position), before, accuracy: 0.001)
        audio.resume()
        for _ in 0..<10 { audio.advanceOriginalFrame() }
        XCTAssertEqual(audio.currentSequenceID, 5)
        XCTAssertTrue(audio.selectMusicSource(.recordings))
        try audio.applyOriginalCommand(.stopMusic(fadeFrames: 10))
        audio.pause()
        XCTAssertTrue(audio.selectMusicSource(.native))
        audio.resume()
        for _ in 0..<10 { audio.advanceOriginalFrame() }
        XCTAssertNil(audio.musicOutput)
    }

    func testSourcePreferencePersistsIndependentlyOfGameSaves() throws {
        let name = "RecordedMusicTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let factory: AudioController.MusicOutputFactory = { _, _, _ in SimulatedMusicOutput() }
        let first = AudioController(preferences: defaults, musicOutputFactory: factory)
        XCTAssertEqual(first.musicSource, .native)
        XCTAssertTrue(first.selectMusicSource(.recordings))
        let restored = AudioController(preferences: defaults, musicOutputFactory: factory)
        XCTAssertEqual(restored.musicSource, .recordings)
        restored.isMuted = true
        defer { restored.stopAll() }
        try restored.playOriginalSequence(id: 35)
        XCTAssertTrue(restored.musicOutput is SimulatedMusicOutput)
        XCTAssertEqual(restored.currentSequenceID, 35)
    }

    func testTransportMapsIntroductionsAndManyLoopsInBothDirections() throws {
        let table = try RecordedMusicLibrary.load()
        for track in table.tracks {
            guard let start = track.nativeLoopStartSeconds, let end = track.nativeLoopEndSeconds else { continue }
            let period = end - start
            for position in [0.5, start + 0.1, end - 0.1, end + 0.1, end + 12 * period + 0.5] {
                let frame = track.recordingFrame(for: position)
                let returned = track.nativePhase(track.nativePosition(for: frame))
                XCTAssertEqual(returned, track.nativePhase(position), accuracy: 2 / 44_100, track.symbol)
            }
        }
    }

    func testTerminatingRecordingsEndInsteadOfLooping() throws {
        try AudioTestSupport.requireAudioFilePlayer()
        let table = try RecordedMusicLibrary.load()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        for id in [1, 4, 26] {
            let track = try table.track(id: id)
            let output = try RecordedMusicPlayback(track: track)
            defer { output.stop() }
            output.engine.stop()
            try output.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
            try output.seek(to: track.nativePosition(for: track.frameCount - 3000))
            try output.resume()
            _ = try render(output.engine, frames: 8192)
            XCTAssertFalse(output.isActive, track.symbol)
        }
    }

    private func render(_ engine: AVAudioEngine, frames: Int) throws -> [Float] {
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096))
        var result: [Float] = []
        while result.count < frames {
            let count = AVAudioFrameCount(min(4096, frames - result.count))
            XCTAssertEqual(try engine.renderOffline(count, to: buffer), .success)
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            result.append(contentsOf: UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
        }
        return result
    }
}
