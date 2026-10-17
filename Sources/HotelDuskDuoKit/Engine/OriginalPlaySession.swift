import Foundation
import Combine
import CoreGraphics

/// Hosts the recovered route through the start of Chapter 2: the original event
/// runner, the entrance process at the DS update rate, and original audio.
/// Systems that are not recovered stop play with their source location.
@MainActor
public final class OriginalPlaySession: ObservableObject {
    /// 33,513,982 Hz / (6 × 355 × 263): the DS video update rate.
    public static let updatesPerSecond = 59.8261

    public struct EntranceScene: Equatable {
        /// Index into the original u01–u03 and d01–d03 panels.
        public var panel: Int
        public var sceneVisible: Bool
        public var awaitingHandle: Bool
    }

    public struct BellScene: Equatable {
        /// Field +0x444; the draw at 0x021FD7B4 rotates bell01 by it. The
        /// native view does not apply the rotation yet.
        public var angle: Float
        public var awaitingTouch: Bool
        public var quitEnabled: Bool
    }

    @Published public private(set) var chapterTransition: OriginalChapterTransition?
    public private(set) var chapterTitleImages: OriginalChapterTitleImages?
    private let saveStore: any OriginalChapterSaveStore
    private let saveDate: () -> Date
    @Published public private(set) var searchItem: UInt8?
    @Published public private(set) var notebook: OriginalNotebook?
    @Published public private(set) var notebookImage: CGImage?
    private var notebookTouch: SIMD2<Int>?
    @Published public private(set) var runner: OriginalEventRunner
    @Published public private(set) var entrance: EntranceScene?
    @Published public private(set) var bell: BellScene?

    public struct SignScene: Equatable {
        public var strokes: [Int16]
        public var awaitingStroke: Bool
        public var quitEnabled: Bool
    }
    @Published public private(set) var sign: SignScene?
    @Published public private(set) var jigsaw: OriginalJigsawProcess?
    @Published public private(set) var clock: OriginalClockProcess?
    @Published public private(set) var clockImage: CGImage?
    private var clockRenderer: OriginalClockRenderer?
    private var clockUpdates: UInt64 = 0
    private var resumesWalkingAfterClock = false
    @Published public private(set) var suitcaseKey: OriginalSuitcaseKeyProcess?
    @Published public private(set) var suitcaseImage: CGImage?
    private var suitcaseRenderer: OriginalSuitcaseRenderer?
    private var suitcaseTouch: SIMD2<Float>?
    @Published public private(set) var thinWire: OriginalThinWireProcess?
    @Published public private(set) var thinWireImage: CGImage?
    private var thinWireRenderer: OriginalThinWireRenderer?
    private var thinWireTouch: SIMD2<Float>?
    @Published public private(set) var hanger: OriginalHangerProcess?
    @Published public private(set) var hangerImage: CGImage?
    @Published public private(set) var hangerScreenEffects = OriginalScreenEffects()
    private var hangerRenderer: OriginalHangerRenderer?
    private var hangerTouch: SIMD2<Float>?
    @Published public private(set) var suitcaseContents: OriginalSuitcaseContentsProcess?
    @Published public private(set) var suitcaseContentsImage: CGImage?
    @Published public private(set) var suitcaseContentsScreenEffects = OriginalScreenEffects()
    private var suitcaseContentsRenderer: OriginalSuitcaseContentsRenderer?
    private var suitcaseContentsTouch: SIMD2<Float>?
    private var suitcaseContentsParent: OriginalEventRunner?
    @Published public private(set) var memoPull: OriginalMemoPullProcess?
    @Published public private(set) var memoPullImage: CGImage?
    @Published public private(set) var memoPullScreenEffects = OriginalScreenEffects()
    private var memoPullRenderer: OriginalMemoPullRenderer?
    private var memoPullTouch: SIMD2<Float>?
    @Published public private(set) var cabinetDial: OriginalCabinetDialProcess?
    @Published public private(set) var cabinetDialImage: CGImage?
    @Published public private(set) var cabinetDialScreenEffects = OriginalScreenEffects()
    private var cabinetDialRenderer: OriginalCabinetDialRenderer?
    private var cabinetDialTouch: SIMD2<Float>?
    @Published public private(set) var crowbar: OriginalCrowbarProcess?
    @Published public private(set) var crowbarImage: CGImage?
    @Published public private(set) var crowbarScreenEffects = OriginalScreenEffects()
    private var crowbarRenderer: OriginalCrowbarRenderer?
    private var crowbarTouch: SIMD2<Float>?
    @Published public private(set) var memoDrawing: OriginalMemoDrawingProcess?
    @Published public private(set) var memoDrawingImage: CGImage?
    @Published public private(set) var memoDrawingScreenEffects = OriginalScreenEffects()
    private var memoDrawingRenderer: OriginalMemoDrawingImage?
    private var memoDrawingTouch: SIMD2<Int>?
    private let puzzleSeed: () -> UInt32
    @Published public private(set) var paperclip: OriginalPaperclipProcess?
    @Published public private(set) var paperclipImage: CGImage?
    private var paperclipRenderer: OriginalPaperclipRenderer?
    private var paperclipTouch: SIMD2<Float>?
    private var paperclipMarkerFrame = 0
    @Published public private(set) var touchPicture: OriginalTouchPicture?
    public private(set) var touchPictureImages: OriginalTouchPictureImages?
    public private(set) var acquiredItemImage: CGImage?
    private var jigsawParent: OriginalEventRunner?
    private let jigsawSeed: () -> UInt32
    @Published public private(set) var closeup: OriginalSearchCloseup?
    public private(set) var closeupImage: OriginalUpViewImage?
    public private(set) var closeupDetailImage: OriginalUpViewImage?
    private var pendingCloseupDetail: (event: Int16, asset: String)?
    private var searchParent: OriginalEventRunner?
    private var pendingCloseup: (area: UInt16, subarea: UInt16, view: UInt16)?
    private var pendingChildCloseup: (view: UInt16, requestStart: Int)?
    private var closeupParents: [(scene: OriginalSearchCloseup, bitmaps: [OriginalLinearBitmap])] = []
    private var closeupBitmaps: [OriginalLinearBitmap] = []
    @Published public private(set) var door: OriginalDoorScene?
    public private(set) var doorImage: OriginalUpViewImage?
    public private(set) var itemNames: [UInt8: String] = [:]
    private let doorTable = try? OriginalStateDefaults.bundled().doorTable
    @Published public private(set) var lobby: OriginalMapExploration?
    @Published public private(set) var lobbyImage: CGImage?
    public private(set) var lobbyMap: CGImage?
    private var lobbyRenderer: OriginalMapRenderer?
    private var lobbyTouch: SIMD2<Float>?
    private var hasReturnedFromDunningIntroduction = false
    private var signProcess: OriginalSignProcess?
    private var heldTouch: OriginalEntranceProcess.Touch?
    private let audio: AudioController
    private let catalog: OriginalScriptCatalog
    private var pendingDoorOpen: Int16?
    private var handledMapRequests = 0
    private var pendingDeparture: (map: Int16, requestStart: Int)?
    private var process: OriginalEntranceProcess?
    private var bellProcess: OriginalBellProcess?
    private var bellMask: [UInt8] = []
    private var fixture: String?
    private var processReturn: Int16 = 2
    private var fadeRemaining: [Int: Int] = [:]
    private var pendingTouch: OriginalEntranceProcess.Touch?
    private var timer: Timer?
    private var isPaused = false
    private var presentedPacketOffset: Int?

    public init(runner: OriginalEventRunner, audio: AudioController, catalog: OriginalScriptCatalog, fixture: String? = nil,
                jigsawSeed: @escaping () -> UInt32 = { UInt32.random(in: .min ... .max) },
                puzzleSeed: @escaping () -> UInt32 = { UInt32.random(in: .min ... .max) },
                saveStore: any OriginalChapterSaveStore = OriginalChapterFileStore.application,
                saveDate: @escaping () -> Date = Date.init,
                chapterTransition: OriginalChapterTransition? = nil) {
        self.runner = runner
        self.audio = audio
        self.catalog = catalog
        self.fixture = fixture
        self.jigsawSeed = jigsawSeed
        self.puzzleSeed = puzzleSeed
        self.saveStore = saveStore
        self.saveDate = saveDate
        self.chapterTransition = chapterTransition
        if chapterTransition?.stage == .title {
            do { chapterTitleImages = try OriginalChapterTitleImages(library: .bundled()) }
            catch {
                self.chapterTransition = nil
                self.runner.halt("The chapter title could not be loaded: \(error)")
            }
        }
        settle()
    }

    public static func chapterOne(audio: AudioController, saveStore: any OriginalChapterSaveStore = OriginalChapterFileStore.application) throws -> OriginalPlaySession {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: catalog, defaults: .bundled(),
            timestamp: Int64(Date().timeIntervalSince1970))
        var fixture: String?
        #if DEBUG
        fixture = ProcessInfo.processInfo.environment["HOTEL_DUSK_FIXTURE"]
        if fixture == "R102-sign" {
            try fastForward(&runner) { if case .process(25) = $0.phase { return true }; return false }
            fixture = nil
        } else if let target = fixture.flatMap({ $0.hasPrefix("R102-event-") ? Int($0.dropFirst(11)) : nil }) {
            try fastForward(&runner) { $0.eventIndex == target }
            fixture = nil
        }
        #endif
        return OriginalPlaySession(runner: runner, audio: audio, catalog: catalog, fixture: fixture, saveStore: saveStore)
    }

    #if DEBUG
    /// Debug-only input record: plays the original script with fixed inputs
    /// until `stop` holds. The bell is rung to completion (return 0), the card
    /// is signed (return 0), and the first option of each prompt is taken. It
    /// replaces only the unrecovered map walk with the bell look result.
    static func fastForward(_ runner: inout OriginalEventRunner,
                            until stop: (OriginalEventRunner) -> Bool) throws {
        let table = try OriginalSearchTable.bundled(map: "R102")
        for _ in 0..<1000 where !stop(runner) {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .picture: runner.finishPicture()
            case .exploration(2) where runner.eventIndex == nil: runner.lookInSearchView(area: 2, subarea: 2, table: table)
            case .process(56), .process(24), .process(25): runner.finishProcess(returnValue: 0)
            case .choice(let options): runner.choose(options[0].id)
            default: return
            }
        }
    }
    #endif

    /// Debug-only isolated component input, like the reference runner's
    /// diagnostic writes. `R102-bell-look` stands in for the unrecovered map
    /// walk and 3D search view: at R102 exploration it supplies the original
    /// look result for area 2, node `obj02` (subarea 2). Players never see it.
    private func applyFixture() -> Bool {
        guard fixture == "R102-bell-look", case .exploration(2) = runner.phase,
              runner.program.name == "EP1_R102", let table = try? OriginalSearchTable.bundled(map: "R102") else {
            return false
        }
        fixture = nil
        runner.lookInSearchView(area: 2, subarea: 2, table: table)
        return true
    }

    /// A tap on either page while text is shown.
    public func advanceDialogue() {
        guard !isPaused else { return }
        switch runner.phase {
        case .dialogue, .itemNotice: break
        default: return
        }
        runner.acknowledgeDialogue()
        settle()
    }

    /// The player picked an option of an original choice prompt.
    public func choose(_ id: UInt16) {
        guard !isPaused, case .choice = runner.phase else { return }
        runner.choose(id)
        settle()
    }

    /// The player pressed the pulsing interrupt icon during an armed page.
    public func interrupt() {
        guard !isPaused, runner.interruptAvailable else { return }
        runner.pressInterrupt()
        settle()
    }

    /// The player asked the partner about a keyword in the question menu.
    public func ask(_ keyword: Int16) {
        guard !isPaused, chapterTransition == nil, notebook == nil, case .questions = runner.phase else { return }
        runner.ask(keyword)
        settle()
    }

    /// The player closed the question menu.
    public func leaveConversation() {
        guard !isPaused, chapterTransition == nil, notebook == nil, case .questions = runner.phase else { return }
        runner.leave()
        settle()
    }

    /**
     * Shows an inventory item to the current conversation partner.
     */
    public func showItemInConversation(_ item: UInt8) {
        guard !isPaused, chapterTransition == nil, notebook == nil, case .questions = runner.phase else { return }
        runner.showItem(item)
        settle()
    }

    /**
     * Opens the original memo editor while retaining the map or conversation.
     */
    public func openNotebook() {
        guard !isPaused, chapterTransition == nil, notebook == nil else { return }
        switch runner.phase {
        case .questions: break
        case .exploration where lobby?.mode == .walking && door == nil && closeup == nil: break
        default: return
        }
        do {
            let library = try OriginalBitmapLibrary.bundled()
            notebook = try OriginalNotebook(game: runner.game, load: library.loadNotebookData)
            runner.openNotebook()
            lobbyTouch = nil
            refreshNotebookImage()
            settle()
        } catch { runner.halt("The notebook could not open: \(error)"); settle() }
    }

    public func closeNotebook() {
        guard !isPaused, notebook != nil else { return }
        releaseNotebook()
        notebook?.storePage()
        if let notebook { runner.storeNotebook(notebook) }
        notebook = nil
        notebookImage = nil
        settle()
    }

    public func turnNotebookPage(forward: Bool) {
        guard !isPaused, notebook != nil else { return }
        releaseNotebook()
        notebook?.turnPage(forward: forward)
        if let notebook { runner.storeNotebook(notebook) }
        refreshNotebookImage()
    }

    public func clearNotebookPage() {
        guard !isPaused else { return }
        releaseNotebook()
        notebook?.clear()
        refreshNotebookImage()
    }

    public func undoNotebookEdit() {
        guard !isPaused else { return }
        releaseNotebook()
        notebook?.undo()
        refreshNotebookImage()
    }

    public func toggleNotebookEraser() {
        guard !isPaused else { return }
        releaseNotebook()
        notebook?.toggleEraser()
    }

    public func holdNotebookTouch(x: Int, y: Int) {
        guard !isPaused, notebook != nil else { return }
        notebookTouch = SIMD2(x, y)
    }

    public func releaseNotebook() {
        notebookTouch = nil
        notebook?.release()
    }

    private func refreshNotebookImage() {
        notebookImage = notebook.flatMap(OriginalNotebookImage.render)
    }

    /// A new press on the touch page, in rotated page pixels (192 × 256).
    public func touchEntrance(pageX: Int, pageY: Int) {
        guard process != nil || bellProcess != nil || signProcess != nil,
              (0..<192).contains(pageX), (0..<256).contains(pageY) else { return }
        pendingTouch = OriginalEntranceProcess.Touch(x: 255 - pageY, y: pageX)
    }

    /// The held touch on the touch page, in rotated page pixels; nil on release.
    public func holdTouch(pageX: Int, pageY: Int) {
        guard signProcess != nil else { return }
        heldTouch = OriginalEntranceProcess.Touch(x: 255 - min(max(pageY, 0), 255), y: min(max(pageX, 0), 191))
    }

    public func releaseTouch() { heldTouch = nil }

    /**
     * Forwards a drag to the original jigsaw, retaining its first grab offset.
     */
    public func dragJigsaw(pageX: Float, pageY: Float) {
        guard !isPaused, case .process(26) = runner.phase, pageX.isFinite, pageY.isFinite else { return }
        let point = OriginalJigsawProjection.world(pageX: max(-192, min(384, pageX)),
                                                   pageY: max(-256, min(512, pageY)))
        if jigsaw?.holding == true { jigsaw?.moveTouch(world: point) }
        else { jigsaw?.beginTouch(world: point) }
    }

    public func releaseJigsaw() {
        guard !isPaused, case .process(26) = runner.phase else { return }
        applyJigsawEffects(jigsaw?.endTouch() ?? [])
    }

    public func rotateJigsaw(increasing: Bool) {
        guard !isPaused, case .process(26) = runner.phase else { return }
        applyJigsawEffects(jigsaw?.rotate(increasing: increasing) ?? [])
    }

    public func quitJigsaw() {
        guard !isPaused, case .process(26) = runner.phase else { return }
        jigsaw?.quit()
    }

    public func holdSuitcaseTouch(x: Float, y: Float) {
        guard !isPaused, suitcaseKey != nil else { return }
        suitcaseTouch = SIMD2(x, y)
    }

    public func releaseSuitcaseTouch() { suitcaseTouch = nil }

    public func quitSuitcaseKey() {
        guard !isPaused else { return }
        suitcaseTouch = nil
        suitcaseKey?.quit()
    }

    public func holdThinWireTouch(x: Float, y: Float) {
        guard !isPaused, thinWire != nil, x.isFinite, y.isFinite else { return }
        thinWireTouch = SIMD2(x, y)
    }

    public func releaseThinWireTouch() { thinWireTouch = nil }

    public func quitThinWire() {
        guard !isPaused else { return }
        thinWireTouch = nil
        thinWire?.quit()
    }

    public func holdPaperclipTouch(x: Float, y: Float) {
        guard !isPaused, paperclip != nil, x.isFinite, y.isFinite else { return }
        paperclipTouch = SIMD2(x, y)
    }

    public func holdHangerTouch(x: Float, y: Float) {
        guard !isPaused, hanger != nil, x.isFinite, y.isFinite else { return }
        hangerTouch = SIMD2(x, y)
    }

    public func releaseHangerTouch() { hangerTouch = nil }

    public func holdSuitcaseContentsTouch(x: Float, y: Float) {
        guard !isPaused, runner.phase == .process(id: 35), x.isFinite, y.isFinite else { return }
        suitcaseContentsTouch = SIMD2(x, y)
    }

    public func releaseSuitcaseContentsTouch() { suitcaseContentsTouch = nil }

    public func leaveSuitcaseContents() {
        guard !isPaused, runner.phase == .process(id: 35) else { return }
        suitcaseContentsTouch = nil
        suitcaseContents?.goBack()
    }

    public func quitHanger() {
        guard !isPaused else { return }
        hangerTouch = nil
        hanger?.quit()
    }

    public func releasePaperclipTouch() { paperclipTouch = nil }

    public func holdCabinetDialTouch(x: Float, y: Float) {
        guard !isPaused, cabinetDial != nil, x.isFinite, y.isFinite else { return }
        cabinetDialTouch = SIMD2(x, y)
    }

    public func releaseCabinetDialTouch() { cabinetDialTouch = nil }

    public func quitCabinetDial() {
        guard !isPaused else { return }
        cabinetDialTouch = nil
        cabinetDial?.quit()
    }

    public func holdCrowbarTouch(x: Float, y: Float) {
        guard !isPaused, crowbar != nil, x.isFinite, y.isFinite else { return }
        crowbarTouch = SIMD2(x, y)
    }

    public func releaseCrowbarTouch() { crowbarTouch = nil }

    public func quitCrowbar() {
        guard !isPaused else { return }
        crowbarTouch = nil
        crowbar?.quit()
    }

    public func holdMemoPullTouch(x: Float, y: Float) {
        guard !isPaused, memoPull != nil, x.isFinite, y.isFinite else { return }
        memoPullTouch = SIMD2(x, y)
    }

    public func releaseMemoPullTouch() { memoPullTouch = nil }

    public func holdMemoDrawingTouch(x: Float, y: Float) {
        guard !isPaused, memoDrawing != nil, x.isFinite, y.isFinite,
              (0...191).contains(x), (0...255).contains(y) else { return }
        memoDrawingTouch = SIMD2(Int(x), Int(y))
    }

    public func releaseMemoDrawingTouch() { memoDrawingTouch = nil }

    public func clearMemoDrawing() {
        guard !isPaused else { return }
        memoDrawing?.clear()
        do {
            if let memoDrawing { memoDrawingImage = try memoDrawingRenderer?.render(memoDrawing.drawing) }
        } catch {
            runner.halt("The memo drawing could not be cleared: \(error)")
            settle()
        }
    }

    public func quitMemoDrawing() {
        guard !isPaused else { return }
        memoDrawingTouch = nil
        memoDrawing?.quit()
    }

    public func quitMemoPull() {
        guard !isPaused else { return }
        memoPullTouch = nil
        memoPull?.quit()
    }

    public func quitPaperclip() {
        guard !isPaused else { return }
        paperclipTouch = nil
        paperclip?.quit()
    }

    /**
     * Forwards held picture input. Releasing the touch permits the second press.
     */
    public func touchPicture(pageX: Int, pageY: Int) {
        guard !isPaused, case .picture = runner.phase else { return }
        let effects = touchPicture?.touch(pageX: pageX, pageY: pageY) ?? []
        for effect in effects {
            try? audio.playOriginalEffect(archiveID: 8, entryID: effect == .selectSound ? 1 : 0)
        }
    }

    public func releasePicture() { touchPicture?.release() }

    public func pause() {
        isPaused = true
        releaseNotebook()
        touchPicture?.release()
        lobbyTouch = nil
        suitcaseTouch = nil
        paperclipTouch = nil
        thinWireTouch = nil
        memoPullTouch = nil
        hangerTouch = nil
        memoDrawingTouch = nil
        suitcaseContentsTouch = nil
        stopTimer()
        audio.pause()
        cabinetDialTouch = nil
        crowbarTouch = nil
    }

    public func resume() {
        guard isPaused else { return }
        isPaused = false
        audio.resume()
        settle()
    }

    public func stop() {
        lobbyTouch = nil
        suitcaseTouch = nil
        paperclipTouch = nil
        thinWireTouch = nil
        memoPullTouch = nil
        hangerTouch = nil
        memoDrawingTouch = nil
        suitcaseContentsTouch = nil
        stopTimer()
        audio.stop()
        cabinetDialTouch = nil
        crowbarTouch = nil
    }

    /// Starts whatever the runner's current phase needs from the host.
    private func settle() {
        if chapterTransition != nil { stopTimer(); return }
        if notebook != nil { startTimer(); return }
        /**
         * 0x0203E7C8 leaves the door close-up when its transition starts a person's normal event.
         */
        if door != nil, runner.session.selection.modeID == 3, runner.session.selection.sceneID < 18 {
            door = nil
            doorImage = nil
        }
        switch runner.phase {
        case .dialogue(let packet):
            stopTimer()
            touchPictureImages = nil
            acquiredItemImage = nil
            if presentedPacketOffset != packet.sourceOffset {
                presentedPacketOffset = packet.sourceOffset
                applyAudioControls(packet)
            }
        case .picture(let id):
            if touchPicture == nil {
                do {
                    guard let record = try OriginalTouchPictureTable.bundled().records.first(where: { $0.id == id }) else {
                        throw OriginalDataError.missing("Touch picture \(id)")
                    }
                    let library = try OriginalBitmapLibrary.bundled()
                    let foreground = try library.loadLinear(path: "check/TouchEvent/\(record.foreground).bin")
                    let background = try record.background.isEmpty ? nil : library.loadLinear(path: "check/StilBG/\(record.background).bin")
                    let picture = try OriginalTouchPicture(record: record, indices: foreground.indices,
                        width: foreground.width, height: foreground.height)
                    // Captured default at 0x021046B8 + 0x24: RGB5 (24, 16, 3).
                    touchPictureImages = try OriginalTouchPictureImages(picture: picture, foreground: foreground,
                        background: background, highlightRGB: (198, 132, 24))
                    touchPicture = picture
                } catch {
                    runner.halt("The touch picture could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .itemNotice(let id, _):
            stopTimer()
            if touchPictureImages != nil {
                do { acquiredItemImage = try OriginalTouchPictureImages.item(id, library: .bundled()) }
                catch { runner.halt("The item picture could not be loaded: \(error)"); return settle() }
            }
        case .process(24):
            if bellProcess == nil {
                do {
                    bellMask = try OriginalBitmapLibrary.bundled().loadLinear(path: "trick/bell/bell01.bin").indices
                } catch {
                    runner.halt("Bell resources could not be loaded: \(error)")
                    return settle()
                }
                bellProcess = OriginalBellProcess()
                processReturn = 2
                for fade in OriginalBellProcess.initialFades { fadeRemaining[fade.screen] = Int(fade.duration) }
                bell = BellScene(angle: 0, awaitingTouch: false, quitEnabled: false)
            }
            startTimer()
        case .process(25):
            if signProcess == nil {
                signProcess = OriginalSignProcess()
                processReturn = 2
                sign = SignScene(strokes: [0, 0, 0, 0], awaitingStroke: false, quitEnabled: false)
            }
            startTimer()
        case .process(26):
            if jigsaw == nil {
                jigsaw = OriginalJigsawProcess(seed: jigsawSeed(), savedLooseMask: runner.game.chapterOneJigsawMask)
            }
            startTimer()
        case .process(27):
            if memoPull == nil {
                do {
                    memoPullRenderer = try OriginalMemoPullRenderer()
                    let puzzle = OriginalMemoPullProcess()
                    memoPullImage = try memoPullRenderer?.render(puzzle)
                    memoPullScreenEffects = OriginalScreenEffects()
                    memoPull = puzzle
                } catch {
                    runner.halt("The memo puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(28):
            if paperclip == nil {
                do {
                    paperclipRenderer = try OriginalPaperclipRenderer()
                    let puzzle = OriginalPaperclipProcess()
                    paperclipMarkerFrame = 0
                    paperclipImage = try paperclipRenderer?.render(puzzle, markerFrame: paperclipMarkerFrame)
                    paperclip = puzzle
                } catch {
                    runner.halt("The paperclip puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(let id) where id == 29 || id == 33:
            if thinWire == nil {
                do {
                    let variant: OriginalThinWireProcess.Variant = id == 29 ? .thin : .thick
                    thinWireRenderer = try OriginalThinWireRenderer(variant: variant)
                    let puzzle = OriginalThinWireProcess(variant: variant)
                    thinWireImage = try thinWireRenderer?.render(puzzle)
                    thinWire = puzzle
                } catch {
                    runner.halt("The wire-lock puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(30):
            if crowbar == nil {
                do {
                    let items = try runner.game.inventory.items
                    let renderer = try OriginalCrowbarRenderer(tornPaper: items.contains(7) || items.contains(12))
                    let puzzle = OriginalCrowbarProcess()
                    crowbarRenderer = renderer
                    crowbarImage = try renderer.render(puzzle)
                    crowbarScreenEffects = OriginalScreenEffects()
                    crowbar = puzzle
                } catch {
                    runner.halt("The crowbar puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(31):
            if cabinetDial == nil {
                do {
                    let renderer = try OriginalCabinetDialRenderer()
                    let puzzle = OriginalCabinetDialProcess(randomValue: runner.memoRandomInfo(seed: puzzleSeed()),
                        retainedValue: runner.game.cabinetDialRetainedValue)
                    cabinetDialRenderer = renderer
                    cabinetDialImage = try renderer.render(puzzle)
                    cabinetDialScreenEffects = OriginalScreenEffects()
                    cabinetDial = puzzle
                } catch {
                    runner.halt("The cabinet dial could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(32):
            if hanger == nil {
                do {
                    hangerRenderer = try OriginalHangerRenderer()
                    let puzzle = OriginalHangerProcess()
                    hangerImage = try hangerRenderer?.render(puzzle)
                    hangerScreenEffects = OriginalScreenEffects()
                    hanger = puzzle
                } catch {
                    runner.halt("The hanger puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(34):
            if memoDrawing == nil {
                do {
                    let items = try runner.game.inventory.items
                    let paper: OriginalMemoDrawing.Paper = items.contains(63) ? .whole : items.contains(13) ? .joined : .torn
                    let renderer = try OriginalMemoDrawingImage(paper: paper, library: .bundled())
                    let drawing = try OriginalMemoDrawing(paper: paper, randomInfo: runner.memoRandomInfo(seed: puzzleSeed()), mask: renderer.mask)
                    memoDrawingRenderer = renderer
                    memoDrawing = OriginalMemoDrawingProcess(drawing: drawing)
                    memoDrawingImage = try renderer.render(drawing)
                    memoDrawingScreenEffects = OriginalScreenEffects()
                    runner.recordUnrenderedProcessCaption(processID: 34, caption: 39)
                } catch {
                    runner.halt("The memo drawing could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(35):
            if suitcaseContents == nil {
                do {
                    let renderer = try OriginalSuitcaseContentsRenderer()
                    let process = OriginalSuitcaseContentsProcess(contents: renderer.initialContents)
                    suitcaseContentsRenderer = renderer
                    suitcaseContents = process
                    suitcaseContentsScreenEffects = OriginalScreenEffects()
                    suitcaseContentsImage = try renderer.render(process, game: runner.game)
                } catch {
                    runner.halt("The suitcase contents could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(37):
            if suitcaseKey == nil {
                do {
                    suitcaseRenderer = try OriginalSuitcaseRenderer()
                    let puzzle = OriginalSuitcaseKeyProcess()
                    suitcaseImage = try suitcaseRenderer?.render(puzzle)
                    suitcaseKey = puzzle
                } catch {
                    runner.halt("The suitcase puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(126):
            if clock == nil {
                do {
                    guard let transition = runner.timeTransition else {
                        throw OriginalDataError.missing("Clock transition arguments")
                    }
                    let process = try OriginalClockProcess(label: transition.clockLabel)
                    clockRenderer = try OriginalClockRenderer(process: process, library: .bundled())
                    clockImage = try clockRenderer?.render(process)
                    clock = process
                    clockUpdates = 0
                    resumesWalkingAfterClock = lobby?.mode == .counter
                } catch {
                    runner.halt("The clock transition could not start: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(let id):
            guard id == 56 else {
                runner.halt("Process \(id) is not recovered")
                return settle()
            }
            if process == nil {
                process = OriginalEntranceProcess()
                processReturn = 2
                // The normal initializer starts this one-update fade.
                let fade = OriginalEntranceProcess.initialFade
                fadeRemaining[fade.screen] = Int(fade.duration)
                entrance = EntranceScene(panel: 0, sceneVisible: true, awaitingHandle: false)
            }
            startTimer()
        case .waiting:
            startTimer()
        case .exploration(let map):
            stopTimer()
            if var parent = suitcaseContentsParent {
                parent.resumeProcess(after: runner)
                runner = parent
                suitcaseContentsParent = nil
                suitcaseContents?.finishResponse()
                presentedPacketOffset = nil
                return settle()
            }
            if var parent = jigsawParent {
                parent.resumeProcess(after: runner)
                runner = parent
                jigsawParent = nil
                presentedPacketOffset = nil
                jigsaw?.finishHint()
                return settle()
            }
            if var parent = searchParent {
                parent.resumeSearch(after: runner)
                runner = parent
                searchParent = nil
                presentedPacketOffset = nil
            }
            if resumesWalkingAfterClock {
                /**
                 * 0x02031944, state 0x10, closes search after the clock clears the talk renderer.
                 * The map then consumes the pending time and retry-checkpoint requests.
                 */
                resumesWalkingAfterClock = false
                closeup = nil
                closeupImage = nil
                closeupBitmaps = []
                closeupParents = []
                pendingCloseup = nil
                pendingChildCloseup = nil
                pendingCloseupDetail = nil
                closeupDetailImage = nil
                searchItem = nil
                lobby?.leaveCounter()
            }
            if let request = runner.processRequests.dropFirst(handledMapRequests).reversed().first(where: { $0.kind == 4 }) {
                do {
                    guard request.value == 1, map == 31, let lobby else {
                        throw OriginalDataError.unsupported("Chapter transition \(request.value + 1)")
                    }
                    try runner.prepareChapter(UInt16(request.value), position: lobby.position, facing: lobby.checkpointFacing)
                    handledMapRequests = runner.processRequests.count
                    closeup = nil
                    closeupImage = nil
                    closeupBitmaps = []
                    pendingCloseup = nil
                    pendingChildCloseup = nil
                    closeupParents = []
                    door = nil
                    doorImage = nil
                    lobbyTouch = nil
                    self.lobby?.leaveCounter()
                    chapterTransition = OriginalChapterTransition()
                } catch { runner.halt("The chapter transition could not start: \(error)") }
                return
            }
            if let pending = pendingCloseup {
                pendingCloseup = nil
                do { try openSearchCloseup(area: pending.area, subarea: pending.subarea, viewID: pending.view) }
                catch { runner.halt("The close-up could not be loaded: \(error)"); return }
                return settle()
            }
            if let pending = pendingCloseupDetail, let closeup {
                if closeupDetailImage == nil {
                    do {
                        let bitmap = try OriginalBitmapLibrary.bundled().loadLinear(path: "map/sdata/SearchUp/\(pending.asset).bin")
                        closeupDetailImage = try OriginalUpViewImage(bitmaps: [bitmap], visible: [true])
                        runner.lookInCloseupDetail(area: closeup.area, subarea: closeup.subarea, event: pending.event)
                        try startSearchFallback()
                    } catch { runner.halt("The close-up detail could not be loaded: \(error)"); return }
                    return settle()
                }
                pendingCloseupDetail = nil
                closeupDetailImage = nil
            }
            if let pending = pendingChildCloseup, let closeup {
                pendingChildCloseup = nil
                /**
                 * 0x02064530 request 6 cancels the pending child after the component response.
                 */
                if !runner.processRequests.dropFirst(pending.requestStart).contains(where: { $0.kind == 6 }) {
                    closeupParents.append((closeup, closeupBitmaps))
                    do { try openSearchCloseup(area: closeup.area, subarea: closeup.subarea, viewID: pending.view) }
                    catch { runner.halt("The nested close-up could not be loaded: \(error)"); return }
                    return settle()
                }
            }
            if let closeup {
                do {
                    closeupImage = try OriginalUpViewImage(bitmaps: closeupBitmaps, visible: closeup.visibility(game: runner.game))
                } catch { runner.halt("The close-up could not be drawn: \(error)") }
                return
            }
            if let destination = pendingDoorOpen {
                pendingDoorOpen = nil
                door = nil
                doorImage = nil
                return departThroughDoor(to: destination)
            }
            if door != nil { return }
            if applyFixture() { return settle() }
            if let departure = pendingDeparture {
                pendingDeparture = nil
                let requests = runner.processRequests.dropFirst(departure.requestStart)
                if requests.contains(where: { $0.kind == 2 }) { lobby?.cancelDeparture() }
                else { return moveToMap(departure.map) }
            }
            guard let mapName = OriginalMapExploration.supportedMaps[map],
                  runner.game.chapter > 0 || runner.game.value(for: .eventFlag(group: 2, index: 2)) == true else { return }
            do {
                if lobby?.mapID != map {
                    lobby = try OriginalMapExploration.bundled(mapID: map, previousMapID: runner.game.previousMapID,
                        savedGame: runner.game.previousMapID == map ? runner.game : nil)
                    lobbyRenderer = try OriginalMapRenderer(mapName: mapName)
                    lobbyMap = lobbyRenderer?.map
                }
                for request in runner.processRequests.dropFirst(handledMapRequests).reversed() {
                    if request.kind == 3 {
                        runner.consumeTimeRequest(request.value)
                    } else if request.kind == 9 {
                        if try lobby?.relocate(to: Int(request.value)) == true, let lobby {
                            runner.setMapPosition(lobby.position, facing: lobby.facing)
                        }
                    } else if request.kind == 8 {
                        // Search consumes this request without updating the map position (0x020340D0).
                        if let lobby, lobby.mode == .walking { runner.setMapPosition(lobby.position, facing: lobby.checkpointFacing) }
                        runner.saveRetryCheckpoint()
                    }
                }
                handledMapRequests = runner.processRequests.count
                if runner.game.chapter == 0, !hasReturnedFromDunningIntroduction,
                   runner.game.value(for: .eventFlag(group: 2, index: 7)) == true {
                    lobby?.leaveCounter()
                    hasReturnedFromDunningIntroduction = true
                }
                try renderLobby()
                startTimer()
            } catch { runner.halt("The map could not be loaded: \(error)") }
        case .questions:
            stopTimer()
            do { itemNames = try OriginalItemNames.bundled().names }
            catch { runner.halt("The inventory names could not be loaded: \(error)") }
        case .choice, .halted:
            stopTimer()
        }
    }

    /// Text controls %m0NN start BGM_NN. The music table at 0x0200AD94 maps
    /// BGM_NN to SDAT sequence NN - 1, whose symbol is SEQ_BGM_NN. Only mode 0
    /// is acted on; the other mode values are not recovered.
    private func applyAudioControls(_ packet: OriginalDialoguePacket) {
        for page in packet.pages {
            for token in page.tokens {
                guard case .control(.music(let mode, let name)) = token.kind, mode == 0 else { continue }
                audio.playBGM(title: "SEQ_" + name)
            }
        }
    }

    private func startTimer() {
        guard timer == nil, !isPaused else { return }
        let timer = Timer(timeInterval: 1 / Self.updatesPerSecond, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advanceFrame() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /**
     * Advances one original update, shared by the live timer and deterministic checks.
     */
    func advanceFrame() {
        guard !isPaused, chapterTransition == nil else { return }
        if notebook != nil {
            if let touch = notebookTouch {
                let before = notebook?.pixels
                notebook?.touch(x: touch.x, y: touch.y)
                if before != notebook?.pixels { refreshNotebookImage() }
            }
            return
        }
        audio.advanceOriginalFrame()
        if case .exploration = runner.phase, lobby != nil {
            guard !isPaused else { return }
            let people = lobby?.people(in: runner.game).map(\.position) ?? []
            lobby?.update(heldPageTouch: lobbyTouch, people: people)
            guard lobbyTouch != nil else { return }
            if let region = lobby?.eventRegion, runner.enterMapRegion(region) {
                lobbyTouch = nil
                return settle()
            }
            if let destination = lobby?.exitMapID {
                lobbyTouch = nil
                let requestStart = runner.processRequests.count
                if runner.beginMapDeparture(to: destination) {
                    pendingDeparture = (destination, requestStart)
                    return settle()
                }
                return moveToMap(destination)
            }
            do { try renderLobby() }
            catch { runner.halt("The map could not be drawn: \(error)"); stopTimer() }
            return
        }
        if case .waiting = runner.phase {
            runner.advanceWait()
            return settle()
        }
        if case .picture = runner.phase {
            touchPicture?.update()
            if touchPicture?.phase == .complete {
                touchPicture = nil
                runner.finishPicture()
                settle()
            }
            return
        }
        if bellProcess != nil { return updateBell() }
        if clock != nil { return updateClock() }
        if signProcess != nil { return updateSign() }
        if thinWire != nil { return updateThinWire() }
        if hanger != nil { return updateHanger() }
        if suitcaseContents != nil { return updateSuitcaseContents() }
        if memoPull != nil { return updateMemoPull() }
        if memoDrawing != nil { return updateMemoDrawing() }
        if cabinetDial != nil { return updateCabinetDial() }
        if crowbar != nil { return updateCrowbar() }
        if suitcaseKey != nil { return updateSuitcaseKey() }
        if paperclip != nil { return updatePaperclip() }
        if jigsaw != nil {
            let complete = (fadeRemaining[0] ?? 0) == 0
            for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
            applyJigsawEffects(jigsaw?.update(screen0FadeComplete: complete) ?? [])
            return
        }
        guard var current = process else { return stopTimer() }
        let input = OriginalEntranceProcess.Input(newTouch: pendingTouch, leftHanded: false,
            page0FadeComplete: (fadeRemaining[0] ?? 0) == 0)
        pendingTouch = nil
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let step = current.update(input)
        for effect in step.effects {
            switch effect {
            case .fade(let fade): fadeRemaining[fade.screen] = Int(fade.duration)
            case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
            case .processReturn(let value): processReturn = value
            default: break
            }
        }
        for draw in current.draw(leftHanded: false) {
            // Names are u01...u03; the matching d panel shares the number.
            if case .copyImage(let name, _) = draw, let number = Int(name.dropFirst().prefix(2)) {
                entrance?.panel = number - 1
            }
        }
        entrance?.sceneVisible = current.sceneVisible
        entrance?.awaitingHandle = current.movementAwaitingTouch
        process = current
        if step.status == 3 {
            process = nil
            entrance = nil
            fadeRemaining = [:]
            stopTimer()
            runner.finishProcess(returnValue: processReturn)
            settle()
        }
    }

    private func updateClock() {
        guard var process = clock else { return }
        clockUpdates += 1
        let tick = UInt64(Double(clockUpdates) / Self.updatesPerSecond)
        if process.update(tick: tick, draw: clockUpdates % 2 == 0) {
            try? audio.playOriginalEffect(archiveID: 0, entryID: 0x43)
        }
        do { clockImage = try clockRenderer?.render(process) }
        catch { runner.halt("The clock could not be drawn: \(error)"); stopTimer(); return }
        clock = process
        if process.isComplete {
            clock = nil
            clockImage = nil
            clockRenderer = nil
            runner.finishProcess(returnValue: 2)
            settle()
        }
    }

    private func applyJigsawEffects(_ effects: [OriginalJigsawProcess.Effect]) {
        for effect in effects {
            switch effect {
            case .fadeIn(let updates), .fadeOut(let updates), .completionFade(let updates):
                fadeRemaining[0] = updates
            case .sound(let archive, let entry):
                try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
            case .hint(let pairA, let pairB):
                do {
                    let hint = try runner.processHint(catalog: catalog, pairA: pairA, pairB: pairB)
                    jigsawParent = runner
                    runner = hint
                    presentedPacketOffset = nil
                } catch { runner.halt("The jigsaw hint could not be loaded: \(error)") }
                settle()
            case .completed(let result):
                let mask = jigsaw?.looseMask ?? 0
                jigsaw = nil
                fadeRemaining = [:]
                stopTimer()
                runner.finishJigsaw(returnValue: result, looseMask: mask)
                settle()
            }
        }
    }

    private func updateCabinetDial() {
        guard var puzzle = cabinetDial else { return }
        let complete = !cabinetDialScreenEffects.brightness[0].active
        cabinetDialScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let touch = cabinetDialTouch.flatMap { OriginalCabinetDialProjection.touch(page: $0, process: puzzle) }
        let effects = puzzle.update(touch: touch, fadeComplete: complete)
        cabinetDial = puzzle
        do {
            for effect in effects {
                switch effect {
                case .caption: runner.recordUnrenderedProcessCaption(processID: 31, caption: 39)
                case .hideCaption: break
                case .fadeIn(let updates):
                    try cabinetDialScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try cabinetDialScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try cabinetDialScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .rumble: runner.recordUnrenderedRumble(processID: 31)
                case .completed(let result):
                    cabinetDial = nil
                    cabinetDialImage = nil
                    cabinetDialRenderer = nil
                    cabinetDialTouch = nil
                    cabinetDialScreenEffects = OriginalScreenEffects()
                    closeup = nil
                    closeupImage = nil
                    closeupBitmaps = []
                    closeupParents = []
                    pendingChildCloseup = nil
                    stopTimer()
                    runner.finishCabinetDial(returnValue: result, retainedValue: puzzle.retainedValue)
                    return settle()
                }
            }
            if previous != puzzle { cabinetDialImage = try cabinetDialRenderer?.render(puzzle) }
        } catch {
            runner.halt("The cabinet dial presentation could not be updated: \(error)")
            settle()
        }
    }

    private func updateCrowbar() {
        guard var puzzle = crowbar else { return }
        let complete = !crowbarScreenEffects.brightness[0].active
        crowbarScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let touch = crowbarTouch.flatMap { OriginalCrowbarProjection.touch(page: $0, process: puzzle) }
        let effects = puzzle.update(touch: touch, fadeComplete: complete)
        crowbar = puzzle
        do {
            for effect in effects {
                switch effect {
                case .caption: runner.recordUnrenderedProcessCaption(processID: 30, caption: 39)
                case .hideCaption: break
                case .fadeIn(let updates):
                    try crowbarScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try crowbarScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try crowbarScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .stopLiftSound:
                    _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: 1, entryID: 30, fadeFrames: 1))
                case .soundVolume(let volume):
                    _ = try? audio.applyOriginalCommand(.effectVolume(archiveID: 8, entryID: -1, target: volume, frames: 1))
                case .rumble: runner.recordUnrenderedRumble(processID: 30)
                case .stopRumble: break
                case .completed(let result):
                    crowbar = nil
                    crowbarImage = nil
                    crowbarRenderer = nil
                    crowbarTouch = nil
                    crowbarScreenEffects = OriginalScreenEffects()
                    closeup = nil
                    closeupImage = nil
                    closeupBitmaps = []
                    closeupParents = []
                    pendingChildCloseup = nil
                    stopTimer()
                    runner.finishCrowbar(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { crowbarImage = try crowbarRenderer?.render(puzzle) }
        } catch {
            runner.halt("The crowbar presentation could not be updated: \(error)")
            settle()
        }
    }

    private func updateMemoDrawing() {
        guard var process = memoDrawing else { return }
        let complete = !memoDrawingScreenEffects.brightness[0].active
        memoDrawingScreenEffects.advanceOriginalFrame()
        let previous = process.drawing
        let effects = process.update(touch: memoDrawingTouch, fadeComplete: complete)
        memoDrawing = process
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try memoDrawingScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try memoDrawingScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .startSound: try? audio.playOriginalEffect(archiveID: 0, entryID: 34)
                case .soundVolume(let volume):
                    _ = try? audio.applyOriginalCommand(.effectVolume(archiveID: 0, entryID: 34, target: volume, frames: 10))
                case .stopSound:
                    _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: 0, entryID: 34, fadeFrames: 5))
                case .completed(let result):
                    memoDrawing = nil
                    memoDrawingImage = nil
                    memoDrawingRenderer = nil
                    memoDrawingTouch = nil
                    memoDrawingScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    if runner.hasInventoryProcess {
                        let response = try runner.finishInventoryProcess(returnValue: result, catalog: catalog)
                        searchParent = runner
                        runner = response
                        presentedPacketOffset = nil
                    } else { runner.finishProcess(returnValue: result) }
                    return settle()
                }
            }
            if previous != process.drawing { memoDrawingImage = try memoDrawingRenderer?.render(process.drawing) }
        } catch {
            runner.halt("The memo drawing could not be updated: \(error)")
            settle()
        }
    }

    private func updateMemoPull() {
        guard var puzzle = memoPull else { return }
        let complete = !memoPullScreenEffects.brightness[0].active
        memoPullScreenEffects.advanceOriginalFrame()
        let touch = memoPullTouch.flatMap { OriginalMemoPullProjection.touch(page: $0, paper: puzzle.position) }
        let previous = puzzle
        let effects = puzzle.update(touch: touch, fadeComplete: complete)
        memoPull = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try memoPullScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try memoPullScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try memoPullScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .caption: runner.recordUnrenderedProcessCaption(processID: 27, caption: 39)
                case .hideCaption: break
                case .torn: runner.recordUnrenderedProcessCaption(processID: 27, caption: 29)
                case .completed(let result):
                    memoPull = nil
                    memoPullImage = nil
                    memoPullRenderer = nil
                    memoPullTouch = nil
                    memoPullScreenEffects = OriginalScreenEffects()
                    closeup = nil
                    closeupImage = nil
                    closeupBitmaps = []
                    closeupParents = []
                    pendingChildCloseup = nil
                    stopTimer()
                    runner.finishMemoPull(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { memoPullImage = try memoPullRenderer?.render(puzzle) }
        } catch {
            runner.halt("The memo presentation could not be updated: \(error)")
            settle()
        }
    }

    private func updatePaperclip() {
        guard var puzzle = paperclip else { return }
        let complete = (fadeRemaining[0] ?? 0) == 0
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let touch = paperclipTouch.flatMap { OriginalPaperclipProjection.hit(page: $0) }
        let effects = puzzle.update(touch: touch, isTouchDown: paperclipTouch != nil, fadeComplete: complete)
        paperclip = puzzle
        do {
            paperclipImage = try paperclipRenderer?.render(puzzle, markerFrame: paperclipMarkerFrame)
            if puzzle.phase == 2 { paperclipMarkerFrame = (paperclipMarkerFrame + 2) % 31 }
        } catch {
            runner.halt("The paperclip image could not be drawn: \(error)")
            return settle()
        }
        for effect in effects {
            switch effect {
            case .fadeIn(let updates), .fadeOut(let updates), .completionFade(let updates):
                fadeRemaining[0] = updates
            case .sound(let entry): try? audio.playOriginalEffect(archiveID: 0, entryID: entry)
            case .springBack: runner.recordUnrenderedRumble(processID: 28)
            case .completed(let result):
                paperclip = nil
                paperclipImage = nil
                paperclipRenderer = nil
                paperclipTouch = nil
                fadeRemaining = [:]
                stopTimer()
                do {
                    let response = try runner.finishInventoryProcess(returnValue: result, catalog: catalog)
                    searchParent = runner
                    runner = response
                    presentedPacketOffset = nil
                } catch { runner.halt("The paperclip response could not be loaded: \(error)") }
                settle()
            }
        }
    }

    private func updateHanger() {
        guard var puzzle = hanger else { return }
        let complete = !hangerScreenEffects.brightness[0].active
        hangerScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: hangerTouch, fadeComplete: complete)
        hanger = puzzle
        do {
            if puzzle != previous { hangerImage = try hangerRenderer?.render(puzzle) }
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try hangerScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try hangerScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .completionFade(let updates):
                    try hangerScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .sound(let entry): try? audio.playOriginalEffect(archiveID: 0, entryID: entry)
                case .markCompleted: runner.markHangerCutCompleted()
                case .completed(let result):
                    hanger = nil
                    hangerImage = nil
                    hangerRenderer = nil
                    hangerTouch = nil
                    hangerScreenEffects = OriginalScreenEffects()
                    closeup = nil
                    closeupImage = nil
                    closeupBitmaps = []
                    closeupParents = []
                    pendingChildCloseup = nil
                    stopTimer()
                    runner.finishHanger(returnValue: result)
                    settle()
                }
            }
        } catch {
            runner.halt("The hanger presentation could not be updated: \(error)")
            settle()
        }
    }

    private func updateSuitcaseContents() {
        guard var process = suitcaseContents else { return }
        let complete = !suitcaseContentsScreenEffects.brightness[0].active
        suitcaseContentsScreenEffects.advanceOriginalFrame()
        do {
            let previous = process
            let effects = try process.update(pageTouch: suitcaseContentsTouch, game: runner.game, fadeComplete: complete)
            suitcaseContents = process
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try suitcaseContentsScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try suitcaseContentsScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry):
                    try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .stopDragSound:
                    _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: 0, entryID: 38, fadeFrames: 1))
                case .dragVolume(let volume):
                    _ = try? audio.applyOriginalCommand(.effectVolume(archiveID: 0, entryID: 38, target: volume, frames: 1))
                case .award(let item): try runner.takeSuitcaseItem(item)
                case .response(let response):
                    let child = try runner.processHint(catalog: catalog, pairA: 12, pairB: response)
                    suitcaseContentsParent = runner
                    runner = child
                    suitcaseContentsTouch = nil
                    presentedPacketOffset = nil
                case .completed:
                    suitcaseContents = nil
                    suitcaseContentsImage = nil
                    suitcaseContentsRenderer = nil
                    suitcaseContentsTouch = nil
                    suitcaseContentsScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishSuitcaseContents()
                    return settle()
                }
            }
            if previous != process || !effects.isEmpty {
                suitcaseContentsImage = try suitcaseContentsRenderer?.render(process, game: runner.game)
            }
            if process.awaitingResponse { settle() }
        } catch {
            runner.halt("The suitcase contents could not be updated: \(error)")
            settle()
        }
    }

    private func updateThinWire() {
        guard var puzzle = thinWire else { return }
        let complete = (fadeRemaining[0] ?? 0) == 0
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let previous = puzzle
        let effects = puzzle.update(pageTouch: thinWireTouch, fadeComplete: complete)
        thinWire = puzzle
        do {
            if puzzle != previous { thinWireImage = try thinWireRenderer?.render(puzzle) }
        } catch {
            runner.halt("The wire-lock image could not be drawn: \(error)")
            return settle()
        }
        for effect in effects {
            switch effect {
            case .fadeIn(let updates), .fadeOut(let updates), .completionFade(let updates):
                fadeRemaining[0] = updates
            case .sound(let entry): try? audio.playOriginalEffect(archiveID: 0, entryID: entry)
            case .stopSound(let entry):
                _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: 0, entryID: entry, fadeFrames: 1))
            case .scrapeVolume(let volume):
                _ = try? audio.applyOriginalCommand(.effectVolume(archiveID: 0, entryID: 33, target: volume, frames: 1))
            case .pinLatched: try? audio.playOriginalEffect(archiveID: 1, entryID: 33)
            case .markCompleted: runner.markThickWireCompleted()
            case .caption(let caption): runner.recordUnrenderedProcessCaption(processID: puzzle.processID, caption: caption)
            case .rumble: runner.recordUnrenderedRumble(processID: puzzle.processID)
            case .completed(let result):
                thinWire = nil
                thinWireImage = nil
                thinWireRenderer = nil
                thinWireTouch = nil
                fadeRemaining = [:]
                stopTimer()
                runner.finishThinWire(returnValue: result)
                settle()
            }
        }
    }

    private func updateSuitcaseKey() {
        guard var puzzle = suitcaseKey else { return }
        let complete = (fadeRemaining[0] ?? 0) == 0
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let previous = puzzle
        let effects = puzzle.update(pageTouch: suitcaseTouch, fadeComplete: complete)
        suitcaseKey = puzzle
        do {
            if puzzle != previous { suitcaseImage = try suitcaseRenderer?.render(puzzle) }
        } catch {
            runner.halt("The suitcase image could not be drawn: \(error)")
            return settle()
        }
        for effect in effects {
            switch effect {
            case .fadeIn(let updates), .fadeOut(let updates), .completionFade(let updates):
                fadeRemaining[0] = updates
            case .sound(let entry): try? audio.playOriginalEffect(archiveID: 0, entryID: entry)
            case .stopSound(let entry):
                _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: 0, entryID: entry, fadeFrames: 1))
            case .caption(let caption): runner.recordUnrenderedProcessCaption(processID: 37, caption: caption)
            case .completed(let result):
                suitcaseKey = nil
                suitcaseImage = nil
                suitcaseRenderer = nil
                suitcaseTouch = nil
                fadeRemaining = [:]
                stopTimer()
                runner.finishSuitcaseKey(returnValue: result)
                settle()
            }
        }
    }

    /// One update of process 24. Status 2 hands the result to the event runner.
    private func updateBell() {
        guard var current = bellProcess else { return }
        let input = OriginalBellProcess.Input(newTouch: pendingTouch.map { .init(x: $0.x, y: $0.y) },
            leftHanded: false, screen0FadeComplete: (fadeRemaining[0] ?? 0) == 0)
        pendingTouch = nil
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let step = current.update(input, mask: bellMask)
        for effect in step.effects {
            switch effect {
            case .fade(let fade): fadeRemaining[fade.screen] = Int(fade.duration)
            case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
            case .processReturn(let value): processReturn = value
            case .hintTalk, .presentation: break
            }
        }
        bellProcess = current
        bell = BellScene(angle: current.bellAngle, awaitingTouch: current.awaitingTouch,
                         quitEnabled: current.quitEnabled)
        guard step.status != 0 else { return }
        bellProcess = nil
        bell = nil
        fadeRemaining = [:]
        stopTimer()
        if step.status == 1 {
            runner.halt("Bell hint talk (mode 20 via 0x021FE468) is not recovered")
        } else {
            runner.finishProcess(returnValue: processReturn)
        }
        settle()
    }

    /// One update of process 25. Status 2 hands the result to the event runner.
    private func updateSign() {
        guard var current = signProcess else { return }
        let input = OriginalSignProcess.Input(heldTouch: heldTouch.map { .init(x: $0.x, y: $0.y) },
            newTouch: pendingTouch.map { .init(x: $0.x, y: $0.y) }, leftHanded: false,
            screen0FadeComplete: (fadeRemaining[0] ?? 0) == 0)
        pendingTouch = nil
        for (screen, remaining) in fadeRemaining where remaining > 0 { fadeRemaining[screen] = remaining - 1 }
        let step = current.update(input)
        for effect in step.effects {
            switch effect {
            case .fade(let fade): fadeRemaining[fade.screen] = Int(fade.duration)
            case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
            case .processReturn(let value): processReturn = value
            case .hintTalk, .presentation: break
            }
        }
        signProcess = current
        sign = SignScene(strokes: current.strokes, awaitingStroke: current.awaitingStroke,
                         quitEnabled: current.quitEnabled)
        guard step.status == 2 else { return }
        signProcess = nil
        sign = nil
        heldTouch = nil
        fadeRemaining = [:]
        stopTimer()
        runner.finishProcess(returnValue: processReturn)
        settle()
    }

    public func holdLobbyTouch(x: Float, y: Float) {
        guard !isPaused, chapterTransition == nil, notebook == nil, closeup == nil, door == nil, case .exploration = runner.phase, lobby?.mode == .walking,
              x.isFinite, y.isFinite, x >= 0, x < 192, y >= 0, y < 256 else { return }
        lobbyTouch = SIMD2(x, y)
    }

    public func releaseLobbyTouch() {
        lobbyTouch = nil
        if case .exploration = runner.phase { lobby?.update(heldPageTouch: nil) }
    }

    public var nearbyDoor: Int16? {
        guard let doorTable else { return nil }
        return lobby?.nearbyDoor(in: runner.game, table: doorTable)
    }

    public func inspectNearbyDoor() {
        guard !isPaused, chapterTransition == nil, notebook == nil, closeup == nil, door == nil, case .exploration = runner.phase,
              let destination = nearbyDoor, let lobby, let doorTable else { return }
        if doorTable.departsDirectly(from: lobby.mapID, to: destination, game: runner.game) {
            lobbyTouch = nil
            return departThroughDoor(to: destination)
        }
        do {
            guard let connection = doorTable.connection(from: lobby.mapID, to: destination),
                  let record = try OriginalSearchTable.bundled(map: lobby.mapName).door(id: UInt16(connection.id)),
                  let view = try OriginalUpViewTable.bundled(map: lobby.mapName).views.first(where: { $0.id == Int16(bitPattern: record.upViewID) }),
                  view.layers.allSatisfy({ $0.itemID < 0 && $0.processID < 0 }) else {
                throw OriginalDataError.unsupported("Door destination \(destination)")
            }
            let library = try OriginalBitmapLibrary.bundled()
            let images = try ([view.background] + view.layers.map(\.asset)).map {
                try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
            }
            doorImage = try OriginalUpViewImage(bitmaps: images, visible: Array(repeating: true, count: images.count))
            itemNames = try OriginalItemNames.bundled().names
            door = OriginalDoorScene(destination: destination, doorID: connection.id, area: record.areaID, view: view)
            lobbyTouch = nil
            runner.interactWithDoor(area: record.areaID)
            settle()
        } catch { runner.halt("The door could not be loaded: \(error)"); settle() }
    }

    public func selectDoorComponent(x: Int, y: Int) {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, door != nil else { return }
        if door?.select(doorImage?.hit(pageX: x, pageY: y)) == true { confirmDoorComponent() }
    }

    public func useItemAtDoor(_ item: UInt8?) {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, door != nil else { return }
        if let item, (try? runner.game.inventory.items.contains(item)) != true { return }
        door?.use(item)
    }

    public func confirmDoorComponent() {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, let door, let selected = door.selected else { return }
        self.door?.clearSelection()
        let opensDoor = door.item == nil && selected == 2
            && runner.game.value(for: .doorOpen(index: UInt16(door.doorID))) == false
        let event = door.view.layers[selected - 1].eventID
        runner.interactWithDoor(area: door.area, upView: event, item: door.item)
        self.door?.use(nil)
        if opensDoor {
            pendingDoorOpen = door.destination
        } else if runner.eventIndex == nil {
            runner.halt("The default door response is not recovered")
        }
        settle()
    }

    private func departThroughDoor(to destination: Int16) {
        let requestStart = runner.processRequests.count
        if runner.beginMapDeparture(to: destination) {
            pendingDeparture = (destination, requestStart)
            return settle()
        }
        moveToMap(destination)
    }

    public func leaveDoor() {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase else { return }
        door = nil
        doorImage = nil
        settle()
    }


    public func talkToNearbyPerson() {
        guard !isPaused, chapterTransition == nil, notebook == nil, closeup == nil, door == nil, case .exploration = runner.phase,
              let person = lobby?.nearbyPerson(in: runner.game) else { return }
        lobbyTouch = nil
        runner.talkToPerson(person)
        settle()
    }

    public func inspectLobbyCounter() {
        guard !isPaused, chapterTransition == nil, notebook == nil, closeup == nil, door == nil, case .exploration = runner.phase,
              var lobby, lobby.canInspectCounter(in: runner.game), let area = lobby.nearbySearchArea else { return }
        do {
            if area != lobby.searchAreaID {
                let suffix = String(format: "%02d", area)
                let model = try OriginalModelLibrary.bundled().load(path: "map/\(lobby.mapName)/\(lobby.mapName)_s\(suffix)/\(lobby.mapName)_s\(suffix).mdf")
                try lobby.prepareSearch(area: area, model: model)
                lobbyRenderer = try OriginalMapRenderer(mapName: lobby.mapName, searchArea: area)
            }
            guard lobby.inspectCounter() else { return }
            self.lobby = lobby
            itemNames = try OriginalItemNames.bundled().names
            searchItem = nil
            lobbyTouch = nil
            redrawLobby()
        } catch { runner.halt("The search view could not be loaded: \(error)"); stopTimer() }
    }

    public func panLobbyCounter(_ value: Float) {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup == nil, lobby?.mode == .counter else { return }
        lobby?.setPan(value)
        redrawLobby()
    }

    public func leaveLobbyCounter() {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase else { return }
        lobby?.leaveCounter()
        searchItem = nil
        redrawLobby()
    }

    public func selectLobbyObject(x: Float, y: Float) {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup == nil, lobby?.mode == .counter else { return }
        do {
            let visible = lobby.map { $0.objectVisibility.visibleNodes(in: $0.counter, map: $0.mapID,
                area: $0.searchAreaID, game: runner.game) }
            if try lobby?.selectCounterObject(page: SIMD2(x, y), visibleNodes: visible) != nil { confirmLobbyObject() }
        } catch { runner.halt("The counter selection failed: \(error)"); stopTimer() }
    }

    public func useItemInSearchView(_ item: UInt8?) {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup == nil, lobby?.mode == .counter else { return }
        if let item, (try? runner.game.inventory.items.contains(item)) != true { return }
        if let item, startInventoryProcess(item) { return }
        searchItem = item
        lobby?.clearSelection()
    }

    public func confirmLobbyObject() {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup == nil, lobby?.mode == .counter,
              let node = lobby?.selectedNode, let subarea = OriginalMapExploration.subarea(node: node) else { return }
        do {
            lobby?.clearSelection()
            guard let lobby else { return }
            if let searchItem {
                runner.useItemInSearchView(searchItem, area: lobby.searchAreaID, subarea: subarea)
                self.searchItem = nil
                try startSearchFallback()
                if runner.eventIndex == nil { runner.halt("The default item response is not recovered") }
            } else {
                let table = try OriginalSearchTable.bundled(map: lobby.mapName)
                if let view = table.upViewID(area: lobby.searchAreaID, subarea: subarea), view != .max {
                    pendingCloseup = (lobby.searchAreaID, subarea, view)
                }
                runner.lookInSearchView(area: lobby.searchAreaID, subarea: subarea, table: table)
                try startSearchFallback()
            }
            settle()
        } catch { runner.halt("The counter selection failed: \(error)"); stopTimer() }
    }

    /**
     * The shared response runs only after the room's selector finds no matching event.
     */
    private func startSearchFallback() throws {
        if let response = try runner.searchFallback(catalog: catalog) {
            searchParent = runner
            runner = response
            presentedPacketOffset = nil
        }
    }

    private func openSearchCloseup(area: UInt16, subarea: UInt16, viewID: UInt16) throws {
        guard let mapName = lobby?.mapName,
              let view = try OriginalUpViewTable.bundled(map: mapName).views.first(where: { $0.id == Int16(bitPattern: viewID) }) else {
            throw OriginalDataError.missing("Search close-up \(viewID)")
        }
        let scene = try OriginalSearchCloseup(area: area, subarea: subarea, view: view)
        let library = try OriginalBitmapLibrary.bundled()
        closeupBitmaps = try ([view.background] + view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        closeupImage = try OriginalUpViewImage(bitmaps: closeupBitmaps, visible: scene.visibility(game: runner.game))
        closeup = scene
        lobbyTouch = nil
        /**
         * Process 98 runs the background response on entry (0x02062F08, case 4).
         */
        runner.lookInCloseup(area: area, subarea: subarea, event: view.id)
        try startSearchFallback()
    }

    public func selectCloseupComponent(x: Int, y: Int) {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup != nil else { return }
        if closeup?.select(closeupImage?.hit(pageX: x, pageY: y)) == true { confirmCloseupComponent() }
    }

    /**
     * Close-up inventory uses the same trick table as the surrounding search view.
     */
    public func useItemInCloseup(_ item: UInt8?) {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup != nil else { return }
        if let item {
            guard (try? runner.game.inventory.items.contains(item)) == true else { return }
            if startInventoryProcess(item) { return }
        }
        searchItem = item
        closeup?.clearSelection()
    }

    private func startInventoryProcess(_ item: UInt8) -> Bool {
        do {
            guard try runner.beginInventoryProcess(item: item, table: .bundled()) else { return false }
            searchItem = nil
            lobby?.clearSelection()
            closeup?.clearSelection()
            settle()
        } catch {
            runner.halt("The inventory process could not be loaded: \(error)")
            settle()
        }
        return true
    }

    public func confirmCloseupComponent() {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, let closeup, let event = closeup.selectedEvent else { return }
        self.closeup?.clearSelection()
        if let searchItem {
            pendingChildCloseup = nil
            runner.useItemInCloseup(searchItem, event: event)
            self.searchItem = nil
        } else {
            pendingCloseupDetail = closeup.selectedDetailAsset.map { (event, $0) }
            pendingChildCloseup = pendingCloseupDetail == nil
                ? closeup.selectedChildView.map { ($0, runner.processRequests.count) } : nil
            runner.lookInCloseup(area: closeup.area, subarea: closeup.subarea, event: event)
        }
        do { try startSearchFallback() }
        catch { runner.halt("The close-up response could not be loaded: \(error)") }
        settle()
    }

    public func leaveSearchCloseup() {
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup != nil else { return }
        searchItem = nil
        if let parent = closeupParents.popLast() {
            closeup = parent.scene
            closeupBitmaps = parent.bitmaps
            return settle()
        }
        closeup = nil
        closeupImage = nil
        closeupBitmaps = []
        settle()
    }

    private func renderLobby() throws {
        if let lobby { lobbyImage = try lobbyRenderer?.render(lobby, game: runner.game) }
    }

    private func moveToMap(_ map: Int16) {
        do {
            guard let name = OriginalMapExploration.supportedMaps[map] else {
                throw OriginalDataError.unsupported("Map \(map) in this chapter")
            }
            /**
             * Map entry builds the controller before its arrival script runs (0x02029B78).
             * A clock command can clear the script state's previous map during that arrival.
             */
            let exploration = try OriginalMapExploration.bundled(mapID: map, previousMapID: runner.game.mapID)
            let renderer = try OriginalMapRenderer(mapName: name)
            runner = try runner.moving(to: map, program: catalog.loadProgram("EP\(runner.game.chapter + 1)_\(name)"))
            handledMapRequests = 0
            lobby = exploration
            lobbyRenderer = renderer
            lobbyMap = renderer.map
            lobbyImage = nil
            presentedPacketOffset = nil
            settle()
        } catch { runner.halt("The next map could not be loaded: \(error)"); stopTimer() }
    }

    /**
     * Restores a native chapter checkpoint before the original title process.
     */
    public static func restoring(_ checkpoint: OriginalChapterSave, audio: AudioController,
                                 saveStore: any OriginalChapterSaveStore,
                                 puzzleSeed: @escaping () -> UInt32 = { UInt32.random(in: .min ... .max) }) throws -> OriginalPlaySession {
        let game = try checkpoint.gameState()
        let catalog = try OriginalScriptCatalog.bundled()
        let program = try catalog.loadProgram("EP2_R205")
        var runner = try OriginalEventRunner(program: program, game: game, deferArrival: true)
        try runner.beginChapterTitle()
        var transition = OriginalChapterTransition()
        transition.stage = .title
        return OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
                                   puzzleSeed: puzzleSeed, saveStore: saveStore, chapterTransition: transition)
    }

    /**
     * The chapter save decision precedes the title on both branches.
     */
    public func answerChapterSave(_ save: Bool) {
        guard !isPaused, chapterTransition?.stage == .prompt else { return }
        if !save { return showChapterTitle() }
        do {
            chapterTransition?.slots = try (0..<3).map { try saveStore.load(slot: $0) }
            chapterTransition?.error = nil
            chapterTransition?.stage = .slots
        } catch { chapterTransition?.error = "The save slots could not be read: \(error)" }
    }

    public func selectChapterSaveSlot(_ slot: Int) {
        guard !isPaused, chapterTransition?.stage == .slots, (0..<3).contains(slot) else { return }
        chapterTransition?.selectedSlot = slot
        chapterTransition?.error = nil
    }

    public func confirmChapterSaveSlot() {
        guard !isPaused, chapterTransition?.stage == .slots,
              let slot = chapterTransition?.selectedSlot else { return }
        if chapterTransition?.slots[slot] != nil { chapterTransition?.stage = .overwrite }
        else { writeChapterSave() }
    }

    public func confirmChapterOverwrite(_ overwrite: Bool) {
        guard !isPaused, chapterTransition?.stage == .overwrite else { return }
        if overwrite { writeChapterSave() }
        else { chapterTransition?.stage = .slots }
    }

    public func cancelChapterSave() {
        guard !isPaused, chapterTransition?.stage == .slots else { return }
        if chapterTransition?.selectedSlot != nil {
            chapterTransition?.selectedSlot = nil
            chapterTransition?.error = nil
        } else { showChapterTitle() }
    }

    private func writeChapterSave() {
        guard let slot = chapterTransition?.selectedSlot else { return }
        do {
            let checkpoint = try OriginalChapterSave(game: runner.game, savedAt: saveDate())
            try saveStore.save(checkpoint, slot: slot)
            chapterTransition?.slots[slot] = checkpoint
            chapterTransition?.error = nil
            showChapterTitle()
        } catch {
            chapterTransition?.stage = .slots
            chapterTransition?.error = "The game could not be saved: \(error)"
        }
    }

    private func showChapterTitle() {
        do {
            chapterTitleImages = try OriginalChapterTitleImages(library: .bundled())
            try runner.beginChapterTitle()
            chapterTransition?.error = nil
            chapterTransition?.stage = .title
        } catch {
            chapterTransition = nil
            runner.halt("The chapter title could not start: \(error)")
        }
    }

    public func continueChapterTitle() {
        guard !isPaused, chapterTransition?.stage == .title else { return }
        do {
            guard let map = OriginalMapExploration.supportedMaps[runner.game.mapID] else {
                throw OriginalDataError.unsupported("Chapter map")
            }
            let program = try catalog.loadProgram("EP\(runner.game.chapter + 1)_\(map)")
            let keywords = try OriginalKeywordTable.chapterFile(for: program.name).map {
                try OriginalKeywordTable(decoded: catalog.decodedFile($0))
            }
            // Process 9 saves the retry state before the room arrival (0x02018310).
            runner.saveRetryCheckpoint()
            runner = try OriginalEventRunner(program: program, game: runner.game, keywords: keywords)
            chapterTransition = nil
            handledMapRequests = 0
            presentedPacketOffset = nil
            settle()
        } catch {
            chapterTransition = nil
            runner.halt("The next chapter could not be loaded: \(error)")
        }
    }

    private func redrawLobby() {
        do { try renderLobby() }
        catch { runner.halt("The map could not be drawn: \(error)"); stopTimer() }
    }
}
