import AVFoundation
import Accelerate
import Darwin
import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class AudioProfilingTests: XCTestCase {
    private struct Measurement: Codable {
        let rmsDBFS: Double
        let peakDBFS: Double
        let samples: Int
    }
    private struct Track: Codable {
        let id: Int
        let nativePreparationMS: Double
        let recordedPreparationMS: Double
        let decodedLoopBytes: Int
        let processFootprintBeforeBytes: UInt64?
        let processFootprintPreparedBytes: UInt64?
        let unbalancedNative: Measurement
        let unbalancedRecorded: Measurement
        let native: Measurement
        let recorded: Measurement
        var recordedMinusNativeDB: Double { unbalancedRecorded.rmsDBFS - unbalancedNative.rmsDBFS }
        var calibratedRecordedMinusNativeDB: Double { recorded.rmsDBFS - native.rmsDBFS }
    }
    private struct Report: Encodable {
        let schemaVersion = 1
        let note = "One complete native introduction and loop, or the terminating cue duration. unbalancedNative and unbalancedRecorded include sequence and default app volume before per-source calibration; native and recorded include calibration. Both RMS differences are measurements, not pass criteria: RMS does not establish perceived loudness or fidelity. Preparation includes checksum, decoding and engine setup. PCM bytes exclude engine, sampler and decoder allocations."
        let tracks: [Track]
        let switchToRecordingMS: [Double]
        let switchToNativeMS: [Double]
        let switchNote = "First switch includes preparation; subsequent switches reuse the current cue's alternate backend. Timings exclude the asynchronous 150 ms crossfade."
        let recordedMinusNativeDB: [Double]
        let calibratedRecordedMinusNativeDB: [Double]
        let processFootprintAfterSwitchesBytes: UInt64?
    }

    func testBothBackendsProduceFiniteAudioAndRecordPreparationCost() throws {
        try AudioTestSupport.requireAppleSampler()
        let native = try OriginalAudioLibrary.load()
        let recorded = try RecordedMusicLibrary.load()
        let balance = try MusicSourceBalance.load()
        let driver = try OriginalSoundDriver.load()
        let audio = AudioController()
        audio.isMuted = true
        defer { audio.stopAll() }
        try audio.playOriginalSequence(id: 17)
        var toRecording: [Double] = [], toNative: [Double] = []
        for _ in 0..<3 {
            var start = CFAbsoluteTimeGetCurrent()
            XCTAssertTrue(audio.selectMusicSource(.recordings), audio.lastError ?? "Switch failed")
            toRecording.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
            start = CFAbsoluteTimeGetCurrent()
            XCTAssertTrue(audio.selectMusicSource(.native), audio.lastError ?? "Switch failed")
            toNative.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
        }
        var tracks: [Track] = []
        for sequence in native.sequences {
            tracks.append(try profile(sequence, library: native, recordings: recorded,
                                      balance: balance, driver: driver))
        }
        let report = Report(tracks: tracks, switchToRecordingMS: toRecording, switchToNativeMS: toNative,
                            recordedMinusNativeDB: tracks.map(\.recordedMinusNativeDB),
                            calibratedRecordedMinusNativeDB: tracks.map(\.calibratedRecordedMinusNativeDB),
                            processFootprintAfterSwitchesBytes: footprint())
        if let destination = ProcessInfo.processInfo.environment["HOTEL_DUSK_AUDIO_PROFILE"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: URL(fileURLWithPath: destination), options: .atomic)
        }
    }

    private func profile(_ sequence: OriginalAudioLibrary.Sequence,
                         library: OriginalAudioLibrary,
                         recordings: RecordedMusicLibrary,
                         balance: MusicSourceBalance,
                         driver: OriginalSoundDriver) throws -> Track {
        let recordingTrack = try recordings.track(id: sequence.id)
        let beforeBytes = footprint()
        var start = CFAbsoluteTimeGetCurrent()
        let original = try OriginalMusicPlayback(library: library, sequence: sequence)
        let nativeMS = (CFAbsoluteTimeGetCurrent() - start) * 1000
        start = CFAbsoluteTimeGetCurrent()
        let recording = try RecordedMusicPlayback(track: recordingTrack)
        let recordedMS = (CFAbsoluteTimeGetCurrent() - start) * 1000
        defer { original.stop(); recording.stop() }
        let preparedBytes = footprint()
        let seconds = recordingTrack.nativeLoopEndSeconds ?? recordingTrack.nativeEndSeconds
        let baseGain = driver.linearGain(volume: sequence.volume) * 0.8
        let sourceBalance = try XCTUnwrap(balance.tracks.first { $0.id == sequence.id })
        let rawNative = try measure(original, engine: original.engine, seconds: seconds, gain: baseGain)
        let rawRecorded = try measure(recording, engine: recording.engine, seconds: seconds, gain: baseGain)
        let native = try measure(original, engine: original.engine, seconds: seconds,
                                 gain: baseGain * sourceBalance.nativeGain)
        let recorded = try measure(recording, engine: recording.engine, seconds: seconds,
                                   gain: baseGain * sourceBalance.recordedGain)
        XCTAssertTrue(rawNative.rmsDBFS.isFinite, sequence.symbol)
        XCTAssertTrue(rawRecorded.rmsDBFS.isFinite, sequence.symbol)
        XCTAssertTrue(native.rmsDBFS.isFinite, sequence.symbol)
        XCTAssertTrue(recorded.rmsDBFS.isFinite, sequence.symbol)
        XCTAssertGreaterThan(rawNative.peakDBFS, -100, sequence.symbol)
        XCTAssertGreaterThan(rawRecorded.peakDBFS, -100, sequence.symbol)
        XCTAssertLessThan(native.peakDBFS, 0, "Calibrated native output must stay below full scale: \(sequence.symbol)")
        XCTAssertLessThan(recorded.peakDBFS, 0, "Calibrated recording output must stay below full scale: \(sequence.symbol)")
        return .init(id: sequence.id, nativePreparationMS: nativeMS, recordedPreparationMS: recordedMS,
                     decodedLoopBytes: recording.decodedLoopByteCount, processFootprintBeforeBytes: beforeBytes,
                     processFootprintPreparedBytes: preparedBytes, unbalancedNative: rawNative,
                     unbalancedRecorded: rawRecorded, native: native, recorded: recorded)
    }

    private func footprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? info.phys_footprint : nil
    }

    private func measure(_ output: any OriginalMusicOutput, engine: AVAudioEngine,
                         seconds: Double, gain: Float) throws -> Measurement {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        engine.stop()
        if !engine.isInManualRenderingMode {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        }
        output.outputVolume = gain
        try output.seek(to: 0)
        try output.resume()
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096))
        var frames = Int(seconds * 48_000), count = 0
        var squares = 0.0, peak = 0.0
        while frames > 0 {
            let length = AVAudioFrameCount(min(frames, 4096))
            XCTAssertEqual(try engine.renderOffline(length, to: buffer), .success)
            let channels = try XCTUnwrap(buffer.floatChannelData)
            for channel in 0..<2 {
                var rms: Float = 0, maximum: Float = 0
                vDSP_rmsqv(channels[channel], 1, &rms, vDSP_Length(buffer.frameLength))
                vDSP_maxmgv(channels[channel], 1, &maximum, vDSP_Length(buffer.frameLength))
                guard rms.isFinite, maximum.isFinite else { throw OriginalAudioError.invalidSequence }
                squares += Double(rms) * Double(rms) * Double(buffer.frameLength)
                peak = max(peak, Double(maximum)); count += Int(buffer.frameLength)
            }
            frames -= Int(buffer.frameLength)
        }
        output.pause()
        return .init(rmsDBFS: 10 * log10(max(1e-20, squares / Double(count))),
                     peakDBFS: 20 * log10(max(1e-10, peak)), samples: count)
    }
}
