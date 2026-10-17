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
        /// Opcode 10 kind 5 hands control to UI state 0x6F (0x0203CE9C).
        case choice([Choice])
        /// Opcode 6 (0x0203FBFC): text pages announcing an item just added.
        case itemNotice(itemID: UInt8, page: OriginalDialoguePacket.Page)
        /// Event modes 7 and 8 open the question menu (UI state 0x6F, +0x64 = 0).
        case questions([Topic])
        case halted(Halt)
    }

    /// One option of an original choice prompt. KIF records carry the label,
    /// the mode-5 event ID in field 0 and the option ID in field 3.
    /// A keyword the partner can be asked about, from the chapter `.ttk`.
    public struct Topic: Equatable, Sendable {
        public let keyword: Int16
        public let label: String
    }

    public struct Choice: Equatable, Sendable {
        public let id: UInt16
        public let eventID: UInt16
        public let label: String
    }

    /// Opcodes whose dispatcher cases (0x0203BC9C) only change controller or
    /// display state: portraits and backgrounds (3, 26, 27, 28), animation
    /// start and wait (43, 44), and empty cases. They do not write game state.
    /// Opcode 8 (0x0203FD30) stores an item picture ID at controller +0x10 and
    /// selects picture state 0x13 or 0x14; it writes no game state.
    public static let presentationOpcodes: Set<UInt8> = [0, 1, 2, 3, 5, 7, 8, 14, 20, 22, 26, 27, 28, 38, 43, 44, 48]
    /// Opcode 9 (handler 0x0203C474) calls 0x020401EC, which only sets the advance flag at
    /// controller +0x8C (already set on entry) and returns 0.
    public static let advanceOnlyOpcodes: Set<UInt8> = [9]
    /// Handler 0x0203C4AC: these opcodes push (s8 byte 2, s16 at 4)
    /// with 0x020971D0. Opcode 16 also compares a string and is excluded.
    public static let processRequestOpcodes: Set<UInt8> = [15, 17, 21, 32, 41, 45]

    /// One entry of the stack at 0x021046B8 (+0x14 base, +0x18 count). The map
    /// and search processes consume it (0x0202C264, 0x020340D0, 0x02064530);
    /// kind 5 makes the search process reload its view. Those processes are
    /// not recovered, so entries are kept for the host and tests.
    public struct ProcessRequest: Equatable, Sendable {
        public let kind: Int8
        public let value: Int16
    }

    public let program: OriginalScriptProgram
    public private(set) var game: OriginalGameState
    public private(set) var session: OriginalEventSession
    public private(set) var phase: Phase
    public private(set) var eventIndex: Int?
    /// Presentation commands that the native renderer does not draw yet.
    public private(set) var unrenderedPresentation: [String] = []
    public private(set) var processRequests: [ProcessRequest] = []
    private let graph: OriginalBlockGraph
    private let conditions: OriginalConditions
    private var operations: [OriginalBlockGraph.Record] = []
    private var operationIndex = 0
    private var processReturn: Int16 = 0
    /// The chapter keyword table; the question menu stops without it.
    public let keywords: OriginalKeywordTable?
    /// Controller +0x0C: the conversation partner, from the session scene ID.
    public private(set) var partner: Int16?
    /// Controller +0x66: the block holding the menu's answers and exit.
    private var askBlock: Int16 = -1
    /// Talk controller fields for the "hold on" interrupt. They persist for
    /// the whole talk, like the controller object that owns them.
    public struct Interrupt: Equatable, Sendable {
        /// +0x96: armed by opcode 9 two records after a page's opcode 5.
        public var armed = false
        /// +0x94: opened by opcode 38 after a page; disarms on that page.
        var window = false
        /// +0x95: opcode 38 three records after the page that armed it.
        var keepShared = false
        /// The short at *(+0xC0), shared with the text window.
        var shared: Int16 = 0
        /// +0x98 and +0x9A: the mode-6 event's block and event IDs.
        var block: UInt16 = 0
        var event: UInt16 = 0
        /// Controller byte +0x3E8, set while skipped `%!` pages are replayed.
        var replayMark = false
    }
    public private(set) var interrupt = Interrupt()
    private var noticePages: [OriginalDialoguePacket.Page] = []
    private var pendingChoice: (record: OriginalBlockGraph.Record, ids: [Int16])?

    /// New game state, then the hotel arrival trigger (0x0202899C) in
    /// EP1_R102 with previous map 1. The reference runner reaches this
    /// event after the opening; the opening itself is not run here.
    public static func chapterOneArrival(catalog: OriginalScriptCatalog,
                                         defaults: OriginalStateDefaults,
                                         timestamp: Int64? = nil) throws -> Self {
        var game = try OriginalGameState.newGame(defaults: defaults, timestamp: timestamp)
        game.setMap(2, previous: 1)
        let program = try catalog.loadProgram("EP1_R102")
        let keywords = try OriginalKeywordTable.chapterFile(for: program.name).map {
            try OriginalKeywordTable(decoded: catalog.decodedFile($0))
        }
        return try Self(program: program, game: game, keywords: keywords)
    }

    public init(program: OriginalScriptProgram, game: OriginalGameState,
                keywords: OriginalKeywordTable? = nil) throws {
        self.program = program
        self.game = game
        self.keywords = keywords
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

    /// The search process look branch for a picked model node. The search
    /// initializer 0x02030B04 allocates a fresh talk session (0x02028160);
    /// 0x02031944 case 0 writes scene 0xFFFE (0x02028240), mode 10 and event
    /// 0 (0x02028360), then block 0, area, subarea and upView (0x0202847C,
    /// which also sets the commit byte +0x44). The talk controller (process
    /// 0x7D) then selects with 0x020551B8.
    ///
    /// The map walk that opens a search area and the 3D search view that picks
    /// `objNN` (0x02033528) are not recovered; callers supply that result.
    public mutating func lookInSearchView(area: UInt16, subarea: UInt16, table: OriginalSearchTable) {
        guard case .exploration = phase else { return }
        switch OriginalSearchSelection.look(table: table, mapID: game.mapID, nowTime: game.nowTime,
                                            area: area, subarea: subarea) {
        case .upViewNotRecovered(let upView):
            halt("Search up view \(upView) (0x020B4A80, .upv) is not recovered")
        case .look(let context):
            interrupt = Interrupt()
            var fresh = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
            fresh.selection = context
            fresh.eventCommitted = true
            session = fresh
            selectNext()
        }
    }

    /// The player dismissed the current text page.
    public mutating func acknowledgeDialogue() {
        switch phase {
        case .dialogue(let packet):
            operationIndex += packet.consumedRecordCount
            run()
        case .itemNotice(let item, _):
            if !noticePages.isEmpty { phase = .itemNotice(itemID: item, page: noticePages.removeFirst()) }
            else { operationIndex += advance(after: operations[operationIndex]); run() }
        default: break
        }
    }

    /// One original controller update while a wait is active.
    public mutating func advanceWait() {
        guard case .waiting(let updates) = phase else { return }
        if updates > 1 { phase = .waiting(updates: updates - 1) }
        else { operationIndex += 1; run() }
    }

    /// The player picked an option. 0x0203C3E8 state 0 pushed the return
    /// frame (0x02028564), state 1 marked each listed ID (0x02097C80), and
    /// state 0x6F with +0x64 = 2 sets mode 5 and the option's event
    /// (0x0202824C). The talk process then restores (0x020544BC).
    public mutating func choose(_ id: UInt16) {
        guard case .choice(let choices) = phase, let picked = choices.first(where: { $0.id == id }),
              let pending = pendingChoice, let index = eventIndex else { return }
        pendingChoice = nil
        let event = graph.tables[2][index]
        let reader = OriginalBytes(event.raw)
        guard let mode = try? reader.u16(0), let eventID = try? reader.u16(2), let blockID = currentBlockID() else {
            return halt("Choice parent event is truncated", sourceOffset: pending.record.sourceOffset)
        }
        if session.savedFrames.count < 64 {
            session.savedFrames.append(.init(blockID: blockID, modeID: mode, eventID: eventID,
                                             operationIndex: Int16(operationIndex + 1)))
        }
        session.restoreOverride = 1
        do { try game.apply(.itemCheckFlags(pending.ids)) }
        catch { return halt("Choice flags failed: \(error)", sourceOffset: pending.record.sourceOffset) }
        session.selection.modeID = 5
        session.selection.eventID = picked.eventID
        session.operationIndex = 0
        session.eventCommitted = true
        endTalkEvent()
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
            // 0x0203A444: no row selected sets +0x14 = 3, which ends the talk.
            lastSelectionMiss = session.selection
            eventIndex = nil
            phase = .exploration(mapID: game.mapID)
        case .unresolved(let candidate, let condition):
            halt("Condition state is not recovered: \(condition)", sourceOffset: candidate.eventSourceOffset)
        }
    }

    /// Every event the runner has entered, in order (for diagnostics and tests).
    public private(set) var eventTrail: [Int] = []
    /// The selection context of the last talk that found no event.
    public private(set) var lastSelectionMiss: OriginalEventSelectionContext?

    private mutating func begin(eventIndex index: Int) {
        eventIndex = index
        eventTrail.append(index)
        processReturn = 0
        // 0x0203A444 clears the commit byte (0x02028470) once an event is set up.
        session.eventCommitted = false
        // 0x0203A444: a scene ID other than 0xFFFF, 0xFFFE or 0xFFFD names the
        // partner; otherwise the previous partner stays.
        let scene = session.selection.sceneID
        if scene < 0xFFFD { partner = Int16(bitPattern: scene) }
        do {
            operations = try graph.operations(forEvent: index)
            operationIndex = Int(max(0, session.operationIndex))
            if let process = try OriginalEventCompletion.embeddedProcessID(event: graph.tables[2][index]) {
                phase = .process(id: process)
                return
            }
            try startMode(event: graph.tables[2][index])
        } catch {
            return halt("Event \(index) could not be decoded: \(error)", sourceOffset: graph.tables[2][index].sourceOffset)
        }
        run()
    }

    /// 0x0203B0A8: mode-specific start of an event, before its operations.
    private mutating func startMode(event: OriginalBlockGraph.Record) throws {
        let reader = OriginalBytes(event.raw)
        let mode = try reader.u16(0), key = Int16(bitPattern: try reader.u16(4))
        let records = key >= 0 && conditions.entries.indices.contains(Int(key)) ? conditions.entries[Int(key)].first ?? [] : []
        switch mode {
        case 1:
            // Topic answers mark the keyword asked by the partner (0x02098440);
            // a nonzero byte 0x11 is the shown-item path instead.
            if reader.bytes[0x11] == 0, let partner {
                game.markKeywordAsked(Int(Int16(bitPattern: try reader.u16(0x12))), person: Int(partner))
            }
        case 3:
            // Type-3 records: if every listed ID is already marked
            // (0x02097CC4 selector 0), the event skips all its operations.
            let marked = try records.filter { $0.raw.first == 3 }.map {
                game.itemCheckFlag(Int16(bitPattern: try OriginalBytes($0.raw).u16(2)))
            }
            if !marked.isEmpty, !marked.contains(false) { operationIndex = operations.count }
        case 7, 8:
            askBlock = -1
            guard let partner else { break }
            for record in records {
                let bytes = OriginalBytes(record.raw)
                let keyword = Int(Int16(bitPattern: try bytes.u16(4)))
                let block = Int16(bitPattern: try bytes.u16(2))
                if !game.keywordAvailable(keyword) || game.keywordUsed(keyword) {
                    if !game.keywordAvailable(keyword) { operationIndex = operations.count }
                    askBlock = block
                    if block != -1 {
                        session.selection.blockID = UInt16(bitPattern: block)
                        session.selection.modeID = 0
                        session.selection.eventID = 0
                    }
                } else if !game.keywordAsked(keyword, person: Int(partner)) {
                    askBlock = block
                    if block != -1 {
                        session.selection.blockID = UInt16(bitPattern: block)
                        session.selection.modeID = 0
                        session.selection.eventID = 0
                    }
                }
            }
        default: break
        }
    }

    /// The question menu built at 0x0203D61C for modes 7 and 8: keywords that
    /// are available, unused, not yet asked of the partner and flagged for
    /// the partner in the `.ttk`. Items the player could show are not listed.
    private func topics() -> [Topic]? {
        guard let keywords, let partner, (0..<16).contains(Int(partner)) else { return nil }
        return keywords.records.compactMap { record in
            let id = record.index
            guard game.keywordAvailable(id), !game.keywordUsed(id),
                  !game.keywordAsked(id, person: Int(partner)), record.personFlags[Int(partner)] != 0 else { return nil }
            return Topic(keyword: Int16(id), label: record.label)
        }
    }

    /// State 0x6F, +0x64 = 0, with a keyword. The topic's answer is a mode-1
    /// event selected by keyword (0x020282D8), in block +0x66 when one is set
    /// (0x02028350). The +0x6C = -1 branch through mode 26 is not recovered.
    public mutating func ask(_ keyword: Int16) {
        guard case .questions(let topics) = phase, topics.contains(where: { $0.keyword == keyword }) else { return }
        if askBlock > 0 { session.selection.blockID = UInt16(bitPattern: askBlock) }
        session.selection.modeID = 1
        session.selection.parameter56 = keyword
        session.selection.eventID = 0
        session.operationIndex = 0
        session.eventCommitted = true
        endTalkEvent()
    }

    /// State 0x6F with no keyword (+0x68 = -1): the partner's mode-4 event in
    /// the menu block (0x020295B0), selected with 0x02028268 or 0x0202824C.
    public mutating func leave() {
        guard case .questions = phase, let partner else { return }
        let block = askBlock >= 1 ? UInt16(bitPattern: askBlock) : session.selection.blockID
        guard let event = leaveEvent(person: UInt16(bitPattern: partner), block: block) else {
            return halt("No mode-4 exit for person \(partner) in block \(block)")
        }
        session.commit(.init(blockID: block, modeID: 4, eventID: event, operationIndex: 0))
        endTalkEvent()
    }

    /// 0x020295B0: scene = person, block ID and current time, first mode-4 row.
    private func leaveEvent(person: UInt16, block: UInt16) -> UInt16? {
        for scene in graph.tables[0] {
            guard (try? OriginalBytes(scene.raw).u16(0)) == person, let blocks = scene.children else { continue }
            for blockIndex in blocks {
                let row = OriginalBytes(graph.tables[1][blockIndex].raw)
                guard (try? row.u16(0)) == block, (try? row.u16(2)) == game.nowTime,
                      let events = graph.tables[1][blockIndex].children else { continue }
                for index in events {
                    let event = OriginalBytes(graph.tables[2][index].raw)
                    if (try? event.u16(0)) == 4 { return try? event.u16(2) }
                }
            }
        }
        return nil
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
                    let packet = try OriginalDialoguePacket(record: record, following: following, text: program.text)
                    if session.restoredFromNonDialogue, skipReplayedPage(packet, following: following) {
                        operationIndex += packet.consumedRecordCount
                        continue
                    }
                    if let following { followUp(dialogueAt: operationIndex, next: following) }
                    // Text state 0x10 disarms on the first update of a page
                    // whose window is open (0x0203D43C).
                    if interrupt.window || interrupt.keepShared { disarmInterrupt() }
                    phase = .dialogue(packet)
                    return
                case _ where session.restoredFromNonDialogue:
                    // 0x0203BEA0: during a replay every other opcode is skipped.
                    break
                case 11:
                    // 0x0203BDE4: a positive limit blocks limit + 2 updates.
                    let limit = Int(try OriginalBytes(record.raw).u16(2))
                    if limit > 0 { phase = .waiting(updates: limit + 2); return }
                case 12, 18, 24, 29, 30, 35, 49:
                    try game.apply(OriginalOperation(record: record))
                case _ where Self.advanceOnlyOpcodes.contains(opcode):
                    break
                case _ where Self.processRequestOpcodes.contains(opcode):
                    let reader = OriginalBytes(record.raw)
                    processRequests.append(ProcessRequest(kind: Int8(bitPattern: reader.bytes[2]),
                                                          value: Int16(bitPattern: try reader.u16(4))))
                case 6:
                    // State 1 adds the item with 0x02097914 and opens a text
                    // window: u16 at 8 is the first line, u16 at 10 the page count.
                    let reader = OriginalBytes(record.raw)
                    let item = UInt8(truncatingIfNeeded: try reader.u16(2))
                    try game.apply(.addInventory(id: UInt16(item)))
                    let first = Int(try reader.u16(8)), count = Int(try reader.u16(10))
                    guard count > 0, first + count * 3 <= program.text.entries.count else {
                        throw OriginalDataError.invalid("Item notice text bounds")
                    }
                    noticePages = try (0..<count).map { page in
                        let entries = Array(program.text.entries[(first + page * 3)..<(first + page * 3 + 3)])
                        var tokens: [OriginalDialogueToken] = []
                        for entry in entries {
                            tokens += try OriginalDialogueControl.tokens(for: entry)
                            tokens.append(.init(textIndex: entry.index, byteOffset: entry.bytes.count, kind: .glyph(10)))
                        }
                        return OriginalDialoguePacket.Page(page: 1, entries: entries, tokens: tokens)
                    }
                    phase = .itemNotice(itemID: item, page: noticePages.removeFirst())
                    return
                case 10 where try OriginalBytes(record.raw).u16(4) == 5:
                    let reader = OriginalBytes(record.raw)
                    let count = Int(try reader.u16(2))
                    guard count <= 5 else { throw OriginalDataError.invalid("Choice list exceeds command") }
                    let ids = try (0..<count).map { Int16(bitPattern: try reader.u16(6 + $0 * 2)) }
                    let choices = try ids.map { id -> Choice in
                        guard let kif = program.choices.first(where: { $0.fields[3] == UInt32(UInt16(bitPattern: id)) }) else {
                            throw OriginalDataError.missing("KIF option \(id)")
                        }
                        return Choice(id: UInt16(bitPattern: id), eventID: UInt16(truncatingIfNeeded: kif.fields[0]),
                                      label: String(data: kif.labelBytes, encoding: .isoLatin1) ?? "")
                    }
                    pendingChoice = (record, ids)
                    phase = .choice(choices)
                    return
                case 52, 53:
                    // Handlers 0x0203CABC and 0x0203CAD0: fixed kinds 10 and 11, value 0.
                    processRequests.append(ProcessRequest(kind: opcode == 52 ? 10 : 11, value: 0))
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

    /// 0x0203F57C first update while session +0x2DA is set: replayed pages
    /// after an interrupt. Returns true when the page is skipped.
    private mutating func skipReplayedPage(_ packet: OriginalDialoguePacket, following: OriginalBlockGraph.Record?) -> Bool {
        let first = packet.pages.first?.entries.first?.bytes ?? Data()
        if first.starts(with: [0x25, 0x21]) { interrupt.replayMark = true; return true }   // "%!"
        if first.starts(with: [0x25, 0x3F]) { return true }                                // "%?"
        if interrupt.shared == 0 || interrupt.window {
            if !interrupt.window {
                interrupt.shared = 1
                if let following { followUp(dialogueAt: operationIndex, next: following) }
                return true
            }
            interrupt.replayMark = true
        } else {
            if let following { followUp(dialogueAt: operationIndex, next: following) }
            return true
        }
        if interrupt.replayMark {
            interrupt.window = false
            interrupt.replayMark = false
            session.restoredFromNonDialogue = false   // 0x020285D4
        }
        return false
    }

    /// 0x020401FC with the record after a dialogue command.
    private mutating func followUp(dialogueAt index: Int, next: OriginalBlockGraph.Record) {
        switch next.raw[0] {
        case 5:
            // 0x0204033C: opcode 9 two records after the page arms the interrupt.
            guard index + 2 < operations.count, operations[index + 2].raw[0] == 9 else { return }
            interrupt.window = false
            interrupt.armed = true
            interrupt.block = currentBlockID() ?? 0
            interrupt.event = (try? OriginalBytes(operations[index + 2].raw).u16(2)) ?? 0
            if index + 3 < operations.count, operations[index + 3].raw[0] == 38 {
                interrupt.keepShared = true
                interrupt.shared = 0
            }
        case 33:
            if let id = try? OriginalBytes(next.raw).u16(2) { try? game.apply(.flag12FE(index: id)) }
        case 38:
            interrupt.window = true
            interrupt.shared = 0
        default: break
        }
    }

    private mutating func disarmInterrupt() {
        interrupt.armed = false
        if !interrupt.keepShared { interrupt.shared = 1 }
    }

    /// The pulsing interrupt icon is shown in text state 0x10 while armed.
    public var interruptAvailable: Bool {
        if case .dialogue = phase { return interrupt.armed }
        return false
    }

    /// State 0x10 with +0x70 > 0 (0x0203D3B8): save the current page, select
    /// the armed mode-6 event, disarm, and end this talk event.
    public mutating func pressInterrupt() {
        guard interruptAvailable, let index = eventIndex, let block = currentBlockID() else { return }
        let reader = OriginalBytes(graph.tables[2][index].raw)
        guard let mode = try? reader.u16(0), let eventID = try? reader.u16(2) else { return }
        if session.savedFrames.count < 64 {
            session.savedFrames.append(.init(blockID: block, modeID: mode, eventID: eventID,
                                             operationIndex: Int16(operationIndex)))
        }
        session.restoreOverride = 1
        session.commit(.init(blockID: interrupt.block, modeID: 6, eventID: interrupt.event, operationIndex: 0))
        disarmInterrupt()
        interrupt.keepShared = false
        endTalkEvent()
    }

    private func currentBlockID() -> UInt16? {
        guard let index = eventIndex,
              let block = graph.tables[1].first(where: { $0.children?.contains(index) == true }) else { return nil }
        return try? OriginalBytes(block.raw).u16(0)
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
        if let mode = try? reader.u16(0), [0, 1, 7, 8].contains(mode) {
            return completeConversation(mode: mode, event: event, key: key)
        }
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
            endTalkEvent()
        }
    }

    /// 0x0203D61C for conversation modes 0, 1, 7 and 8.
    private mutating func completeConversation(mode: UInt16, event: OriginalBlockGraph.Record, key: Int16) {
        let entry = key >= 0 && conditions.entries.indices.contains(Int(key)) ? conditions.entries[Int(key)] : nil
        let exit = entry?.second?.first
        let transition = exit.flatMap { try? OriginalEventTransition(record: $0) }
        guard let topics = topics() else {
            return halt("Question menu needs the chapter keyword table and a partner", sourceOffset: event.sourceOffset)
        }
        let nibble = game.personNibble(Int(partner ?? 0))
        switch mode {
        case 8:
            phase = .questions(topics)
            return
        case 7:
            // The menu reopens only if an open topic is also one of this
            // event's type-2 records (keyword at s16 offset 4).
            let listed = Set((entry?.first ?? []).filter { $0.raw.first == 2 }.compactMap {
                try? Int16(bitPattern: OriginalBytes($0.raw).u16(4))
            })
            if topics.contains(where: { listed.contains($0.keyword) }) {
                phase = .questions(topics)
                return
            }
            transition?.apply(to: &session)
        default:
            defer { if mode == 1 { exhaustKeywords() } }
            if let transition { transition.apply(to: &session) }
            else if !topics.isEmpty, nibble > 0 {
                phase = .questions(topics)
                return
            }
        }
        endTalkEvent()
    }

    /// 0x02055CF0 after every answer: an open keyword is used up when a
    /// flag-1 person was asked, or when every flag-3 person was asked.
    private mutating func exhaustKeywords() {
        guard let keywords else { return }
        for record in keywords.records where game.keywordAvailable(record.index) && !game.keywordUsed(record.index) {
            var anyFlagOne = false, allFlagThree = true, anyFlagThree = false
            for person in 0..<16 {
                switch record.personFlags[person] {
                case 1: if game.keywordAsked(record.index, person: person) { anyFlagOne = true }
                case 3:
                    anyFlagThree = true
                    if !game.keywordAsked(record.index, person: person) { allFlagThree = false }
                default: break
                }
            }
            if anyFlagOne || (allFlagThree && anyFlagThree) { game.markKeywordUsed(record.index) }
        }
    }

    /// 0x020544BC: restore a saved frame or follow a committed selection;
    /// otherwise the talk ends and the map resumes.
    private mutating func endTalkEvent() {
        if session.restoreCloseupContext() { return selectNext() }
        eventIndex = nil
        phase = .exploration(mapID: game.mapID)
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
