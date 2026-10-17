import Foundation

/// Native SSEQ/SSAR instruction state, translated from ARM7 038009D8.
/// A renderer supplies live voice counts for the original zero-duration wait rule.
public struct OriginalSequenceMachine: Codable, Sendable {
    public struct SharedState: Codable, Sendable {
        public var variables = Array(repeating: Int16(-1), count: 16)
        public var random: OriginalSoundDriver.RandomState
        public init(driver: OriginalSoundDriver) { random = .init(driver: driver) }
    }
    public struct Track: Codable, Sendable {
        public fileprivate(set) var program = 0
        public fileprivate(set) var noteWait = true
        public fileprivate(set) var lastKey = 60
        public fileprivate(set) var ended = false
        public fileprivate(set) var controls: [Int: Int] = [
            0xC0: 64, 0xC1: 127, 0xC3: 0, 0xC4: 0, 0xC5: 2, 0xC6: 64,
            0xC8: 0, 0xCA: 0, 0xCB: 16, 0xCC: 0, 0xCD: 1, 0xCE: 0, 0xCF: 0,
            0xD0: 255, 0xD1: 255, 0xD2: 255, 0xD3: 255, 0xD5: 127, 0xE0: 0, 0xE3: 0
        ]
        fileprivate var pc: Int
        fileprivate var wait = 0
        fileprivate var waitingForVoices = false
        fileprivate var condition = true
        fileprivate var stack: [Frame] = []
        fileprivate struct Frame: Codable, Sendable {
            var address: Int
            var repeats: Int
        }
        fileprivate init(pc: Int) { self.pc = pc }
    }
    public enum Event: Equatable, Sendable {
        case note(track: Int, key: Int, velocity: Int, duration: Int)
        case control(track: Int, opcode: Int, value: Int)
        case endTrack(Int)
    }
    public private(set) var tracks: [Track?] = Array(repeating: nil, count: 16)
    public private(set) var variables = Array(repeating: Int16(-1), count: 16)
    public private(set) var tempo = 120
    public private(set) var volume = 127
    public private(set) var tick = 0
    private let data: Data
    private var allocatedTracks = 1

    public init(data: Data, startOffset: Int = 0) throws {
        guard data.indices.contains(startOffset) else { throw OriginalAudioError.invalidSequence }
        self.data = data
        var start = startOffset
        if data[start] == 0xFE {
            guard data.count - start >= 3 else { throw OriginalAudioError.invalidSequence }
            allocatedTracks = Int(data[start + 1]) | Int(data[start + 2]) << 8 | 1
            start += 3
        }
        tracks[0] = Track(pc: start)
    }

    public var hasActiveTracks: Bool { tracks.contains { $0.map { !$0.ended } ?? false } }

    /// One musical tick. The source driver schedules these with its tempo accumulator.
    public mutating func advanceTick(voiceCounts: [Int: Int] = [:], shared: inout SharedState) throws -> [Event] {
        var events: [Event] = []
        for id in 0..<16 {
            guard var track = tracks[id], !track.ended else { continue }
            if track.waitingForVoices {
                if voiceCounts[id, default: 0] > 0 { continue }
                track.waitingForVoices = false
            }
            if track.wait > 0 { track.wait -= 1 }
            if track.wait != 0 { tracks[id] = track; continue }

            func byte() throws -> Int {
                guard data.indices.contains(track.pc) else { throw OriginalAudioError.invalidSequence }
                defer { track.pc += 1 }
                return Int(data[track.pc])
            }
            func integer(_ count: Int) throws -> Int {
                var value = 0
                for shift in 0..<count { value |= try byte() << (shift * 8) }
                return value
            }
            func variableLength() throws -> Int {
                var value = 0
                for _ in 0..<4 {
                    let next = try byte()
                    value = value << 7 | (next & 127)
                    if next < 128 { return value }
                }
                throw OriginalAudioError.invalidSequence
            }
            func variable(_ index: Int) throws -> Int16 {
                switch index {
                case 0..<16: return variables[index]
                case 16..<32: return shared.variables[index - 16]
                default: throw OriginalAudioError.invalidSequence
                }
            }
            func argument(opcode: Int, mode: Int) throws -> Int {
                if mode == 0xA0 {
                    let low = Int(Int16(truncatingIfNeeded: try integer(2)))
                    let high = Int(Int16(truncatingIfNeeded: try integer(2)))
                    return (Int(shared.random.next()) * (high - low + 1) >> 16) + low
                }
                if mode == 0xA1 { return Int(try variable(byte())) }
                if opcode < 0x82 { return try variableLength() }
                if (0xB0...0xBF).contains(opcode) { return Int(Int16(truncatingIfNeeded: try integer(2))) }
                if (0xE0...0xEF).contains(opcode) { return try integer(2) }
                return try byte()
            }

            var budget = 65_536
            while track.wait == 0, !track.waitingForVoices, !track.ended {
                budget -= 1
                guard budget >= 0 else { throw OriginalAudioError.invalidSequence }
                let offset = track.pc
                var opcode = try byte()
                var execute = true
                if opcode == 0xA2 { execute = track.condition; opcode = try byte() }
                var mode = 0
                if opcode == 0xA0 || opcode == 0xA1 { mode = opcode; opcode = try byte() }
                if opcode < 0x80 {
                    let velocity = try byte()
                    let duration = try argument(opcode: opcode, mode: mode)
                    if execute {
                        let key = min(127, max(0, opcode + Int(Int8(truncatingIfNeeded: track.controls[0xC3, default: 0]))))
                        events.append(.note(track: id, key: key, velocity: velocity, duration: duration > 0 ? duration : -1))
                        track.lastKey = key
                        if track.noteWait {
                            track.wait = duration
                            if duration == 0 { track.waitingForVoices = true }
                        }
                    }
                    continue
                }
                switch opcode {
                case 0x80, 0x81:
                    let value = try argument(opcode: opcode, mode: mode)
                    if execute {
                        if opcode == 0x80 { track.wait = value }
                        else if value < 65_536 {
                            track.program = value & 0xFFFF
                            events.append(.control(track: id, opcode: 0x81, value: track.program))
                        }
                    }
                case 0x93:
                    let target = try byte()
                    let address = try integer(3)
                    if execute, target != id, (0..<16).contains(target), allocatedTracks & (1 << target) != 0 {
                        // OpenTrack restarts the allocated track with its existing controls.
                        var next = tracks[target] ?? Track(pc: address)
                        next.pc = address
                        next.ended = false
                        tracks[target] = next
                    }
                case 0x94, 0x95:
                    let address = try integer(3)
                    if execute {
                        if opcode == 0x94 { track.pc = address }
                        else if track.stack.count < 3 {
                            track.stack.append(.init(address: track.pc, repeats: 0))
                            track.pc = address
                        }
                    }
                case 0xB0...0xBD:
                    let index = try byte()
                    let rhs = Int16(truncatingIfNeeded: try argument(opcode: opcode, mode: mode))
                    let lhs = try variable(index)
                    guard execute else { continue }
                    var result = lhs
                    switch opcode {
                    case 0xB0: result = rhs
                    case 0xB1: result = lhs &+ rhs
                    case 0xB2: result = lhs &- rhs
                    case 0xB3: result = lhs &* rhs
                    case 0xB4:
                        if rhs != 0 { result = Int16(truncatingIfNeeded: Int(lhs) / Int(rhs)) }
                    case 0xB5:
                        let amount = abs(Int(rhs)) & 255
                        if rhs < 0 { result = amount >= 32 ? (lhs < 0 ? -1 : 0) : Int16(truncatingIfNeeded: Int32(lhs) >> amount) }
                        else { result = amount >= 32 ? 0 : Int16(truncatingIfNeeded: Int32(lhs) << amount) }
                    case 0xB6: result = shared.random.value(upTo: rhs)
                    case 0xB7: break
                    case 0xB8: track.condition = lhs == rhs
                    case 0xB9: track.condition = lhs >= rhs
                    case 0xBA: track.condition = lhs > rhs
                    case 0xBB: track.condition = lhs <= rhs
                    case 0xBC: track.condition = lhs < rhs
                    case 0xBD: track.condition = lhs != rhs
                    default: break
                    }
                    if index < 16 { variables[index] = result }
                    else { shared.variables[index - 16] = result }
                case 0xC0...0xD6:
                    let value = try argument(opcode: opcode, mode: mode) & 255
                    if execute {
                        switch opcode {
                        case 0xC2: volume = value
                        case 0xC7: track.noteWait = value & 1 != 0
                        case 0xC9:
                            track.lastKey = (value + track.controls[0xC3, default: 0]) & 255
                            track.controls[0xCE] = 1
                        case 0xD4:
                            if track.stack.count < 3 { track.stack.append(.init(address: track.pc, repeats: value)) }
                        case 0xD6: break
                        default: track.controls[opcode] = value
                        }
                        events.append(.control(track: id, opcode: opcode, value: value))
                    }
                case 0xE0, 0xE1, 0xE3:
                    let value = try argument(opcode: opcode, mode: mode) & 0xFFFF
                    if execute {
                        if opcode == 0xE1 { tempo = value }
                        else { track.controls[opcode] = value }
                        events.append(.control(track: id, opcode: opcode, value: value))
                    }
                case 0xFC:
                    if execute, var frame = track.stack.last {
                        if frame.repeats != 0 { frame.repeats -= 1 }
                        if track.stack.last?.repeats == 0 || frame.repeats != 0 {
                            track.pc = frame.address
                            track.stack[track.stack.count - 1] = frame
                        } else { track.stack.removeLast() }
                    }
                case 0xFD:
                    if execute, let frame = track.stack.popLast() { track.pc = frame.address }
                case 0xFE: break // Allocation is consumed once at sequence initialization.
                case 0xFF:
                    if execute { track.ended = true; events.append(.endTrack(id)) }
                default: throw OriginalAudioError.unsupportedSequenceCommand(opcode, offset)
                }
            }
            tracks[id] = track
        }
        tick += 1
        return events
    }
}
