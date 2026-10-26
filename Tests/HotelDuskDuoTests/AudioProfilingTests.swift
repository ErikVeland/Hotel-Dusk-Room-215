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
        let native: Measurement
        let recorded: Measurement
        var recordedMinusNativeDB: Double { recorded.rmsDBFS - native.rmsDBFS }
    }
    private struct Report: Encodable {
        let schemaVersion = 1
        let note = "One complete native introduction and loop, or the terminating cue duration. RMS is a level comparison, not perceptual loudness or fidelity. Preparation includes checksum, decoding and engine setup. PCM bytes exclude engine, sampler and decoder allocations."
        let tracks: [Track]
        let switchToRecordingMS: [Double]
        let switchToNativeMS: [Double]
        let switchNote = "First switch includes preparation; subsequent switches reuse the current cue's alternate backend. Timings exclude the asynchronous 150 ms crossfade."
        let recordedMinusNativeDB: [Double]
        let processFootprintAfterSwitchesBytes: UInt64?
    }

    func testBothBackendsProduceFiniteAudioAndRecordPreparationCost() throws {
        let native = try OriginalAudioLibrary.load()
        let recorded = try RecordedMusicLibrary.load()
        let driver = try OriginalSoundDriver.load()
        var tracks: [Track] = []
        for sequence in native.sequences {
            let track = try recorded.track(id: sequence.id)
            let beforeBytes = footprint()
            var start = CFAbsoluteTimeGetCurrent()
            let original = try OriginalMusicPlayback(library: native, sequence: sequence)
            let nativeMS = (CFAbsoluteTimeGetCurrent() - start) * 1000
            start = CFAbsoluteTimeGetCurrent()
            let recording = try RecordedMusicPlayback(track: track)
            let recordedMS = (CFAbsoluteTimeGetCurrent() - start) * 1000
            let preparedBytes = footprint()
            defer { original.stop(); recording.stop() }
            let seconds = track.nativeLoopEndSeconds ?? track.nativeEndSeconds
            let gain = driver.linearGain(volume: sequence.volume)
            let left = try measure(original, engine: original.engine, seconds: seconds, gain: gain)
            let right = try measure(recording, engine: recording.engine, seconds: seconds, gain: gain)
            XCTAssertTrue(left.rmsDBFS.isFinite, sequence.symbol)
            XCTAssertTrue(right.rmsDBFS.isFinite, sequence.symbol)
            XCTAssertGreaterThan(left.peakDBFS, -100, sequence.symbol)
            XCTAssertGreaterThan(right.peakDBFS, -100, sequence.symbol)
            tracks.append(.init(id: sequence.id, nativePreparationMS: nativeMS, recordedPreparationMS: recordedMS,
                                decodedLoopBytes: recording.decodedLoopByteCount, processFootprintBeforeBytes: beforeBytes,
                                processFootprintPreparedBytes: preparedBytes, native: left, recorded: right))
        }
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
        let report = Report(tracks: tracks, switchToRecordingMS: toRecording, switchToNativeMS: toNative,
                            recordedMinusNativeDB: tracks.map(\.recordedMinusNativeDB), processFootprintAfterSwitchesBytes: footprint())
        if let destination = ProcessInfo.processInfo.environment["HOTEL_DUSK_AUDIO_PROFILE"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: URL(fileURLWithPath: destination), options: .atomic)
        }
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
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
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
