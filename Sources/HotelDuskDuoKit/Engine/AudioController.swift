import Foundation
import Combine
import AVFoundation

/// Plays recovered music through Apple's native sequencer and original samples.
/// Cue selection belongs to recovered game logic, not this audio adapter.
@MainActor
public final class AudioController: ObservableObject {
    typealias MusicOutputFactory = @MainActor (
        MusicSource, OriginalAudioLibrary, OriginalAudioLibrary.Sequence
    ) throws -> any OriginalMusicOutput

    public enum MusicSource: String, CaseIterable, Identifiable {
        case native
        case recordings
        public var id: String { rawValue }
        public var title: String { self == .native ? "Native music" : "Recorded soundtrack" }
    }
    @Published public private(set) var musicSource: MusicSource = .native
    @Published public private(set) var currentBGMTitle = ""
    @Published public private(set) var currentSequenceID: Int?
    @Published public private(set) var lastError: String?
    @Published public var isMuted = false { didSet { applyVolume() } }
    @Published public var volume: Float = 0.8 { didSet { applyVolume() } }
    @Published public private(set) var soundEffectsHistory: [String] = []
    private(set) var musicOutput: (any OriginalMusicOutput)?
    var playback: OriginalMusicPlayback? { musicOutput as? OriginalMusicPlayback }
    private var fadingOutput: (any OriginalMusicOutput)?
    private var preparedOutput: (source: MusicSource, id: Int, output: any OriginalMusicOutput)?
    private(set) var currentOutputGain: Float = 1
    private var fadingOutputGain: Float = 1
    private var fadingSource: MusicSource?
    private var musicBalance: MusicSourceBalance?
    private var sourceBlend: Float = 1
    private var sourceTransition: Task<Void, Never>?
    private var isPaused = false
    private var playingSequenceID: Int?
    private var recordings: RecordedMusicLibrary?
    private var musicOutputFactory: MusicOutputFactory?
    private var preferences: UserDefaults?
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
    private var dialogueAudio: OriginalDialogueAudio?
    private var footstepCadence = OriginalFootstepCadence()
    private var walkingInputStarted = false
    private var walkingMapID: Int16?
    private var walkingAmbient: OriginalMapSoundCue?

    public nonisolated init() {}

    init(musicOutputFactory: @escaping MusicOutputFactory) {
        self.musicOutputFactory = musicOutputFactory
    }

    init(preferences: UserDefaults, musicOutputFactory: @escaping MusicOutputFactory) {
        self.musicOutputFactory = musicOutputFactory
        self.preferences = preferences
        musicSource = preferences.string(forKey: "musicSource").flatMap(MusicSource.init(rawValue:)) ?? .native
    }

    public convenience init(preferences: UserDefaults) {
        self.init()
        self.preferences = preferences
        musicSource = preferences.string(forKey: "musicSource").flatMap(MusicSource.init(rawValue:)) ?? .native
    }

    /// Prepare the replacement before changing audible output. Failed switches
    /// leave the current track, position and source preference intact.
    @discardableResult
    public func selectMusicSource(_ source: MusicSource) -> Bool {
        guard source != musicSource else { return true }
        finishSourceTransition()
        do {
            if let id = playingSequenceID, let previous = musicOutput {
                let library = try library ?? OriginalAudioLibrary.load()
                guard let sequence = library.sequences.first(where: { $0.id == id }) else {
                    throw OriginalAudioError.unknownSequence(String(id))
                }
                let next = try takeMusicOutput(source: source, library: library, sequence: sequence)
                let nextGain = try calibratedGain(source: source, id: id)
                let timing = try recordingTrack(id: id)
                next.outputVolume = 0
                do {
                    try next.seek(to: source == .native ? timing.nativePhase(previous.position) : previous.position)
                    if !isPaused { try next.resume() }
                } catch {
                    next.stop()
                    throw error
                }
                finishSourceTransition()
                fadingOutputGain = currentOutputGain
                currentOutputGain = nextGain
                musicOutput = next
                if isPaused {
                    cacheOutput(previous, source: musicSource, id: id)
                } else {
                    fadingOutput = previous
                    fadingSource = musicSource
                    sourceBlend = 0
                    sourceTransition = Task { [weak self] in
                        // Crossfade on its own clock, including in book menus.
                        for step in 1...15 {
                            do { try await Task.sleep(for: .milliseconds(10)) }
                            catch { return }
                            guard let self else { return }
                            self.sourceBlend = Float(step) / 15
                            self.applyVolume()
                        }
                        self?.finishSourceTransition()
                    }
                }
            }
            musicSource = source
            preferences?.set(source.rawValue, forKey: "musicSource")
            lastError = nil
            applyVolume()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func recordingTrack(id: Int) throws -> RecordedMusicLibrary.Track {
        let table = try recordings ?? RecordedMusicLibrary.load()
        recordings = table
        return try table.track(id: id)
    }

    private func makeMusicOutput(source: MusicSource, library: OriginalAudioLibrary,
                                 sequence: OriginalAudioLibrary.Sequence) throws -> any OriginalMusicOutput {
        if let musicOutputFactory { return try musicOutputFactory(source, library, sequence) }
        switch source {
        case .native: return try OriginalMusicPlayback(library: library, sequence: sequence)
        case .recordings: return try RecordedMusicPlayback(track: recordingTrack(id: sequence.id))
        }
    }

    private func calibratedGain(source: MusicSource, id: Int) throws -> Float {
        let balance = try musicBalance ?? MusicSourceBalance.load()
        musicBalance = balance
        guard let track = balance.tracks.first(where: { $0.id == id }) else { throw OriginalAudioError.invalidManifest }
        return source == .native ? track.nativeGain : track.recordedGain
    }

    private func takeMusicOutput(source: MusicSource, library: OriginalAudioLibrary,
                                 sequence: OriginalAudioLibrary.Sequence) throws -> any OriginalMusicOutput {
        if let prepared = preparedOutput, prepared.source == source, prepared.id == sequence.id {
            preparedOutput = nil
            return prepared.output
        }
        return try makeMusicOutput(source: source, library: library, sequence: sequence)
    }

    /// Retain at most the alternate backend for the current cue. Pause and mute
    /// it while keeping the graph ready, avoiding engine startup on a switch.
    private func cacheOutput(_ output: any OriginalMusicOutput, source: MusicSource, id: Int) {
        preparedOutput?.output.stop()
        output.pause()
        output.outputVolume = 0
        preparedOutput = (source, id, output)
    }

    private func finishSourceTransition() {
        sourceTransition?.cancel()
        sourceTransition = nil
        if let output = fadingOutput, let source = fadingSource, let id = playingSequenceID {
            cacheOutput(output, source: source, id: id)
        } else { fadingOutput?.stop() }
        fadingOutput = nil
        fadingSource = nil
        sourceBlend = 1
        applyVolume()
    }

    /// SDAT IDs are zero based. No title-to-scene aliases are supplied.
    public func playOriginalSequence(id: Int) throws {
        try reportFailure { try startOriginalSequence(id: id) }
    }

    private func startOriginalSequence(id: Int) throws {
        guard !musicDisabled else { return }
        let source = try library ?? OriginalAudioLibrary.load()
        guard let sequence = source.sequences.first(where: { $0.id == id }) else {
            throw OriginalAudioError.unknownSequence(String(id))
        }
        if currentSequenceID == id, let musicOutput {
            if !isPaused { try musicOutput.resume() }
            return
        }
        let next = try makeMusicOutput(source: musicSource, library: source, sequence: sequence)
        let nextGain = try calibratedGain(source: musicSource, id: id)
        if isPaused { try next.seek(to: 0) }
        let driver = try driver ?? OriginalSoundDriver.load()
        effects?.stop(playerID: 1, frames: 1)
        finishSourceTransition()
        preparedOutput?.output.stop()
        preparedOutput = nil
        musicOutput?.stop()
        musicOutput = next
        currentOutputGain = nextGain
        playingSequenceID = id
        library = source
        self.driver = driver
        musicRamp = nil
        musicVolumeValue = sequence.volume
        currentSequenceID = id
        currentBGMTitle = sequence.symbol
        sourceVolume = driver.linearGain(volume: sequence.volume)
        lastError = nil
        applyVolume()
        do { if !isPaused { try next.resume() } }
        catch {
            musicOutput = nil
            playingSequenceID = nil
            currentSequenceID = nil
            currentBGMTitle = ""
            lastError = error.localizedDescription
            throw error
        }
    }

    func ensureOriginalEffect(archiveID: Int, entryID: Int) throws {
        let archive = try soundArchive ?? OriginalSoundArchive.load()
        let cue = try archive.effect(archiveID: archiveID, entryID: entryID)
        guard effects?.matches(playerID: cue.playerID, archiveID: archiveID, entryID: entryID) != true else { return }
        try playOriginalEffect(archiveID: archiveID, entryID: entryID)
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
        try reportFailure { try startOriginalEffect(archiveID: archiveID, entryID: entryID) }
    }

    /**
     * Fades all active effect players, as used by the original bowling result callback.
     */
    func stopOriginalEffects(fadeFrames: Int) {
        effects?.stop(playerID: nil, frames: max(0, fadeFrames))
    }

    private func startOriginalEffect(archiveID: Int, entryID: Int) throws {
        guard !effectsDisabled else { return }
        let archive = try soundArchive ?? OriginalSoundArchive.load()
        let cue = try archive.effect(archiveID: archiveID, entryID: entryID)
        if isMuted {
            soundArchive = archive
            recordEffect(cue.symbol)
            lastError = nil
            return
        }
        let driver = try driver ?? OriginalSoundDriver.load()
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
        let level = volume.isFinite ? min(1, max(0, volume)) : 0
        output.engine.mainMixerNode.outputVolume = isMuted ? 0 : level
        try output.play(renderer, playerID: cue.playerID)
        soundArchive = archive
        self.driver = driver
        effects = output
        recordEffect(cue.symbol)
        lastError = nil
        applyVolume()
    }

    private func recordEffect(_ symbol: String) {
        soundEffectsHistory.append(symbol)
        if soundEffectsHistory.count > 128 { soundEffectsHistory.removeFirst(soundEffectsHistory.count - 128) }
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
        try reportFailure { try applyCommand(command) }
    }

    private func applyCommand(_ command: OriginalAudioCommand) throws -> Bool {
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
        case .waitForMusic: return currentSequenceID != nil && (musicOutput?.isActive ?? false)
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
        if let error = effects?.takeRenderError() { lastError = error.localizedDescription }
        if var ramp = musicRamp {
            ramp.advance()
            musicVolumeValue = ramp.value >> 8
            updateMusicGain()
            if ramp.isComplete {
                musicRamp = nil
                if ramp.stopsAtEnd { stop() }
            } else { musicRamp = ramp }
        }
        if currentSequenceID != nil, musicOutput?.isActive == false, !isPaused { stop() }
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

    public func pause() {
        isPaused = true
        finishSourceTransition()
        musicOutput?.pause()
        effects?.pause()
    }
    public func resume() {
        isPaused = false
        do { try musicOutput?.resume(); try effects?.resume() }
        catch { lastError = error.localizedDescription }
    }
    public func stop() {
        finishSourceTransition()
        preparedOutput?.output.stop()
        preparedOutput = nil
        musicOutput?.stop()
        musicOutput = nil
        playingSequenceID = nil
        musicRamp = nil
        currentSequenceID = nil
        currentBGMTitle = ""
    }
    public func toggleMute() { isMuted.toggle() }

    /// Applies only controls supplied by the current original dialogue packet.
    func applyDialogueAudio(_ packet: OriginalDialoguePacket) {
        for page in packet.pages {
            for token in page.tokens {
                guard case .control(let control) = token.kind else { continue }
                switch control {
                case .music, .sound: break
                default: continue
                }
                do {
                    let table = try dialogueAudio ?? OriginalDialogueAudio.load()
                    dialogueAudio = table
                    if let command = try table.command(for: control) {
                        _ = try applyOriginalCommand(command)
                    }
                } catch { lastError = error.localizedDescription }
            }
        }
    }

    func playWalkingMusic(mapID: Int16, game: OriginalGameState) {
        do {
            let table = try dialogueAudio ?? OriginalDialogueAudio.load()
            dialogueAudio = table
            if walkingMapID != mapID {
                stopWalkingAudio()
                walkingMapID = mapID
            }
            if let command = try table.walkingMusic(mapID: mapID, game: game) {
                _ = try applyOriginalCommand(command)
            }
            if let cue = try table.walkingAmbience(mapID: mapID, game: game) {
                try ensureOriginalEffect(archiveID: cue.archiveID, entryID: cue.entryID)
                walkingAmbient = cue
            }
        } catch { lastError = error.localizedDescription }
    }

    func advanceWalkingAudio(mapID: Int16, from start: SIMD3<Float>, to end: SIMD3<Float>, hasInput: Bool = true) {
        // 0x0202B100 state 0 waits for the first walking input. It does not
        // call the distance/cadence update during the untouched initial idle.
        guard hasInput || walkingInputStarted else { return }
        walkingInputStarted = true
        guard let foot = footstepCadence.update(from: start, to: end) else { return }
        do {
            let table = try dialogueAudio ?? OriginalDialogueAudio.load()
            dialogueAudio = table
            if let cue = table.maps.first(where: { $0.mapID == mapID })?.footstep {
                try playOriginalEffect(archiveID: cue.archiveID, entryID: cue.entryID + foot)
            }
        } catch { lastError = error.localizedDescription }
    }

    /// Map controller cleanup, 0x0202CB58: release its ambient effect over five frames.
    func stopWalkingAudio() {
        if let cue = walkingAmbient {
            do { _ = try applyOriginalCommand(.stopEffect(archiveID: cue.archiveID, entryID: cue.entryID, fadeFrames: 5)) }
            catch { lastError = error.localizedDescription }
        }
        walkingAmbient = nil
        walkingMapID = nil
        footstepCadence = OriginalFootstepCadence()
        walkingInputStarted = false
    }

    /// Ends the game session, including looping environmental and puzzle effects.
    public func stopAll() {
        stopWalkingAudio()
        stop()
        effects?.stopAll()
        effects = nil
        lastEffectBank = nil
        musicDisabled = false
        effectsDisabled = false
        isPaused = false
    }

    private func reportFailure<T>(_ action: () throws -> T) throws -> T {
        do { return try action() }
        catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func applyVolume() {
        let level = volume.isFinite ? min(1, max(0, volume)) : 0
        let gain: Float = isMuted ? 0 : level * sourceVolume
        musicOutput?.outputVolume = gain * sourceBlend * currentOutputGain
        fadingOutput?.outputVolume = gain * (1 - sourceBlend) * fadingOutputGain
        effects?.engine.mainMixerNode.outputVolume = isMuted ? 0 : level
    }
}

@MainActor
final class OriginalMusicPlayback: OriginalMusicOutput {
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

    var outputVolume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    var position: TimeInterval { pausedPosition ?? sequencer.currentPositionInSeconds }

    func seek(to seconds: TimeInterval) throws {
        guard seconds.isFinite, seconds >= 0 else { throw OriginalAudioError.invalidCommand }
        sequencer.currentPositionInSeconds = seconds
        if !sequencer.isPlaying || pausedPosition != nil { pausedPosition = seconds }
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
