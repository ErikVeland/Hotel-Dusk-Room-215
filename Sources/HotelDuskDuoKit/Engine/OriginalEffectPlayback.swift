import Foundation
import AVFoundation

/// Serializes effect state against Core Audio's render callback.
/// Original player IDs select the playback slots; caller names never select samples.
private final class OriginalEffectRenderBox: @unchecked Sendable {
    struct Playing {
        let archiveID: Int
        let entryID: Int
        let renderer: OriginalEffectRenderer
        var ramp: OriginalAudioRamp?
    }
    private let lock = NSLock()
    private var players: [Int: Playing] = [:]
    private var shared: OriginalSequenceMachine.SharedState
    private(set) var error: Error?

    init(driver: OriginalSoundDriver) { shared = .init(driver: driver) }

    func play(_ renderer: OriginalEffectRenderer, playerID: Int) {
        lock.withLock {
            renderer.setSharedState(shared)
            players[playerID] = Playing(archiveID: renderer.archiveID, entryID: renderer.entryID, renderer: renderer)
        }
    }

    func isPlaying(playerID: Int) -> Bool {
        lock.withLock { players[playerID].map { $0.renderer.isSequenceActive || ($0.ramp?.stopsAtEnd ?? false) } ?? false }
    }

    func matches(playerID: Int, archiveID: Int, entryID: Int) -> Bool {
        lock.withLock {
            players[playerID].map { $0.archiveID == archiveID && $0.entryID == entryID && $0.renderer.isSequenceActive } ?? false
        }
    }

    func stop(playerID: Int?, frames: Int) {
        lock.withLock {
            for id in Array(players.keys) where playerID == nil || playerID == id {
                guard var playing = players[id] else { continue }
                if frames <= 0 { playing.renderer.stop(); playing.ramp = nil }
                else { playing.ramp = .init(start: playing.renderer.state.playerVolume << 8, target: 0, frames: frames, stopsAtEnd: true) }
                players[id] = playing
            }
        }
    }

    func volume(playerID: Int?, target: Int, frames: Int) {
        lock.withLock {
            for id in Array(players.keys) where playerID == nil || playerID == id {
                guard var playing = players[id], playing.ramp?.stopsAtEnd != true else { continue }
                if frames <= 0 { playing.renderer.setPlayerVolume(target); playing.ramp = nil }
                else { playing.ramp = .init(start: playing.renderer.state.playerVolume << 8, target: min(127, max(0, target)) << 8, frames: frames, stopsAtEnd: false) }
                players[id] = playing
            }
        }
    }

    func pitch(playerID: Int, target: Int) {
        lock.withLock { players[playerID]?.renderer.setPitchForFirstActiveTrack(target) }
    }

    func advanceFrame() {
        lock.withLock {
            for id in Array(players.keys) {
                guard var playing = players[id], var ramp = playing.ramp else { continue }
                ramp.advance()
                playing.renderer.setPlayerVolume(ramp.value >> 8)
                if ramp.isComplete {
                    if ramp.stopsAtEnd { playing.renderer.stop() }
                    playing.ramp = nil
                } else { playing.ramp = ramp }
                players[id] = playing
            }
        }
    }

    func render(frames: Int, buffers: UnsafeMutableAudioBufferListPointer) -> OSStatus {
        lock.withLock {
            guard buffers.count == 2, let l = buffers[0].mData, let r = buffers[1].mData else { return -50 }
            let left = l.assumingMemoryBound(to: Float.self)
            let right = r.assumingMemoryBound(to: Float.self)
            left.initialize(repeating: 0, count: frames)
            right.initialize(repeating: 0, count: frames)
            do {
                for id in players.keys.sorted() {
                    guard let playing = players[id] else { continue }
                    playing.renderer.setSharedState(shared)
                    let pcm = try playing.renderer.render(frameCount: frames)
                    shared = playing.renderer.state.shared
                    for frame in 0..<frames {
                        left[frame] += pcm.left[frame]
                        right[frame] += pcm.right[frame]
                    }
                    if playing.renderer.isFinished { players[id] = nil }
                }
                return noErr
            } catch {
                self.error = error
                players.removeAll()
                left.initialize(repeating: 0, count: frames)
                right.initialize(repeating: 0, count: frames)
                return noErr
            }
        }
    }
}

@MainActor
final class OriginalEffectPlayback {
    let engine: AVAudioEngine
    private let box: OriginalEffectRenderBox
    private let sourceNode: AVAudioSourceNode

    init(driver: OriginalSoundDriver) {
        let box = OriginalEffectRenderBox(driver: driver)
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let node = AVAudioSourceNode(format: format) { _, _, count, audioBufferList in
            box.render(frames: Int(count), buffers: UnsafeMutableAudioBufferListPointer(audioBufferList))
        }
        let engine = AVAudioEngine()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        self.box = box
        self.engine = engine
        self.sourceNode = node
    }

    func play(_ renderer: OriginalEffectRenderer, playerID: Int) throws {
        box.play(renderer, playerID: playerID)
        if !engine.isRunning { try engine.start() }
    }
    func isPlaying(playerID: Int) -> Bool { box.isPlaying(playerID: playerID) }
    func matches(playerID: Int, archiveID: Int, entryID: Int) -> Bool { box.matches(playerID: playerID, archiveID: archiveID, entryID: entryID) }
    func stop(playerID: Int? = nil, frames: Int = 0) { box.stop(playerID: playerID, frames: frames) }
    func volume(playerID: Int?, target: Int, frames: Int) { box.volume(playerID: playerID, target: target, frames: frames) }
    func pitch(playerID: Int, target: Int) { box.pitch(playerID: playerID, target: target) }
    func advanceFrame() { box.advanceFrame() }
    func pause() { engine.pause() }
    func resume() throws { if !engine.isRunning { try engine.start() } }
}
