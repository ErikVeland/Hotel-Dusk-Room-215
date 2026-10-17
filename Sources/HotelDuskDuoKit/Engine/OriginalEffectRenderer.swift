import Foundation

/// Native sample rendering for original SSAR effects.
/// Envelope and sequence rules come from ARM7; output resampling and final gain
/// still require comparison with the reference recordings before fidelity sign-off.
public final class OriginalEffectRenderer {
    public struct State: Codable, Sendable {
        public let archiveID: Int
        public let entryID: Int
        public let sampleRate: Double
        public fileprivate(set) var sequence: OriginalSequenceMachine
        public fileprivate(set) var shared: OriginalSequenceMachine.SharedState
        public fileprivate(set) var renderedFrames: Int64 = 0
        public fileprivate(set) var playerVolume: Int
        fileprivate var voices: [Voice] = []
        fileprivate var parameters = Array(repeating: Parameters(), count: 16)
        fileprivate var alarmCountdown: Double = 0
        fileprivate var tempoAccumulator = 240
        fileprivate var stopped = false
    }
    fileprivate struct Parameters: Codable, Sendable {
        var program = 0
        var volume = 127
        var expression = 127
        var pan = 64
        var bend = 0
        var bendRange = 2
        var priority = 64
        var pitch = 0
    }
    fileprivate struct Voice: Codable, Sendable {
        var channel: Int
        var priority: Int
        var track: Int
        var sampleKey: Int?
        var duty: Int?
        var rootKey: Int
        var key: Int
        var velocity: Int
        var pan: Int
        var timer: Int
        var remainingTicks: Int
        var envelope: OriginalSoundDriver.Envelope
        var position: Double = 0
        var noiseState: UInt16 = 0x7FFF
        var noiseOutput: Int16 = 32767
        var step: Double = 0
        var left: Float = 0
        var right: Float = 0
        var finished = false
    }
    public let archiveID: Int
    public let entryID: Int
    public let sampleRate: Double
    public private(set) var state: State
    private let cue: OriginalSoundArchive.Effect
    private let driver: OriginalSoundDriver
    private let instruments: [[OriginalSoundArchive.Instrument?]]
    private let samples: [Int: OriginalSoundArchive.Sample]

    public init(archive: OriginalSoundArchive, driver: OriginalSoundDriver, archiveID: Int, entryID: Int,
                sampleRate: Double = 48_000, shared: OriginalSequenceMachine.SharedState? = nil) throws {
        guard sampleRate.isFinite, sampleRate > 0 else { throw OriginalAudioError.invalidManifest }
        let cue = try archive.effect(archiveID: archiveID, entryID: entryID)
        let sequence = try OriginalSequenceMachine(data: archive.effectEventData(archiveID: archiveID), startOffset: cue.eventOffset)
        var instruments: [[OriginalSoundArchive.Instrument?]] = []
        var samples: [Int: OriginalSoundArchive.Sample] = [:]
        for program in 0..<(try archive.instrumentCount(bankID: cue.bankID)) {
            var keys: [OriginalSoundArchive.Instrument?] = []
            for note in 0...127 {
                let instrument = try archive.instrument(bankID: cue.bankID, program: program, note: note)
                keys.append(instrument)
                if let instrument, case let .pcm(waveArchiveID, waveID) = instrument.voice {
                    let key = waveArchiveID << 16 | waveID
                    if samples[key] == nil { samples[key] = try archive.sample(archiveID: waveArchiveID, waveID: waveID) }
                }
            }
            instruments.append(keys)
        }
        self.archiveID = archiveID
        self.entryID = entryID
        self.sampleRate = sampleRate
        self.cue = cue
        self.driver = driver
        self.instruments = instruments
        self.samples = samples
        self.state = State(archiveID: archiveID, entryID: entryID, sampleRate: sampleRate,
                           sequence: sequence, shared: shared ?? .init(driver: driver), playerVolume: cue.volume)
    }

    public var isFinished: Bool { (state.stopped || !state.sequence.hasActiveTracks) && state.voices.isEmpty }
    public var isSequenceActive: Bool { !state.stopped && state.sequence.hasActiveTracks }
    public func setPlayerVolume(_ value: Int) { state.playerVolume = min(127, max(0, value)) }
    public func setSharedState(_ shared: OriginalSequenceMachine.SharedState) { state.shared = shared }
    public func setPitchForFirstActiveTrack(_ value: Int) {
        if let track = state.sequence.tracks.firstIndex(where: { $0.map { !$0.ended } ?? false }) {
            state.parameters[track].pitch = Int(Int16(truncatingIfNeeded: value))
        }
    }

    /// Restores sequence, random history, envelope, sample phase and pending waits.
    public func restore(_ saved: State) throws {
        guard saved.archiveID == archiveID, saved.entryID == entryID, saved.sampleRate == sampleRate else {
            throw OriginalAudioError.invalidManifest
        }
        state = saved
    }

    public func stop() {
        state.stopped = true
        for index in state.voices.indices {
            state.voices[index].envelope.release()
            state.voices[index].priority = 1
        }
    }

    public func render(frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard frameCount >= 0 else { throw OriginalAudioError.invalidManifest }
        var left = Array(repeating: Float(0), count: frameCount)
        var right = left
        for frame in 0..<frameCount {
            if state.alarmCountdown <= 0 {
                try advanceDriver()
                // The original OS alarm ticks at ARM7 clock/64.
                state.alarmCountdown += Double(driver.driverAlarmInterval) * 64 * sampleRate / 33_513_982
            }
            for index in state.voices.indices {
                var voice = state.voices[index]
                if voice.finished { continue }
                let value: Float
                if let sampleKey = voice.sampleKey, let sample = samples[sampleKey] {
                    var position = Int(voice.position)
                    if position >= sample.pcm.count {
                        if let start = sample.loopStart, let length = sample.loopLength {
                            voice.position = Double(start) + (voice.position - Double(start)).truncatingRemainder(dividingBy: Double(length))
                            position = Int(voice.position)
                        } else {
                            voice.finished = true
                            state.voices[index] = voice
                            continue
                        }
                    }
                    value = Float(sample.pcm[position]) / 32768
                } else if let duty = voice.duty {
                    value = duty == 7 || Int(voice.position) & 7 < 7 - duty ? -1 : Float(32767) / 32768
                } else {
                    value = Float(voice.noiseOutput) / 32768
                }
                left[frame] += value * voice.left
                right[frame] += value * voice.right
                let previous = Int(voice.position)
                voice.position += voice.step
                if voice.sampleKey == nil, voice.duty == nil {
                    for _ in previous..<Int(voice.position) {
                        let low = voice.noiseState & 1
                        voice.noiseState >>= 1
                        if low != 0 { voice.noiseState ^= 0x6000 }
                        voice.noiseOutput = low != 0 ? -32767 : 32767
                    }
                }
                state.voices[index] = voice
            }
            state.voices.removeAll(where: \.finished)
            left[frame] = min(1, max(-1, left[frame]))
            right[frame] = min(1, max(-1, right[frame]))
            state.alarmCountdown -= 1
            state.renderedFrames += 1
        }
        return (left, right)
    }

    private func advanceDriver() throws {
        while state.tempoAccumulator >= 240, state.sequence.hasActiveTracks, !state.stopped {
            state.tempoAccumulator -= 240
            for index in state.voices.indices where state.voices[index].remainingTicks > 0 {
                state.voices[index].remainingTicks -= 1
            }
            let counts = Dictionary(grouping: state.voices, by: \.track).mapValues(\.count)
            var sequence = state.sequence
            var shared = state.shared
            let events = try sequence.advanceTick(voiceCounts: counts, shared: &shared)
            state.sequence = sequence
            state.shared = shared
            for event in events {
                switch event {
                case let .note(track, key, velocity, duration):
                    try startNote(track: track, key: key, velocity: velocity, duration: duration)
                case let .control(track, opcode, value):
                    switch opcode {
                    case 0x81: state.parameters[track].program = value
                    case 0xC0: state.parameters[track].pan = value
                    case 0xC1: state.parameters[track].volume = value
                    case 0xC4: state.parameters[track].bend = Int(Int8(truncatingIfNeeded: value))
                    case 0xC5: state.parameters[track].bendRange = value
                    case 0xC6: state.parameters[track].priority = value
                    case 0xD5: state.parameters[track].expression = value
                    case 0xC2, 0xC3, 0xC7, 0xD4, 0xD6, 0xE1: break
                    default: throw OriginalAudioError.unsupportedEffect("SSAR controller \(opcode)")
                    }
                case let .endTrack(track):
                    for index in state.voices.indices where state.voices[index].track == track {
                        state.voices[index].envelope.release()
                        state.voices[index].priority = 1
                    }
                }
            }
        }
        if !state.stopped, state.sequence.hasActiveTracks { state.tempoAccumulator += state.sequence.tempo }
        for index in state.voices.indices {
            var voice = state.voices[index]
            let parameters = state.parameters[voice.track]
            if voice.remainingTicks == 0 { voice.envelope.release(); voice.priority = 1 }
            voice.envelope.advance()
            let attenuation = driver.attenuation.values[min(127, voice.velocity)] + voice.envelope.attenuation +
                driver.attenuation.values[state.playerVolume] + driver.attenuation.values[min(127, state.sequence.volume)] +
                driver.attenuation.values[min(127, parameters.volume)] + driver.attenuation.values[min(127, parameters.expression)]
            if voice.envelope.stage == .release, attenuation <= -723 { voice.finished = true }
            let gain = Float(pow(10, Double(min(0, attenuation)) / 200))
            let pan = min(127, max(0, voice.pan + parameters.pan - 64))
            let hardwarePan = pan == 127 ? 128 : pan
            voice.left = gain * Float(128 - hardwarePan) / 128
            voice.right = gain * Float(hardwarePan) / 128
            let pitch = (voice.key - voice.rootKey) * 64 + (parameters.bend * parameters.bendRange * 64 >> 7) + parameters.pitch
            let timer = min(65535, max(16, Int(Double(voice.timer) * pow(2, -Double(pitch) / 768))))
            voice.step = 16_756_991 / Double(timer) / sampleRate
            state.voices[index] = voice
        }
        state.voices.removeAll(where: \.finished)
        _ = state.shared.random.next()
    }

    private func startNote(track: Int, key: Int, velocity: Int, duration: Int) throws {
        let program = state.parameters[track].program
        guard instruments.indices.contains(program), let instrument = instruments[program][key] else { return }
        var sampleKey: Int?
        var duty: Int?
        let allowedChannels: ClosedRange<Int>
        var timer = 8006 // ARM7 03800258/038002AC: original PSG base timer.
        switch instrument.voice {
        case let .pcm(archiveID, waveID):
            allowedChannels = 0...15
            sampleKey = archiveID << 16 | waveID
            guard let sample = samples[sampleKey!] else { throw OriginalAudioError.invalidManifest }
            timer = sample.timer
        case .pulse(let value): duty = value; allowedChannels = 8...13
        case .noise: allowedChannels = 14...15
        }
        let priority = (cue.channelPriority + state.parameters[track].priority) & 255
        var chosen: (channel: Int, priority: Int, gain: Float)?
        for channel in driver.channelOrder.values where allowedChannels.contains(channel) {
            let current = state.voices.first { $0.channel == channel }
            let candidate = (channel, current?.priority ?? 0, (current?.left ?? 0) + (current?.right ?? 0))
            if let previous = chosen {
                if candidate.1 > previous.priority || (candidate.1 == previous.priority && candidate.2 >= previous.gain) { continue }
            }
            chosen = candidate
        }
        guard let chosen, priority >= chosen.priority else { return }
        state.voices.removeAll { $0.channel == chosen.channel }
        let envelope = OriginalSoundDriver.Envelope(driver: driver, attack: instrument.attack, decay: instrument.decay,
                                                    sustain: instrument.sustain, release: instrument.release)
        state.voices.append(Voice(channel: chosen.channel, priority: priority, track: track, sampleKey: sampleKey, duty: duty, rootKey: instrument.rootKey,
                                  key: key, velocity: velocity, pan: instrument.pan, timer: timer,
                                  remainingTicks: duration, envelope: envelope))
    }
}
