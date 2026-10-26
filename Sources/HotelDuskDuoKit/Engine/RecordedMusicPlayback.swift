import AVFoundation
import Foundation

@MainActor
protocol OriginalMusicOutput: AnyObject {
    var outputVolume: Float { get set }
    var isActive: Bool { get }
    /// Position in the native sequence's time scale, including its introduction.
    var position: TimeInterval { get }
    func seek(to seconds: TimeInterval) throws
    func resume() throws
    func pause()
    func stop()
}

struct RecordedMusicLibrary: Decodable {
    struct Track: Decodable {
        let id: Int
        let symbol: String
        let title: String
        let file: String
        let sha256: String
        let sampleRate: Double
        let frameCount: Int64
        let timeScale: Double
        let offsetSeconds: Double
        let nativeEndSeconds: Double
        let nativeLoopStartSeconds: Double?
        let nativeLoopEndSeconds: Double?
        let loopStartFrame: Int64?
        let loopEndFrame: Int64?

        func nativePhase(_ seconds: TimeInterval) -> TimeInterval {
            guard let start = nativeLoopStartSeconds, let end = nativeLoopEndSeconds, seconds >= end else {
                return max(0, seconds)
            }
            return start + (seconds - start).truncatingRemainder(dividingBy: end - start)
        }

        func recordingFrame(for seconds: TimeInterval) -> Int64 {
            guard seconds > 0 else { return 0 }
            let phase = nativePhase(seconds)
            var frame = Int64(((phase * timeScale + offsetSeconds) * sampleRate).rounded())
            if let start = loopStartFrame, let end = loopEndFrame,
               let nativeEnd = nativeLoopEndSeconds, seconds >= nativeEnd, frame < start {
                frame += end - start
            }
            return max(0, min(frameCount, frame))
        }

        func nativePosition(for frame: Int64) -> TimeInterval {
            max(0, (Double(frame) / sampleRate - offsetSeconds) / timeScale)
        }
    }

    let schemaVersion: Int
    let tracks: [Track]

    static func load() throws -> Self {
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: resource("manifest.json")))
        guard value.schemaVersion == 1, value.tracks.map(\.id) == Array(0..<36),
              value.tracks.allSatisfy({ track in
                  guard track.sampleRate == 44_100, track.frameCount > 0,
                        track.timeScale.isFinite, track.timeScale > 0,
                        track.offsetSeconds.isFinite else { return false }
                  if let start = track.loopStartFrame, let end = track.loopEndFrame,
                     let nativeStart = track.nativeLoopStartSeconds, let nativeEnd = track.nativeLoopEndSeconds {
                      return start >= 0 && end > start && end <= track.frameCount && nativeEnd > nativeStart
                  }
                  return track.loopStartFrame == nil && track.loopEndFrame == nil
                      && track.nativeLoopStartSeconds == nil && track.nativeLoopEndSeconds == nil
              }) else { throw OriginalAudioError.invalidManifest }
        return value
    }

    static func resource(_ name: String) throws -> URL {
        guard let root = Bundle.module.url(forResource: "RecordedMusic", withExtension: nil) else {
            throw OriginalAudioError.missingResource("RecordedMusic")
        }
        return root.appendingPathComponent(name)
    }

    func track(id: Int) throws -> Track {
        guard let track = tracks.first(where: { $0.id == id }) else {
            throw OriginalAudioError.unknownSequence(String(id))
        }
        return track
    }
}

/// Streams the introduction, then repeats decoded PCM before the album fade.
/// Scheduling the loop buffer ahead of playback avoids a timer at the join.
@MainActor
final class RecordedMusicPlayback: OriginalMusicOutput {
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let track: RecordedMusicLibrary.Track
    private let file: AVAudioFile
    private let loop: AVAudioPCMBuffer?
    private let join: AVAudioPCMBuffer?
    private var startingFrame: Int64 = 0
    private var scheduled = false
    private var stopped = false

    var decodedLoopByteCount: Int {
        Int((loop?.frameLength ?? 0) + (join?.frameLength ?? 0)) * 2 * MemoryLayout<Float>.stride
    }

    init(track: RecordedMusicLibrary.Track) throws {
        let url = try RecordedMusicLibrary.resource(track.file)
        guard OriginalAudioLibrary.digest(try Data(contentsOf: url)) == track.sha256 else {
            throw OriginalAudioError.corruptResource(track.file)
        }
        let file = try AVAudioFile(forReading: url)
        guard file.processingFormat.sampleRate == track.sampleRate,
              file.processingFormat.channelCount == 2,
              abs(file.length - track.frameCount) < 2048 else { throw OriginalAudioError.invalidManifest }
        var loop: AVAudioPCMBuffer?
        var join: AVAudioPCMBuffer?
        if let start = track.loopStartFrame, let end = track.loopEndFrame {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                               frameCapacity: AVAudioFrameCount(end - start)) else {
                throw OriginalAudioError.invalidManifest
            }
            file.framePosition = start
            try file.read(into: buffer, frameCount: buffer.frameCapacity)
            guard buffer.frameLength == buffer.frameCapacity else { throw OriginalAudioError.invalidManifest }
            // Blend the last 3 ms toward the samples immediately before the
            // repeat start. This removes a sample-phase click without moving
            // either loop boundary or shortening the musical repeat.
            let count: AVAudioFrameCount = 128
            guard start >= Int64(count), buffer.frameLength > count,
                  let context = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: count),
                  let tail = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: count),
                  let output = buffer.floatChannelData else { throw OriginalAudioError.invalidManifest }
            file.framePosition = start - Int64(count)
            try file.read(into: context, frameCount: count)
            guard context.frameLength == count, let before = context.floatChannelData,
                  let joined = tail.floatChannelData else { throw OriginalAudioError.invalidManifest }
            tail.frameLength = count
            for channel in 0..<2 {
                for index in 0..<Int(count) {
                    let weight = Float(index + 1) / Float(count)
                    let target = Int(buffer.frameLength - count) + index
                    let value = output[channel][target] * (1 - weight) + before[channel][index] * weight
                    output[channel][target] = value
                    joined[channel][index] = value
                }
            }
            loop = buffer
            join = tail
        }
        self.file = file
        self.loop = loop
        self.join = join
        self.track = track
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        engine.prepare()
    }

    var outputVolume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    var recordingFrame: Int64 {
        let rendered: Int64
        if let time = player.lastRenderTime, let cursor = player.playerTime(forNodeTime: time) {
            rendered = Int64(Double(cursor.sampleTime) * track.sampleRate / cursor.sampleRate)
        } else { rendered = 0 }
        let frame = startingFrame + max(0, rendered)
        if let start = track.loopStartFrame, let end = track.loopEndFrame, frame >= end {
            return start + (frame - end) % (end - start)
        }
        return min(file.length, frame)
    }

    var position: TimeInterval { track.nativePosition(for: recordingFrame) }
    var isActive: Bool { !stopped && scheduled && (loop != nil || recordingFrame < file.length) }

    func seek(to seconds: TimeInterval) throws {
        guard seconds.isFinite else { throw OriginalAudioError.invalidCommand }
        let wasPlaying = player.isPlaying
        player.stop()
        startingFrame = min(file.length, track.recordingFrame(for: seconds))
        scheduled = false
        stopped = false
        schedule()
        if wasPlaying { try resume() }
    }

    private func schedule() {
        guard !scheduled else { return }
        let end = track.loopEndFrame ?? file.length
        let segmentEnd = end - Int64(join?.frameLength ?? 0)
        if startingFrame < segmentEnd {
            player.scheduleSegment(file, startingFrame: startingFrame,
                                   frameCount: AVAudioFrameCount(segmentEnd - startingFrame), at: nil)
        }
        if let join, startingFrame < end {
            if startingFrame <= segmentEnd {
                player.scheduleBuffer(join)
            } else if let remainder = AVAudioPCMBuffer(pcmFormat: join.format,
                                                       frameCapacity: AVAudioFrameCount(end - startingFrame)),
                      let input = join.floatChannelData, let output = remainder.floatChannelData {
                remainder.frameLength = remainder.frameCapacity
                for channel in 0..<2 {
                    output[channel].update(from: input[channel] + Int(startingFrame - segmentEnd),
                                           count: Int(remainder.frameLength))
                }
                player.scheduleBuffer(remainder)
            }
        }
        if let loop { player.scheduleBuffer(loop, at: nil, options: .loops) }
        scheduled = true
    }

    func resume() throws {
        schedule()
        if !engine.isRunning { try engine.start() }
        player.play()
        stopped = false
    }

    func pause() { player.pause(); engine.pause() }
    func stop() { player.stop(); engine.stop(); scheduled = false; stopped = true }
}
