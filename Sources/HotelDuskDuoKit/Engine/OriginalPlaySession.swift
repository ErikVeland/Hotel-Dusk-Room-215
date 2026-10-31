import Foundation
import Combine
import CoreGraphics

/// Runs the recovered event flow and native interactions at the DS update
/// rate. Unrecovered story requests stop with their source location.
@MainActor
public final class OriginalPlaySession: ObservableObject {
    let dialogueNotebook = DialogueNotebook()
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
    @Published private(set) var isBrowsingInventory = false
    @Published public private(set) var searchItem: UInt8?
    @Published public private(set) var notebook: OriginalNotebook?
    @Published public private(set) var notebookImage: CGImage?
    @Published public private(set) var nativeNotebookPages: [String: Data] = [:]
    private var notebookTouch: SIMD2<Int>?
    @Published public private(set) var runner: OriginalEventRunner
    @Published public private(set) var encounterPortraits: [OriginalEncounterAnimations.Portrait] = []
    private var encounterAnimations: OriginalEncounterAnimations?
    @Published public private(set) var entrance: EntranceScene?
    @Published public private(set) var bell: BellScene?

    public struct SignScene: Equatable {
        public var strokes: [Int16]
        public var awaitingStroke: Bool
        public var quitEnabled: Bool
    }
    @Published public private(set) var sign: SignScene?
    @Published public private(set) var vendingMachine: OriginalVendingMachineProcess?
    @Published public private(set) var vendingMachineImage: CGImage?
    @Published public private(set) var vendingMachineProducts: [UInt8: CGImage] = [:]
    @Published public private(set) var numberSeal: OriginalNumberSealProcess?
    @Published public private(set) var numberSealImage: CGImage?
    private var numberSealTouch: SIMD2<Int>?
    @Published public private(set) var codeNotice: OriginalCodeNoticeProcess?
    @Published public private(set) var codeNoticeImage: CGImage?
    @Published public private(set) var codeNoticeCaption: String?
    @Published public private(set) var afterConfess: OriginalAfterConfessProcess?
    @Published public private(set) var afterConfessTouchImage: CGImage?
    @Published public private(set) var afterConfessUpperImage: CGImage?
    private var afterConfessRenderer: OriginalAfterConfessRenderer?
    @Published public private(set) var vsScene: OriginalVSSceneProcess?
    @Published public private(set) var vsSceneImage: CGImage?
    private var vsSceneRenderer: OriginalVSSceneRenderer?
    @Published public private(set) var picturePeel: OriginalPicturePeelProcess?
    @Published public private(set) var picturePeelImage: CGImage?
    @Published public private(set) var picturePeelUpperImage: CGImage?
    private var picturePeelRenderer: OriginalPicturePeelRenderer?
    private var picturePeelTouch: SIMD2<Int>?
    @Published public private(set) var typewriter: OriginalTypewriterProcess?
    @Published public private(set) var typewriterUpperImage: CGImage?
    @Published public private(set) var typewriterImage: CGImage?
    private var typewriterRenderer: OriginalTypewriterRenderer?
    @Published public private(set) var jigsaw: OriginalJigsawProcess?
    @Published public private(set) var clock: OriginalClockProcess?
    @Published public private(set) var clockImage: CGImage?
    private var clockRenderer: OriginalClockRenderer?
    private var clockUpdates: UInt64 = 0
    private var resumesWalkingAfterClock = false
    @Published public private(set) var cassetteBallpoint: OriginalCassetteBallpointProcess?
    @Published public private(set) var cassetteRewind: OriginalCassetteRewindProcess?
    @Published public private(set) var cassetteDeck: OriginalCassetteDeckProcess?
    @Published public private(set) var cassetteImage: CGImage?
    @Published public private(set) var cassetteOpacity = 1.0
    private var cassetteRenderer: (any OriginalCassetteRendering)?
    private var cassetteDeckRenderer: (any OriginalCassetteDeckRendering)?
    private var cassetteTouch: SIMD2<Int>?
    private var cassettePress: SIMD2<Int>?
    @Published public private(set) var applePainting: OriginalApplePaintingProcess?
    @Published public private(set) var applePaintingImage: CGImage?
    private var applePaintingRenderer: OriginalApplePaintingRenderer?
    @Published public private(set) var pencilSharpener: OriginalPencilSharpenerProcess?
    @Published public private(set) var pencilSharpenerImage: CGImage?
    @Published public private(set) var bowlingMatch: OriginalBowlingMatchProcess?
    @Published public private(set) var bowlingImage: CGImage?
    private var bowlingRenderer: (any OriginalBowlingRendering)?
    private var bowlingTouch: SIMD2<Float>?
    private var bowlingParent: OriginalEventRunner?
    private var applePaintingMask: OriginalApplePaintingMask?
    @Published public private(set) var cpr: OriginalCPRProcess?
    @Published public private(set) var appleWordEntry: OriginalAppleWordEntryProcess?
    @Published public private(set) var suitcaseKey: OriginalSuitcaseKeyProcess?
    @Published public private(set) var suitcaseImage: CGImage?
    private var suitcaseRenderer: (any OriginalSuitcaseRendering)?
    private var suitcaseTouch: SIMD2<Float>?
    @Published public private(set) var fountainPen: OriginalFountainPenProcess?
    @Published public private(set) var fountainPenImage: CGImage?
    @Published public private(set) var fountainPenScreenEffects = OriginalScreenEffects()
    private var fountainPenRenderer: OriginalFountainPenRenderer?
    private var fountainPenTouch: SIMD2<Int>?
    public let puzzleMicrophone = OriginalMicrophoneInput()
    @Published public private(set) var differences: OriginalDifferencesProcess?
    @Published public private(set) var differencesImage: CGImage?
    @Published public private(set) var differencesScreenEffects = OriginalScreenEffects()
    private var differencesRenderer: OriginalDifferencesRenderer?
    private var differencesTouch: SIMD2<Int>?
    private var differencesParent: OriginalEventRunner?
    @Published public private(set) var toiletTank: OriginalToiletTankProcess?
    @Published public private(set) var toiletTankImage: CGImage?
    @Published public private(set) var toiletTankScreenEffects = OriginalScreenEffects()
    private var toiletTankRenderer: (any OriginalToiletTankRendering)?
    private var toiletTankTouch: SIMD2<Int>?
    private var toiletTankParent: OriginalEventRunner?
    @Published public private(set) var linenWagon: OriginalLinenWagonProcess?
    @Published public private(set) var linenWagonImage: CGImage?
    @Published public private(set) var linenWagonScreenEffects = OriginalScreenEffects()
    private var linenWagonRenderer: OriginalLinenWagonRenderer?
    private var linenWagonTouch: SIMD2<Int>?
    @Published public private(set) var jukebox: OriginalJukeboxProcess?
    @Published public private(set) var matchsticks: OriginalMatchstickProcess?
    @Published public private(set) var matchsticksImage: CGImage?
    @Published public private(set) var matchsticksScreenEffects = OriginalScreenEffects()
    private var matchsticksRenderer: OriginalMatchstickRenderer?
    private var matchsticksTouch: SIMD2<Int>?
    @Published public private(set) var coinPuzzle: OriginalCoinProcess?
    @Published public private(set) var coinPuzzleImage: CGImage?
    @Published public private(set) var coinPuzzleScreenEffects = OriginalScreenEffects()
    private var coinPuzzleRenderer: OriginalCoinRenderer?
    private var coinPuzzleTouch: SIMD2<Float>?
    @Published public private(set) var dollRepair: OriginalDollRepairProcess?
    @Published public private(set) var dollRepairImage: CGImage?
    @Published public private(set) var dollRepairScreenEffects = OriginalScreenEffects()
    private var dollRepairRenderer: OriginalDollRepairRenderer?
    private var dollRepairTouch: SIMD2<Int>?
    @Published public private(set) var bookmarkBox: OriginalBookmarkBoxProcess?
    @Published public private(set) var bookmarkBoxImage: CGImage?
    @Published public private(set) var bookmarkBoxScreenEffects = OriginalScreenEffects()
    private let bookmarkBoxRender: @MainActor (OriginalBookmarkBoxProcess) throws -> CGImage
    private var bookmarkBoxTouch: SIMD2<Int>?
    @Published public private(set) var switchboard: OriginalSwitchboardProcess?
    @Published public private(set) var switchboardImage: CGImage?
    @Published public private(set) var switchboardScreenEffects = OriginalScreenEffects()
    private var switchboardRenderer: OriginalSwitchboardRenderer?
    private var switchboardTouch: SIMD2<Int>?
    @Published public private(set) var labelPeel: OriginalLabelPeelProcess?
    @Published public private(set) var labelPeelImage: CGImage?
    @Published public private(set) var labelPeelScreenEffects = OriginalScreenEffects()
    private var labelPeelRenderer: OriginalLabelPeelRenderer?
    private var labelPeelTouch: SIMD2<Int>?
    private var labelPeelFollowupPending = false
    @Published public private(set) var christmasTree: OriginalChristmasTreeProcess?
    @Published public private(set) var christmasTreeImage: CGImage?
    @Published public private(set) var christmasTreeScreenEffects = OriginalScreenEffects()
    private var christmasTreeRenderer: OriginalChristmasTreeRenderer?
    private var christmasTreeDraggedDecoration: Int?
    @Published public private(set) var searchShed: OriginalSearchShedProcess?
    @Published public private(set) var searchShedImage: CGImage?
    @Published public private(set) var brickWall: OriginalBrickWallProcess?
    private var brickWallTouch: SIMD2<Float>?
    @Published public private(set) var searchShedScreenEffects = OriginalScreenEffects()
    private var searchShedRenderer: (any OriginalSearchShedRendering)?
    private var searchShedTouch: SIMD2<Float>?
    @Published public private(set) var bagSearch: OriginalBagSearchProcess?
    @Published public private(set) var bagSearchImage: CGImage?
    @Published public private(set) var bagSearchScreenEffects = OriginalScreenEffects()
    private var bagSearchRenderer: (any OriginalBagSearchRendering)?
    private var bagSearchTouch: SIMD2<Float>?
    private var switchboardParent: OriginalEventRunner?
    @Published public private(set) var thinWire: OriginalThinWireProcess?
    @Published public private(set) var thinWireImage: CGImage?
    private var thinWireRenderer: (any OriginalThinWireRendering)?
    private var thinWireTouch: SIMD2<Float>?
    @Published public private(set) var hanger: OriginalHangerProcess?
    @Published public private(set) var hangerImage: CGImage?
    @Published public private(set) var hangerScreenEffects = OriginalScreenEffects()
    private var hangerRenderer: (any OriginalHangerRendering)?
    private var hangerTouch: SIMD2<Float>?
    @Published public private(set) var suitcaseContents: OriginalSuitcaseContentsProcess?
    @Published public private(set) var suitcaseContentsImage: CGImage?
    @Published public private(set) var suitcaseContentsScreenEffects = OriginalScreenEffects()
    private var suitcaseContentsRenderer: (any OriginalSuitcaseContentsRendering)?
    private var suitcaseContentsTouch: SIMD2<Float>?
    private var suitcaseContentsParent: OriginalEventRunner?
    @Published public private(set) var memoPull: OriginalMemoPullProcess?
    @Published public private(set) var memoPullImage: CGImage?
    @Published public private(set) var memoPullScreenEffects = OriginalScreenEffects()
    private var memoPullRenderer: (any OriginalMemoPullRendering)?
    private var memoPullTouch: SIMD2<Float>?
    @Published public private(set) var cabinetDial: OriginalCabinetDialProcess?
    @Published public private(set) var cabinetDialImage: CGImage?
    @Published public private(set) var cabinetDialScreenEffects = OriginalScreenEffects()
    private var cabinetDialRenderer: (any OriginalCabinetDialRendering)?
    private var cabinetDialTouch: SIMD2<Float>?
    @Published public private(set) var crowbar: OriginalCrowbarProcess?
    @Published public private(set) var crowbarImage: CGImage?
    @Published public private(set) var crowbarScreenEffects = OriginalScreenEffects()
    private var crowbarRenderer: (any OriginalCrowbarRendering)?
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
    /// The conversation that a notebook memo response interrupts.
    private var memoParent: OriginalEventRunner?
    private var shownItemParent: OriginalEventRunner?
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
    private var lobbyRenderer: (any OriginalMapRendering)?
    private let mapRendererFactory: OriginalMapRendererFactory
    private let suitcaseRendererFactory: OriginalSuitcaseRendererFactory
    private let hangerRendererFactory: OriginalHangerRendererFactory
    private let thinWireRendererFactory: OriginalThinWireRendererFactory
    private let suitcaseContentsRendererFactory: OriginalSuitcaseContentsRendererFactory
    private let memoPullRendererFactory: OriginalMemoPullRendererFactory
    private let crowbarRendererFactory: OriginalCrowbarRendererFactory
    private let cabinetDialRendererFactory: OriginalCabinetDialRendererFactory
    private let cassetteRendererFactory: OriginalCassetteRendererFactory
    private let cassetteDeckRendererFactory: OriginalCassetteDeckRendererFactory
    private let bowlingRendererFactory: OriginalBowlingRendererFactory
    private let searchShedRendererFactory: OriginalSearchShedRendererFactory
    private let toiletTankRendererFactory: OriginalToiletTankRendererFactory
    private let bagSearchRendererFactory: OriginalBagSearchRendererFactory
    private var lobbyTouch: SIMD2<Float>?
    private var firstPersonMovement: SIMD2<Float>?
    private var usesLegacyInteractionPacing = false
    private var hasReturnedFromDunningIntroduction = false
    private var signProcess: OriginalSignProcess?
    private var heldTouch: OriginalEntranceProcess.Touch?
    private let audio: AudioController
    private let originalEffectPlayer: ((Int, Int) -> Void)?
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
    private var pendingCodeNoticeTouch: SIMD2<Int>?
    private var timer: Timer?
    @Published private(set) var isPaused = false
    private var presentedPacketOffset: Int?
    /// Called at stable walking boundaries, never while an event is suspended.
    var onWalkingCheckpoint: ((OriginalResumeSave) -> Void)?
    var onProgressCheckpoint: ((OriginalResumeSave) -> Void)?
    var onProgressSaveError: ((Error) -> Void)?
    var onRecoverableStop: ((OriginalEventRunner.Halt) -> Void)?
    private var didReportRecoverableStop = false
    private var progressJournal: OriginalPlayProgress?
    private var routeTrace: OriginalRouteTraceLog?
    private var progressInputActive = false
    private var isReplayingProgress = false
    private var replaySeedIndex = [0, 0]
    private var replaySlotIndex = 0
    private var replayWriteIndex = 0
    private var replayInvalid = false
    var replayMicrophoneEnergy: UInt32 = 0
    private(set) var usesInstantSaves = false

    public var canSaveWalkingCheckpoint: Bool {
        guard case .exploration(let map) = runner.phase else { return false }
        return lobby?.mapID == map && lobby?.mode == .walking && chapterTransition == nil
            && notebook == nil && door == nil && closeup == nil && searchParent == nil && memoParent == nil && shownItemParent == nil
            && jigsawParent == nil && toiletTankParent == nil && differencesParent == nil && switchboardParent == nil && suitcaseContentsParent == nil && pendingDeparture == nil
            && pendingDoorOpen == nil && pendingCloseup == nil && pendingChildCloseup == nil
            && handledMapRequests == runner.processRequests.count
    }

    var canReviewConversations: Bool {
        guard !dialogueNotebook.ink.isEmpty, chapterTransition == nil, notebook == nil,
              process == nil, bellProcess == nil, signProcess == nil, vendingMachine == nil, numberSeal == nil, codeNotice == nil, picturePeel == nil, jigsaw == nil,
              clock == nil, suitcaseKey == nil, thinWire == nil, hanger == nil, switchboard == nil, fountainPen == nil, bookmarkBox == nil, dollRepair == nil, coinPuzzle == nil, matchsticks == nil, jukebox == nil, linenWagon == nil, differences == nil, toiletTank == nil,
              suitcaseContents == nil, memoPull == nil, cabinetDial == nil,
              crowbar == nil, memoDrawing == nil, paperclip == nil, labelPeel == nil, christmasTree == nil, searchShed == nil,
              bagSearch == nil,
              cassetteBallpoint == nil, cassetteRewind == nil,
              applePainting == nil, appleWordEntry == nil,
              pencilSharpener == nil,
              bowlingMatch == nil,
              cpr == nil,
              touchPicture == nil else { return false }
        switch runner.phase {
        case .dialogue, .itemNotice, .choice, .questions: return true
        case .exploration: return lobby?.mode == .walking && door == nil && closeup == nil
        default: return false
        }
    }

    public func walkingCheckpoint() throws -> OriginalResumeSave {
        guard canSaveWalkingCheckpoint, let lobby else {
            throw OriginalDataError.unsupported("Return to walking before saving")
        }
        var game = runner.game
        game.setMapPosition(lobby.position, facing: lobby.facing)
        return try OriginalResumeSave(game: game, checkpointFacing: lobby.checkpointFacing,
                                      musicSequenceID: audio.currentSequenceID, savedAt: saveDate())
    }

    private func checkpointWalking() {
        guard onWalkingCheckpoint != nil, let checkpoint = try? walkingCheckpoint() else { return }
        onWalkingCheckpoint?(checkpoint)
    }

    public init(runner: OriginalEventRunner, audio: AudioController, catalog: OriginalScriptCatalog, fixture: String? = nil,
                jigsawSeed: @escaping () -> UInt32 = { UInt32.random(in: .min ... .max) },
                puzzleSeed: @escaping () -> UInt32 = { UInt32.random(in: .min ... .max) },
                saveStore: any OriginalChapterSaveStore = OriginalChapterFileStore.application,
                saveDate: @escaping () -> Date = Date.init,
                originalEffectPlayer: ((Int, Int) -> Void)? = nil,
                chapterTransition: OriginalChapterTransition? = nil,
                restoredExploration: OriginalMapExploration? = nil,
                mapRendererFactory: @escaping OriginalMapRendererFactory = { try OriginalMapRenderer(mapName: $0, searchArea: $1) },
                suitcaseRendererFactory: @escaping OriginalSuitcaseRendererFactory = { try OriginalSuitcaseRenderer() },
                hangerRendererFactory: @escaping OriginalHangerRendererFactory = { try OriginalHangerRenderer() },
                thinWireRendererFactory: @escaping OriginalThinWireRendererFactory = { try OriginalThinWireRenderer(variant: $0) },
                suitcaseContentsRendererFactory: @escaping OriginalSuitcaseContentsRendererFactory = { try OriginalSuitcaseContentsRenderer() },
                memoPullRendererFactory: @escaping OriginalMemoPullRendererFactory = { try OriginalMemoPullRenderer() },
                crowbarRendererFactory: @escaping OriginalCrowbarRendererFactory = { try OriginalCrowbarRenderer(tornPaper: $0) },
                cabinetDialRendererFactory: @escaping OriginalCabinetDialRendererFactory = { try OriginalCabinetDialRenderer(variant: $0) },
                cassetteRendererFactory: OriginalCassetteRendererFactory? = nil,
                cassetteDeckRendererFactory: OriginalCassetteDeckRendererFactory? = nil,
                bowlingRendererFactory: OriginalBowlingRendererFactory? = nil,
                searchShedRendererFactory: OriginalSearchShedRendererFactory? = nil,
                toiletTankRendererFactory: @escaping OriginalToiletTankRendererFactory = { try OriginalToiletTankRenderer() },
                bagSearchRendererFactory: @escaping OriginalBagSearchRendererFactory = { try OriginalBagSearchRenderer() },
                bookmarkBoxRender: (@MainActor (OriginalBookmarkBoxProcess) throws -> CGImage)? = nil) {
        self.runner = runner
        self.audio = audio
        usesLegacyInteractionPacing = audio.restoresLegacyInteractions
        self.originalEffectPlayer = originalEffectPlayer
        self.catalog = catalog
        encounterAnimations = try? OriginalEncounterAnimations(catalog: catalog)
        self.fixture = fixture
        self.jigsawSeed = jigsawSeed
        self.puzzleSeed = puzzleSeed
        self.saveStore = saveStore
        self.saveDate = saveDate
        self.chapterTransition = chapterTransition
        self.mapRendererFactory = mapRendererFactory
        self.suitcaseRendererFactory = suitcaseRendererFactory
        self.hangerRendererFactory = hangerRendererFactory
        self.thinWireRendererFactory = thinWireRendererFactory
        self.suitcaseContentsRendererFactory = suitcaseContentsRendererFactory
        self.memoPullRendererFactory = memoPullRendererFactory
        self.crowbarRendererFactory = crowbarRendererFactory
        self.cabinetDialRendererFactory = cabinetDialRendererFactory
        self.cassetteRendererFactory = cassetteRendererFactory ?? { try OriginalCassetteRenderer(tool: $0) }
        self.cassetteDeckRendererFactory = cassetteDeckRendererFactory ?? { try OriginalCassetteDeckRenderer() }
        self.bowlingRendererFactory = bowlingRendererFactory ?? { try OriginalBowlingRenderer() }
        self.searchShedRendererFactory = searchShedRendererFactory ?? { try OriginalSearchShedRenderer() }
        self.toiletTankRendererFactory = toiletTankRendererFactory
        self.bagSearchRendererFactory = bagSearchRendererFactory
        if let bookmarkBoxRender {
            self.bookmarkBoxRender = bookmarkBoxRender
        } else {
            var renderer: OriginalBookmarkBoxRenderer?
            self.bookmarkBoxRender = { puzzle in
                if renderer == nil { renderer = try OriginalBookmarkBoxRenderer() }
                guard let renderer else { throw OriginalDataError.invalid("Bookmark box renderer") }
                return try renderer.render(puzzle)
            }
        }
        lobby = restoredExploration
        if chapterTransition?.stage == .title {
            do { chapterTitleImages = try OriginalChapterTitleImages(library: .bundled(), chapter: runner.game.chapter) }
            catch {
                self.chapterTransition = nil
                self.runner.halt("The chapter title could not be loaded: \(error)")
            }
        }
        settle()
    }

    public static func chapterOne(audio: AudioController, timestamp: Int64? = nil, saveStore: any OriginalChapterSaveStore = OriginalChapterFileStore.application,
                                  mapRendererFactory: @escaping OriginalMapRendererFactory = { try OriginalMapRenderer(mapName: $0, searchArea: $1) },
                                  suitcaseRendererFactory: @escaping OriginalSuitcaseRendererFactory = { try OriginalSuitcaseRenderer() },
                                  hangerRendererFactory: @escaping OriginalHangerRendererFactory = { try OriginalHangerRenderer() },
                                  thinWireRendererFactory: @escaping OriginalThinWireRendererFactory = { try OriginalThinWireRenderer(variant: $0) },
                                  suitcaseContentsRendererFactory: @escaping OriginalSuitcaseContentsRendererFactory = { try OriginalSuitcaseContentsRenderer() },
                                  memoPullRendererFactory: @escaping OriginalMemoPullRendererFactory = { try OriginalMemoPullRenderer() },
                                  crowbarRendererFactory: @escaping OriginalCrowbarRendererFactory = { try OriginalCrowbarRenderer(tornPaper: $0) },
                                  cabinetDialRendererFactory: @escaping OriginalCabinetDialRendererFactory = { try OriginalCabinetDialRenderer(variant: $0) },
                                  toiletTankRendererFactory: @escaping OriginalToiletTankRendererFactory = { try OriginalToiletTankRenderer() },
                                  bagSearchRendererFactory: @escaping OriginalBagSearchRendererFactory = { try OriginalBagSearchRenderer() }) throws -> OriginalPlaySession {
        let catalog = try OriginalScriptCatalog.bundled()
        let startTime = timestamp ?? Int64(Date().timeIntervalSince1970)
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: catalog, defaults: .bundled(),
            timestamp: startTime)
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
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog, fixture: fixture, saveStore: saveStore,
                                   mapRendererFactory: mapRendererFactory, suitcaseRendererFactory: suitcaseRendererFactory,
                                   hangerRendererFactory: hangerRendererFactory,
                                   thinWireRendererFactory: thinWireRendererFactory,
                                   suitcaseContentsRendererFactory: suitcaseContentsRendererFactory,
                                   memoPullRendererFactory: memoPullRendererFactory,
                                   crowbarRendererFactory: crowbarRendererFactory,
                                   cabinetDialRendererFactory: cabinetDialRendererFactory,
                                   toiletTankRendererFactory: toiletTankRendererFactory,
                                   bagSearchRendererFactory: bagSearchRendererFactory)
        play.prepareProgress(OriginalPlayProgress(origin: .arrival, base: Data(), timestamp: startTime))
        return play
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
        let recordsProgress = beginProgressInput(.advanceDialogue)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        switch runner.phase {
        case .dialogue, .itemNotice: break
        default: return
        }
        dialogueNotebook.endPresentation()
        runner.acknowledgeDialogue()
        settle()
    }

    /// Presentation taps finish the ink and overflow pages before the script moves on.
    func advanceWrittenDialogue() {
        switch runner.phase {
        case .dialogue, .itemNotice: break
        default: return
        }
        guard !isPaused, dialogueNotebook.consumeTap() else { return }
        advanceDialogue()
    }

    func beginInventoryBrowsing() {
        let recordsProgress = beginProgressInput(.beginInventoryBrowsing)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, notebook == nil else { return }
        switch runner.phase {
        case .exploration, .questions: break
        default: return
        }
        lobbyTouch = nil
        firstPersonMovement = nil
        isBrowsingInventory = true
    }

    func endInventoryBrowsing() {
        let recordsProgress = beginProgressInput(.endInventoryBrowsing)
        defer { endProgressInput(recordsProgress) }
        if isBrowsingInventory { isBrowsingInventory = false }
    }

    /// The player picked an option of an original choice prompt.
    public func choose(_ id: UInt16) {
        let recordsProgress = beginProgressInput(.choose(id: id))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .choice(let choices) = runner.phase,
              let choice = choices.first(where: { $0.id == id }) else { return }
        dialogueNotebook.followNextPassage()
        runner.choose(id)
        settle()
        // Some scripts first repeat the selected answer. The choice already
        // confirms that line, so show the response without another Continue.
        if case .dialogue(let packet) = runner.phase {
            let text = packet.pages.flatMap { OriginalDialogueLines(page: $0).lines }
                .map { $0.map(\.text).joined() }.joined(separator: " ")
            func words(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            if words(text) == words(choice.label) {
                dialogueNotebook.followNextPassage()
                dialogueNotebook.endPresentation()
                runner.acknowledgeDialogue()
                settle()
            }
        }
    }

    /// The player pressed the pulsing interrupt icon during an armed page.
    public func interrupt() {
        let recordsProgress = beginProgressInput(.interrupt)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, runner.interruptAvailable else { return }
        runner.pressInterrupt()
        settle()
    }

    /// The player asked the partner about a keyword in the question menu.
    public func ask(_ keyword: Int16) {
        let recordsProgress = beginProgressInput(.ask(keyword: keyword))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, notebook == nil, case .questions = runner.phase else { return }
        dialogueNotebook.followNextPassage()
        runner.ask(keyword)
        settle()
    }

    /// The player closed the question menu.
    public func leaveConversation() {
        let recordsProgress = beginProgressInput(.leaveConversation)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, notebook == nil, case .questions = runner.phase else { return }
        runner.leave()
        settle()
    }

    /**
     * Shows an inventory item to the current conversation partner.
     */
    public func showItemInConversation(_ item: UInt8) {
        let recordsProgress = beginProgressInput(.showItemInConversation(item: item))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, notebook == nil, case .questions = runner.phase else { return }
        do {
            if let response = try runner.showItem(item, catalog: catalog) {
                shownItemParent = runner
                runner = response
            }
        } catch { runner.halt("The shared item response could not be loaded: \(error)") }
        settle()
    }

    /**
     * Opens the original memo editor while retaining the map or conversation.
     */
    public func openNotebook() {
        let recordsProgress = beginProgressInput(.openNotebook)
        defer { endProgressInput(recordsProgress) }
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
            firstPersonMovement = nil
            refreshNotebookImage()
            settle()
        } catch { runner.halt("The notebook could not open: \(error)"); settle() }
    }

    public func closeNotebook() {
        let recordsProgress = beginProgressInput(.closeNotebook)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, notebook != nil else { return }
        releaseNotebook()
        notebook?.storePage()
        if let notebook { runner.storeNotebook(notebook) }
        let memo = notebook?.unreadMemo
        notebook = nil
        notebookImage = nil
        if let memo, case .questions = runner.phase {
            do {
                var parent = runner
                let response = try parent.readMemo(memo, catalog: catalog)
                memoParent = parent
                runner = response
                presentedPacketOffset = nil
            } catch { runner.halt("The memo response could not be loaded: \(error)") }
        }
        settle()
    }

    public func turnNotebookPage(forward: Bool) {
        let recordsProgress = beginProgressInput(.turnNotebookPage(forward: forward))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, notebook != nil else { return }
        releaseNotebook()
        notebook?.turnPage(forward: forward)
        if let notebook { runner.storeNotebook(notebook) }
        refreshNotebookImage()
    }

    public func setNativeNotebookInk(page: Int, drawing: Data, packed: Data) {
        guard !isPaused, let current = notebook, current.canEdit, current.page == page,
              drawing.count <= 8_000_000, packed.count == OriginalNotebook.packedSize else { return }
        let recordsProgress = beginProgressInput(.setNativeNotebookInk(page: page, drawing: drawing, packed: packed))
        defer { endProgressInput(recordsProgress) }
        do {
            try notebook?.replaceInk(packed: packed)
            nativeNotebookPages[String(page)] = drawing
            refreshNotebookImage()
        } catch { onProgressSaveError?(error) }
    }

    public func clearNotebookPage() {
        let recordsProgress = beginProgressInput(.clearNotebookPage)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        releaseNotebook()
        notebook?.clear()
        refreshNotebookImage()
    }

    public func undoNotebookEdit() {
        let recordsProgress = beginProgressInput(.undoNotebookEdit)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        releaseNotebook()
        notebook?.undo()
        refreshNotebookImage()
    }

    public func toggleNotebookEraser() {
        let recordsProgress = beginProgressInput(.toggleNotebookEraser)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        releaseNotebook()
        notebook?.toggleEraser()
    }

    public func holdNotebookTouch(x: Int, y: Int) {
        let recordsProgress = beginProgressInput(.holdNotebookTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, notebook != nil else { return }
        notebookTouch = SIMD2(x, y)
    }

    public func releaseNotebook() {
        let recordsProgress = beginProgressInput(.releaseNotebook)
        defer { endProgressInput(recordsProgress) }
        notebookTouch = nil
        notebook?.release()
    }

    private func refreshNotebookImage() {
        notebookImage = notebook.flatMap(OriginalNotebookImage.render)
    }

    /// A new press on the touch page, in rotated page pixels (192 × 256).
    public func touchEntrance(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.touchEntrance(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, process != nil || bellProcess != nil || signProcess != nil,
              (0..<192).contains(pageX), (0..<256).contains(pageY) else { return }
        pendingTouch = OriginalEntranceProcess.Touch(x: 255 - pageY, y: pageX)
    }

    /**
     * Sends a new touch-page press to the Chapter 10 code notice.
     */
    public func touchCodeNotice(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.touchCodeNotice(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(let id) = runner.phase, id == 62 || id == 67,
              (0..<192).contains(pageX), (0..<256).contains(pageY), codeNotice != nil else { return }
        pendingCodeNoticeTouch = SIMD2(pageX, pageY)
    }

    public func touchNumberSeal(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.touchNumberSeal(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, runner.phase == .process(id: 87), numberSeal != nil,
              (0..<192).contains(pageX), (0..<256).contains(pageY) else { return }
        numberSealTouch = SIMD2(pageX, pageY)
    }

    public func vendingMachineAction(_ action: OriginalVendingMachineProcess.Action) {
        let recordsProgress = beginProgressInput(.vendingMachine(action: action))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, runner.phase == .process(id: 57), var process = vendingMachine else { return }
        if let sound = process.receive(action) {
            try? audio.playOriginalEffect(archiveID: action == .quit ? 8 : 52, entryID: sound)
        }
        vendingMachine = process
    }

    /**
     * Sends a touch-page press to the Chapter 10 VSScene interaction.
     */
    public func touchVSScene() {
        let recordsProgress = beginProgressInput(.touchVSScene)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(88) = runner.phase, var process = vsScene else { return }
        process.touch()
        vsScene = process
    }

    /**
     * Sends a tap from the touch page to the typewriter keyboard.
     */
    public func tapTypewriter(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.tapTypewriter(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(let id) = runner.phase,
              [74, 86, 90, 91].contains(id), (0..<192).contains(pageX),
              (0..<256).contains(pageY), var process = typewriter else { return }
        let submission = process.tap(at: SIMD2(255 - pageY, pageX))
        if submission == .accepted {
            typewriter = nil
            typewriterImage = nil
            typewriterUpperImage = nil
            typewriterRenderer = nil
            stopTimer()
            runner.finishProcess(returnValue: 0)
            settle()
        } else {
            typewriter = process
        }
    }

    /**
     * Changes the typewriter cipher dial while the process is active.
     */
    public func adjustTypewriterShift(by amount: Int) {
        let recordsProgress = beginProgressInput(.adjustTypewriterShift(amount: amount))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, typewriter != nil else { return }
        typewriter?.adjustShift(by: amount)
    }

    /**
     * Leaves the typewriter through its source exit path.
     */
    public func quitTypewriter() {
        let recordsProgress = beginProgressInput(.quitTypewriter)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, var process = typewriter,
              let result = process.requestExit() else { return }
        typewriter = nil
        typewriterImage = nil
        typewriterUpperImage = nil
        typewriterRenderer = nil
        stopTimer()
        runner.finishProcess(returnValue: result)
        settle()
    }

    /**
     * Sends a tap to the Chapter 10 pencil-sharpener exit mask.
     */
    public func tapPencilSharpener(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.tapPencilSharpener(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(59) = runner.phase,
              var process = pencilSharpener else { return }
        process.tap(pageX: pageX, pageY: pageY)
        pencilSharpener = process
    }

    /**
     * Holds the pencil while the player grinds its lead on the file.
     */
    public func holdPencilSharpenerTouch(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(
            .holdPencilSharpenerTouch(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(59) = runner.phase,
              var process = pencilSharpener else { return }
        process.holdTouch(pageX: pageX, pageY: pageY)
        pencilSharpener = process
    }

    /**
     * Releases the held pencil.
     */
    public func releasePencilSharpenerTouch() {
        let recordsProgress = beginProgressInput(.releasePencilSharpenerTouch)
        defer { endProgressInput(recordsProgress) }
        guard case .process(59) = runner.phase, var process = pencilSharpener else { return }
        process.releaseTouch()
        pencilSharpener = process
    }

    /// The held touch on the touch page, in rotated page pixels; nil on release.
    public func holdTouch(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.holdTouch(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard signProcess != nil else { return }
        heldTouch = OriginalEntranceProcess.Touch(x: 255 - min(max(pageY, 0), 255), y: min(max(pageX, 0), 191))
    }

    public func releaseTouch() {
        let recordsProgress = beginProgressInput(.releaseTouch)
        defer { endProgressInput(recordsProgress) }
        heldTouch = nil
    }

    /**
     * Selects and drags a Chapter 10 brick with the Hammer.
     */
    public func holdBrickWallTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdBrickWallTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(75) = runner.phase, var process = brickWall,
              x.isFinite, y.isFinite, (0..<192).contains(x), (0..<256).contains(y) else { return }
        let point = SIMD2(x, y)
        if brickWallTouch == nil {
            let hammerAvailable = (try? runner.game.inventory.items.contains(0x47)) == true
            guard process.beginDrag(at: point, hammerAvailable: hammerAvailable) else { return }
        }
        process.drag(to: point)
        brickWallTouch = point
        brickWall = process
    }

    /**
     * Releases the selected brick and returns to the Chapter 10 event when the doorway is clear.
     */
    public func releaseBrickWallTouch() {
        let recordsProgress = beginProgressInput(.releaseBrickWallTouch)
        defer { endProgressInput(recordsProgress) }
        brickWallTouch = nil
        guard !isPaused, case .process(75) = runner.phase, var process = brickWall else { return }
        let effects = process.endDrag()
        brickWall = process
        guard effects.contains(.completed(0)) else { return }
        brickWall = nil
        runner.finishProcess(returnValue: 0)
        settle()
    }

    public func leaveBrickWall() {
        let recordsProgress = beginProgressInput(.leaveBrickWall)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(75) = runner.phase, var process = brickWall,
              let result = process.leave() else { return }
        brickWall = nil
        brickWallTouch = nil
        runner.finishProcess(returnValue: result)
        settle()
    }

    /**
     * Forwards a held page touch to the bowling process.
     */
    public func holdBowlingTouch(pageX: Float, pageY: Float) {
        let recordsProgress = beginProgressInput(.holdBowlingTouch(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(44) = runner.phase,
              pageX.isFinite, pageY.isFinite,
              (0..<192).contains(pageX), (0..<256).contains(pageY),
              var match = bowlingMatch else { return }
        let touch = SIMD2(pageX, pageY)
        if let previousTouch = bowlingTouch, match.phase == .ready,
           previousTouch != touch,
           let anchor = bowlingDragAnchor(pageX: previousTouch.x, pageY: previousTouch.y, match: match) {
            _ = match.beginDrag(at: Self.fixedBowlingPoint(anchor.lanePoint), ballWasHit: true)
        }
        bowlingMatch = match
        bowlingTouch = touch
    }

    /**
     * Releases the active bowling drag.
     */
    public func releaseBowlingTouch() {
        let recordsProgress = beginProgressInput(.releaseBowlingTouch)
        defer { endProgressInput(recordsProgress) }
        bowlingTouch = nil
        guard !isPaused, case .process(44) = runner.phase,
              var match = bowlingMatch else { return }
        _ = match.endDrag()
        bowlingMatch = match
    }

    /**
     * Forwards a drag to the original jigsaw, retaining its first grab offset.
     */
    func receiveJigsawFold(isClosed: Bool) {
        let recordsProgress = beginProgressInput(.receiveJigsawFold(isClosed: isClosed))
        defer { endProgressInput(recordsProgress) }
        jigsaw?.receiveFold(isClosed: isClosed)
    }
    func cancelPendingJigsawFold() {
        let recordsProgress = beginProgressInput(.cancelPendingJigsawFold)
        defer { endProgressInput(recordsProgress) }
        jigsaw?.cancelPendingFold()
    }

    public func dragJigsaw(pageX: Float, pageY: Float) {
        let recordsProgress = beginProgressInput(.dragJigsaw(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(let id) = runner.phase, jigsaw?.processID == id, pageX.isFinite, pageY.isFinite else { return }
        let point = OriginalJigsawProjection.world(pageX: max(-192, min(384, pageX)),
                                                   pageY: max(-256, min(512, pageY)))
        if jigsaw?.holding == true { jigsaw?.moveTouch(world: point) }
        else { jigsaw?.beginTouch(world: point) }
    }

    public func releaseJigsaw() {
        let recordsProgress = beginProgressInput(.releaseJigsaw)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(let id) = runner.phase, jigsaw?.processID == id else { return }
        applyJigsawEffects(jigsaw?.endTouch() ?? [])
    }

    public func rotateJigsaw(increasing: Bool) {
        let recordsProgress = beginProgressInput(.rotateJigsaw(increasing: increasing))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(let id) = runner.phase, jigsaw?.processID == id else { return }
        applyJigsawEffects(jigsaw?.rotate(increasing: increasing) ?? [])
    }

    public func quitJigsaw() {
        let recordsProgress = beginProgressInput(.quitJigsaw)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(let id) = runner.phase, jigsaw?.processID == id else { return }
        jigsaw?.quit()
    }

    public func holdSuitcaseTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdSuitcaseTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, suitcaseKey != nil else { return }
        suitcaseTouch = SIMD2(x, y)
    }

    public func releaseSuitcaseTouch() {
        let recordsProgress = beginProgressInput(.releaseSuitcaseTouch)
        defer { endProgressInput(recordsProgress) }
        suitcaseTouch = nil
    }

    public func holdCassetteTouch(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.holdCassetteTouch(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, (cassetteRewind != nil || cassetteBallpoint != nil || cassetteDeck != nil),
              (0..<192).contains(pageX), (0..<256).contains(pageY) else { return }
        captureCassetteTouch(pageX: pageX, pageY: pageY)
    }

    public func releaseCassetteTouch() {
        let recordsProgress = beginProgressInput(.releaseCassetteTouch)
        defer { endProgressInput(recordsProgress) }
        cassetteTouch = nil
    }

    /**
     * Selects the hidden letter through overlay 38's camera and artwork mask.
     */
    public func touchApplePainting(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.touchApplePainting(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(64) = runner.phase,
              (0..<OriginalApplePaintingRenderer.pageWidth).contains(pageX),
              (0..<OriginalApplePaintingRenderer.pageHeight).contains(pageY),
              var process = applePainting, let mask = applePaintingMask else { return }
        guard process.select(pageX: Int32(pageX), pageY: Int32(pageY),
                             cameraX: process.cameraX, cameraY: process.cameraY,
                             mask: mask) else { return }
        runner.storeApplePaintingFoundMask(process.foundMask)
        applePainting = process
    }

    /**
     * Applies camera movement from a drag across the apple painting.
     */
    public func moveApplePaintingCamera(horizontalSteps: Int, verticalSteps: Int) {
        let recordsProgress = beginProgressInput(.moveApplePaintingCamera(horizontalSteps: horizontalSteps, verticalSteps: verticalSteps))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(64) = runner.phase,
              var process = applePainting, process.phase == .looking,
              let renderer = applePaintingRenderer else { return }
        process.moveCamera(horizontalSteps: horizontalSteps, verticalSteps: verticalSteps)
        guard let image = try? renderer.render(index: process.paintingIndex,
                                               cameraX: process.cameraX, cameraY: process.cameraY) else { return }
        applePaintingImage = image
        applePainting = process
    }

    /**
     * Completes process 63 after the player closes and fully reopens the Duo.
     */
    func receiveCPRFold(isClosed: Bool, isFullyOpen: Bool) {
        let recordsProgress = beginProgressInput(.receiveCPRFold(isClosed: isClosed, isFullyOpen: isFullyOpen))
        defer { endProgressInput(recordsProgress) }
        guard case .process(63) = runner.phase, var process = cpr else { return }
        let result = process.receiveFold(isClosed: isClosed, isFullyOpen: isFullyOpen)
        if let result {
            cpr = nil
            runner.finishProcess(returnValue: result)
            settle()
        } else {
            cpr = process
        }
    }

    /**
     * Returns process 64's source result after the letter is acknowledged.
     */
    public func acknowledgeApplePaintingLetter() {
        let recordsProgress = beginProgressInput(.acknowledgeApplePaintingLetter)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(64) = runner.phase, var process = applePainting,
              process.acknowledgeLetter() != nil,
              let invocation = runner.embeddedProcessInvocation,
              let returnValue = OriginalAlphabetProcessContext.successfulReturnValue(for: invocation) else {
            return
        }
        applePainting = nil
        applePaintingImage = nil
        applePaintingRenderer = nil
        applePaintingMask = nil
        runner.finishProcess(returnValue: returnValue)
        settle()
    }

    /**
     * Records one letter tap and returns process 81 after the ordered word is complete.
     */
    public func selectAppleWordLetter(at index: Int) {
        let recordsProgress = beginProgressInput(.selectAppleWordLetter(index: index))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(81) = runner.phase,
              var process = appleWordEntry else { return }
        if process.selectLetter(at: index) != nil {
            guard let invocation = runner.embeddedProcessInvocation,
                  let result = OriginalAlphabetProcessContext.successfulReturnValue(for: invocation) else {
                runner.halt("The apple word-entry return could not be recovered")
                return settle()
            }
            appleWordEntry = nil
            runner.finishProcess(returnValue: result)
            settle()
        } else {
            appleWordEntry = process
        }
    }

    public func activateCassetteDeckControl() {
        let recordsProgress = beginProgressInput(.activateCassetteDeckControl)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, cassetteDeck != nil else { return }
        cassetteDeck?.activateSelectedControl()
    }

    public func exitCassetteDeck() {
        let recordsProgress = beginProgressInput(.exitCassetteDeck)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, cassetteDeck != nil else { return }
        cassetteDeck?.requestExit()
    }

    private func captureCassetteTouch(pageX: Int, pageY: Int) {
        let rawTouch = SIMD2(255 - pageY, pageX)
        if cassetteTouch == nil { cassettePress = rawTouch }
        cassetteTouch = rawTouch
    }

    public func quitSuitcaseKey() {
        let recordsProgress = beginProgressInput(.quitSuitcaseKey)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        suitcaseTouch = nil
        suitcaseKey?.quit()
    }

    public func holdThinWireTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdThinWireTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, thinWire != nil, x.isFinite, y.isFinite else { return }
        thinWireTouch = SIMD2(x, y)
    }

    public func holdFountainPenTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdFountainPenTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(let id) = runner.phase, id == 42 || id == 74, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        fountainPenTouch = SIMD2(Int(x), Int(y))
    }
    public func releaseFountainPenTouch() {
        let recordsProgress = beginProgressInput(.releaseFountainPenTouch)
        defer { endProgressInput(recordsProgress) }
        fountainPenTouch = nil
    }
    public func quitFountainPen() {
        let recordsProgress = beginProgressInput(.quitFountainPen)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(let id) = runner.phase, id == 42 || id == 74 else { return }
        fountainPenTouch = nil
        fountainPen?.quit()
        puzzleMicrophone.stop()
    }
    public func enablePuzzleMicrophone() async {
        guard !isPaused, fountainPen?.phase == 2 else { return }
        await puzzleMicrophone.start()
        if isPaused || fountainPen?.phase != 2 { puzzleMicrophone.stop() }
    }

    public func holdDifferencesTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdDifferencesTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(73) = runner.phase, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        differencesTouch = SIMD2(Int(x), Int(y))
    }
    public func releaseDifferencesTouch() {
        let recordsProgress = beginProgressInput(.releaseDifferencesTouch)
        defer { endProgressInput(recordsProgress) }
        differencesTouch = nil
    }
    public func clearDifferences() {
        let recordsProgress = beginProgressInput(.clearDifferences)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(73) = runner.phase else { return }
        differencesTouch = nil; differences?.clear()
        if let differences { differencesImage = try? differencesRenderer?.render(differences) }
    }
    public func quitDifferences() {
        let recordsProgress = beginProgressInput(.quitDifferences)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(73) = runner.phase else { return }
        differencesTouch = nil; differences?.quit()
    }

    public func holdToiletTankTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdToiletTankTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(48) = runner.phase, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        toiletTankTouch = SIMD2(Int(x), Int(y))
    }
    public func releaseToiletTankTouch() {
        let recordsProgress = beginProgressInput(.releaseToiletTankTouch)
        defer { endProgressInput(recordsProgress) }
        toiletTankTouch = nil
    }
    public func quitToiletTank() {
        let recordsProgress = beginProgressInput(.quitToiletTank)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(48) = runner.phase else { return }
        toiletTankTouch = nil
        toiletTank?.quit()
    }
    public func holdLinenWagonTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdLinenWagonTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(60) = runner.phase, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        linenWagonTouch = SIMD2(Int(x), Int(y))
    }
    public func releaseLinenWagonTouch() {
        let recordsProgress = beginProgressInput(.releaseLinenWagonTouch)
        defer { endProgressInput(recordsProgress) }
        linenWagonTouch = nil
    }
    public func quitLinenWagon() {
        let recordsProgress = beginProgressInput(.quitLinenWagon)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(60) = runner.phase else { return }
        linenWagonTouch = nil
        linenWagon?.quit()
    }

    public func holdMatchsticksTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdMatchsticksTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, let matchsticks, runner.phase == .process(id: matchsticks.variant.rawValue), x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        matchsticksTouch = SIMD2(Int(x), Int(y))
    }
    public func releaseMatchsticksTouch() {
        let recordsProgress = beginProgressInput(.releaseMatchsticksTouch)
        defer { endProgressInput(recordsProgress) }
        matchsticksTouch = nil
    }
    public func quitMatchsticks() {
        let recordsProgress = beginProgressInput(.quitMatchsticks)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, let matchsticks, runner.phase == .process(id: matchsticks.variant.rawValue) else { return }
        matchsticksTouch = nil
        self.matchsticks?.quit()
    }

    public func resetMatchsticks() {
        let recordsProgress = beginProgressInput(.resetMatchsticks)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        matchsticksTouch = nil; matchsticks?.reset()
    }
    public func holdCoinPuzzleTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdCoinPuzzleTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(51) = runner.phase, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        coinPuzzleTouch = SIMD2(x, y)
    }
    public func releaseCoinPuzzleTouch() {
        let recordsProgress = beginProgressInput(.releaseCoinPuzzleTouch)
        defer { endProgressInput(recordsProgress) }
        coinPuzzleTouch = nil
    }
    public func quitCoinPuzzle() {
        let recordsProgress = beginProgressInput(.quitCoinPuzzle)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(51) = runner.phase else { return }
        coinPuzzleTouch = nil
        coinPuzzle?.quit()
    }

    /// Plays a jukebox record, or stops it when it is already playing.
    public func selectJukeboxRecord(_ record: Int) {
        let recordsProgress = beginProgressInput(.selectJukeboxRecord(record: record))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(58) = runner.phase, var jukebox else { return }
        let effects = jukebox.select(record)
        self.jukebox = jukebox
        for effect in effects {
            switch effect {
            case .play(let sequence):
                runner.setJukeboxSequence(Int16(sequence))
                try? audio.applyOriginalCommand(.startMusic(sequenceID: sequence))
            case .stop:
                runner.setJukeboxSequence(-1)
                try? audio.applyOriginalCommand(.stopMusic(fadeFrames: 0))
            case .completed: break
            }
        }
    }

    public func quitJukebox() {
        let recordsProgress = beginProgressInput(.quitJukebox)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(58) = runner.phase, var jukebox else { return }
        for case .completed(let result) in jukebox.quit() {
            self.jukebox = nil
            runner.finishProcess(returnValue: result)
            settle()
        }
    }

    public func checkCoinPuzzle() {
        let recordsProgress = beginProgressInput(.checkCoinPuzzle)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        coinPuzzleTouch = nil; coinPuzzle?.check()
    }
    public func holdDollRepairTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdDollRepairTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(38) = runner.phase, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        dollRepairTouch = SIMD2(Int(x), Int(y))
    }
    public func releaseDollRepairTouch() {
        let recordsProgress = beginProgressInput(.releaseDollRepairTouch)
        defer { endProgressInput(recordsProgress) }
        dollRepairTouch = nil
    }
    public func quitDollRepair() {
        let recordsProgress = beginProgressInput(.quitDollRepair)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(38) = runner.phase else { return }
        dollRepairTouch = nil
        dollRepair?.quit()
    }

    public func holdBookmarkBoxTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdBookmarkBoxTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(47) = runner.phase, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        bookmarkBoxTouch = SIMD2(Int(x), Int(y))
    }
    public func releaseBookmarkBoxTouch() {
        let recordsProgress = beginProgressInput(.releaseBookmarkBoxTouch)
        defer { endProgressInput(recordsProgress) }
        bookmarkBoxTouch = nil
    }
    public func quitBookmarkBox() {
        let recordsProgress = beginProgressInput(.quitBookmarkBox)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(47) = runner.phase else { return }
        bookmarkBoxTouch = nil
        bookmarkBox?.quit()
    }

    public func holdSwitchboardTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdSwitchboardTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(41) = runner.phase, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        switchboardTouch = SIMD2(Int(x), Int(y))
    }
    public func releaseSwitchboardTouch() {
        let recordsProgress = beginProgressInput(.releaseSwitchboardTouch)
        defer { endProgressInput(recordsProgress) }
        switchboardTouch = nil
    }
    public func quitSwitchboard() {
        let recordsProgress = beginProgressInput(.quitSwitchboard)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(41) = runner.phase else { return }
        switchboardTouch = nil
        switchboard?.quit()
    }

    public func holdLabelPeelTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdLabelPeelTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(46) = runner.phase, x.isFinite, y.isFinite,
              x >= 32, x < 160, y >= 48, y < 208 else { return }
        labelPeelTouch = SIMD2(Int(x), Int(y))
    }

    public func releaseLabelPeelTouch() {
        let recordsProgress = beginProgressInput(.releaseLabelPeelTouch)
        defer { endProgressInput(recordsProgress) }
        labelPeelTouch = nil
    }

    public func holdPicturePeelTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdPicturePeelTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(61) = runner.phase,
              x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256 else { return }
        picturePeelTouch = SIMD2(Int(x), Int(y))
    }

    public func releasePicturePeelTouch() {
        let recordsProgress = beginProgressInput(.releasePicturePeelTouch)
        defer { endProgressInput(recordsProgress) }
        picturePeelTouch = nil
    }

    public func quitPicturePeel() {
        let recordsProgress = beginProgressInput(.quitPicturePeel)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(61) = runner.phase,
              var process = picturePeel,
              case .returned(let returnValue) = process.requestExit() else { return }
        picturePeel = nil
        picturePeelImage = nil
        picturePeelUpperImage = nil
        picturePeelRenderer = nil
        picturePeelTouch = nil
        stopTimer()
        runner.finishProcess(returnValue: returnValue)
        settle()
    }

    public func openChristmasTreeMenu() {
        let recordsProgress = beginProgressInput(.openChristmasTreeMenu)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(43) = runner.phase,
              christmasTreeDraggedDecoration == nil else { return }
        christmasTree?.openMenu()
    }

    public func holdChristmasTreeTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdChristmasTreeTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(43) = runner.phase, let process = christmasTree,
              let renderer = christmasTreeRenderer, x.isFinite, y.isFinite,
              x >= 0, x < 192, y >= 0, y < 256, process.canPlaceDecoration else { return }
        let point = SIMD2(x, y)
        if christmasTreeDraggedDecoration == nil {
            christmasTreeDraggedDecoration = renderer.decoration(at: point, process: process)
        }
        guard christmasTreeDraggedDecoration != nil else { return }
        do {
            christmasTreeImage = try renderer.render(process, draggedDecoration: christmasTreeDraggedDecoration,
                                                     at: point)
        } catch {
            runner.halt("The Christmas tree decoration could not be rendered: \(error)")
            cancelChristmasTreeTouch()
            settle()
        }
    }

    public func releaseChristmasTreeTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.releaseChristmasTreeTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(43) = runner.phase, var process = christmasTree,
              let renderer = christmasTreeRenderer, let decoration = christmasTreeDraggedDecoration,
              x.isFinite, y.isFinite else { return cancelChristmasTreeTouch() }
        let point = SIMD2(x, y)
        if let target = renderer.target(at: point) {
            _ = process.dropDecoration(decoration, at: OriginalChristmasTreeLayout.modelDecorationTargets[target])
        }
        christmasTreeDraggedDecoration = nil
        christmasTree = process
        do { christmasTreeImage = try renderer.render(process) }
        catch {
            runner.halt("The Christmas tree decoration could not be rendered: \(error)")
            settle()
        }
    }

    public func cancelChristmasTreeTouch() {
        let recordsProgress = beginProgressInput(.cancelChristmasTreeTouch)
        defer { endProgressInput(recordsProgress) }
        christmasTreeDraggedDecoration = nil
        guard let christmasTree, let christmasTreeRenderer else { return }
        do { christmasTreeImage = try christmasTreeRenderer.render(christmasTree) }
        catch { runner.halt("The Christmas tree decoration could not be rendered: \(error)"); settle() }
    }

    public func holdSearchShedTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdSearchShedTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(79) = runner.phase, var process = searchShed,
              x.isFinite, y.isFinite, x >= 0, x < 192, y >= 0, y < 256,
              let renderer = searchShedRenderer else { return }
        let point = SIMD2(x, y)
        if searchShedTouch == nil, let object = renderer.object(at: point, process: process) {
            if object == 9 {
                _ = process.select(object: object, targetIsUnobstructed: true)
            } else if let position = renderer.planePoint(at: point, height: process.objects[object].position.y) {
                process.beginDrag(object: object, at: position)
            }
        }
        if process.draggedObject != nil, let object = process.draggedObject,
           let position = renderer.planePoint(at: point, height: process.objects[object].position.y) {
            process.drag(to: position)
        }
        searchShedTouch = point
        searchShed = process
        do { searchShedImage = try renderer.render(process) }
        catch { runner.halt("The search shed could not be rendered: \(error)"); settle() }
    }

    public func releaseSearchShedTouch() {
        let recordsProgress = beginProgressInput(.releaseSearchShedTouch)
        defer { endProgressInput(recordsProgress) }
        searchShedTouch = nil
        searchShed?.endDrag()
    }

    public func openSearchShedMenu() {
        let recordsProgress = beginProgressInput(.openSearchShedMenu)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(79) = runner.phase else { return }
        searchShed?.openMenu()
    }

    public func openSearchShedTreeBox() {
        let recordsProgress = beginProgressInput(.openSearchShedTreeBox)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(79) = runner.phase, var process = searchShed else { return }
        let effects = process.openFoundBox()
        searchShed = process
        applySearchShed(effects)
    }

    public func holdBagSearchTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdBagSearchTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(55) = runner.phase, var process = bagSearch,
              x.isFinite, y.isFinite, x >= 0, x < 192, y >= 0, y < 256,
              let renderer = bagSearchRenderer else { return }
        let point = SIMD2(x, y)
        if bagSearchTouch == nil,
           let object = try? renderer.object(at: point, process: process),
           let planePoint = renderer.planePointFixed(at: point) {
            process.beginDrag(object: object, at: planePoint)
        }
        if process.draggedObject != nil, let planePoint = renderer.planePointFixed(at: point) {
            process.drag(to: planePoint)
        }
        bagSearchTouch = point
        bagSearch = process
        do { bagSearchImage = try renderer.render(process) }
        catch { runner.halt("The tree-box search could not be rendered: \(error)"); settle() }
    }

    public func releaseBagSearchTouch() {
        let recordsProgress = beginProgressInput(.releaseBagSearchTouch)
        defer { endProgressInput(recordsProgress) }
        bagSearchTouch = nil
        guard var process = bagSearch else { return }
        _ = process.endDrag()
        bagSearch = process
        if let renderer = bagSearchRenderer {
            do { bagSearchImage = try renderer.render(process) }
            catch { runner.halt("The tree-box search could not be rendered: \(error)"); settle() }
        }
    }

    public func cancelBagSearchTouch() {
        let recordsProgress = beginProgressInput(.cancelBagSearchTouch)
        defer { endProgressInput(recordsProgress) }
        releaseBagSearchTouch()
    }

    public func openBagSearchMenu() {
        let recordsProgress = beginProgressInput(.openBagSearchMenu)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .process(55) = runner.phase else { return }
        bagSearch?.openMenu()
    }

    public func releaseThinWireTouch() {
        let recordsProgress = beginProgressInput(.releaseThinWireTouch)
        defer { endProgressInput(recordsProgress) }
        thinWireTouch = nil
    }

    public func quitThinWire() {
        let recordsProgress = beginProgressInput(.quitThinWire)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        thinWireTouch = nil
        thinWire?.quit()
    }

    public func holdPaperclipTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdPaperclipTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, paperclip != nil, x.isFinite, y.isFinite else { return }
        paperclipTouch = SIMD2(x, y)
    }

    public func holdHangerTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdHangerTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, hanger != nil, x.isFinite, y.isFinite else { return }
        hangerTouch = SIMD2(x, y)
    }

    public func releaseHangerTouch() {
        let recordsProgress = beginProgressInput(.releaseHangerTouch)
        defer { endProgressInput(recordsProgress) }
        hangerTouch = nil
    }

    public func holdSuitcaseContentsTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdSuitcaseContentsTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, runner.phase == .process(id: 35), x.isFinite, y.isFinite else { return }
        suitcaseContentsTouch = SIMD2(x, y)
    }

    public func releaseSuitcaseContentsTouch() {
        let recordsProgress = beginProgressInput(.releaseSuitcaseContentsTouch)
        defer { endProgressInput(recordsProgress) }
        suitcaseContentsTouch = nil
    }

    public func leaveSuitcaseContents() {
        let recordsProgress = beginProgressInput(.leaveSuitcaseContents)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, runner.phase == .process(id: 35) else { return }
        suitcaseContentsTouch = nil
        suitcaseContents?.goBack()
    }

    public func quitHanger() {
        let recordsProgress = beginProgressInput(.quitHanger)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        hangerTouch = nil
        hanger?.quit()
    }

    public func releasePaperclipTouch() {
        let recordsProgress = beginProgressInput(.releasePaperclipTouch)
        defer { endProgressInput(recordsProgress) }
        paperclipTouch = nil
    }

    public func holdCabinetDialTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdCabinetDialTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, cabinetDial != nil, x.isFinite, y.isFinite else { return }
        cabinetDialTouch = SIMD2(x, y)
    }

    public func releaseCabinetDialTouch() {
        let recordsProgress = beginProgressInput(.releaseCabinetDialTouch)
        defer { endProgressInput(recordsProgress) }
        cabinetDialTouch = nil
    }

    public func quitCabinetDial() {
        let recordsProgress = beginProgressInput(.quitCabinetDial)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        cabinetDialTouch = nil
        cabinetDial?.quit()
    }

    public func holdCrowbarTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdCrowbarTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, crowbar != nil, x.isFinite, y.isFinite else { return }
        crowbarTouch = SIMD2(x, y)
    }

    public func releaseCrowbarTouch() {
        let recordsProgress = beginProgressInput(.releaseCrowbarTouch)
        defer { endProgressInput(recordsProgress) }
        crowbarTouch = nil
    }

    public func quitCrowbar() {
        let recordsProgress = beginProgressInput(.quitCrowbar)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        crowbarTouch = nil
        crowbar?.quit()
    }

    public func holdMemoPullTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdMemoPullTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, memoPull != nil, x.isFinite, y.isFinite else { return }
        memoPullTouch = SIMD2(x, y)
    }

    public func releaseMemoPullTouch() {
        let recordsProgress = beginProgressInput(.releaseMemoPullTouch)
        defer { endProgressInput(recordsProgress) }
        memoPullTouch = nil
    }

    public func holdMemoDrawingTouch(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.holdMemoDrawingTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, memoDrawing != nil, x.isFinite, y.isFinite,
              (0...191).contains(x), (0...255).contains(y) else { return }
        memoDrawingTouch = SIMD2(Int(x), Int(y))
    }

    public func releaseMemoDrawingTouch() {
        let recordsProgress = beginProgressInput(.releaseMemoDrawingTouch)
        defer { endProgressInput(recordsProgress) }
        memoDrawingTouch = nil
    }

    public func clearMemoDrawing() {
        let recordsProgress = beginProgressInput(.clearMemoDrawing)
        defer { endProgressInput(recordsProgress) }
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
        let recordsProgress = beginProgressInput(.quitMemoDrawing)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        memoDrawingTouch = nil
        memoDrawing?.quit()
    }

    public func quitMemoPull() {
        let recordsProgress = beginProgressInput(.quitMemoPull)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        memoPullTouch = nil
        memoPull?.quit()
    }

    public func quitPaperclip() {
        let recordsProgress = beginProgressInput(.quitPaperclip)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused else { return }
        paperclipTouch = nil
        paperclip?.quit()
    }

    /**
     * Forwards held picture input. Releasing the touch permits the second press.
     */
    public func touchPicture(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.touchPicture(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .picture = runner.phase else { return }
        let effects = touchPicture?.touch(pageX: pageX, pageY: pageY) ?? []
        for effect in effects {
            try? audio.playOriginalEffect(archiveID: 8, entryID: effect == .selectSound ? 1 : 0)
        }
    }

    public func activatePicture(pageX: Int, pageY: Int) {
        let recordsProgress = beginProgressInput(.activatePicture(pageX: pageX, pageY: pageY))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, case .picture = runner.phase else { return }
        let effects = touchPicture?.activate(pageX: pageX, pageY: pageY) ?? []
        if effects.contains(.confirmSound) { try? audio.playOriginalEffect(archiveID: 8, entryID: 0) }
    }

    public func releasePicture() {
        let recordsProgress = beginProgressInput(.releasePicture)
        defer { endProgressInput(recordsProgress) }
        touchPicture?.release()
    }

    public func pause() {
        let recordsProgress = beginProgressInput(.pause)
        defer { endProgressInput(recordsProgress) }
        checkpointWalking()
        isPaused = true
        heldTouch = nil
        pendingTouch = nil
        releaseNotebook()
        touchPicture?.release()
        lobbyTouch = nil
        firstPersonMovement = nil
        suitcaseTouch = nil
        paperclipTouch = nil
        thinWireTouch = nil
        differencesTouch = nil
        dollRepairTouch = nil
        coinPuzzleTouch = nil
        linenWagonTouch = nil
        bookmarkBoxTouch = nil
        toiletTankTouch = nil
        switchboardTouch = nil
        fountainPenTouch = nil
        puzzleMicrophone.stop()
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
        let recordsProgress = beginProgressInput(.resume)
        defer { endProgressInput(recordsProgress) }
        guard isPaused else { return }
        isPaused = false
        audio.resume()
        settle()
    }

    public func stop() {
        isPaused = true
        onWalkingCheckpoint = nil
        onProgressCheckpoint = nil
        onProgressSaveError = nil
        onRecoverableStop = nil
        dialogueNotebook.onSaveProgress = nil
        lobbyTouch = nil
        firstPersonMovement = nil
        suitcaseTouch = nil
        paperclipTouch = nil
        thinWireTouch = nil
        differencesTouch = nil
        dollRepairTouch = nil
        coinPuzzleTouch = nil
        linenWagonTouch = nil
        bookmarkBoxTouch = nil
        toiletTankTouch = nil
        switchboardTouch = nil
        fountainPenTouch = nil
        puzzleMicrophone.stop()
        memoPullTouch = nil
        hangerTouch = nil
        memoDrawingTouch = nil
        suitcaseContentsTouch = nil
        stopTimer()
        audio.stopAll()
        cabinetDialTouch = nil
        crowbarTouch = nil
    }

    var hasInspectionArtwork: Bool {
        switch runner.phase {
        case .dialogue, .itemNotice, .waiting:
            return acquiredItemImage != nil || touchPictureImages != nil || closeup != nil || door != nil
                || suitcaseContents != nil || lobby?.mode == .counter
        default: return false
        }
    }

    /// Starts whatever the runner's current phase needs from the host.
    private func settle() {
        defer {
            dialogueNotebook.record(runner.phase, program: runner.program.name)
        }
        if case .halted(let halt) = runner.phase {
            stopTimer()
            guard !didReportRecoverableStop else { return }
            didReportRecoverableStop = true
            onRecoverableStop?(halt)
            return
        }
        if chapterTransition != nil { startTimer(); return }
        if notebook != nil { startTimer(); return }
        switch runner.phase {
        case .dialogue, .itemNotice, .picture, .waiting: break
        default:
            touchPictureImages = nil
            acquiredItemImage = nil
        }
        /**
         * 0x0203E7C8 leaves the door close-up when its transition starts a person's normal event.
         */
        if door != nil, runner.session.selection.modeID == 3, runner.session.selection.sceneID < 18 {
            door = nil
            doorImage = nil
        }
        if let door, case .exploration = runner.phase {
            do { try refreshDoorImage(door) }
            catch { runner.halt("The door could not be redrawn: \(error)") }
        }
        switch runner.phase {
        case .dialogue(let packet):
            startTimer()
            do {
                try encounterAnimations?.present(packet, program: runner.program.name)
                encounterPortraits = encounterAnimations?.portraits ?? []
            } catch {
                encounterAnimations?.clear()
                encounterPortraits = []
            }
            if presentedPacketOffset != packet.sourceOffset {
                presentedPacketOffset = packet.sourceOffset
                applyAudioControls(packet)
            }
            if !usesLegacyInteractionPacing, packet.pages.allSatisfy({ OriginalDialogueLines(page: $0).isEmpty }) {
                dialogueNotebook.endPresentation()
                runner.acknowledgeDialogue()
                return settle()
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
            startTimer()
            acquiredItemImage = try? OriginalInventoryArtwork.shared.image(for: id)
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
        case .process(63):
            cpr = OriginalCPRProcess()
        case .process(57):
            if vendingMachine == nil {
                do {
                    let process = OriginalVendingMachineProcess(
                        randomInfo: runner.memoRandomInfo(seed: nextProgressSeed(jigsaw: false)),
                        shifted: runner.game.bytes[0x137F] != 0,
                        itemStates: Array(runner.game.bytes[0x9D..<0xF5]))
                    let renderer = try OriginalVendingMachineRenderer(library: .bundled())
                    vendingMachine = process
                    vendingMachineImage = renderer.keypad
                    vendingMachineProducts = renderer.products
                } catch {
                    runner.halt("The vending machine could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(87):
            if numberSeal == nil {
                do {
                    let process = OriginalNumberSealProcess(mapID: runner.game.mapID,
                        randomInfo: runner.memoRandomInfo(seed: nextProgressSeed(jigsaw: false)),
                        shifted: runner.game.bytes[0x137F] != 0)
                    let renderer = try OriginalNumberSealRenderer(process: process, library: .bundled())
                    numberSeal = process
                    numberSealImage = renderer.image
                    numberSealTouch = nil
                } catch {
                    runner.halt("The numbered sticker could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(62), .process(67):
            if codeNotice == nil {
                do {
                    let renderer = try OriginalCodeNoticeRenderer()
                    guard case .process(let processID) = runner.phase else { return settle() }
                    let textIndex = Int(processID)
                    guard runner.program.text.entries.indices.contains(textIndex) else {
                        throw OriginalDataError.missing("Code notice text \(processID)")
                    }
                    codeNotice = OriginalCodeNoticeProcess(processID: textIndex)
                    codeNoticeImage = renderer.pageBackground
                    codeNoticeCaption = ""
                    processReturn = 2
                    pendingCodeNoticeTouch = nil
                } catch {
                    runner.halt("The code notice could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(75):
            if brickWall == nil {
                brickWall = OriginalBrickWallProcess(seed: nextProgressSeed(jigsaw: false))
                processReturn = 2
            }
            startTimer()
        case .process(61):
            if picturePeel == nil {
                do {
                    let renderer = try OriginalPicturePeelRenderer(library: .bundled())
                    let process = OriginalPicturePeelProcess(mask: renderer.initialMask)
                    picturePeelRenderer = renderer
                    picturePeelUpperImage = renderer.upperScreen
                    picturePeelImage = try renderer.render(process)
                    picturePeel = process
                    processReturn = 2
                    picturePeelTouch = nil
                } catch {
                    runner.halt("The picture peel could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(44):
            if bowlingMatch == nil {
                do {
                    let renderer = try bowlingRendererFactory()
                    let match = OriginalBowlingMatchProcess()
                    bowlingImage = try renderer.render(bowlingSceneState(match))
                    bowlingRenderer = renderer
                    bowlingMatch = match
                    processReturn = 2
                } catch {
                    runner.halt("The bowling scene could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(52):
            if cassetteDeck == nil {
                do {
                    let renderer = try cassetteDeckRendererFactory()
                    let process = OriginalCassetteDeckProcess()
                    cassetteImage = try renderer.render(camera: process.camera, state: process.sceneState)
                    cassetteDeckRenderer = renderer
                    cassetteDeck = process
                    cassetteTouch = nil
                    cassettePress = nil
                    cassetteOpacity = 1
                    processReturn = 2
                } catch {
                    runner.halt("The cassette playback scene could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(74), .process(86), .process(90), .process(91):
            if typewriter == nil {
                do {
                    let renderer = try OriginalTypewriterRenderer()
                    guard case .process(let processID) = runner.phase else { return settle() }
                    let variant: OriginalTypewriterCipher.Variant
                    switch processID {
                    case 86: variant = .opening
                    case 90: variant = .memento
                    case 91: variant = .final
                    default: variant = .first
                    }
                    let cipher = OriginalTypewriterCipher(variant: variant,
                        randomInfo: runner.memoRandomInfo(seed: nextProgressSeed(jigsaw: false)))
                    typewriterRenderer = renderer
                    typewriterUpperImage = renderer.upperScreen
                    typewriterImage = renderer.touchScreen
                    typewriter = OriginalTypewriterProcess(cipher: cipher)
                    processReturn = 2
                } catch {
                    runner.halt("The typewriter could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(64):
            guard applePainting == nil else { return }
            guard let invocation = runner.embeddedProcessInvocation,
                  OriginalAlphabetProcessContext.mode(for: invocation) == .paintingSearch,
                  let index = OriginalAlphabetProcessContext.paintingIndex(for: invocation),
                  OriginalAlphabetProcessContext.callerValue(forKey: 0x15, mode: .paintingSearch) == 10 else {
                runner.halt("The apple painting call context could not be recovered")
                return settle()
            }
            do {
                let renderer = try OriginalApplePaintingRenderer(library: .bundled())
                guard let process = OriginalApplePaintingProcess(
                    paintingIndex: index, foundMask: runner.game.applePaintingFoundMask) else {
                    throw OriginalDataError.invalid("Apple painting map selection")
                }
                applePaintingRenderer = renderer
                applePaintingMask = try renderer.mask(for: index)
                applePaintingImage = try renderer.render(index: index)
                applePainting = process
            } catch {
                runner.halt("The apple painting could not be loaded: \(error)")
                return settle()
            }
        case .process(34):
            if memoDrawing == nil {
                do {
                    let items = try runner.game.inventory.items
                    let paper: OriginalMemoDrawing.Paper = items.contains(63) ? .whole : items.contains(13) ? .joined : .torn
                    let renderer = try OriginalMemoDrawingImage(paper: paper, library: .bundled())
                    let drawing = try OriginalMemoDrawing(paper: paper, randomInfo: runner.memoRandomInfo(seed: nextProgressSeed(jigsaw: false)), mask: renderer.mask)
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
        case .process(81):
            guard let process = OriginalAppleWordEntryProcess(foundMask: runner.game.applePaintingFoundMask) else {
                runner.halt("The apple word entry started before all five letters were found")
                return settle()
            }
            appleWordEntry = process
            startTimer()
        case .process(45):
            if cassetteRewind == nil {
                do {
                    let renderer = try cassetteRendererFactory(.pencil)
                    cassetteImage = try renderer.render()
                    cassetteRenderer = renderer
                    cassetteRewind = OriginalCassetteRewindProcess()
                    cassetteTouch = nil
                    cassettePress = nil
                    cassetteOpacity = 1
                    processReturn = 2
                } catch {
                    runner.halt("The cassette could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(76):
            if cassetteBallpoint == nil {
                do {
                    let renderer = try cassetteRendererFactory(.ballpoint)
                    cassetteImage = try renderer.render()
                    cassetteRenderer = renderer
                    cassetteBallpoint = OriginalCassetteBallpointProcess()
                    cassetteTouch = nil
                    cassettePress = nil
                    cassetteOpacity = 1
                    processReturn = 2
                } catch {
                    runner.halt("The cassette could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(26), .process(39), .process(40), .process(84):
            if jigsaw == nil, case .process(let id) = runner.phase,
               let variant = OriginalJigsawProcess.Variant(rawValue: id) {
                jigsaw = OriginalJigsawProcess(seed: nextProgressSeed(jigsaw: true), savedLooseMask: runner.game.jigsawMask(for: variant), variant: variant)
            }
            startTimer()
        case .process(42):
            if fountainPen == nil {
                do {
                    let renderer = try OriginalFountainPenRenderer()
                    let puzzle = try renderer.makeProcess(seed: nextProgressSeed(jigsaw: true))
                    fountainPenRenderer = renderer
                    fountainPenImage = try renderer.render(puzzle)
                    fountainPenScreenEffects = OriginalScreenEffects()
                    fountainPen = puzzle
                } catch {
                    runner.halt("The fountain pen could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(73):
            if differences == nil {
                do {
                    let renderer = try OriginalDifferencesRenderer()
                    let puzzle = try renderer.makeProcess()
                    differencesRenderer = renderer
                    differencesImage = try renderer.render(puzzle)
                    differencesScreenEffects = OriginalScreenEffects()
                    differences = puzzle
                } catch {
                    runner.halt("The pamphlet puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(48):
            if toiletTank == nil {
                do {
                    let puzzle = OriginalToiletTankProcess()
                    toiletTankRenderer = try toiletTankRendererFactory()
                    toiletTankImage = try toiletTankRenderer?.render(puzzle)
                    toiletTankScreenEffects = OriginalScreenEffects()
                    toiletTank = puzzle
                } catch {
                    runner.halt("The toilet tank could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(60):
            if linenWagon == nil {
                do {
                    let puzzle = OriginalLinenWagonProcess(seed: nextProgressSeed(jigsaw: false))
                    linenWagonRenderer = try OriginalLinenWagonRenderer()
                    linenWagonImage = try linenWagonRenderer?.render(puzzle)
                    linenWagonScreenEffects = OriginalScreenEffects()
                    linenWagon = puzzle
                } catch {
                    runner.halt("The linen wagon could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(let id) where id == 53 || id == 54:
            if matchsticks == nil {
                do {
                    let puzzle = OriginalMatchstickProcess(variant: id == 53 ? .squares : .triangles)
                    matchsticksRenderer = try OriginalMatchstickRenderer()
                    matchsticksImage = try matchsticksRenderer?.render(puzzle)
                    matchsticksScreenEffects = OriginalScreenEffects()
                    matchsticks = puzzle
                } catch {
                    runner.halt("The matchstick puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(58):
            if jukebox == nil {
                do {
                    let data = try OriginalBitmapLibrary.bundled().loadNotebookData(path: "trick/jukebox/JK_USA.txt")
                    jukebox = OriginalJukeboxProcess(titles: try OriginalJukeboxProcess.titles(from: data),
                                                     playing: runner.game.jukeboxSequence)
                } catch {
                    runner.halt("The jukebox could not be loaded: \(error)")
                    return settle()
                }
            }
        case .process(59):
            if pencilSharpener == nil {
                do {
                    let renderer = try OriginalPencilSharpenerRenderer()
                    pencilSharpenerImage = renderer.image
                    pencilSharpener = OriginalPencilSharpenerProcess()
                    processReturn = 2
                } catch {
                    runner.halt("The pencil-sharpener scene could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(51):
            if coinPuzzle == nil {
                do {
                    let puzzle = OriginalCoinProcess()
                    coinPuzzleRenderer = try OriginalCoinRenderer()
                    coinPuzzleImage = try coinPuzzleRenderer?.render(puzzle)
                    coinPuzzleScreenEffects = OriginalScreenEffects()
                    coinPuzzle = puzzle
                } catch {
                    runner.halt("The coin puzzle could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(38):
            if dollRepair == nil {
                do {
                    let puzzle = OriginalDollRepairProcess()
                    dollRepairRenderer = try OriginalDollRepairRenderer()
                    dollRepairImage = try dollRepairRenderer?.render(puzzle)
                    dollRepairScreenEffects = OriginalScreenEffects()
                    dollRepair = puzzle
                } catch {
                    runner.halt("The doll repair could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(47):
            if bookmarkBox == nil {
                do {
                    let puzzle = OriginalBookmarkBoxProcess()
                    bookmarkBoxImage = try bookmarkBoxRender(puzzle)
                    bookmarkBoxScreenEffects = OriginalScreenEffects()
                    bookmarkBox = puzzle
                } catch {
                    runner.halt("The bookmark box could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(41):
            if switchboard == nil {
                do {
                    let puzzle = OriginalSwitchboardProcess()
                    switchboardRenderer = try OriginalSwitchboardRenderer()
                    switchboardImage = try switchboardRenderer?.render(puzzle)
                    switchboardScreenEffects = OriginalScreenEffects()
                    switchboard = puzzle
                } catch {
                    runner.halt("The electrical panel could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(46):
            if labelPeel == nil {
                do {
                    let renderer = try OriginalLabelPeelRenderer(library: .bundled())
                    let stage: OriginalLabelPeelProcess.Stage = labelPeelFollowupPending ? .peel : .solvent
                    labelPeelFollowupPending = false
                    let puzzle = OriginalLabelPeelProcess(mask: renderer.initialMask, stage: stage)
                    labelPeelRenderer = renderer
                    labelPeelImage = try renderer.render(puzzle)
                    labelPeelScreenEffects = OriginalScreenEffects()
                    labelPeel = puzzle
                } catch {
                    runner.halt("The wine label could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(43):
            if christmasTree == nil {
                do {
                    let renderer = try OriginalChristmasTreeRenderer(library: .bundled())
                    let process = OriginalChristmasTreeProcess(savedOrder: runner.game.christmasTreeDecorationOrder)
                    christmasTreeRenderer = renderer
                    christmasTreeImage = try renderer.render(process)
                    christmasTreeScreenEffects = OriginalScreenEffects()
                    christmasTree = process
                } catch {
                    runner.halt("The Christmas tree image could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(79):
            if searchShed == nil {
                do {
                    let process = OriginalSearchShedProcess()
                    let renderer = try searchShedRendererFactory()
                    searchShedRenderer = renderer
                    searchShedImage = try renderer.render(process)
                    searchShedScreenEffects = OriginalScreenEffects()
                    searchShed = process
                } catch {
                    runner.halt("The search shed could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(55):
            if bagSearch == nil {
                do {
                    let process = OriginalBagSearchProcess()
                    let renderer = try bagSearchRendererFactory()
                    bagSearchRenderer = renderer
                    bagSearchImage = try renderer.render(process)
                    bagSearchScreenEffects = OriginalScreenEffects()
                    bagSearch = process
                } catch {
                    runner.halt("The tree-box search could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(88):
            if vsScene == nil {
                do {
                    let renderer = try OriginalVSSceneRenderer()
                    vsSceneRenderer = renderer
                    vsSceneImage = renderer.image()
                    vsScene = OriginalVSSceneProcess()
                } catch {
                    runner.halt("The VSScene ending layer could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(85):
            if afterConfess == nil {
                do {
                    let renderer = try OriginalAfterConfessRenderer()
                    let process = OriginalAfterConfessProcess()
                    guard let pages = renderer.pages(for: process.phase) else {
                        throw OriginalDataError.invalid("AfterConfess opening scene")
                    }
                    afterConfessRenderer = renderer
                    afterConfessTouchImage = pages.touch
                    afterConfessUpperImage = pages.upper
                    afterConfess = process
                } catch {
                    runner.halt("The AfterConfess scene could not be loaded: \(error)")
                    return settle()
                }
            }
            startTimer()
        case .process(27):
            if memoPull == nil {
                do {
                    memoPullRenderer = try memoPullRendererFactory()
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
        case .process(let id) where id == 29 || id == 33 || id == 77 || id == 78:
            if thinWire == nil {
                do {
                    let variant = OriginalThinWireProcess.Variant(rawValue: id)!
                    thinWireRenderer = try thinWireRendererFactory(variant)
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
                    let renderer = try crowbarRendererFactory(items.contains(7) || items.contains(12))
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
        case .process(31), .process(80):
            if cabinetDial == nil {
                do {
                    let variant: OriginalCabinetDialProcess.Variant = runner.phase == .process(id: 80) ? .cashbox : .cabinet
                    let renderer = try cabinetDialRendererFactory(variant)
                    let puzzle = OriginalCabinetDialProcess(randomValue: variant == .cabinet ? runner.memoRandomInfo(seed: nextProgressSeed(jigsaw: false)) : 0,
                        retainedValue: variant == .cabinet ? runner.game.cabinetDialRetainedValue : runner.game.cashboxDialRetainedValue,
                        variant: variant)
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
                    hangerRenderer = try hangerRendererFactory()
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
        case .process(35):
            if suitcaseContents == nil {
                do {
                    let renderer = try suitcaseContentsRendererFactory()
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
                    suitcaseRenderer = try suitcaseRendererFactory()
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
            if var parent = bowlingParent {
                parent.resumeProcess(after: runner)
                runner = parent
                bowlingParent = nil
                _ = bowlingMatch?.finishCommentaryResponse()
                presentedPacketOffset = nil
                return settle()
            }
            if var parent = suitcaseContentsParent {
                parent.resumeProcess(after: runner)
                runner = parent
                suitcaseContentsParent = nil
                suitcaseContents?.finishResponse()
                presentedPacketOffset = nil
                return settle()
            }
            if var parent = toiletTankParent {
                parent.resumeProcess(after: runner)
                runner = parent
                toiletTankParent = nil
                presentedPacketOffset = nil
                toiletTank?.finishHint()
                return settle()
            }
            if var parent = differencesParent {
                parent.resumeProcess(after: runner)
                runner = parent
                differencesParent = nil
                presentedPacketOffset = nil
                differences?.finishHint()
                return settle()
            }
            if var parent = switchboardParent {
                parent.resumeProcess(after: runner)
                runner = parent
                switchboardParent = nil
                presentedPacketOffset = nil
                switchboard?.finishHint()
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
            if var parent = shownItemParent {
                parent.resumeConversation(after: runner)
                runner = parent
                shownItemParent = nil
                presentedPacketOffset = nil
                return settle()
            }
            if var parent = memoParent {
                parent.resumeConversation(after: runner)
                runner = parent
                memoParent = nil
                presentedPacketOffset = nil
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
                    guard (1..<10).contains(request.value), let lobby, lobby.mapID == map else {
                        throw OriginalDataError.unsupported("Chapter transition \(request.value + 1)")
                    }
                    let destination = runner.processRequests.dropFirst(handledMapRequests).last(where: { $0.kind == 1 })?.value
                    if let destination, OriginalMapExploration.supportedMaps[destination] == nil {
                        throw OriginalDataError.unsupported("Chapter destination \(destination)")
                    }
                    try runner.prepareChapter(UInt16(request.value), position: lobby.position,
                                              facing: lobby.checkpointFacing, destination: destination)
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
                    firstPersonMovement = nil
                    self.lobby?.leaveCounter()
                    chapterTransition = OriginalChapterTransition()
                    if usesInstantSaves { showChapterTitle() }
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
            if door != nil {
                let requestsDeparture = runner.processRequests.dropFirst(handledMapRequests)
                    .contains { $0.kind == 1 }
                guard requestsDeparture else { return }
                door = nil
                doorImage = nil
            }
            if applyFixture() { return settle() }
            if let departure = pendingDeparture {
                pendingDeparture = nil
                let requests = runner.processRequests.dropFirst(departure.requestStart)
                if requests.contains(where: { $0.kind == 2 }) { lobby?.cancelDeparture() }
                else {
                    // 0x0202C264 consumes a departure script's clock request before the
                    // destination selects arrival events in the new time block.
                    for request in requests where request.kind == 3 { runner.consumeTimeRequest(request.value) }
                    return moveToMap(departure.map)
                }
            }
            guard let mapName = OriginalMapExploration.supportedMaps[map],
                  runner.game.chapter > 0 || runner.game.value(for: .eventFlag(group: 2, index: 2)) == true else { return }
            do {
                if lobby?.mapID != map {
                    lobby = try OriginalMapExploration.bundled(mapID: map, previousMapID: runner.game.previousMapID,
                        savedGame: runner.game.previousMapID == map ? runner.game : nil)
                    lobbyRenderer = try mapRendererFactory(mapName, nil)
                    lobbyMap = lobbyRenderer?.map
                }
                var scriptedDestination: Int16?, scriptedRelocation: Int?
                for request in runner.processRequests.dropFirst(handledMapRequests).reversed() {
                    if request.kind == 1 {
                        scriptedDestination = request.value
                    } else if request.kind == 3 {
                        runner.consumeTimeRequest(request.value)
                    } else if request.kind == 9 {
                        if scriptedRelocation == nil {
                            scriptedRelocation = Int(request.value)
                        }
                    } else if request.kind == 8 {
                        // Search consumes this request without updating the map position (0x020340D0).
                        if let lobby, lobby.mode == .walking { runner.setMapPosition(lobby.position, facing: lobby.checkpointFacing) }
                        runner.saveRetryCheckpoint()
                    }
                }
                handledMapRequests = runner.processRequests.count
                if let destination = scriptedDestination {
                    // 0x0202C264 request 1 starts map entry after the conversation returns.
                    lobbyTouch = nil
                    firstPersonMovement = nil
                    return moveToMap(destination, relocationMarker: scriptedRelocation)
                }
                if let scriptedRelocation,
                   try lobby?.relocate(to: scriptedRelocation) == true, let lobby {
                    runner.setMapPosition(lobby.position, facing: lobby.facing)
                }
                if runner.game.chapter == 0, !hasReturnedFromDunningIntroduction,
                   runner.game.value(for: .eventFlag(group: 2, index: 7)) == true {
                    lobby?.leaveCounter()
                    hasReturnedFromDunningIntroduction = true
                }
                try renderLobby()
                if lobby?.mode == .walking { audio.playWalkingMusic(mapID: map, game: runner.game) }
                checkpointWalking()
                startTimer()
            } catch { runner.halt("The map could not be loaded: \(error)") }
        case .questions:
            startTimer()
            do { itemNames = try OriginalItemNames.bundled().names }
            catch { runner.halt("The inventory names could not be loaded: \(error)") }
        case .choice:
            startTimer()
        case .halted:
            stopTimer()
        }
    }

    /// Resolve original music and sound controls through the recovered tables.
    private func applyAudioControls(_ packet: OriginalDialoguePacket) {
        audio.applyDialogueAudio(packet)
    }

    private func startTimer() {
        guard timer == nil, !isPaused, !isReplayingProgress else { return }
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
        guard !isPaused else { return }
        let recordsProgress = shouldRecordProgressFrame && beginProgressInput(
            .frames(count: 1, microphone: puzzleMicrophone.energy))
        defer { endProgressInput(recordsProgress) }
        // Music and effect fades continue while reading, browsing and choosing.
        audio.advanceOriginalFrame()
        if case .dialogue = runner.phase {
            if (try? encounterAnimations?.advance()) == true {
                encounterPortraits = encounterAnimations?.portraits ?? []
            }
        }
        guard !isBrowsingInventory, chapterTransition == nil else { return }
        if notebook != nil {
            if let touch = notebookTouch {
                let before = notebook?.pixels
                notebook?.touch(x: touch.x, y: touch.y)
                if before != notebook?.pixels { refreshNotebookImage() }
            }
            return
        }
        switch runner.phase {
        case .dialogue, .itemNotice, .questions, .choice, .halted: return
        default: break
        }
        if case .exploration = runner.phase, lobby != nil {
            guard !isPaused else { return }
            let people = lobby?.people(in: runner.game).map(\.position) ?? []
            let previousPosition = lobby?.position
            if let movement = firstPersonMovement {
                lobby?.update(firstPersonMovement: movement, people: people, modernPace: !usesLegacyInteractionPacing)
            } else {
                lobby?.update(heldPageTouch: lobbyTouch, people: people)
            }
            if let previousPosition, let lobby, lobby.mode == .walking {
                audio.advanceWalkingAudio(mapID: lobby.mapID, from: previousPosition, to: lobby.position,
                                          hasInput: lobbyTouch != nil || firstPersonMovement != nil)
            }
            guard lobbyTouch != nil || firstPersonMovement != nil else { return }
            if let region = lobby?.eventRegion, runner.enterMapRegion(region) {
                lobbyTouch = nil
                firstPersonMovement = nil
                return settle()
            }
            if let destination = lobby?.exitMapID {
                lobbyTouch = nil
                firstPersonMovement = nil
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
        if vendingMachine != nil { return updateVendingMachine() }
        if numberSeal != nil { return updateNumberSeal() }
        if codeNotice != nil { return updateCodeNotice() }
        if afterConfess != nil { return updateAfterConfess() }
        if vsScene != nil { return updateVSScene() }
        if picturePeel != nil { return updatePicturePeel() }
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
        if pencilSharpener != nil { return updatePencilSharpener() }
        if bowlingMatch != nil { return updateBowling() }
        if clock != nil { return updateClock() }
        if cassetteDeck != nil { return updateCassetteDeck() }
        if cassetteBallpoint != nil { return updateCassetteBallpoint() }
        if cassetteRewind != nil { return updateCassetteRewind() }
        if signProcess != nil { return updateSign() }
        if thinWire != nil { return updateThinWire() }
        if differences != nil { return updateDifferences() }
        if coinPuzzle != nil { return updateCoinPuzzle() }
        if matchsticks != nil { return updateMatchsticks() }
        if linenWagon != nil { return updateLinenWagon() }
        if dollRepair != nil { return updateDollRepair() }
        if bookmarkBox != nil { return updateBookmarkBox() }
        if labelPeel != nil { return updateLabelPeel() }
        if christmasTree != nil { return updateChristmasTree() }
        if searchShed != nil { return updateSearchShed() }
        if bagSearch != nil { return updateBagSearch() }
        if toiletTank != nil { return updateToiletTank() }
        if switchboard != nil { return updateSwitchboard() }
        if fountainPen != nil { return updateFountainPen() }
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

    private static let bowlingCameraMatrixFixed20_12: [Int32] = [
        0, 12_288, 21_709, 0, 2_048, -43_827, 0, 0,
        0, -4_096, 0, 0, 0, 4_096, 0, 0
    ]

    private func bowlingSceneState(_ match: OriginalBowlingMatchProcess) throws -> OriginalBowlingRenderer.SceneState {
        try OriginalBowlingRenderer.SceneState(
            cameraMatrixFixed20_12: Self.bowlingCameraMatrixFixed20_12,
            ballPositionFixed20_12: match.turn.ballPositionFixed20_12,
            pins: match.turn.simulation.pins.pins)
    }

    private func bowlingDragAnchor(pageX: Float, pageY: Float,
                                   match: OriginalBowlingMatchProcess) -> OriginalBowlingTouchRay.DragAnchor? {
        guard let camera = OriginalBowlingCameraBasis(matrixFixed20_12: Self.bowlingCameraMatrixFixed20_12),
              let ray = OriginalBowlingTouchRay.ray(pagePoint: SIMD2(pageX, pageY), camera: camera),
              let anchor = OriginalBowlingTouchRay.dragAnchor(
                origin: ray.origin, direction: ray.direction,
                laneVertices: OriginalBowlingTouchRay.translatedVertices(
                    OriginalBowlingTouchRay.lanePlaneVertices,
                    byFixed20_12: SIMD3(0, 2_979, 0)),
                ballVertices: OriginalBowlingTouchRay.translatedVertices(
                    OriginalBowlingTouchRay.ballPlaneVertices,
                    byFixed20_12: match.turn.ballPositionFixed20_12)) else { return nil }
        return anchor
    }

    private func bowlingLanePoint(pageX: Float, pageY: Float) -> SIMD3<Int32>? {
        guard let camera = OriginalBowlingCameraBasis(matrixFixed20_12: Self.bowlingCameraMatrixFixed20_12),
              let ray = OriginalBowlingTouchRay.ray(pagePoint: SIMD2(pageX, pageY), camera: camera),
              let point = OriginalBowlingTouchRay.firstHit(
                origin: ray.origin, direction: ray.direction,
                vertices: OriginalBowlingTouchRay.translatedVertices(
                    OriginalBowlingTouchRay.lanePlaneVertices,
                    byFixed20_12: SIMD3(0, 2_979, 0))) else { return nil }
        return Self.fixedBowlingPoint(point)
    }

    private static func fixedBowlingPoint(_ point: SIMD3<Float>) -> SIMD3<Int32> {
        SIMD3(Int32((point.x * 4_096).rounded()), Int32((point.y * 4_096).rounded()),
              Int32((point.z * 4_096).rounded()))
    }

    private func updateBowling() {
        guard var match = bowlingMatch, let renderer = bowlingRenderer else { return stopTimer() }
        if let requestID = match.nextCommentaryRequest {
            do {
                let response = try runner.processHint(catalog: catalog, pairA: 21, pairB: requestID)
                bowlingParent = runner
                runner = response
                bowlingMatch = match
                presentedPacketOffset = nil
                return settle()
            } catch {
                runner.halt("The bowling response could not be loaded: \(error)")
                stopTimer()
                return
            }
        }
        if match.phase == .dragging, let touch = bowlingTouch {
            if let lanePoint = bowlingLanePoint(pageX: touch.x, pageY: touch.y) {
                match.updateDrag(to: lanePoint)
            }
        }
        switch match.phase {
        case .rolling:
            match.advanceOneUpdate()
            if match.phase == .showingResult {
                _ = try? audio.playOriginalEffect(archiveID: 60, entryID: 0)
            }
        case .showingResult:
            match.advanceOneUpdate()
        case .presentingResult:
            if match.presentationFramesRemaining == OriginalBowlingMatchProcess.resultPresentationFrames {
                audio.stopOriginalEffects(fadeFrames: 10)
            }
            match.advanceOneUpdate()
        case .betweenThrows:
            _ = match.beginNextThrow()
        case .completed:
            bowlingMatch = nil
            bowlingImage = nil
            bowlingRenderer = nil
            bowlingTouch = nil
            stopTimer()
            runner.finishProcess(returnValue: match.returnValue ?? processReturn)
            settle()
            return
        case .ready, .dragging:
            break
        }
        do {
            bowlingImage = try renderer.render(bowlingSceneState(match))
        } catch {
            runner.halt("The bowling scene could not be drawn: \(error)")
            stopTimer()
        }
        bowlingMatch = match
    }

    private func updatePencilSharpener() {
        guard var current = pencilSharpener else { return stopTimer() }
        current.updateOneFrame()
        pencilSharpener = current
        guard let returnValue = current.returnedProcessValue else { return }
        pencilSharpener = nil
        pencilSharpenerImage = nil
        stopTimer()
        runner.finishProcess(returnValue: returnValue)
        settle()
    }

    private func updateVendingMachine() {
        guard var process = vendingMachine else { return stopTimer() }
        if let sound = process.update() {
            try? audio.playOriginalEffect(archiveID: 52, entryID: sound)
        }
        vendingMachine = process
        guard let result = process.result else { return }
        vendingMachine = nil
        vendingMachineImage = nil
        vendingMachineProducts = [:]
        stopTimer()
        runner.finishProcess(returnValue: result)
        settle()
    }

    private func updateNumberSeal() {
        guard var process = numberSeal else { return stopTimer() }
        let previous = process.phase
        process.update(touch: numberSealTouch)
        numberSealTouch = nil
        numberSeal = process
        if previous == .awaitingExit, case .fadingOut = process.phase {
            try? audio.playOriginalEffect(archiveID: 8, entryID: 2)
        }
        guard let result = process.result else { return }
        numberSeal = nil
        numberSealImage = nil
        stopTimer()
        runner.finishProcess(returnValue: result)
        settle()
    }

    private func updateCodeNotice() {
        guard var process = codeNotice else { return stopTimer() }
        let controlFinished = process.phase == .waitingForExitControl
        let effects = process.update(pageTouch: pendingCodeNoticeTouch,
                                     exitControlFinished: controlFinished)
        pendingCodeNoticeTouch = nil
        for effect in effects {
            switch effect {
            case .returned:
                break
            }
        }
        codeNotice = process
        guard let result = process.result else { return }
        codeNotice = nil
        codeNoticeImage = nil
        codeNoticeCaption = nil
        pendingCodeNoticeTouch = nil
        stopTimer()
        runner.finishProcess(returnValue: result)
        settle()
    }

    private func updateCassetteBallpoint() {
        guard var process = cassetteBallpoint else { return }
        let previousPhase = process.phase
        process.update(newRawTouch: cassettePress)
        cassettePress = nil
        if process.phase == .fading { cassetteOpacity = max(0, 1 - Double(process.fadeUpdates) / Double(OriginalCassetteBallpointProcess.quitFadeUpdates)) }
        if previousPhase == .quitDelay, process.phase == .fading { cassetteOpacity = 1 }
        cassetteBallpoint = process
        guard process.phase == .complete else { return }
        cassetteTouch = nil
        cassettePress = nil
        cassetteBallpoint = nil
        cassetteImage = nil
        cassetteRenderer = nil
        cassetteOpacity = 1
        runner.finishProcess(returnValue: process.returnedProcessValue ?? 2)
        settle()
    }

    private func updateCassetteDeck() {
        guard var process = cassetteDeck, let renderer = cassetteDeckRenderer else { return }
        let oldCamera = process.camera
        let oldState = process.sceneState
        let press = cassettePress
        var sceneHit = false
        if process.phase == .opening, let press {
            let pagePoint = SIMD2(press.y, 255 - press.x)
            do { sceneHit = try renderer.hasHit(pageX: pagePoint.x, pageY: pagePoint.y,
                                                camera: process.camera, state: process.sceneState) }
            catch { runner.halt("The cassette deck could not be hit-tested: \(error)"); stopTimer(); return }
        }
        process.update(touch: cassetteTouch, pressedTouch: press, sceneHit: sceneHit)
        cassettePress = nil
        cassetteOpacity = process.opacity
        if oldCamera != process.camera || oldState != process.sceneState {
            do { cassetteImage = try renderer.render(camera: process.camera, state: process.sceneState) }
            catch { runner.halt("The cassette deck could not be drawn: \(error)"); stopTimer(); return }
        }
        cassetteDeck = process
        guard process.phase == .complete else { return }
        cassetteTouch = nil
        cassettePress = nil
        cassetteDeck = nil
        cassetteDeckRenderer = nil
        cassetteImage = nil
        cassetteOpacity = 1
        runner.finishProcess(returnValue: process.returnedProcessValue ?? 2)
        settle()
    }

    private func updateCassetteRewind() {
        guard var process = cassetteRewind else { return }
        let touch = process.phase == .ready ? cassettePress : cassetteTouch
        process.update(rawTouch: touch)
        cassettePress = nil
        cassetteRewind = process
        guard process.phase == .complete else { return }
        cassetteTouch = nil
        cassettePress = nil
        cassetteRewind = nil
        cassetteImage = nil
        cassetteRenderer = nil
        cassetteOpacity = 1
        runner.finishProcess(returnValue: process.returnedProcessValue ?? 2)
        settle()
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
                case .caption: runner.recordUnrenderedProcessCaption(processID: UInt16(puzzle.variant.rawValue), caption: 39)
                case .hideCaption: break
                case .fadeIn(let updates):
                    try cabinetDialScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try cabinetDialScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try cabinetDialScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .rumble: runner.recordUnrenderedRumble(processID: UInt16(puzzle.variant.rawValue))
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

    private func updateFountainPen() {
        guard var puzzle = fountainPen else { return }
        let complete = !fountainPenScreenEffects.brightness[0].active
        fountainPenScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: fountainPenTouch, microphoneEnergy: isReplayingProgress ? replayMicrophoneEnergy : puzzleMicrophone.energy, fadeComplete: complete)
        fountainPen = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try fountainPenScreenEffects.beginBrightness(screen: 0, mask: 0x3F, mode: 3, from: -16, frames: UInt16(updates))
                case .fadeFromWhite(let updates):
                    try fountainPenScreenEffects.beginBrightness(screen: 0, mask: 0x3F, mode: 3, from: 16, frames: UInt16(updates))
                case .reveal(let updates):
                    try fountainPenScreenEffects.beginBrightness(screen: 0, mask: 0x3F, mode: 1, from: 0, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try fountainPenScreenEffects.beginBrightness(screen: 0, mask: 0x3F, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .ensureSound(let archive, let entry): try? audio.ensureOriginalEffect(archiveID: archive, entryID: entry)
                case .completed(let result):
                    fountainPen = nil
                    fountainPenImage = nil
                    fountainPenRenderer = nil
                    fountainPenTouch = nil
                    puzzleMicrophone.stop()
                    fountainPenScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous.revision != puzzle.revision || previous.phase != puzzle.phase || previous.inscriptionVisible != puzzle.inscriptionVisible {
                fountainPenImage = try fountainPenRenderer?.render(puzzle)
            }
        } catch {
            runner.halt("The fountain pen could not be updated: \(error)")
            settle()
        }
    }

    private func updateToiletTank() {
        guard var puzzle = toiletTank else { return }
        let complete = !toiletTankScreenEffects.brightness[0].active
        toiletTankScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: toiletTankTouch, fadeComplete: complete)
        toiletTank = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try toiletTankScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try toiletTankScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try toiletTankScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .slideSound(let moving):
                    if moving { try? audio.ensureOriginalEffect(archiveID: 0, entryID: 46) }
                    _ = try? audio.applyOriginalCommand(.effectVolume(archiveID: 0, entryID: 46, target: moving ? 127 : 0, frames: 5))
                case .stopSlideSound:
                    _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: 0, entryID: 46, fadeFrames: 10))
                case .hint(let pairA, let pairB):
                    let hint = try runner.processHint(catalog: catalog, pairA: pairA, pairB: pairB)
                    toiletTankParent = runner; runner = hint
                    toiletTankTouch = nil; presentedPacketOffset = nil
                    return settle()
                case .completed(let result):
                    toiletTank = nil; toiletTankImage = nil; toiletTankRenderer = nil; toiletTankTouch = nil
                    toiletTankScreenEffects = OriginalScreenEffects()
                    stopTimer(); runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous.lidAngle != puzzle.lidAngle || previous.flushAngle != puzzle.flushAngle || previous.phase != puzzle.phase { toiletTankImage = try toiletTankRenderer?.render(puzzle) }
        } catch {
            runner.halt("The toilet tank could not be updated: \(error)")
            settle()
        }
    }

    private func updateDifferences() {
        guard var puzzle = differences else { return }
        let complete = !differencesScreenEffects.brightness[0].active
        differencesScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(touch: differencesTouch, fadeComplete: complete)
        differences = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try differencesScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try differencesScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try differencesScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .startSound: try? audio.playOriginalEffect(archiveID: 0, entryID: 34)
                case .soundVolume(let value):
                    _ = try? audio.applyOriginalCommand(.effectVolume(archiveID: 0, entryID: 34, target: value, frames: 10))
                case .stopSound:
                    _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: 0, entryID: 34, fadeFrames: 5))
                case .victory: try? audio.playOriginalEffect(archiveID: 0, entryID: 1)
                case .hint(let pairA, let pairB):
                    let hint = try runner.processHint(catalog: catalog, pairA: pairA, pairB: pairB)
                    differencesParent = runner; runner = hint
                    differencesTouch = nil; presentedPacketOffset = nil
                    return settle()
                case .completed(let result):
                    differences = nil; differencesImage = nil; differencesRenderer = nil; differencesTouch = nil
                    differencesScreenEffects = OriginalScreenEffects()
                    stopTimer(); runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous.revision != puzzle.revision { differencesImage = try differencesRenderer?.render(puzzle) }
        } catch {
            runner.halt("The pamphlet puzzle could not be updated: \(error)")
            settle()
        }
    }

    private func updateLinenWagon() {
        guard var puzzle = linenWagon else { return }
        let complete = !linenWagonScreenEffects.brightness[0].active
        linenWagonScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: linenWagonTouch, gunAnimationComplete: linenWagonRenderer?.gunResourceReady == true, fadeComplete: complete)
        linenWagon = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn:
                    let updates = 60
                    try linenWagonScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try linenWagonScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut:
                    let updates = 60
                    try linenWagonScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .loadGunAnimation: try linenWagonRenderer?.loadGunResource()
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .completed(let result):
                    linenWagon = nil
                    linenWagonImage = nil
                    linenWagonRenderer = nil
                    linenWagonTouch = nil
                    linenWagonScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { linenWagonImage = try linenWagonRenderer?.render(puzzle) }
        } catch {
            runner.halt("The linen wagon could not be updated: \(error)")
            settle()
        }
    }

    private func updateMatchsticks() {
        guard var puzzle = matchsticks else { return }
        let complete = !matchsticksScreenEffects.brightness[0].active
        matchsticksScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: matchsticksTouch, fadeComplete: complete)
        matchsticks = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try matchsticksScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try matchsticksScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try matchsticksScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .completed(let result):
                    matchsticks = nil
                    matchsticksImage = nil
                    matchsticksRenderer = nil
                    matchsticksTouch = nil
                    matchsticksScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { matchsticksImage = try matchsticksRenderer?.render(puzzle) }
        } catch {
            runner.halt("The matchstick puzzle could not be updated: \(error)")
            settle()
        }
    }

    private func updateCoinPuzzle() {
        guard var puzzle = coinPuzzle else { return }
        let complete = !coinPuzzleScreenEffects.brightness[0].active
        coinPuzzleScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: coinPuzzleTouch, fadeComplete: complete)
        coinPuzzle = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try coinPuzzleScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try coinPuzzleScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try coinPuzzleScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .completed(let result):
                    coinPuzzle = nil
                    coinPuzzleImage = nil
                    coinPuzzleRenderer = nil
                    coinPuzzleTouch = nil
                    coinPuzzleScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { coinPuzzleImage = try coinPuzzleRenderer?.render(puzzle) }
        } catch {
            runner.halt("The coin puzzle could not be updated: \(error)")
            settle()
        }
    }

    private func updateDollRepair() {
        guard var puzzle = dollRepair else { return }
        let complete = !dollRepairScreenEffects.brightness[0].active
        dollRepairScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: dollRepairTouch, fadeComplete: complete)
        dollRepair = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try dollRepairScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try dollRepairScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try dollRepairScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .completed(let result):
                    dollRepair = nil
                    dollRepairImage = nil
                    dollRepairRenderer = nil
                    dollRepairTouch = nil
                    dollRepairScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { dollRepairImage = try dollRepairRenderer?.render(puzzle) }
        } catch {
            runner.halt("The doll repair could not be updated: \(error)")
            settle()
        }
    }
    private func updateBookmarkBox() {
        guard var puzzle = bookmarkBox else { return }
        let complete = !bookmarkBoxScreenEffects.brightness[0].active
        bookmarkBoxScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: bookmarkBoxTouch, fadeComplete: complete)
        bookmarkBox = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try bookmarkBoxScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try bookmarkBoxScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try bookmarkBoxScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .ensureSound(let archive, let entry): try? audio.ensureOriginalEffect(archiveID: archive, entryID: entry)
                case .stopSound(let archive, let entry, let frames):
                    _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: archive, entryID: entry, fadeFrames: frames))
                case .completed(let result):
                    bookmarkBox = nil
                    bookmarkBoxImage = nil
                    bookmarkBoxTouch = nil
                    bookmarkBoxScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { bookmarkBoxImage = try bookmarkBoxRender(puzzle) }
        } catch {
            runner.halt("The bookmark box could not be updated: \(error)")
            settle()
        }
    }

    private func updateSwitchboard() {
        guard var puzzle = switchboard else { return }
        let complete = !switchboardScreenEffects.brightness[0].active
        switchboardScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: switchboardTouch, fadeComplete: complete)
        switchboard = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try switchboardScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .completionFade(let updates):
                    try switchboardScreenEffects.beginBrightness(screen: 0, mask: 0x21, mode: 3, from: 16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try switchboardScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .sound(let archive, let entry): try? audio.playOriginalEffect(archiveID: archive, entryID: entry)
                case .hint(let pairA, let pairB):
                    let hint = try runner.processHint(catalog: catalog, pairA: pairA, pairB: pairB)
                    switchboardParent = runner
                    runner = hint
                    switchboardTouch = nil
                    presentedPacketOffset = nil
                    return settle()
                case .completed(let result):
                    switchboard = nil
                    switchboardImage = nil
                    switchboardRenderer = nil
                    switchboardTouch = nil
                    switchboardScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { switchboardImage = try switchboardRenderer?.render(puzzle) }
        } catch {
            runner.halt("The electrical panel could not be updated: \(error)")
            settle()
        }
    }

    private func updateLabelPeel() {
        guard var puzzle = labelPeel else { return }
        let complete = !labelPeelScreenEffects.brightness[0].active
        labelPeelScreenEffects.advanceOriginalFrame()
        let previous = puzzle
        let effects = puzzle.update(pageTouch: labelPeelTouch, fadeComplete: complete)
        labelPeel = puzzle
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try labelPeelScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try labelPeelScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .dragging(true): try? audio.ensureOriginalEffect(archiveID: 0, entryID: 44)
                case .dragging(false):
                    _ = try? audio.applyOriginalCommand(.stopEffect(archiveID: 0, entryID: 44, fadeFrames: 5))
                case .completed(let result):
                    labelPeelFollowupPending = result == 2
                    labelPeel = nil
                    labelPeelImage = nil
                    labelPeelRenderer = nil
                    labelPeelTouch = nil
                    labelPeelScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if previous != puzzle { labelPeelImage = try labelPeelRenderer?.render(puzzle) }
        } catch {
            runner.halt("The wine label could not be updated: \(error)")
            settle()
        }
    }

    private func updateAfterConfess() {
        guard var process = afterConfess else { return }
        let previousPhase = process.phase
        let completed = process.update()
        afterConfess = process
        if completed {
            afterConfess = nil
            afterConfessTouchImage = nil
            afterConfessUpperImage = nil
            afterConfessRenderer = nil
            stopTimer()
            runner.finishProcess(returnValue: process.resultValue ?? OriginalAfterConfessProcess.result)
            settle()
            return
        }
        if process.phase != previousPhase,
           let pages = afterConfessRenderer?.pages(for: process.phase) {
            afterConfessTouchImage = pages.touch
            afterConfessUpperImage = pages.upper
        }
    }

    private func updateVSScene() {
        guard var process = vsScene else { return }
        let completed = process.update()
        vsScene = process
        guard completed else { return }
        vsScene = nil
        vsSceneImage = nil
        vsSceneRenderer = nil
        stopTimer()
        runner.finishProcess(returnValue: process.resultValue ?? OriginalVSSceneProcess.result)
        settle()
    }

    private func updatePicturePeel() {
        guard var process = picturePeel, let renderer = picturePeelRenderer else { return }
        let previous = process
        let effects = process.update(touch: picturePeelTouch)
        picturePeel = process
        do {
            for effect in effects {
                if case .sound(let archive, let entry) = effect {
                    if let originalEffectPlayer { originalEffectPlayer(archive, entry) }
                    else { try? audio.ensureOriginalEffect(archiveID: archive, entryID: entry) }
                }
            }
            if previous != process { picturePeelImage = try renderer.render(process) }
        } catch {
            runner.halt("The picture peel could not be updated: \(error)")
            settle()
        }
    }

    private func updateChristmasTree() {
        guard var process = christmasTree else { return }
        let fadeComplete = !christmasTreeScreenEffects.brightness[0].active
        christmasTreeScreenEffects.advanceOriginalFrame()
        let effects = process.update(fadeComplete: fadeComplete)
        christmasTree = process
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try christmasTreeScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3, from: -16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try christmasTreeScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2, from: 0, frames: UInt16(updates))
                case .completed(let result):
                    let decorationOrder = process.arrangement.encodedOrder
                    christmasTree = nil
                    christmasTreeImage = nil
                    christmasTreeRenderer = nil
                    christmasTreeDraggedDecoration = nil
                    christmasTreeScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishChristmasTree(returnValue: result, decorationOrder: decorationOrder)
                    return settle()
                }
            }
        } catch {
            runner.halt("The Christmas tree process could not be updated: \(error)")
            settle()
        }
    }

    private func updateSearchShed() {
        guard var process = searchShed else { return }
        let fadeComplete = !searchShedScreenEffects.brightness[0].active
        searchShedScreenEffects.advanceOriginalFrame()
        let effects = process.update(fadeComplete: fadeComplete)
        searchShed = process
        applySearchShed(effects)
    }

    private func updateBagSearch() {
        guard var process = bagSearch else { return }
        let fadeComplete = !bagSearchScreenEffects.brightness[0].active
        bagSearchScreenEffects.advanceOriginalFrame()
        let effects = process.update(fadeComplete: fadeComplete)
        bagSearch = process
        do {
            for effect in effects {
                switch effect {
                case .fadeOut(let updates):
                    try bagSearchScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2,
                                                               from: 0, frames: UInt16(updates))
                case .completed(let result):
                    bagSearch = nil
                    bagSearchImage = nil
                    bagSearchRenderer = nil
                    bagSearchTouch = nil
                    bagSearchScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
            if let renderer = bagSearchRenderer { bagSearchImage = try renderer.render(process) }
        } catch {
            runner.halt("The tree-box search could not be updated: \(error)")
            settle()
        }
    }

    private func applySearchShed(_ effects: [OriginalSearchShedProcess.Effect]) {
        do {
            for effect in effects {
                switch effect {
                case .fadeIn(let updates):
                    try searchShedScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 3,
                                                                 from: -16, frames: UInt16(updates))
                case .fadeOut(let updates):
                    try searchShedScreenEffects.beginBrightness(screen: 0, mask: 1, mode: 2,
                                                                 from: 0, frames: UInt16(updates))
                case .foundTreeBox:
                    break
                case .completed(let result):
                    searchShed = nil
                    searchShedImage = nil
                    searchShedRenderer = nil
                    searchShedTouch = nil
                    searchShedScreenEffects = OriginalScreenEffects()
                    stopTimer()
                    runner.finishProcess(returnValue: result)
                    return settle()
                }
            }
        } catch {
            runner.halt("The search shed could not be updated: \(error)")
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

    /// Advances a sign-card process. Status 2 hands the result to the event runner.
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
        let recordsProgress = beginProgressInput(.holdLobbyTouch(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, !isBrowsingInventory, chapterTransition == nil, notebook == nil, closeup == nil, door == nil, case .exploration = runner.phase, lobby?.mode == .walking,
              x.isFinite, y.isFinite, x >= 0, x < 192, y >= 0, y < 256 else { return }
        firstPersonMovement = nil
        lobbyTouch = SIMD2(x, y)
    }

    /// Camera-relative movement uses the same walls, people and event regions as map walking.
    public func holdFirstPersonMovement(strafe: Float, forward: Float) {
        let recordsProgress = beginProgressInput(.holdFirstPersonMovement(strafe: strafe, forward: forward))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, !isBrowsingInventory, canSaveWalkingCheckpoint, strafe.isFinite, forward.isFinite else { return }
        lobbyTouch = nil
        firstPersonMovement = SIMD2(strafe, forward)
    }

    public func turnFirstPerson(by radians: Float) {
        let recordsProgress = beginProgressInput(.turnFirstPerson(radians: radians))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, !isBrowsingInventory, canSaveWalkingCheckpoint, radians.isFinite else { return }
        lobby?.turnView(by: radians)
        redrawLobby()
    }

    public func finishFirstPersonLook() {
        let recordsProgress = beginProgressInput(.finishFirstPersonLook)
        defer { endProgressInput(recordsProgress) }
        if canSaveWalkingCheckpoint { redrawLobby() }
        checkpointWalking()
    }

    public func releaseLobbyTouch() {
        let recordsProgress = beginProgressInput(.releaseLobbyTouch)
        defer { endProgressInput(recordsProgress) }
        lobbyTouch = nil
        firstPersonMovement = nil
        if case .exploration = runner.phase { lobby?.update(heldPageTouch: nil) }
        if canSaveWalkingCheckpoint { redrawLobby() }
        checkpointWalking()
    }

    public var nearbyDoor: Int16? {
        guard let doorTable else { return nil }
        return lobby?.nearbyDoor(in: runner.game, table: doorTable)
    }

    public func inspectNearbyDoor() {
        let recordsProgress = beginProgressInput(.inspectNearbyDoor)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, notebook == nil, closeup == nil, door == nil, case .exploration = runner.phase,
              let destination = nearbyDoor, let lobby, let doorTable else { return }
        let connections = doorTable.connections(from: lobby.mapID, to: destination)
        let searchTable = try? OriginalSearchTable.bundled(map: lobby.mapName)
        let connection = searchTable.flatMap { table in
            connections.first { table.door(id: UInt16(bitPattern: $0.id)) != nil }
        } ?? connections.first
        guard let connection else { return }
        let doorRecord = searchTable?.door(id: UInt16(bitPattern: connection.id))
        routeTrace?.write(kind: "doorInspection", fields: routeTraceFields(extra: [
            "destinationMap": String(destination), "doorID": String(connection.id),
            "doorArea": doorRecord.map { String($0.areaID) } ?? "unknown",
            "upViewID": doorRecord.map { String($0.upViewID) } ?? "unknown"
        ]))
        if doorTable.departsDirectly(from: lobby.mapID, using: connection, game: runner.game) {
            lobbyTouch = nil
            firstPersonMovement = nil
            return departThroughDoor(to: destination)
        }
        do {
            guard let record = doorRecord else {
                throw OriginalDataError.unsupported("Door destination \(destination)")
            }
            lobbyTouch = nil
            firstPersonMovement = nil
            guard record.upViewID != .max else {
                runner.interactWithMapDoor(area: record.areaID)
                try startSearchFallback()
                return settle()
            }
            guard let view = try OriginalUpViewTable.bundled(map: lobby.mapName).views.first(where: {
                      $0.id == Int16(bitPattern: record.upViewID)
                  }),
                  view.layers.allSatisfy({ $0.itemID < 0 && $0.processID < 0 }) else {
                throw OriginalDataError.unsupported("Door destination \(destination)")
            }
            let scene = OriginalDoorScene(destination: destination, doorID: connection.id,
                                          area: record.areaID, view: view)
            try refreshDoorImage(scene)
            itemNames = try OriginalItemNames.bundled().names
            door = scene
            runner.interactWithDoor(area: record.areaID)
            try startSearchFallback()
            settle()
        } catch { runner.halt("The door could not be loaded: \(error)"); settle() }
    }

    private func refreshDoorImage(_ scene: OriginalDoorScene) throws {
        let library = try OriginalBitmapLibrary.bundled()
        let bitmaps = try ([scene.view.background] + scene.view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        doorImage = try OriginalUpViewImage(bitmaps: bitmaps, visible: scene.visibility(game: runner.game))
    }

    public func selectDoorComponent(x: Int, y: Int, confirmImmediately: Bool = false) {
        let recordsProgress = beginProgressInput(.selectDoorComponent(x: x, y: y, confirmImmediately: confirmImmediately))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, door != nil else { return }
        let hit = doorImage?.hit(pageX: x, pageY: y)
        if let hit {
            routeTrace?.write(kind: "doorComponentHit", fields: routeTraceFields(extra: [
                "destinationMap": String(door?.destination ?? -1), "doorID": String(door?.doorID ?? -1),
                "area": String(door?.area ?? .max), "component": String(hit),
                "pageX": String(x), "pageY": String(y)
            ]))
        }
        let repeated = door?.select(hit) == true
        if repeated || (confirmImmediately && door?.selected != nil) { confirmDoorComponent() }
    }

    public func useItemAtDoor(_ item: UInt8?) {
        let recordsProgress = beginProgressInput(.useItemAtDoor(item: item))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, door != nil else { return }
        if let item, (try? runner.game.inventory.items.contains(item)) != true { return }
        door?.use(item)
    }

    public func confirmDoorComponent() {
        let recordsProgress = beginProgressInput(.confirmDoorComponent)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, let door, let selected = door.selected else { return }
        self.door?.clearSelection()
        let opensDoor = door.item == nil && selected == 2
            && runner.game.value(for: .doorOpen(index: UInt16(door.doorID))) == false
        let event = door.view.layers[selected - 1].eventID
        runner.interactWithDoor(area: door.area, upView: event, item: door.item)
        do { try startSearchFallback() }
        catch { runner.halt("The door response could not be loaded: \(error)") }
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
        let recordsProgress = beginProgressInput(.leaveDoor)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase else { return }
        door = nil
        doorImage = nil
        settle()
    }


    public func talkToNearbyPerson() {
        let recordsProgress = beginProgressInput(.talkToNearbyPerson)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, notebook == nil, closeup == nil, door == nil, case .exploration = runner.phase,
              let person = lobby?.nearbyPerson(in: runner.game) else { return }
        lobbyTouch = nil
        firstPersonMovement = nil
        runner.talkToPerson(person)
        settle()
    }

    public func inspectLobbyCounter() {
        let recordsProgress = beginProgressInput(.inspectLobbyCounter)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, notebook == nil, closeup == nil, door == nil, case .exploration = runner.phase,
              var lobby, lobby.canInspectCounter(in: runner.game), let area = lobby.nearbySearchArea else { return }
        do {
            if area != lobby.searchAreaID {
                let suffix = String(format: "%02d", area)
                let model = try OriginalModelLibrary.bundled().load(path: "map/\(lobby.mapName)/\(lobby.mapName)_s\(suffix)/\(lobby.mapName)_s\(suffix).mdf")
                try lobby.prepareSearch(area: area, model: model)
                lobbyRenderer = try mapRendererFactory(lobby.mapName, area)
            }
            guard lobby.inspectCounter() else { return }
            self.lobby = lobby
            itemNames = try OriginalItemNames.bundled().names
            searchItem = nil
            lobbyTouch = nil
            firstPersonMovement = nil
            redrawLobby()
        } catch { runner.halt("The search view could not be loaded: \(error)"); stopTimer() }
    }

    public func panLobbyCounter(_ value: Float) {
        let recordsProgress = beginProgressInput(.panLobbyCounter(value: value))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup == nil, lobby?.mode == .counter else { return }
        lobby?.setPan(value)
        redrawLobby()
    }

    public func leaveLobbyCounter() {
        let recordsProgress = beginProgressInput(.leaveLobbyCounter)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase else { return }
        lobby?.leaveCounter()
        searchItem = nil
        redrawLobby()
    }

    public func selectLobbyObject(x: Float, y: Float, confirmImmediately: Bool = false) {
        let recordsProgress = beginProgressInput(.selectLobbyObject(x: x, y: y, confirmImmediately: confirmImmediately))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup == nil, lobby?.mode == .counter else { return }
        do {
            let visible = lobby.map { $0.objectVisibility.visibleNodes(in: $0.counter, map: $0.mapID,
                area: $0.searchAreaID, game: runner.game) }
            let repeated = try lobby?.selectCounterObject(page: SIMD2(x, y), visibleNodes: visible) != nil
            routeTrace?.write(kind: "searchHit", fields: routeTraceFields(extra: [
                "pickedNode": lobby?.selectedNode ?? "none", "repeated": String(repeated),
                "confirmImmediately": String(confirmImmediately)
            ]))
            if repeated || (confirmImmediately && lobby?.selectedNode != nil) { confirmLobbyObject() }
        } catch { runner.halt("The counter selection failed: \(error)"); stopTimer() }
    }

    /**
     * Starts the search response for a room object selected with its visible hit mesh.
     */
    public func selectLobbyRoomObject(x: Float, y: Float) {
        let recordsProgress = beginProgressInput(.selectLobbyRoomObject(x: x, y: y))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase,
              closeup == nil, let lobby, lobby.mode == .walking,
              let area = lobby.nearbySearchArea else { return }
        do {
            let visible = lobby.objectVisibility.visibleNodes(in: lobby.room, map: lobby.mapID, area: nil, game: runner.game)
            guard let node = try lobby.pickedRoomObject(page: SIMD2(x, y), visibleNodes: visible),
                  let subarea = OriginalMapExploration.subarea(node: node) else { return }
            routeTrace?.write(kind: "roomObjectHit", fields: routeTraceFields(extra: [
                "pickedNode": node, "area": String(area), "subarea": String(subarea)
            ]))
            if lobby.mapID == 12, node == "obj9999",
               runner.game.value(for: .eventFlag(group: 23, index: 4)) == true {
                routeTrace?.write(kind: "storyDispatch", fields: routeTraceFields(extra: [
                    "trigger": "chapter9-pantry-quiz", "pickedNode": node
                ]))
                try startChapterNinePantryQuiz()
                settle()
                return
            }
            let table = try OriginalSearchTable.bundled(map: lobby.mapName)
            if let view = table.upViewID(area: area, subarea: subarea), view != .max {
                pendingCloseup = (area, subarea, view)
            }
            runner.lookInSearchView(area: area, subarea: subarea, table: table)
            try startSearchFallback()
            settle()
        } catch { runner.halt("The room object selection failed: \(error)"); settle() }
    }

    /**
     * Starts Quiz 9 from the pantry's hidden door hit masks after the birthday cards are read.
     */
    private func startChapterNinePantryQuiz() throws {
        let context = OriginalEventSelectionContext(sceneID: 1, blockID: 0, modeID: 24,
            eventID: 2, nowTime: runner.game.nowTime, mapID: 7)
        var review = try OriginalEventRunner(program: catalog.loadProgram("EP9_R107"),
            game: runner.game, selection: context)
        review.attachRouteTrace(routeTrace)
        runner = review
    }

    public func useItemInSearchView(_ item: UInt8?) {
        let recordsProgress = beginProgressInput(.useItemInSearchView(item: item))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup == nil, lobby?.mode == .counter else { return }
        if let item, (try? runner.game.inventory.items.contains(item)) != true { return }
        if let item, startInventoryProcess(item) { return }
        searchItem = item
        lobby?.clearSelection()
    }

    public func confirmLobbyObject() {
        let recordsProgress = beginProgressInput(.confirmLobbyObject)
        defer { endProgressInput(recordsProgress) }
        routeTrace?.write(kind: "searchConfirm", fields: routeTraceFields(extra: [
            "pickedNode": lobby?.selectedNode ?? "none", "hasItem": String(searchItem != nil)
        ]))
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
        firstPersonMovement = nil
        /**
         * Process 98 runs the background response on entry (0x02062F08, case 4).
         */
        runner.lookInCloseup(area: area, subarea: subarea, event: view.id)
        try startSearchFallback()
    }

    public func selectCloseupComponent(x: Int, y: Int, confirmImmediately: Bool = false) {
        let recordsProgress = beginProgressInput(.selectCloseupComponent(x: x, y: y, confirmImmediately: confirmImmediately))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup != nil else { return }
        let repeated = closeup?.select(closeupImage?.hit(pageX: x, pageY: y)) == true
        if repeated || (confirmImmediately && closeup?.selected != nil) { confirmCloseupComponent() }
    }

    /**
     * Close-up inventory uses the same trick table as the surrounding search view.
     */
    public func useItemInCloseup(_ item: UInt8?) {
        let recordsProgress = beginProgressInput(.useItemInCloseup(item: item))
        defer { endProgressInput(recordsProgress) }
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
        let recordsProgress = beginProgressInput(.confirmCloseupComponent)
        defer { endProgressInput(recordsProgress) }
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
        let recordsProgress = beginProgressInput(.leaveSearchCloseup)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition == nil, case .exploration = runner.phase, closeup != nil else { return }
        let search = closeup
        let startsWordEntry = runner.program.name == "EP9_R125"
            && runner.game.applePaintingFoundMask & 0x1f == 0x1f
            && runner.processRequests.dropFirst(handledMapRequests).contains { $0.kind == 5 }
        searchItem = nil
        if let parent = closeupParents.popLast() {
            closeup = parent.scene
            closeupBitmaps = parent.bitmaps
            return settle()
        }
        closeup = nil
        closeupImage = nil
        closeupBitmaps = []
        if startsWordEntry, let search {
            handledMapRequests = runner.processRequests.count
            runner.beginChapterNineWordEntry(area: search.area, subarea: search.subarea,
                upView: runner.session.selection.upViewID)
        }
        settle()
    }

    private func renderLobby() throws {
        if let lobby { lobbyImage = try lobbyRenderer?.render(lobby, game: runner.game) }
    }

    private func moveToMap(_ map: Int16, relocationMarker: Int? = nil) {
        do {
            guard let name = OriginalMapExploration.supportedMaps[map] else {
                throw OriginalDataError.unsupported("Map \(map) in this chapter")
            }
            /**
             * Map entry builds the controller before its arrival script runs (0x02029B78).
             * A clock command can clear the script state's previous map during that arrival.
             */
            let restoresCurrentPosition = map == runner.game.mapID
            if restoresCurrentPosition, let lobby {
                runner.setMapPosition(lobby.position, facing: lobby.checkpointFacing)
            }
            var exploration = try OriginalMapExploration.bundled(mapID: map, previousMapID: runner.game.mapID,
                savedGame: restoresCurrentPosition ? runner.game : nil)
            let renderer = try mapRendererFactory(name, nil)
            audio.stopWalkingAudio()
            runner = try runner.moving(to: map, program: catalog.loadMapProgram(chapter: runner.game.chapter, mapID: map))
            if let relocationMarker, try exploration.relocate(to: relocationMarker) {
                runner.setMapPosition(exploration.position, facing: exploration.facing)
            }
            handledMapRequests = 0
            lobby = exploration
            lobbyRenderer = renderer
            lobbyMap = renderer.map
            lobbyImage = nil
            presentedPacketOffset = nil
            settle()
        } catch { runner.halt("The next map could not be loaded: \(error)"); stopTimer() }
    }

    public static func restoring(_ checkpoint: OriginalResumeSave, audio: AudioController,
                                 saveStore: any OriginalChapterSaveStore,
                                 mapRendererFactory: @escaping OriginalMapRendererFactory = { try OriginalMapRenderer(mapName: $0, searchArea: $1) },
                                 suitcaseRendererFactory: @escaping OriginalSuitcaseRendererFactory = { try OriginalSuitcaseRenderer() },
                                 hangerRendererFactory: @escaping OriginalHangerRendererFactory = { try OriginalHangerRenderer() },
                                 thinWireRendererFactory: @escaping OriginalThinWireRendererFactory = { try OriginalThinWireRenderer(variant: $0) },
                                 suitcaseContentsRendererFactory: @escaping OriginalSuitcaseContentsRendererFactory = { try OriginalSuitcaseContentsRenderer() },
                                 memoPullRendererFactory: @escaping OriginalMemoPullRendererFactory = { try OriginalMemoPullRenderer() },
                                 crowbarRendererFactory: @escaping OriginalCrowbarRendererFactory = { try OriginalCrowbarRenderer(tornPaper: $0) },
                                 cabinetDialRendererFactory: @escaping OriginalCabinetDialRendererFactory = { try OriginalCabinetDialRenderer(variant: $0) },
                                 cassetteRendererFactory: OriginalCassetteRendererFactory? = nil,
                                 cassetteDeckRendererFactory: OriginalCassetteDeckRendererFactory? = nil,
                                 bowlingRendererFactory: OriginalBowlingRendererFactory? = nil,
                                 toiletTankRendererFactory: @escaping OriginalToiletTankRendererFactory = { try OriginalToiletTankRenderer() },
                                 bagSearchRendererFactory: @escaping OriginalBagSearchRendererFactory = { try OriginalBagSearchRenderer() },
                                 bookmarkBoxRender: (@MainActor (OriginalBookmarkBoxProcess) throws -> CGImage)? = nil) throws -> OriginalPlaySession {
        if let journal = checkpoint.progress {
            _ = try checkpoint.gameState()
            let wasMuted = audio.isMuted
            let wasRestoring = audio.isRestoringProgress
            let wasLegacy = audio.restoresLegacyInteractions
            var restored = false
            audio.isMuted = true
            audio.isRestoringProgress = true
            audio.restoresLegacyInteractions = journal.qualityOfLifeVersion == nil
            defer {
                audio.stopAll()
                audio.isRestoringProgress = wasRestoring
                audio.restoresLegacyInteractions = wasLegacy
                audio.isMuted = wasMuted
                if restored, let sequence = checkpoint.musicSequenceID {
                    try? audio.playOriginalSequence(id: sequence)
                }
            }
            let play: OriginalPlaySession
            switch journal.origin {
            case .arrival:
                play = try chapterOne(audio: audio, timestamp: journal.timestamp, saveStore: saveStore,
                mapRendererFactory: mapRendererFactory,
                suitcaseRendererFactory: suitcaseRendererFactory,
                hangerRendererFactory: hangerRendererFactory,
                thinWireRendererFactory: thinWireRendererFactory,
                suitcaseContentsRendererFactory: suitcaseContentsRendererFactory,
                memoPullRendererFactory: memoPullRendererFactory,
                crowbarRendererFactory: crowbarRendererFactory,
                cabinetDialRendererFactory: cabinetDialRendererFactory,
                toiletTankRendererFactory: toiletTankRendererFactory,
                bagSearchRendererFactory: bagSearchRendererFactory)
            case .walking:
                let base = try JSONDecoder().decode(OriginalResumeSave.self, from: journal.base)
                play = try restoring(base, audio: audio, saveStore: saveStore,
                mapRendererFactory: mapRendererFactory,
                suitcaseRendererFactory: suitcaseRendererFactory,
                hangerRendererFactory: hangerRendererFactory,
                thinWireRendererFactory: thinWireRendererFactory,
                suitcaseContentsRendererFactory: suitcaseContentsRendererFactory,
                memoPullRendererFactory: memoPullRendererFactory,
                crowbarRendererFactory: crowbarRendererFactory,
                cabinetDialRendererFactory: cabinetDialRendererFactory,
                cassetteRendererFactory: cassetteRendererFactory,
                cassetteDeckRendererFactory: cassetteDeckRendererFactory,
                bowlingRendererFactory: bowlingRendererFactory,
                toiletTankRendererFactory: toiletTankRendererFactory,
                bagSearchRendererFactory: bagSearchRendererFactory,
                bookmarkBoxRender: bookmarkBoxRender)
            case .chapter:
                let base = try JSONDecoder().decode(OriginalChapterSave.self, from: journal.base)
                play = try restoring(base, audio: audio, saveStore: saveStore,
                mapRendererFactory: mapRendererFactory,
                suitcaseRendererFactory: suitcaseRendererFactory,
                hangerRendererFactory: hangerRendererFactory,
                thinWireRendererFactory: thinWireRendererFactory,
                suitcaseContentsRendererFactory: suitcaseContentsRendererFactory,
                memoPullRendererFactory: memoPullRendererFactory,
                crowbarRendererFactory: crowbarRendererFactory,
                cabinetDialRendererFactory: cabinetDialRendererFactory,
                cassetteRendererFactory: cassetteRendererFactory,
                cassetteDeckRendererFactory: cassetteDeckRendererFactory,
                bowlingRendererFactory: bowlingRendererFactory,
                toiletTankRendererFactory: toiletTankRendererFactory,
                bagSearchRendererFactory: bagSearchRendererFactory)
            }
            play.stopTimer()
            if journal.origin == .walking, let session = journal.baseSession {
                try play.runner.restoreWalkingSession(session)
            }
            if journal.origin == .walking, !journal.inputs.isEmpty,
               let position = journal.baseRuntimePosition, let facing = journal.baseRuntimeFacing {
                guard position.x.isFinite, position.y.isFinite, position.z.isFinite, facing.isFinite else {
                    throw OriginalDataError.invalid("Saved walking position")
                }
                play.runner.setMapPosition(position, facing: facing)
            }
            play.prepareProgress(journal)
            play.isReplayingProgress = true
            for input in journal.inputs { play.applyProgressInput(input) }
            var restoredGame = play.runner.game
            if play.canSaveWalkingCheckpoint, let lobby = play.lobby {
                restoredGame.setMapPosition(lobby.position, facing: lobby.facing)
            }
            guard !play.replayInvalid, Data(restoredGame.bytes) == checkpoint.state,
                  restoredGame.conditionGlobalByte == checkpoint.conditionGlobalByte,
                  play.runner.program.name == journal.program, play.runner.eventIndex == journal.eventIndex,
                  play.progressPhase == journal.phase,
                  play.canSaveWalkingCheckpoint || play.runner.session == journal.session,
                  play.replaySeedIndex == [journal.jigsawSeeds.count, journal.puzzleSeeds.count],
                  play.replaySlotIndex == journal.chapterSlotReads.count,
                  play.replayWriteIndex == journal.chapterWrites.count else {
                play.stop()
                throw OriginalDataError.invalid("Saved interaction could not be restored accurately")
            }
            if let notebook = journal.notebook { play.dialogueNotebook.restore(notebook) }
            play.isReplayingProgress = false
            play.pause()
            restored = true
            return play
        }
        let game = try checkpoint.gameState()
        let catalog = try OriginalScriptCatalog.bundled()
        guard let map = OriginalMapExploration.supportedMaps[game.mapID] else {
            throw OriginalDataError.unsupported("Resume map")
        }
        let program = try catalog.loadMapProgram(chapter: game.chapter, mapID: game.mapID)
        let keywords = try OriginalKeywordTable.chapterFile(for: program.name).map {
            try OriginalKeywordTable(decoded: catalog.decodedFile($0))
        }
        // Restore the live position without rerunning arrival events or granting items again.
        var exploration = try OriginalMapExploration.bundled(mapID: game.mapID,
            previousMapID: game.previousMapID, savedGame: game)
        exploration.restoreCheckpointFacing(checkpoint.checkpointFacing)
        let renderer = try mapRendererFactory(map, nil)
        let runner = try OriginalEventRunner(program: program, game: game, keywords: keywords, deferArrival: true)
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
                                       saveStore: saveStore, restoredExploration: exploration,
                                       mapRendererFactory: mapRendererFactory,
                                       suitcaseRendererFactory: suitcaseRendererFactory,
                                       hangerRendererFactory: hangerRendererFactory,
                                       thinWireRendererFactory: thinWireRendererFactory,
                                       suitcaseContentsRendererFactory: suitcaseContentsRendererFactory,
                                       memoPullRendererFactory: memoPullRendererFactory,
                                       crowbarRendererFactory: crowbarRendererFactory,
                                       cabinetDialRendererFactory: cabinetDialRendererFactory,
                                       cassetteRendererFactory: cassetteRendererFactory,
                                       cassetteDeckRendererFactory: cassetteDeckRendererFactory,
                                       bowlingRendererFactory: bowlingRendererFactory,
                                       toiletTankRendererFactory: toiletTankRendererFactory,
                                       bagSearchRendererFactory: bagSearchRendererFactory,
                                       bookmarkBoxRender: bookmarkBoxRender)
        play.lobbyRenderer = renderer
        play.lobbyMap = renderer.map
        try play.renderLobby()
        if let sequence = checkpoint.musicSequenceID { try? audio.playOriginalSequence(id: sequence) }
        play.prepareProgress(OriginalPlayProgress(origin: .walking, base: try JSONEncoder().encode(checkpoint)))
        return play
    }

    /**
     * Restores a native chapter checkpoint before the original title process.
     */
    public static func restoring(_ checkpoint: OriginalChapterSave, audio: AudioController,
                                 saveStore: any OriginalChapterSaveStore,
                                 puzzleSeed: @escaping () -> UInt32 = { UInt32.random(in: .min ... .max) },
                                 mapRendererFactory: @escaping OriginalMapRendererFactory = { try OriginalMapRenderer(mapName: $0, searchArea: $1) },
                                 suitcaseRendererFactory: @escaping OriginalSuitcaseRendererFactory = { try OriginalSuitcaseRenderer() },
                                 hangerRendererFactory: @escaping OriginalHangerRendererFactory = { try OriginalHangerRenderer() },
                                 thinWireRendererFactory: @escaping OriginalThinWireRendererFactory = { try OriginalThinWireRenderer(variant: $0) },
                                 suitcaseContentsRendererFactory: @escaping OriginalSuitcaseContentsRendererFactory = { try OriginalSuitcaseContentsRenderer() },
                                 memoPullRendererFactory: @escaping OriginalMemoPullRendererFactory = { try OriginalMemoPullRenderer() },
                                 crowbarRendererFactory: @escaping OriginalCrowbarRendererFactory = { try OriginalCrowbarRenderer(tornPaper: $0) },
                                 cabinetDialRendererFactory: @escaping OriginalCabinetDialRendererFactory = { try OriginalCabinetDialRenderer(variant: $0) },
                                 cassetteRendererFactory: OriginalCassetteRendererFactory? = nil,
                                 cassetteDeckRendererFactory: OriginalCassetteDeckRendererFactory? = nil,
                                 bowlingRendererFactory: OriginalBowlingRendererFactory? = nil,
                                 toiletTankRendererFactory: @escaping OriginalToiletTankRendererFactory = { try OriginalToiletTankRenderer() },
                                 bagSearchRendererFactory: @escaping OriginalBagSearchRendererFactory = { try OriginalBagSearchRenderer() }) throws -> OriginalPlaySession {
        let game = try checkpoint.gameState()
        let catalog = try OriginalScriptCatalog.bundled()
        guard OriginalMapExploration.supportedMaps[game.mapID] != nil else {
            throw OriginalDataError.unsupported("Chapter save map")
        }
        let program = try catalog.loadMapProgram(chapter: game.chapter, mapID: game.mapID)
        var runner = try OriginalEventRunner(program: program, game: game, deferArrival: true)
        try runner.beginChapterTitle()
        var transition = OriginalChapterTransition()
        transition.stage = .title
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog,
                                   puzzleSeed: puzzleSeed, saveStore: saveStore, chapterTransition: transition,
                                   mapRendererFactory: mapRendererFactory,
                                   suitcaseRendererFactory: suitcaseRendererFactory,
                                   hangerRendererFactory: hangerRendererFactory,
                                   thinWireRendererFactory: thinWireRendererFactory,
                                   suitcaseContentsRendererFactory: suitcaseContentsRendererFactory,
                                   memoPullRendererFactory: memoPullRendererFactory,
                                   crowbarRendererFactory: crowbarRendererFactory,
                                   cabinetDialRendererFactory: cabinetDialRendererFactory,
                                   cassetteRendererFactory: cassetteRendererFactory,
                                   cassetteDeckRendererFactory: cassetteDeckRendererFactory,
                                   bowlingRendererFactory: bowlingRendererFactory,
                                   toiletTankRendererFactory: toiletTankRendererFactory,
                                   bagSearchRendererFactory: bagSearchRendererFactory)
        play.prepareProgress(OriginalPlayProgress(origin: .chapter, base: try JSONEncoder().encode(checkpoint)))
        return play
    }

    /**
     * The chapter save decision precedes the title on both branches.
     */
    public func answerChapterSave(_ save: Bool) {
        let recordsProgress = beginProgressInput(.answerChapterSave(save: save))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition?.stage == .prompt else { return }
        if !save { return showChapterTitle() }
        do {
            chapterTransition?.slots = try progressChapterSlots()
            chapterTransition?.error = nil
            chapterTransition?.stage = .slots
        } catch { chapterTransition?.error = "The save slots could not be read: \(error)" }
    }

    public func selectChapterSaveSlot(_ slot: Int) {
        let recordsProgress = beginProgressInput(.selectChapterSaveSlot(slot: slot))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition?.stage == .slots, (0..<3).contains(slot) else { return }
        chapterTransition?.selectedSlot = slot
        chapterTransition?.error = nil
    }

    public func confirmChapterSaveSlot() {
        let recordsProgress = beginProgressInput(.confirmChapterSaveSlot)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition?.stage == .slots,
              let slot = chapterTransition?.selectedSlot else { return }
        if chapterTransition?.slots[slot] != nil { chapterTransition?.stage = .overwrite }
        else { writeChapterSave() }
    }

    public func confirmChapterOverwrite(_ overwrite: Bool) {
        let recordsProgress = beginProgressInput(.confirmChapterOverwrite(overwrite: overwrite))
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition?.stage == .overwrite else { return }
        if overwrite { writeChapterSave() }
        else { chapterTransition?.stage = .slots }
    }

    public func cancelChapterSave() {
        let recordsProgress = beginProgressInput(.cancelChapterSave)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition?.stage == .slots else { return }
        if chapterTransition?.selectedSlot != nil {
            chapterTransition?.selectedSlot = nil
            chapterTransition?.error = nil
        } else { showChapterTitle() }
    }

    private func writeChapterSave() {
        guard let slot = chapterTransition?.selectedSlot else { return }
        do {
            let checkpoint = try progressChapterWrite(slot: slot)
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
            chapterTitleImages = try OriginalChapterTitleImages(library: .bundled(), chapter: runner.game.chapter)
            try runner.beginChapterTitle()
            chapterTransition?.error = nil
            chapterTransition?.stage = .title
        } catch {
            chapterTransition = nil
            runner.halt("The chapter title could not start: \(error)")
        }
    }

    public func continueChapterTitle() {
        let recordsProgress = beginProgressInput(.continueChapterTitle)
        defer { endProgressInput(recordsProgress) }
        guard !isPaused, chapterTransition?.stage == .title else { return }
        do {
            guard OriginalMapExploration.supportedMaps[runner.game.mapID] != nil else {
                throw OriginalDataError.unsupported("Chapter map")
            }
            let program = try catalog.loadMapProgram(chapter: runner.game.chapter, mapID: runner.game.mapID)
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

extension OriginalPlaySession {
    /// Enables JSON Lines tracing for inputs, selector candidates and runner operations.
    public func enableRouteTracing(to url: URL, runID: String, checkpointName: String) throws {
        let trace = try OriginalRouteTraceLog(url: url, runID: runID, checkpointName: checkpointName)
        routeTrace = trace
        runner.attachRouteTrace(trace)
    }

    private func routeTraceFields(extra: [String: String] = [:]) -> [String: String] {
        let state = Data(runner.game.bytes)
        let inventory = (try? runner.game.inventory.items.map(String.init).joined(separator: ",")) ?? "unknown"
        return [
            "program": runner.program.name, "map": String(runner.game.mapID),
            "previousMap": String(runner.game.previousMapID), "time": String(runner.game.nowTime),
            "block": String(runner.session.selection.blockID), "mode": String(runner.session.selection.modeID),
            "scene": String(runner.session.selection.sceneID), "event": String(runner.session.selection.eventID),
            "area": String(runner.session.selection.areaID), "subarea": String(runner.session.selection.subareaID),
            "inventory": inventory, "stateSHA256": OriginalScriptCatalog.digest(state),
            "phase": progressPhase
        ].merging(extra) { _, new in new }
    }

    func enableInstantSaves() {
        usesInstantSaves = true
        progressJournal?.usesInstantSaves = true
        if let transition = chapterTransition, transition.stage != .title { showChapterTitle() }
    }

    private func prepareProgress(_ journal: OriginalPlayProgress) {
        progressJournal = journal
        usesLegacyInteractionPacing = journal.qualityOfLifeVersion == nil
        nativeNotebookPages = journal.nativeNotebookPages ?? [:]
        usesInstantSaves = journal.usesInstantSaves
        dialogueNotebook.onSaveProgress = { [weak self] _ in self?.notifyProgress() }
    }

    private var progressPhase: String {
        switch runner.phase {
        case .dialogue: return "dialogue"
        case .itemNotice(let item, _): return "item-\(item)"
        case .process(let id): return "process-\(id)"
        case .waiting(let updates): return "waiting-\(updates)"
        case .exploration(let map): return "map-\(map)"
        case .choice(let choices): return "choice-\(choices.map(\.id))"
        case .questions(let topics): return "topics-\(topics.map(\.keyword))"
        case .picture(let id): return "picture-\(id)"
        case .halted(let halt): return "halted-\(halt.reason)"
        }
    }

    private var shouldRecordProgressFrame: Bool {
        guard !isBrowsingInventory, chapterTransition == nil else { return false }
        if notebook != nil { return notebookTouch != nil }
        switch runner.phase {
        case .dialogue, .itemNotice, .questions, .choice, .halted: return false
        case .exploration where lobby != nil: return lobbyTouch != nil || firstPersonMovement != nil
        default: return true
        }
    }

    private func beginProgressInput(_ input: OriginalProgressInput) -> Bool {
        if let routeTrace {
            runner.attachRouteTrace(routeTrace)
            routeTrace.beginInput(String(describing: input))
            routeTrace.write(kind: "inputState", fields: routeTraceFields())
        }
        guard progressJournal != nil, !isReplayingProgress, !progressInputActive else { return false }
        progressInputActive = true
        if case let .frames(count, microphone) = input,
           let last = progressJournal?.inputs.last,
           case let .frames(previous, energy) = last, energy == microphone {
            let index = progressJournal!.inputs.count - 1
            progressJournal?.inputs[index] = .frames(count: previous + count, microphone: energy)
        } else {
            progressJournal?.inputs.append(input)
        }
        return true
    }

    private func endProgressInput(_ recorded: Bool) {
        if let routeTrace {
            runner.attachRouteTrace(routeTrace)
            routeTrace.write(kind: "inputComplete", fields: routeTraceFields())
        }
        guard recorded else { return }
        progressInputActive = false
        if canSaveWalkingCheckpoint, lobbyTouch == nil, firstPersonMovement == nil {
            do {
                let checkpoint = try walkingCheckpoint()
                let previous = progressJournal?.origin == .walking
                    ? try progressJournal.map { try JSONDecoder().decode(OriginalResumeSave.self, from: $0.base) } : nil
                let unchanged = previous?.state == checkpoint.state &&
                    previous?.conditionGlobalByte == checkpoint.conditionGlobalByte &&
                    previous?.checkpointFacing == checkpoint.checkpointFacing &&
                    previous?.musicSequenceID == checkpoint.musicSequenceID
                let base = unchanged ? progressJournal!.base : try JSONEncoder().encode(checkpoint)
                progressJournal = OriginalPlayProgress(origin: .walking, base: base, baseSession: runner.session,
                    baseRuntimePosition: runner.game.mapPosition, baseRuntimeFacing: runner.game.facing, usesInstantSaves: usesInstantSaves)
                usesLegacyInteractionPacing = false
            } catch { onProgressSaveError?(error) }
        }
        notifyProgress()
    }

    func progressCheckpoint() throws -> OriginalResumeSave {
        guard var journal = progressJournal else { return try walkingCheckpoint() }
        journal.notebook = dialogueNotebook.savedState()
        journal.nativeNotebookPages = nativeNotebookPages.isEmpty ? nil : nativeNotebookPages
        journal.program = runner.program.name
        journal.eventIndex = runner.eventIndex
        journal.phase = progressPhase
        journal.session = runner.session
        var game = runner.game
        if canSaveWalkingCheckpoint, let lobby { game.setMapPosition(lobby.position, facing: lobby.facing) }
        return try OriginalResumeSave(game: game, checkpointFacing: lobby?.checkpointFacing ?? game.facing,
            musicSequenceID: audio.currentSequenceID, savedAt: saveDate(), progress: journal)
    }

    private func notifyProgress() {
        guard onProgressCheckpoint != nil, !isReplayingProgress, !progressInputActive else { return }
        if case .halted = runner.phase { return }
        do {
            let checkpoint = try progressCheckpoint()
            onProgressCheckpoint?(checkpoint)
        } catch { onProgressSaveError?(error) }
    }

    private func nextProgressSeed(jigsaw: Bool) -> UInt32 {
        if isReplayingProgress {
            let slot = jigsaw ? 0 : 1
            let seeds = jigsaw ? progressJournal?.jigsawSeeds : progressJournal?.puzzleSeeds
            let index = replaySeedIndex[slot]
            guard let seeds, seeds.indices.contains(index) else { replayInvalid = true; return 0 }
            replaySeedIndex[slot] += 1
            return seeds[index]
        }
        let seed = jigsaw ? jigsawSeed() : puzzleSeed()
        if jigsaw { progressJournal?.jigsawSeeds.append(seed) }
        else { progressJournal?.puzzleSeeds.append(seed) }
        return seed
    }

    private func progressChapterSlots() throws -> [OriginalChapterSave?] {
        if isReplayingProgress {
            guard let reads = progressJournal?.chapterSlotReads, reads.indices.contains(replaySlotIndex) else {
                replayInvalid = true
                throw OriginalDataError.invalid("Missing chapter slot state")
            }
            defer { replaySlotIndex += 1 }
            return reads[replaySlotIndex]
        }
        let slots = try (0..<3).map { try saveStore.load(slot: $0) }
        progressJournal?.chapterSlotReads.append(slots)
        return slots
    }

    private struct SavedChapterWriteError: Error, CustomStringConvertible {
        let description: String
    }

    private func progressChapterWrite(slot: Int) throws -> OriginalChapterSave {
        if isReplayingProgress {
            guard let writes = progressJournal?.chapterWrites, writes.indices.contains(replayWriteIndex) else {
                replayInvalid = true
                throw OriginalDataError.invalid("Missing chapter save result")
            }
            let write = writes[replayWriteIndex]
            replayWriteIndex += 1
            if let failure = write.failure { throw SavedChapterWriteError(description: failure) }
            return try OriginalChapterSave(game: runner.game, savedAt: write.date)
        }
        let date = saveDate()
        do {
            let checkpoint = try OriginalChapterSave(game: runner.game, savedAt: date)
            try saveStore.save(checkpoint, slot: slot)
            progressJournal?.chapterWrites.append(.init(date: date, failure: nil))
            return checkpoint
        } catch {
            progressJournal?.chapterWrites.append(.init(date: date, failure: String(describing: error)))
            throw error
        }
    }
}
