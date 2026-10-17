import Foundation

/// Runs original BLK events through the recovered selector, condition, state
/// and completion transcriptions. The runner stops at the first operation,
/// exit mode or process whose original behavior is not recovered. It never
/// skips a story command to keep playing.
public struct OriginalEventRunner: Sendable {
    public struct Halt: Equatable, Sendable {
        public let reason: String
        public let program: String
        public let eventIndex: Int?
        public let sourceOffset: Int?
    }

    public enum Phase: Equatable, Sendable {
        /// The original text state (controller 0x1C = 0x10) waits for a tap.
        case dialogue(OriginalDialoguePacket)
        /// Event mode 15 runs the process from byte 16 + 23 before its exit.
        case process(id: UInt16)
        /// Opcode 11 blocks the stated number of original updates.
        case waiting(updates: Int)
        /// A normal event ended without a CHK transition. The original returns
        /// to map exploration, which this rewrite has not recovered.
        case exploration(mapID: Int16)
        case halted(Halt)
    }

    /// Opcodes whose dispatcher cases (0x0203BC9C) only change controller or
    /// display state: portraits and backgrounds (3, 26, 27, 28), animation
    /// start and wait (43, 44), and empty cases. They do not write game state.
    public static let presentationOpcodes: Set<UInt8> = [0, 1, 2, 3, 5, 7, 14, 20, 22, 26, 27, 28, 38, 43, 44, 48]

    public let program: OriginalScriptProgram
    public private(set) var game: OriginalGameState
    public private(set) var session: OriginalEventSession
    public private(set) var phase: Phase
    public private(set) var eventIndex: Int?
    /// Presentation commands that the native renderer does not draw yet.
    public private(set) var unrenderedPresentation: [String] = []
    private let graph: OriginalBlockGraph
    private let conditions: OriginalConditions
    private var operations: [OriginalBlockGraph.Record] = []
    private var operationIndex = 0
    private var processReturn: Int16 = 0

    /// New game state, then the hotel arrival trigger (0x0202899C) in
    /// EP1_R102 with previous map 1. The reference runner reaches this
    /// event after the opening; the opening itself is not run here.
    public static func chapterOneArrival(catalog: OriginalScriptCatalog,
                                         defaults: OriginalStateDefaults,
                                         timestamp: Int64? = nil) throws -> Self {
        var game = try OriginalGameState.newGame(defaults: defaults, timestamp: timestamp)
        game.setMap(2, previous: 1)
        return try Self(program: catalog.loadProgram("EP1_R102"), game: game)
    }

    public init(program: OriginalScriptProgram, game: OriginalGameState) throws {
        self.program = program
        self.game = game
        graph = try program.blocks
        conditions = try program.conditions
        session = .mapSession(nowTime: game.nowTime, mapID: game.mapID)
        phase = .exploration(mapID: game.mapID)
        var evaluating = session
        let state = game, checks = conditions
        let outcome = try OriginalArrivalSelector.select(graph: graph, previousMapID: game.previousMapID,
            nowTime: game.nowTime, mapID: game.mapID) {
                try evaluating.evaluate($0, conditions: checks, game: state)
            }
        session = evaluating
        enter(outcome)
    }

    /// The player dismissed the current text page.
    public mutating func acknowledgeDialogue() {
        guard case .dialogue(let packet) = phase else { return }
        operationIndex += packet.consumedRecordCount
        run()
    }

    /// One original controller update while a wait is active.
    public mutating func advanceWait() {
        guard case .waiting(let updates) = phase else { return }
        if updates > 1 { phase = .waiting(updates: updates - 1) }
        else { operationIndex += 1; run() }
    }

    /// The embedded process finished with its process-manager return value.
    public mutating func finishProcess(returnValue: Int16) {
        guard case .process = phase else { return }
        processReturn = returnValue
        run()
    }

    public mutating func halt(_ reason: String, sourceOffset: Int? = nil) {
        phase = .halted(Halt(reason: reason, program: program.name, eventIndex: eventIndex,
                             sourceOffset: sourceOffset))
    }

    private mutating func enter(_ outcome: OriginalEventSelector.Outcome) {
        switch outcome {
        case .selected(let selection):
            begin(eventIndex: selection.eventIndex)
        case .noMatch:
            halt("No original event matches scene \(session.selection.sceneID), mode \(session.selection.modeID), event \(session.selection.eventID)")
        case .unresolved(let candidate, let condition):
            halt("Condition state is not recovered: \(condition)", sourceOffset: candidate.eventSourceOffset)
        }
    }

    private mutating func begin(eventIndex index: Int) {
        eventIndex = index
        processReturn = 0
        do {
            operations = try graph.operations(forEvent: index)
            operationIndex = Int(max(0, session.operationIndex))
            if let process = try OriginalEventCompletion.embeddedProcessID(event: graph.tables[2][index]) {
                phase = .process(id: process)
                return
            }
        } catch {
            return halt("Event \(index) could not be decoded: \(error)", sourceOffset: graph.tables[2][index].sourceOffset)
        }
        run()
    }

    /// Executes operations until one needs the player, a timer or a process.
    private mutating func run() {
        while operationIndex < operations.count {
            let record = operations[operationIndex]
            let opcode = record.raw[0]
            do {
                switch opcode {
                case 4:
                    let following = operationIndex + 1 < operations.count ? operations[operationIndex + 1] : nil
                    phase = .dialogue(try OriginalDialoguePacket(record: record, following: following, text: program.text))
                    return
                case 11:
                    // 0x0203BDE4: a positive limit blocks limit + 2 updates.
                    let limit = Int(try OriginalBytes(record.raw).u16(2))
                    if limit > 0 { phase = .waiting(updates: limit + 2); return }
                case 12, 18, 24, 29, 30, 35, 49:
                    try game.apply(OriginalOperation(record: record))
                case _ where Self.presentationOpcodes.contains(opcode):
                    unrenderedPresentation.append("op\(opcode)@\(record.sourceOffset)")
                default:
                    guard let command = try OriginalStateCommand(record: record) else {
                        return halt("Operation \(opcode) is not recovered", sourceOffset: record.sourceOffset)
                    }
                    try game.apply(command)
                }
            } catch {
                return halt("Operation \(opcode) failed: \(error)", sourceOffset: record.sourceOffset)
            }
            operationIndex += advance(after: record)
        }
        complete()
    }

    /// Common advancement at 0x0203CE70, plus opcode 3's paired-screen read.
    private func advance(after record: OriginalBlockGraph.Record) -> Int {
        var last = record, count = 1
        if record.raw[0] == 3, operationIndex + 1 < operations.count {
            let next = operations[operationIndex + 1]
            if next.raw[0] == 3, next.raw[1] != record.raw[1] { last = next; count = 2 }
        }
        return last.raw[1] == 2 ? count + 1 : count
    }

    /// 0x0203D61C: record completion in the current map's event bank, then
    /// follow the event's CHK exit transition.
    private mutating func complete() {
        guard let index = eventIndex else { return }
        let event = graph.tables[2][index]
        let reader = OriginalBytes(event.raw)
        guard let key = try? Int16(bitPattern: reader.u16(4)) else {
            return halt("Event key is truncated", sourceOffset: event.sourceOffset)
        }
        game.markEventCompleted(group: game.mapID, event: key)
        let result: OriginalEventCompletion.Result
        do {
            result = try OriginalEventCompletion.stateOnlyExit(event: event, conditions: conditions,
                                                               processReturn: processReturn)
        } catch {
            return halt("Event exit failed: \(error)", sourceOffset: event.sourceOffset)
        }
        switch result {
        case .requiresOriginalHandler(let mode):
            halt("Exit handler for event mode \(mode) is not recovered", sourceOffset: event.sourceOffset)
        case .completed(let completion):
            completion.apply(to: &session)
            guard completion.transition != nil else {
                eventIndex = nil
                phase = .exploration(mapID: game.mapID)
                return
            }
            selectNext()
        }
    }

    private mutating func selectNext() {
        var context = session.selection
        context.nowTime = game.nowTime
        context.mapID = game.mapID
        var evaluating = session
        let state = game, checks = conditions
        do {
            let outcome = try OriginalEventSelector.select(graph: graph, context: context,
                evaluate: { try evaluating.evaluate($0, conditions: checks, game: state) },
                applyEffect: { evaluating.apply($0) })
            session = evaluating
            enter(outcome)
        } catch {
            halt("Event selection failed: \(error)")
        }
    }
}
