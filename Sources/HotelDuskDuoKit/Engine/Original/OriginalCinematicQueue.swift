import Foundation

/// Native scheduling from 0x020A1A5C. A newly activated command first runs on
/// the next original update. Unsupported scene actions must throw in the host.
public struct OriginalCinematicQueue: Sendable {
    public enum Result: Equatable, Sendable { case waiting, complete }
    public struct Active: Codable, Equatable, Sendable {
        public let commandIndex: Int
        public var updateCount: UInt64
        public var waitCounter: UInt16
        /// A native handler's Codable state, retained across book closure.
        public var handlerState: Data
    }
    public struct Checkpoint: Codable, Equatable, Sendable {
        public let commandDigest: String
        public var nextCommandIndex: Int
        public var active: Active?
        public var updateCount: UInt64
        public var isFinished: Bool
    }

    public let program: OriginalCinematicProgram
    public private(set) var state: Checkpoint

    public init(program: OriginalCinematicProgram) {
        self.program = program
        state = Checkpoint(commandDigest: program.commandDigest, nextCommandIndex: 0,
                           active: nil, updateCount: 0, isFinished: false)
    }

    public mutating func restore(_ checkpoint: Checkpoint) throws {
        guard checkpoint.commandDigest == program.commandDigest,
              (0...program.commands.count).contains(checkpoint.nextCommandIndex),
              checkpoint.active.map({ program.commands.indices.contains($0.commandIndex)
                  && $0.commandIndex + 1 == checkpoint.nextCommandIndex }) ?? true,
              !checkpoint.isFinished || (checkpoint.active == nil && checkpoint.nextCommandIndex == program.commands.count) else {
            throw OriginalDataError.invalid("Cinematic checkpoint does not match source program")
        }
        state = checkpoint
    }

    /// Call once per original frame. A paused book does not call this method.
    /// The host handles resource completion, rendering, audio and scene actions.
    /// It must not treat an unknown command as complete.
    @discardableResult
    public mutating func update(host: (OriginalCinematicRecord, inout Active) throws -> Result) throws -> Bool {
        guard !state.isFinished else { return false }
        var next = state
        if var active = next.active {
            let command = program.commands[active.commandIndex]
            let result: Result
            if command.handlerAddress == 0x020A3B34 {
                let limit = try command.unsigned16(4)
                if active.waitCounter < limit { active.waitCounter += 1 }
                result = active.waitCounter < limit ? .waiting : .complete
            } else {
                result = try host(command, &active)
            }
            active.updateCount &+= 1
            next.active = result == .waiting ? active : nil
        }
        if next.active == nil {
            if next.nextCommandIndex < program.commands.count {
                let index = next.nextCommandIndex
                let command = program.commands[index]
                let counter = command.handlerAddress == 0x020A3B34 ? try command.unsigned16(6) : 0
                next.active = Active(commandIndex: index, updateCount: 0, waitCounter: counter, handlerState: Data())
                next.nextCommandIndex += 1
            } else {
                next.isFinished = true
            }
        }
        next.updateCount &+= 1
        state = next
        return !next.isFinished
    }
}
