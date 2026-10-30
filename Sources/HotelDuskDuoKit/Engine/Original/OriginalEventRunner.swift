import Foundation

/// Runs original BLK events through the recovered selector, condition, state
/// and completion transcriptions. The runner stops at the first operation,
/// exit mode or process whose original behavior is not recovered. It never
/// skips a story command to keep playing.
public struct OriginalEventRunner: Sendable {
    private var inventoryProcess: OriginalInventoryProcessTable.Record?
    var hasInventoryProcess: Bool { inventoryProcess != nil }
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
        /// A normal event ended without a CHK transition. The host resumes map exploration.
        case exploration(mapID: Int16)
        /**
         * Ordinary choices and chapter reviews use UI state 0x6F (0x0203CE9C).
         */
        case choice([Choice])
        /// Opcode 6 (0x0203FBFC): text pages announcing an item just added.
        case itemNotice(itemID: UInt8, page: OriginalDialoguePacket.Page)
        /**
         * Opcode 8 waits for the original touch-picture process to return.
         */
        case picture(id: UInt16)
        /// Event modes 7 and 8 open the question menu (UI state 0x6F, +0x64 = 0).
        case questions([Topic])
        case halted(Halt)
    }

    /// A keyword the partner can be asked about, from the chapter `.ttk`.
    public struct Topic: Equatable, Sendable {
        public let keyword: Int16
        public let label: String
    }

    /**
     * KIF field 0 names the answer event; field 3 identifies the option in the native menu.
     */
    public struct Choice: Equatable, Sendable {
        public let id: UInt16
        public let eventID: UInt16
        public let label: String
    }

    /**
     * Preserves the story event and selector state that created an embedded process.
     */
    public struct EmbeddedProcessInvocation: Equatable, Sendable {
        public let processID: UInt16
        public let programName: String
        public let eventIndex: Int
        public let eventSourceOffset: Int
        public let eventBytes: Data
        public let selection: OriginalEventSelectionContext
    }

    /// Opcodes whose dispatcher cases (0x0203BC9C) only change controller or
    /// display state: portraits and backgrounds (3, 26, 27, 28), animation
    /// start and wait (43, 44), and empty cases. They do not write game state.
    public static let presentationOpcodes: Set<UInt8> = [0, 1, 2, 3, 5, 7, 14, 20, 22, 26, 27, 28, 38, 43, 44, 48]
    /// Opcode 9 (handler 0x0203C474) calls 0x020401EC, which only sets the advance flag at
    /// controller +0x8C (already set on entry) and returns 0.
    public static let advanceOnlyOpcodes: Set<UInt8> = [9]
    /// Handler 0x0203C4AC: these opcodes push (s8 byte 2, s16 at 4)
    /// with 0x020971D0. Opcode 16 has a separate clock-process handler.
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
    public private(set) var embeddedProcessInvocation: EmbeddedProcessInvocation?
    /// Presentation commands that the native renderer does not draw yet.
    public private(set) var unrenderedPresentation: [String] = []
    public private(set) var processRequests: [ProcessRequest] = []
    public private(set) var timeTransition: OriginalTimeTransition?
    private var routeTrace: OriginalRouteTraceLog?
    private let graph: OriginalBlockGraph
    private let conditions: OriginalConditions
    private let scope: OriginalProgramScope
    private var operations: [OriginalBlockGraph.Record] = []
    private var operationIndex = 0
    private var processReturn: Int16 = 0
    /// The chapter keyword table; the question menu stops without it.
    public let keywords: OriginalKeywordTable?
    /// Controller +0x0C: the conversation partner, from the session scene ID.
    public private(set) var partner: Int16?
    /// Controller +0x66: the block holding the menu's answers and exit.
    private var askBlock: Int16 = -1
    private var questionOrder: [Int16] = []
    public private(set) var reviewQuestionIndex = 0
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

    /// Enables structured selector, operation and process-return observations.
    public mutating func attachRouteTrace(_ trace: OriginalRouteTraceLog?) {
        routeTrace = trace
    }

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
                keywords: OriginalKeywordTable? = nil,
                selection: OriginalEventSelectionContext? = nil,
                scope: OriginalProgramScope = .normal, deferArrival: Bool = false) throws {
        self.program = program
        self.game = game
        self.keywords = keywords
        self.scope = scope
        graph = try program.blocks
        conditions = try program.conditions
        session = .mapSession(nowTime: game.nowTime, mapID: game.mapID)
        phase = .exploration(mapID: game.mapID)
        if deferArrival { return }
        if let selection {
            session.selection = selection
            session.eventCommitted = true
            selectNext()
            return
        }
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
    /// The host supplies the picked `objNN` result (0x02033528). The native
    /// R102 counter route provides it through original model hit geometry.
    public mutating func lookInSearchView(area: UInt16, subarea: UInt16, table: OriginalSearchTable) {
        guard case .exploration = phase else { return }
        switch OriginalSearchSelection.look(table: table, mapID: game.mapID, nowTime: game.nowTime,
                                            area: area, subarea: subarea) {
        case .look(let context), .closeup(let context, _):
            interrupt = Interrupt()
            var fresh = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
            fresh.selection = context
            fresh.eventCommitted = true
            session = fresh
            selectNext()
        }
    }

    /**
     * Process 98 selects mode 11 with the confirmed layer's event ID (0x02062038).
     */
    public mutating func lookInCloseup(area: UInt16, subarea: UInt16, event: Int16) {
        lookInCloseup(area: area, subarea: subarea, event: event, mode: 11)
    }

    /**
     * 0x02062C08 selects mode 12 after the detail image has loaded.
     */
    public mutating func lookInCloseupDetail(area: UInt16, subarea: UInt16, event: Int16) {
        lookInCloseup(area: area, subarea: subarea, event: event, mode: 12)
    }

    /**
     * Resumes R125's pending search request with the recovered word-entry event.
     */
    public mutating func beginChapterNineWordEntry(area: UInt16, subarea: UInt16, upView: Int16) {
        guard program.name == "EP9_R125",
              game.applePaintingFoundMask & 0x1f == 0x1f,
              case .exploration = phase else { return }
        var fresh = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        fresh.selection.sceneID = 0xFFFE
        fresh.selection.modeID = 15
        fresh.selection.eventID = 5
        fresh.selection.areaID = area
        fresh.selection.subareaID = subarea
        fresh.selection.upViewID = upView
        fresh.eventCommitted = true
        session = fresh
        interrupt = Interrupt()
        selectNext()
    }

    private mutating func lookInCloseup(area: UInt16, subarea: UInt16, event: Int16, mode: UInt16) {
        guard case .exploration = phase else { return }
        var fresh = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        fresh.selection.sceneID = 0xFFFE
        fresh.selection.blockID = 0
        fresh.selection.modeID = mode
        fresh.selection.eventID = 0
        fresh.selection.areaID = area
        fresh.selection.subareaID = subarea
        fresh.selection.upViewID = event
        fresh.eventCommitted = true
        session = fresh
        interrupt = Interrupt()
        selectNext()
    }

    /**
     * 0x0203A444 tries System after a search, close-up or door selection finds no event.
     */
    public func searchFallback(catalog: OriginalScriptCatalog) throws -> Self? {
        guard scope == .normal, case .exploration = phase, eventIndex == nil,
              let context = lastSelectionMiss, context == session.selection,
              ((10...14).contains(context.modeID) || context.modeID == 16) else { return nil }
        return try Self(program: catalog.loadProgram("System"), game: game,
                        selection: context, scope: .system)
    }

    /**
     * Restores the map runner after its shared search response ends.
     */
    public mutating func resumeSearch(after response: Self) {
        guard case .exploration = phase, case .exploration = response.phase, response.scope == .system else { return }
        game = response.game
        unrenderedPresentation += response.unrenderedPresentation
        processRequests += response.processRequests
        lastSelectionMiss = nil
    }

    /**
     * Search-process state 1 at 0x02031944 selects mode 16 with area, object and item IDs.
     */
    public mutating func useItemInSearchView(_ item: UInt8, area: UInt16, subarea: UInt16) {
        guard case .exploration = phase, (try? game.inventory.items.contains(item)) == true else { return }
        var fresh = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        fresh.selection.sceneID = 0xFFFE
        fresh.selection.blockID = 0
        fresh.selection.eventID = 0
        fresh.selection.modeID = 16
        fresh.selection.areaID = area
        fresh.selection.subareaID = subarea
        fresh.selection.checkItemID = Int16(item)
        fresh.selection.upViewID = -1
        fresh.eventCommitted = true
        session = fresh
        interrupt = Interrupt()
        selectNext()
    }

    /**
     * Close-up state 11 at 0x02063BDC uses mode 16, area FFFF and the selected component event.
     */
    public mutating func useItemInCloseup(_ item: UInt8, event: Int16) {
        useItemInSearchView(item, area: 0xFFFF, subarea: UInt16(bitPattern: event))
    }

    /**
     * Door entry uses mode 13. Component inspection uses mode 14 and item use uses mode 16.
     */
    public mutating func interactWithDoor(area: UInt16, upView: Int16? = nil, item: UInt8? = nil) {
        guard case .exploration = phase else { return }
        var fresh = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        fresh.selection.sceneID = 0xFFFE
        fresh.selection.blockID = 0
        fresh.selection.eventID = 0
        fresh.selection.areaID = item == nil ? area : 0xFFFF
        fresh.selection.subareaID = item == nil ? 1 : UInt16(bitPattern: upView ?? -1)
        fresh.selection.upViewID = item == nil ? upView ?? -1 : -1
        fresh.selection.modeID = item != nil ? 16 : upView == nil ? 13 : 14
        if let item { fresh.selection.checkItemID = Int16(item) }
        fresh.eventCommitted = true
        session = fresh
        interrupt = Interrupt()
        selectNext()
    }

    /**
     * 0x0202DEC4 selects mode 10 when a closed map door has no up-view.
     */
    public mutating func interactWithMapDoor(area: UInt16, subarea: UInt16 = 1) {
        guard case .exploration = phase else { return }
        var fresh = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        fresh.selection.sceneID = 0xFFFE
        fresh.selection.blockID = 0
        fresh.selection.eventID = 0
        fresh.selection.modeID = 10
        fresh.selection.areaID = area
        fresh.selection.subareaID = subarea
        fresh.selection.upViewID = -1
        fresh.eventCommitted = true
        session = fresh
        interrupt = Interrupt()
        selectNext()
    }

    /**
     * Starts a map conversation using the saved person block (0x0202DEC4).
     * The first mode-0 row supplies the event ID through 0x020295B0.
     */
    public mutating func talkToPerson(_ person: Int16) {
        guard case .exploration = phase, let block = game.conversationBlock(map: game.mapID, person: person) else { return }
        let scene = UInt16(bitPattern: person)
        let event = firstEvent(person: scene, block: block, mode: 0) ?? 0
        var fresh = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        fresh.selection.sceneID = scene
        fresh.commit(.init(blockID: block, modeID: 0, eventID: event, operationIndex: 0))
        session = fresh
        interrupt = Interrupt()
        askBlock = -1
        partner = person
        selectNext()
    }

    /**
     * 0x0202E158 starts a normal talk when a map region has a permitted event.
     */
    @discardableResult
    public mutating func enterMapRegion(_ region: UInt16) -> Bool {
        guard case .exploration = phase else { return false }
        var evaluating = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        let state = game, checks = conditions
        do {
            let outcome = try OriginalRegionSelector.select(graph: graph, region: region, nowTime: game.nowTime) {
                try evaluating.evaluate($0, conditions: checks, game: state)
            }
            switch outcome {
            case .noMatch: return false
            case .unresolved: enter(outcome)
            case .selected:
                session = evaluating
                interrupt = Interrupt()
                askBlock = -1
                partner = nil
                selectNext()
            }
        } catch { halt("Map region \(region) could not be selected: \(error)") }
        return true
    }

    /**
     * Returns true when departure starts a script or stops on an unresolved condition.
     */
    @discardableResult
    public mutating func beginMapDeparture(to destination: Int16) -> Bool {
        guard case .exploration = phase else { return false }
        var evaluating = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID)
        let state = game, checks = conditions
        do {
            let outcome = try OriginalRegionSelector.departure(graph: graph, destination: destination, nowTime: game.nowTime) {
                try evaluating.evaluate($0, conditions: checks, game: state)
            }
            switch outcome {
            case .noMatch: return false
            case .unresolved: enter(outcome)
            case .selected:
                session = evaluating
                interrupt = Interrupt()
                askBlock = -1
                partner = nil
                selectNext()
            }
        } catch { halt("Departure to map \(destination) could not be selected: \(error)") }
        return true
    }

    /**
     * Retains game state and applies the destination's arrival selection.
     */
    public func moving(to map: Int16, program: OriginalScriptProgram) throws -> Self {
        var state = game
        state.setMap(map, previous: game.mapID)
        state.markMapVisited()
        return try Self(program: program, game: state, keywords: keywords)
    }

    /**
     * The map host applies the recovered scripted placement to persistent state.
     */
    mutating func setMapPosition(_ position: SIMD3<Float>, facing: Float) {
        game.setMapPosition(position, facing: facing)
    }

    /**
     * The map host consumes the chapter request after the review returns.
     */
    mutating func prepareChapter(_ chapter: UInt16, position: SIMD3<Float>, facing: Float, destination: Int16? = nil) throws {
        try game.beginChapter(chapter)
        game.setMap(destination ?? game.mapID, previous: game.mapID)
        game.setMapPosition(position, facing: facing)
    }

    /**
     * The title uses the source clock table, including its leading space.
     */
    mutating func beginChapterTitle() throws {
        try game.beginChapterTitle(label: OriginalChapter(game.chapter).clockLabel)
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

    /**
     * Resumes after the picture child returns. The following opcode owns item acquisition.
     */
    public mutating func finishPicture() {
        guard case .picture = phase else { return }
        operationIndex += 1
        run()
    }

    /// The player picked an option. 0x0203C3E8 state 0 pushed the return
    /// frame (0x02028564), state 1 marked each listed ID (0x02097C80), and
    /// state 0x6F with +0x64 = 2 sets mode 5 and the option's event
    /// (0x0202824C). The talk process then restores (0x020544BC).
    public mutating func choose(_ id: UInt16) {
        if session.selection.modeID == 24, case .choice(let choices) = phase,
           let picked = choices.first(where: { $0.id == id }) {
            session.commit(.init(blockID: session.selection.blockID, modeID: 17,
                                 eventID: picked.eventID, operationIndex: 0))
            endTalkEvent()
            return
        }
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
        session.selection.modeID = 5
        session.selection.eventID = picked.eventID
        session.operationIndex = 0
        session.eventCommitted = true
        endTalkEvent()
    }

    /// The embedded process finished with its process-manager return value.
    public mutating func finishProcess(returnValue: Int16) {
        guard case .process(let id) = phase, inventoryProcess == nil else { return }
        var fields = traceContextFields()
        fields.merge([
            "processID": String(id), "returnValue": String(returnValue)
        ]) { _, new in new }
        routeTrace?.write(kind: "processReturn", fields: fields)
        embeddedProcessInvocation = nil
        if timeTransition != nil {
            timeTransition = nil
            operationIndex += 1
        }
        // CTrickBase destructor 0x02026DD4 marks the process bit only when
        // its return value is zero. Clock and non-puzzle IDs are excluded by
        // the original puzzle-bit range.
        if returnValue == 0 { game.markPuzzleCompleted(processID: id) }
        processReturn = returnValue
        run()
    }

    /**
     * Stores overlay 38's persistent apple-letter bits while process 64 is active.
     */
    public mutating func storeApplePaintingFoundMask(_ mask: UInt16) {
        guard phase == .process(id: 64) else { return }
        game.applePaintingFoundMask = mask
    }

    /**
     * Overlay 13 stores a completed arrangement when its success branch returns zero.
     */
    public mutating func finishChristmasTree(returnValue: Int16, decorationOrder: UInt16?) {
        guard case .process(43) = phase else { return }
        if returnValue == 0, let decorationOrder {
            game.storeChristmasTreeDecorationOrder(decorationOrder)
        }
        finishProcess(returnValue: returnValue)
    }

    /**
     * The map consumes request 3 after the child and parent talk have returned.
     */
    mutating func consumeTimeRequest(_ value: Int16) {
        game.applyTimeChange(value)
        session.selection.nowTime = game.nowTime
    }

    /**
     * Overlay 12 marks process 37 complete only after the key breaks.
     */
    public mutating func finishSuitcaseKey(returnValue: Int16) {
        guard case .process(37) = phase else { return }
        if returnValue == 0 { game.markPuzzleCompleted(processID: 37) }
        finishProcess(returnValue: returnValue)
    }

    /**
     * Overlay 12 marks the completed wire attempt before the shared script handles its outcome.
     */
    public mutating func finishThinWire(returnValue: Int16) {
        guard case .process(let id) = phase, OriginalThinWireProcess.Variant(rawValue: id) != nil else { return }
        if returnValue == 0 { game.markPuzzleCompleted(processID: id) }
        finishProcess(returnValue: returnValue)
    }

    /**
     * Process 33 marks completion before the lock turns and the suitcase opens.
     */
    public mutating func markThickWireCompleted() {
        guard case .process(33) = phase else { return }
        game.markPuzzleCompleted(processID: 33)
    }

    /**
     * Overlay 24 awards an item before its acquisition animation and shared response.
     */
    public mutating func takeSuitcaseItem(_ item: UInt8) throws {
        guard case .process(35) = phase else { return }
        try game.apply(.addInventory(id: UInt16(item)))
    }

    /**
     * The process 35 destructor always records puzzle flag 11.
     */
    public mutating func finishSuitcaseContents() {
        guard case .process(35) = phase else { return }
        game.markPuzzleCompleted(processID: 35)
        finishProcess(returnValue: 0)
    }

    /**
     * Overlay 4 marks process 32 complete only when the two cuts produce usable wire.
     */
    public mutating func finishHanger(returnValue: Int16) {
        guard case .process(32) = phase else { return }
        if returnValue == 0 { game.markPuzzleCompleted(processID: 32) }
        finishProcess(returnValue: returnValue)
    }

    /**
     * Overlay 6 records a completed memo pull only when the paper tears.
     */
    public mutating func finishMemoPull(returnValue: Int16) {
        guard case .process(27) = phase else { return }
        if returnValue == 0 { game.markPuzzleCompleted(processID: 27) }
        finishProcess(returnValue: returnValue)
    }

    /**
     * Overlay 10 retains the wheel number and marks only a successful cabinet unlock.
     */
    public mutating func finishCabinetDial(returnValue: Int16, retainedValue: UInt16) {
        guard case .process(let processID) = phase, processID == 31 || processID == 80 else { return }
        if processID == 31 { game.storeCabinetDialValue(retainedValue) }
        else { game.storeCashboxDialValue(retainedValue) }
        finishProcess(returnValue: returnValue)
    }

    /**
     * Overlay 5 records process 30 completion only after a successful lift.
     */
    public mutating func finishCrowbar(returnValue: Int16) {
        guard case .process(30) = phase else { return }
        if returnValue == 0 { game.markPuzzleCompleted(processID: 30) }
        finishProcess(returnValue: returnValue)
    }

    /**
     * Overlay 4 records the successful cut before its completion fade and return.
     */
    public mutating func markHangerCutCompleted() {
        guard case .process(32) = phase else { return }
        game.markPuzzleCompleted(processID: 32)
    }

    public mutating func saveRetryCheckpoint() { game.saveRetryCheckpoint() }

    /**
     * Clears the original notebook notification without advancing the parent event.
     */
    public mutating func openNotebook() { game.openNotebook() }

    /// Process 58 stores the jukebox song while the process runs (0x020989D4).
    mutating func setJukeboxSequence(_ id: Int16) {
        guard case .process(58) = phase else { return }
        game.setJukeboxSequence(id)
    }

    /**
     * Stores writable ink while retaining the parent event selection.
     */
    public mutating func storeNotebook(_ notebook: OriginalNotebook) { game.storeNotebook(notebook) }

    public mutating func memoRandomInfo(seed: UInt32) -> UInt16 {
        game.initialisePuzzleRandomInfo(seed: seed)
    }

    /**
     * Starts a table-selected inventory process while retaining the search runner.
     */
    public mutating func beginInventoryProcess(item: UInt8, table: OriginalInventoryProcessTable) throws -> Bool {
        guard scope == .normal, case .exploration = phase,
              let record = try table.process(for: item, game: game) else { return false }
        inventoryProcess = record
        phase = .process(id: record.processID)
        return true
    }

    /**
     * 0x0202830C selects the System response using the inventory row and process result.
     */
    public mutating func finishInventoryProcess(returnValue: Int16, catalog: OriginalScriptCatalog) throws -> Self {
        guard let record = inventoryProcess, phase == .process(id: record.processID), [28, 34].contains(record.processID) else {
            throw OriginalDataError.unsupported("Inventory process completion")
        }
        var returnedGame = game
        if returnValue == 0 { returnedGame.markPuzzleCompleted(processID: record.processID) }
        var context = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0, modeID: 30,
            eventID: 0, nowTime: game.nowTime, mapID: game.mapID)
        context.pairA = record.index
        context.pairB = returnValue
        let response = try Self(program: catalog.loadProgram("System"), game: returnedGame,
                                selection: context, scope: .system)
        game = returnedGame
        inventoryProcess = nil
        phase = .exploration(mapID: game.mapID)
        return response
    }

    /**
     * Keeps missing process presentation visible in the same trace as script presentation.
     */
    public mutating func recordUnrenderedProcessCaption(processID: UInt16, caption: Int) {
        unrenderedPresentation.append("process\(processID):caption\(caption)")
    }

    public mutating func recordUnrenderedRumble(processID: UInt16) {
        unrenderedPresentation.append("process\(processID):rumble")
    }

    /**
     * The jigsaw destructor saves its loose-piece mask before the process returns.
     */
    public mutating func finishJigsaw(returnValue: Int16, looseMask: UInt32) {
        guard case .process(let id) = phase, let variant = OriginalJigsawProcess.Variant(rawValue: id) else { return }
        game.setJigsawMask(looseMask, for: variant)
        finishProcess(returnValue: returnValue)
    }

    /**
     * Mode 20 uses System scene 202 and the pair written by 0x020282A4.
     */
    public func processHint(catalog: OriginalScriptCatalog, pairA: Int16, pairB: Int16) throws -> Self {
        var context = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID).selection
        context.modeID = 20
        context.pairA = pairA
        context.pairB = pairB
        return try Self(program: catalog.loadProgram("System"), game: game, selection: context, scope: .system)
    }

    /**
     * 0x02078138: after the notebook shows a new Mila memo in a conversation, 0x02028328
     * commits mode 31 with the memo index and 0x02098948 marks it read. Mode 31 selects
     * from System scene 203.
     */
    public mutating func readMemo(_ index: Int, catalog: OriginalScriptCatalog) throws -> Self {
        guard case .questions = phase else { throw OriginalDataError.unsupported("Memo outside a conversation") }
        game.markMemoRead(index)
        var context = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: game.mapID).selection
        context.modeID = 31
        context.parameter60 = Int16(index)
        return try Self(program: catalog.loadProgram("System"), game: game, selection: context, scope: .system)
    }

    /// The memo response returns its state; the conversation keeps its question menu.
    public mutating func resumeConversation(after response: Self) {
        guard case .questions = phase, case .exploration = response.phase, response.scope == .system else { return }
        game = response.game
        unrenderedPresentation += response.unrenderedPresentation
        processRequests += response.processRequests
    }

    /**
     * A child hint returns its game state while the parent retains its process and script position.
     */
    public mutating func resumeProcess(after hint: Self) {
        guard case .process = phase, case .exploration = hint.phase, hint.scope == .system else { return }
        game = hint.game
        unrenderedPresentation += hint.unrenderedPresentation
        processRequests += hint.processRequests
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
        if case .exploration = phase { questionOrder.removeAll() }
        eventIndex = index
        // The new event must not inherit the previous event's skipped-page marker.
        interrupt.replayMark = false
        lastSelectionMiss = nil
        eventTrail.append(index)
        processReturn = 0
        embeddedProcessInvocation = nil
        // 0x0203A444 clears the commit byte (0x02028470) once an event is set up.
        session.eventCommitted = false
        // 0x0203A444: a scene ID other than 0xFFFF, 0xFFFE or 0xFFFD names the
        // partner; otherwise the previous partner stays.
        let scene = session.selection.sceneID
        if scene < 0xFFFD { partner = Int16(bitPattern: scene) }
        // 0x0203A444 stores the block for normal and System events (source kind 0 or 1).
        game.rememberConversationBlock(scene: scene, block: session.selection.blockID)
        do {
            operations = try graph.operations(forEvent: index)
            operationIndex = Int(max(0, session.operationIndex))
            if let process = try OriginalEventCompletion.embeddedProcessID(event: graph.tables[2][index]) {
                let event = graph.tables[2][index]
                embeddedProcessInvocation = EmbeddedProcessInvocation(
                    processID: process, programName: program.name, eventIndex: index,
                    eventSourceOffset: event.sourceOffset, eventBytes: event.raw,
                    selection: session.selection)
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

    /**
     * 0x0204B728 appends new questions without moving the existing menu entries.
     */
    private mutating func openQuestions(_ available: [Topic]) {
        let byID = Dictionary(uniqueKeysWithValues: available.map { ($0.keyword, $0) })
        questionOrder.removeAll { byID[$0] == nil }
        for topic in available where !questionOrder.contains(topic.keyword) {
            questionOrder.append(topic.keyword)
        }
        phase = .questions(questionOrder.compactMap { byID[$0] })
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

    /**
     * 0x02045724 selects a shown-item response before returning from the inventory menu.
     */
    public mutating func showItem(_ item: UInt8) {
        guard case .questions = phase, let partner,
              (try? game.inventory.items.contains(item)) == true else { return }
        var evaluating = session
        let state = game, checks = conditions
        do {
            let outcome = try OriginalShownItemSelector.select(graph: graph, person: UInt16(bitPattern: partner),
                item: item, nowTime: game.nowTime) {
                    try evaluating.evaluate($0, conditions: checks, game: state)
                }
            switch outcome {
            case .selected:
                session = evaluating
                session.selection.areaID = .max
                session.selection.subareaID = .max
                session.selection.checkItemID = Int16(item)
                session.operationIndex = 0
                game.markItemShown(item, person: partner)
                interrupt = Interrupt()
                selectNext()
            case .unresolved: enter(outcome)
            case .noMatch: halt("The shared response for showing this item is not recovered")
            }
        } catch { halt("The shown-item response could not be selected: \(error)") }
    }

    /// State 0x6F with no keyword (+0x68 = -1): the partner's mode-4 event in
    /// the menu block (0x020295B0), selected with 0x02028268 or 0x0202824C.
    public mutating func leave() {
        guard case .questions = phase, let partner else { return }
        let block = askBlock >= 1 ? UInt16(bitPattern: askBlock) : session.selection.blockID
        guard let event = firstEvent(person: UInt16(bitPattern: partner), block: block, mode: 4) else {
            return halt("No mode-4 exit for person \(partner) in block \(block)")
        }
        session.commit(.init(blockID: block, modeID: 4, eventID: event, operationIndex: 0))
        endTalkEvent()
    }

    /// 0x020295B0: scene = person, block ID and current time, first matching mode.
    private func firstEvent(person: UInt16, block: UInt16, mode: UInt16) -> UInt16? {
        for scene in graph.tables[0] {
            guard (try? OriginalBytes(scene.raw).u16(0)) == person, let blocks = scene.children else { continue }
            for blockIndex in blocks {
                let row = OriginalBytes(graph.tables[1][blockIndex].raw)
                guard (try? row.u16(0)) == block, (try? row.u16(2)) == game.nowTime,
                      let events = graph.tables[1][blockIndex].children else { continue }
                for index in events {
                    let event = OriginalBytes(graph.tables[2][index].raw)
                    if (try? event.u16(0)) == mode { return try? event.u16(2) }
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
            let trace = routeTrace
            let stateBefore = trace == nil ? nil : game.bytes
            defer {
                if let trace, let stateBefore {
                    let changes = stateBefore.indices.compactMap { index -> String? in
                        let after = game.bytes[index]
                        return stateBefore[index] == after ? nil : "\(index):\(stateBefore[index])->\(after)"
                    }
                    var fields = traceContextFields()
                    fields.merge([
                        "sourceOffset": String(record.sourceOffset), "opcode": String(opcode),
                        "operationIndex": String(operationIndex), "raw": record.raw.map { String(format: "%02x", $0) }.joined(),
                        "stateChanges": changes.joined(separator: ",")
                    ]) { _, new in new }
                    trace.write(kind: "operation", fields: fields)
                }
            }
            do {
                switch opcode {
                case 4:
                    let following = operationIndex + 1 < operations.count ? operations[operationIndex + 1] : nil
                    let packet = try OriginalDialoguePacket(record: record, following: following, text: program.text)
                    // Game-over pages (`%r`) need the recovered failure screen and retry restore.
                    if packet.pages.contains(where: { $0.tokens.contains { if case .control(.retry) = $0.kind { return true }; return false } }) {
                        return halt("The game-over retry sequence is not recovered", sourceOffset: record.sourceOffset)
                    }
                    if session.restoredFromNonDialogue {
                        let skipped = skipReplayedPage(packet, following: following)
                        if interrupt.window || interrupt.keepShared { disarmInterrupt() }
                        if skipped {
                            operationIndex += packet.consumedRecordCount
                            continue
                        }
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
                case 16:
                    let transition = try OriginalTimeTransition(record: record)
                    processRequests.append(transition.request)
                    game.setMap(game.mapID, previous: 0)
                    if transition.presentsClock {
                        try game.setTimeLabel(transition.clockLabel)
                        timeTransition = transition
                        phase = .process(id: 126)
                        return
                    }
                case 8:
                    phase = .picture(id: try OriginalBytes(record.raw).u16(2))
                    return
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
                    /**
                     * 0x0203BC9C marks all options before it opens the choice menu.
                     */
                    try game.apply(.itemCheckFlags(ids))
                    pendingChoice = (record, ids)
                    phase = .choice(choices)
                    return
                case 47:
                    try game.apply(.keywordUnavailable(Int16(bitPattern: OriginalBytes(record.raw).u16(2))))
                    unrenderedPresentation.append("keywordRemoval@\(record.sourceOffset)")
                case 34:
                    // Handler 0x0203C51C pushes the request, then 0x02028240 and 0x020282EC
                    // commit scene 1, mode 29 and block 0 with the value in session +0x3A.
                    let reader = OriginalBytes(record.raw)
                    let value = Int16(bitPattern: try reader.u16(4))
                    processRequests.append(ProcessRequest(kind: Int8(bitPattern: reader.bytes[2]), value: value))
                    session.selection.sceneID = 1
                    session.selection.modeID = 29
                    session.selection.blockID = 0
                    session.selection.parameter58 = value
                    session.eventCommitted = true
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
        var skip = false
        if interrupt.shared == 0 || interrupt.window {
            if !interrupt.window {
                interrupt.shared = 1
                if let following { followUp(dialogueAt: operationIndex, next: following) }
                skip = true
            } else { interrupt.replayMark = true }
        } else {
            if let following { followUp(dialogueAt: operationIndex, next: following) }
            skip = true
        }
        if interrupt.replayMark {
            interrupt.window = false
            interrupt.replayMark = false
            session.restoredFromNonDialogue = false   // 0x020285D4
        }
        return skip
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
        if scope == .normal { game.markEventCompleted(group: game.mapID, event: key) }
        if let mode = try? reader.u16(0), mode == 17 || mode == 24 {
            completeReview(mode: mode, event: event)
            return
        }
        if (try? reader.u16(0)) == 27 {
            guard let topics = topics() else { return halt("The shown-item response needs a conversation partner and keyword table") }
            let transition = key >= 0 && conditions.entries.indices.contains(Int(key))
                ? conditions.entries[Int(key)].second?.first.flatMap { try? OriginalEventTransition(record: $0) } : nil
            session.operationIndex = 0
            if topics.isEmpty, let transition {
                transition.apply(to: &session)
                endTalkEvent()
            } else { openQuestions(topics) }
            return
        }
        if let mode = try? reader.u16(0), [0, 1, 7, 8].contains(mode) {
            return completeConversation(mode: mode, event: event, key: key)
        }
        let result: OriginalEventCompletion.Result
        do {
            result = try OriginalEventCompletion.stateOnlyExit(event: event, conditions: conditions,
                                                               processReturn: processReturn, game: game)
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

    /**
     * 0x0203D61C opens conditional review answers, retries mistakes and advances correct answers.
     */
    private mutating func completeReview(mode: UInt16, event: OriginalBlockGraph.Record) {
        guard let review = program.review, review.questions.indices.contains(reviewQuestionIndex) else {
            return halt("The chapter review question is unavailable", sourceOffset: event.sourceOffset)
        }
        let question = review.questions[reviewQuestionIndex]
        if mode == 24 {
            do {
                let choices = try question.answers.filter { $0.available(in: game) }.map { answer -> Choice in
                    guard let record = program.choices.first(where: { $0.fields[0] == UInt32(answer.eventID) }) else {
                        throw OriginalDataError.missing("Review answer \(answer.eventID)")
                    }
                    return Choice(id: UInt16(truncatingIfNeeded: record.fields[3]), eventID: answer.eventID,
                                  label: String(data: record.labelBytes, encoding: .isoLatin1) ?? "")
                }
                guard !choices.isEmpty else { throw OriginalDataError.invalid("Empty chapter review menu") }
                phase = .choice(choices)
            } catch { halt("The chapter review answers could not be loaded: \(error)", sourceOffset: event.sourceOffset) }
            return
        }
        guard let answer = question.answers.first(where: { $0.eventID == session.selection.eventID }) else {
            return halt("The chapter review answer is unavailable", sourceOffset: event.sourceOffset)
        }
        if answer.advances {
            reviewQuestionIndex += 1
            if question.nextEvent == .max {
                if game.chapter + 1 < 10 { processRequests.append(.init(kind: 4, value: Int16(game.chapter + 1))) }
                endTalkEvent()
                return
            }
        }
        session.commit(.init(blockID: session.selection.blockID, modeID: 24,
                             eventID: answer.advances ? question.nextEvent : question.promptEvent, operationIndex: 0))
        endTalkEvent()
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
            openQuestions(topics)
            return
        case 7:
            // The menu reopens only if an open topic is also one of this
            // event's type-2 records (keyword at s16 offset 4).
            let listed = Set((entry?.first ?? []).filter { $0.raw.first == 2 }.compactMap {
                try? Int16(bitPattern: OriginalBytes($0.raw).u16(4))
            })
            if topics.contains(where: { listed.contains($0.keyword) }) {
                openQuestions(topics)
                return
            }
            transition?.apply(to: &session)
        default:
            defer { if mode == 1 { exhaustKeywords() } }
            if let transition { transition.apply(to: &session) }
            else if !topics.isEmpty, nibble > 0 {
                openQuestions(topics)
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
            let outcome = try OriginalEventSelector.select(graph: graph, context: context, scope: scope,
                evaluate: { try evaluating.evaluate($0, conditions: checks, game: state) },
                applyEffect: { evaluating.apply($0) },
                observeCandidate: { observation in
                    var fields = traceContextFields(context: context)
                    fields["candidateEventIndex"] = String(observation.selection.eventIndex)
                    fields["candidateSourceOffset"] = String(observation.selection.eventSourceOffset)
                    fields["candidateMode"] = String(observation.modeID)
                    fields["candidateEventID"] = String(observation.eventID)
                    fields["conditionKey"] = String(observation.conditionKey)
                    fields["conditionResult"] = String(describing: observation.condition)
                    let conditionOffset = observation.conditionKey >= 0
                        && checks.entries.indices.contains(Int(observation.conditionKey))
                        ? checks.entries[Int(observation.conditionKey)].first?.first?.sourceOffset
                        : observation.conditionSourceOffset
                    if let offset = conditionOffset {
                        fields["conditionSourceOffset"] = String(offset)
                    }
                    if case .unresolvedState(let probe, _) = observation.condition {
                        fields["unresolvedProbe"] = String(describing: probe)
                    } else if case .unrecoveredCondition(let kind, _) = observation.condition {
                        fields["unresolvedProbe"] = "conditionKind:\(kind)"
                    }
                    self.routeTrace?.write(kind: "candidate", fields: fields)
                })
            session = evaluating
            switch outcome {
            case .selected(let selection):
                var fields = traceContextFields(context: context)
                fields.merge([
                    "result": "selected", "eventIndex": String(selection.eventIndex),
                    "sourceOffset": String(selection.eventSourceOffset)
                ]) { _, new in new }
                routeTrace?.write(kind: "selection", fields: fields)
            case .noMatch:
                var fields = traceContextFields(context: context)
                fields["result"] = "noMatch"
                routeTrace?.write(kind: "selection", fields: fields)
            case .unresolved(let candidate, let condition):
                var fields = traceContextFields(context: context)
                fields.merge([
                    "result": "unresolved", "eventIndex": String(candidate.eventIndex),
                    "sourceOffset": String(candidate.eventSourceOffset), "condition": String(describing: condition)
                ]) { _, new in new }
                routeTrace?.write(kind: "selection", fields: fields)
            }
            enter(outcome)
        } catch {
            halt("Event selection failed: \(error)")
        }
    }

    private func traceContextFields(context: OriginalEventSelectionContext? = nil) -> [String: String] {
        let selection = context ?? session.selection
        let inventory = (try? game.inventory.items.map(String.init).joined(separator: ",")) ?? "unknown"
        let requests = processRequests.map { "\($0.kind):\($0.value)" }.joined(separator: ",")
        return [
            "program": program.name, "map": String(game.mapID), "previousMap": String(game.previousMapID),
            "time": String(game.nowTime), "block": String(selection.blockID), "mode": String(selection.modeID),
            "scene": String(selection.sceneID), "event": String(selection.eventID),
            "area": String(selection.areaID), "subarea": String(selection.subareaID),
            "checkItem": String(selection.checkItemID), "inventory": inventory,
            "processRequests": requests,
            "timeTransition": timeTransition.map { "\($0.request.kind):\($0.request.value)" } ?? "none"
        ]
    }
}

extension OriginalEventRunner {
    mutating func restoreWalkingSession(_ saved: OriginalEventSession) throws {
        guard case .exploration = phase else { throw OriginalDataError.invalid("Walking session state") }
        session = saved
    }
}
