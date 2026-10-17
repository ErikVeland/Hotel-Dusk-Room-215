import Foundation
import Combine
import AVFoundation

/// Plays recovered music through Apple's native sequencer and original samples.
/// Cue selection belongs to recovered game logic, not this audio adapter.
@MainActor
public final class AudioController: ObservableObject {
    @Published public private(set) var currentBGMTitle = ""
    @Published public private(set) var currentSequenceID: Int?
    @Published public private(set) var lastError: String?
    @Published public var isMuted = false { didSet { applyVolume() } }
    @Published public var volume: Float = 0.8 { didSet { applyVolume() } }
    @Published public private(set) var soundEffectsHistory: [String] = []
    private var playback: OriginalMusicPlayback?
    private var effects: OriginalEffectPlayback?
    private var library: OriginalAudioLibrary?
    private var soundArchive: OriginalSoundArchive?
    private var driver: OriginalSoundDriver?
    private var sourceVolume: Float = 1
    private var musicVolumeValue = 127
    private var musicRamp: OriginalAudioRamp?
    private var musicDisabled = false
    private var effectsDisabled = false
    private var lastEffectBank: Int?

    public nonisolated init() {}

    /// SDAT IDs are zero based. No title-to-scene aliases are supplied.
    public func playOriginalSequence(id: Int) throws {
        guard !musicDisabled else { return }
        let source = try library ?? OriginalAudioLibrary.load()
        guard let sequence = source.sequences.first(where: { $0.id == id }) else {
            throw OriginalAudioError.unknownSequence(String(id))
        }
        if currentSequenceID == id, let playback {
            try playback.resume()
            return
        }
        let next = try OriginalMusicPlayback(library: source, sequence: sequence)
        let driver = try driver ?? OriginalSoundDriver.load()
        effects?.stop(playerID: 1, frames: 1)
        playback?.stop()
        playback = next
        library = source
        self.driver = driver
        musicRamp = nil
        musicVolumeValue = sequence.volume
        currentSequenceID = id
        currentBGMTitle = sequence.symbol
        sourceVolume = driver.linearGain(volume: sequence.volume)
        lastError = nil
        applyVolume()
        do { try next.resume() }
        catch {
            playback = nil
            currentSequenceID = nil
            currentBGMTitle = ""
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Compatibility entry point. Only original SDAT symbols are accepted.
    public func playBGM(title: String) {
        do {
            let source = try library ?? OriginalAudioLibrary.load()
            guard let sequence = source.sequences.first(where: { $0.symbol == title }) else {
                throw OriginalAudioError.unknownSequence(title)
            }
            try playOriginalSequence(id: sequence.id)
        } catch { lastError = error.localizedDescription }
    }

    public func playOriginalEffect(archiveID: Int, entryID: Int) throws {
        guard !effectsDisabled else { return }
        let archive = try soundArchive ?? OriginalSoundArchive.load()
        let driver = try driver ?? OriginalSoundDriver.load()
        let cue = try archive.effect(archiveID: archiveID, entryID: entryID)
        let output = effects ?? OriginalEffectPlayback(driver: driver)
        if cue.bankID != 44 {
            if lastEffectBank != cue.bankID || cue.playerID == 1 {
                if cue.playerID != 1 && cue.playerID != 15 && cue.playerID != 16 {
                    for player in 1...10 { output.stop(playerID: player, frames: 1) }
                }
                lastEffectBank = cue.bankID
            }
            if cue.playerID == 16, output.matches(playerID: 16, archiveID: archiveID, entryID: entryID) { return }
        }
        let renderer = try OriginalEffectRenderer(archive: archive, driver: driver, archiveID: archiveID, entryID: entryID)
        try output.play(renderer, playerID: cue.playerID)
        soundArchive = archive
        self.driver = driver
        effects = output
        soundEffectsHistory.append(cue.symbol)
        if soundEffectsHistory.count > 128 { soundEffectsHistory.removeFirst(soundEffectsHistory.count - 128) }
        lastError = nil
        applyVolume()
    }

    /// Compatibility entry point accepts only an exact original SSAR symbol.
    public func playSFX(name: String) {
        do {
            let archive = try soundArchive ?? OriginalSoundArchive.load()
            for source in archive.sequenceArchives {
                if let cue = source.sequences.first(where: { $0.symbol == name }) {
                    try playOriginalEffect(archiveID: source.id, entryID: cue.id)
                    return
                }
            }
            throw OriginalAudioError.unsupportedEffect(name)
        } catch { lastError = error.localizedDescription }
    }

    /// The return value matches the source cinematic handler: true keeps waiting.
    @discardableResult
    public func applyOriginalCommand(_ command: OriginalAudioCommand) throws -> Bool {
        switch command {
        case .startMusic(let id): try playOriginalSequence(id: id)
        case .stopMusic(let frames):
            guard currentSequenceID != nil else { return false }
            if frames <= 0 { stop() }
            else {
                musicRamp = .init(start: musicVolumeValue << 8, target: 0, frames: frames, stopsAtEnd: true)
                currentSequenceID = nil
                currentBGMTitle = ""
            }
        case .waitForMusic: return currentSequenceID != nil && (playback?.isActive ?? false)
        case .disableMusic(let disabled):
            musicDisabled = disabled
            if disabled { stop() }
        case .musicVolume(let target, let frames):
            guard currentSequenceID != nil, frames != 999 else { return false }
            if frames <= 0 { musicVolumeValue = min(127, max(0, target)); musicRamp = nil; updateMusicGain() }
            else { musicRamp = .init(start: musicVolumeValue << 8, target: min(127, max(0, target)) << 8, frames: frames, stopsAtEnd: false) }
        case .startEffect(let archive, let entry): try playOriginalEffect(archiveID: archive, entryID: entry)
        case .stopEffect(let archive, let entry, let frames):
            effects?.stop(playerID: try playerID(archiveID: archive, entryID: entry), frames: frames)
        case .effectVolume(let archive, let entry, let target, let frames):
            effects?.volume(playerID: try playerID(archiveID: archive, entryID: entry), target: target, frames: frames)
        case .disableNewEffects(let disabled): effectsDisabled = disabled
        case .effectPitch(let archive, let entry, let target, _):
            // 0200A464 sends the target immediately to the first active track.
            // Its stored ramp fields have no advancing reader in the recovered code.
            if let player = try playerID(archiveID: archive, entryID: entry) { effects?.pitch(playerID: player, target: target) }
        case .waitForEffectPlayer(let player): return effects?.isPlaying(playerID: player) ?? false
        }
        return false
    }

    /// Call once per original game frame, independently of queued command count.
    public func advanceOriginalFrame() {
        effects?.advanceFrame()
        if var ramp = musicRamp {
            ramp.advance()
            musicVolumeValue = ramp.value >> 8
            updateMusicGain()
            if ramp.isComplete {
                musicRamp = nil
                if ramp.stopsAtEnd { stop() }
            } else { musicRamp = ramp }
        }
        if currentSequenceID != nil, playback?.isActive == false { stop() }
    }

    private func playerID(archiveID: Int, entryID: Int) throws -> Int? {
        if entryID == -1 { return nil }
        let archive = try soundArchive ?? OriginalSoundArchive.load()
        return try archive.effect(archiveID: archiveID, entryID: entryID).playerID
    }

    private func updateMusicGain() {
        sourceVolume = driver?.linearGain(volume: musicVolumeValue) ?? 0
        applyVolume()
    }

    public func pause() { playback?.pause(); effects?.pause() }
    public func resume() {
        do { try playback?.resume(); try effects?.resume() }
        catch { lastError = error.localizedDescription }
    }
    public func stop() {
        playback?.stop()
        playback = nil
        musicRamp = nil
        currentSequenceID = nil
        currentBGMTitle = ""
    }
    public func toggleMute() { isMuted.toggle() }

    private func applyVolume() {
        let level = volume.isFinite ? min(1, max(0, volume)) : 0
        playback?.engine.mainMixerNode.outputVolume = isMuted ? 0 : level * sourceVolume
        effects?.engine.mainMixerNode.outputVolume = isMuted ? 0 : level
    }
}

@MainActor
final class OriginalMusicPlayback {
    let engine: AVAudioEngine
    let sequencer: AVAudioSequencer
    let samplers: [AVAudioUnitSampler]
    private var pausedPosition: TimeInterval?
    private let loops: Bool
    private let endBeat: Double

    init(library: OriginalAudioLibrary, sequence: OriginalAudioLibrary.Sequence) throws {
        let engine = AVAudioEngine()
        let sequencer = AVAudioSequencer(audioEngine: engine)
        try sequencer.load(from: library.midiURL(for: sequence), options: [])
        // Apple's importer moves tempo-only tracks into tempoTrack. Keep the
        // source index map so a conductor track cannot shift instrument banks.
        let sourceTracks = sequence.tracks.filter(\.hasMIDIEvents)
        guard sequencer.tracks.count == sourceTracks.count else {
            throw OriginalAudioError.invalidTrackCount
        }
        let bankURL = try library.soundBankURL(for: sequence)
        var samplers: [AVAudioUnitSampler] = []
        for (track, source) in zip(sequencer.tracks, sourceTracks) {
            track.lengthInBeats = Double(source.endTick) / Double(library.ticksPerBeat)
            if let loop = source.loop {
                try Self.configureLoop(loop, track: track, ticksPerBeat: library.ticksPerBeat)
            }
            if !source.hasNotes {
                track.isMuted = true
                continue
            }
            let sampler = AVAudioUnitSampler()
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: nil)
            try sampler.loadSoundBankInstrument(
                at: bankURL, program: UInt8(source.program & 127),
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8((source.program >> 7) & 127)
            )
            track.destinationAudioUnit = sampler
            samplers.append(sampler)
        }
        let loops = sequence.tracks.compactMap(\.loop)
        if let loop = loops.first {
            guard loops.allSatisfy({ $0 == loop }) else { throw OriginalAudioError.invalidLoop }
            try Self.configureLoop(loop, track: sequencer.tempoTrack, ticksPerBeat: library.ticksPerBeat)
        }
        engine.prepare()
        sequencer.prepareToPlay()
        self.engine = engine
        self.sequencer = sequencer
        self.samplers = samplers
        self.loops = !loops.isEmpty
        self.endBeat = Double(sequence.tracks.map(\.endTick).max() ?? 0) / Double(library.ticksPerBeat)
    }

    var isActive: Bool {
        if pausedPosition != nil { return true }
        return sequencer.isPlaying && (loops || sequencer.currentPositionInBeats < endBeat)
    }

    private static func configureLoop(_ loop: OriginalAudioLibrary.Loop, track: AVMusicTrack, ticksPerBeat: Int) throws {
        guard loop.startTick >= 0, loop.endTick > loop.startTick else { throw OriginalAudioError.invalidLoop }
        track.loopRange = AVBeatRange(
            start: Double(loop.startTick) / Double(ticksPerBeat),
            length: Double(loop.endTick - loop.startTick) / Double(ticksPerBeat)
        )
        track.numberOfLoops = AVMusicTrackLoopCount.forever.rawValue
        track.isLoopingEnabled = true
    }

    func resume() throws {
        guard !sequencer.isPlaying else { return }
        if !engine.isRunning { try engine.start() }
        if let position = pausedPosition {
            sequencer.currentPositionInSeconds = position
            pausedPosition = nil
        }
        try sequencer.start()
    }

    func pause() {
        guard sequencer.isPlaying else { return }
        pausedPosition = sequencer.currentPositionInSeconds
        sequencer.stop()
        for sampler in samplers {
            for channel: UInt8 in 0..<16 {
                sampler.sendController(123, withValue: 0, onChannel: channel)
            }
        }
        engine.pause()
    }

    func stop() {
        sequencer.stop()
        engine.stop()
        pausedPosition = nil
    }
}
