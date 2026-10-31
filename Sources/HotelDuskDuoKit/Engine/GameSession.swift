import Foundation
import Combine

/// Owns native game data and book state above the display lifecycle.
/// Owns resumable progress, chapter saves and pause reasons.
@MainActor
public final class GameSession: ObservableObject {
    @Published public private(set) var chapterSaves: [OriginalChapterSave?] = Array(repeating: nil, count: 3)
    @Published public private(set) var saveError: String?
    @Published public private(set) var recoveryNotice: String?
    private let saveStore: any OriginalChapterSaveStore
    private let resumeStore: any OriginalResumeSaveStore
    private let safePlaceStore: any OriginalResumeSaveStore
    private let mapRendererFactory: OriginalMapRendererFactory
    @Published public private(set) var resumeSave: OriginalResumeSave?
    private var safePlaceSave: OriginalResumeSave?
    private var restoringAfterStop = false
    @Published public private(set) var isPauseMenuOpen = false
    @Published public private(set) var isReviewingConversations = false
    private var isAppActive = true
    @Published public private(set) var originalProgram: OriginalScriptProgram?
    @Published public private(set) var sourceError: String?
    @Published public var memoNotes: [String] = []
    @Published public var isMemoPadOpen = false
    @Published public private(set) var animationPreview: OriginalAnimationFrame?
    @Published public private(set) var animationPreviewID: String?
    /// The active recovered route.
    @Published public private(set) var play: OriginalPlaySession?
    @Published public private(set) var graphicsRevision = 0
    @Published public var isJigsawPuzzleOpen = false {
        didSet {
            if !isJigsawPuzzleOpen { jigsawPuzzleManager.cancelPendingFold() }
        }
    }

    public let hingeManager: DuoHingeManager
    public let audioController: AudioController
    public let jigsawPuzzleManager: JigsawPuzzleManager
    public let memoDraft = MemoDraft()
    public let scriptCatalog: OriginalScriptCatalog?
    public var isBookClosed: Bool { hingeManager.foldState == .closed }
    public var canStartOriginalGame: Bool { scriptCatalog != nil }
    public var canReturnToSafePlace: Bool { play != nil && safePlaceSave != nil }
    private var cancellables = Set<AnyCancellable>()
    private var playCancellable: AnyCancellable?
    private var animationDecoder: OriginalAnimationDecoder?

    public var animationCheckpoint: OriginalAnimationCheckpoint? { animationDecoder?.checkpoint() }

    /// Refreshes book views after a display preference changes.
    public func refreshGraphics() { graphicsRevision &+= 1 }

    public init(hingeManager: DuoHingeManager? = nil,
                audioController: AudioController = AudioController(),
                jigsawPuzzleManager: JigsawPuzzleManager? = nil,
                saveStore: any OriginalChapterSaveStore = OriginalChapterFileStore.application,
                resumeStore: any OriginalResumeSaveStore = OriginalResumeFileStore.application,
                safePlaceStore: any OriginalResumeSaveStore = OriginalResumeFileStore.safePlaceApplication,
                mapRendererFactory: @escaping OriginalMapRendererFactory = { try OriginalMapRenderer(mapName: $0, searchArea: $1) }) {
        self.saveStore = saveStore
        self.resumeStore = resumeStore
        self.safePlaceStore = safePlaceStore
        self.mapRendererFactory = mapRendererFactory
        self.hingeManager = hingeManager ?? DuoHingeManager()
        self.audioController = audioController
        self.jigsawPuzzleManager = jigsawPuzzleManager ?? JigsawPuzzleManager()
        do { scriptCatalog = try OriginalScriptCatalog.bundled() }
        catch {
            scriptCatalog = nil
            sourceError = String(describing: error)
        }
        refreshChapterSaves()
        do { resumeSave = try resumeStore.load() }
        catch { saveError = "The resume checkpoint could not be read: \(error)" }
        do { safePlaceSave = try safePlaceStore.load() }
        catch { saveError = "The safe-place checkpoint could not be read: \(error)" }
        observeFoldEvents()
    }

    /// Loads verified source data for recovery. This does not start or advance
    /// an event, grant items, change chapters, or invent missing game logic.
    public func loadOriginalProgram(_ name: String) throws {
        guard let scriptCatalog else { throw OriginalDataError.missing("Script catalog") }
        originalProgram = try scriptCatalog.loadProgram(name)
    }

    /// A frame-by-frame recovery preview. The original animation clock is not
    /// yet mapped to story events, so this does not supply an invented FPS.
    public func openAnimationPreview(_ id: String) throws {
        let clip = try OriginalAnimationLibrary.bundled().load(id: id)
        var decoder = OriginalAnimationDecoder(clip: clip)
        let frame = try decoder.advance()
        animationDecoder = decoder
        animationPreview = frame
        animationPreviewID = id
    }

    public func advanceAnimationPreview() throws {
        guard !isBookClosed, var decoder = animationDecoder else { return }
        let frame = try decoder.advance()
        animationDecoder = decoder
        animationPreview = frame
    }

    public func closeAnimationPreview() {
        animationDecoder = nil
        animationPreview = nil
        animationPreviewID = nil
    }

    /// Starts a new game at the recovered hotel arrival.
    public func startOriginalGame() {
        play?.stop()
        do {
            let next = try OriginalPlaySession.chapterOne(audio: audioController, saveStore: saveStore,
                mapRendererFactory: mapRendererFactory)
            attachPlay(next)
        } catch {
            sourceError = String(describing: error)
        }
    }

    public func endOriginalGame() {
        play?.pause()
        guard saveCurrentPlace() else {
            isPauseMenuOpen = true
            return
        }
        play?.stop()
        playCancellable = nil
        play = nil
        isPauseMenuOpen = false
        isReviewingConversations = false
        refreshChapterSaves()
    }

    private func refreshChapterSaves() {
        for slot in 0..<3 {
            do { chapterSaves[slot] = try saveStore.load(slot: slot) }
            catch {
                chapterSaves[slot] = nil
                saveError = "Save slot \(slot + 1) could not be read: \(error)"
            }
        }
    }

    public func loadChapterSave(slot: Int) {
        do {
            guard let checkpoint = try saveStore.load(slot: slot) else { return }
            let next = try OriginalPlaySession.restoring(checkpoint, audio: audioController, saveStore: saveStore,
                mapRendererFactory: mapRendererFactory)
            play?.stop()
            saveError = nil
            attachPlay(next)
        } catch { saveError = "The saved game could not be loaded: \(error)" }
    }

    private func attachPlay(_ next: OriginalPlaySession) {
        next.enableInstantSaves()
        isPauseMenuOpen = false
        isReviewingConversations = next.dialogueNotebook.isReviewing
        playCancellable = next.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        next.onWalkingCheckpoint = { [weak self] checkpoint in self?.storeSafePlace(checkpoint) }
        next.onProgressCheckpoint = { [weak self] checkpoint in self?.persist(checkpoint) }
        next.onProgressSaveError = { [weak self] error in self?.saveError = "Progress could not be saved: \(error)" }
        next.onRecoverableStop = { [weak self] halt in self?.recoverFromStop(halt) }
        play = next
        if let checkpoint = try? next.walkingCheckpoint() { storeSafePlace(checkpoint) }
        saveCurrentPlace()
        updatePlayActivity()
        if case .halted(let halt) = next.runner.phase { recoverFromStop(halt) }
    }

    private func storeSafePlace(_ checkpoint: OriginalResumeSave) {
        safePlaceSave = checkpoint
        do { try safePlaceStore.save(checkpoint) }
        catch { saveError = "The safe-place checkpoint could not be saved: \(error)" }
    }

    func recoverFromStop(_ halt: OriginalEventRunner.Halt) {
        guard !restoringAfterStop else { return }
        restoringAfterStop = true
        defer { restoringAfterStop = false }
        guard let checkpoint = safePlaceSave else {
            recoveryNotice = "This interaction could not continue. Play returned to the beginning."
            startOriginalGame()
            return
        }
        do {
            let next = try OriginalPlaySession.restoring(checkpoint, audio: audioController,
                saveStore: saveStore, mapRendererFactory: mapRendererFactory)
            if case .halted(let restoreHalt) = next.runner.phase {
                throw OriginalDataError.invalid("Safe-place restore stopped at \(restoreHalt.program)")
            }
            play?.stop()
            let location = "\(halt.program)\(halt.eventIndex.map { " event \($0)" } ?? "")"
            recoveryNotice = "The \(location) interaction could not continue. Play returned to the last safe place."
            attachPlay(next)
        } catch {
            recoveryNotice = "The \(halt.program) interaction could not continue. Play returned to the beginning."
            saveError = "The safe-place checkpoint could not be restored: \(error)"
            startOriginalGame()
        }
    }

    public func dismissRecoveryNotice() { recoveryNotice = nil }

    /**
     * Leaves the active interaction and restores the most recent walking checkpoint.
     */
    public func returnToSafePlace() {
        guard isPauseMenuOpen, let checkpoint = safePlaceSave else { return }
        do {
            let next = try OriginalPlaySession.restoring(checkpoint, audio: audioController,
                saveStore: saveStore, mapRendererFactory: mapRendererFactory)
            if case .halted(let halt) = next.runner.phase {
                throw OriginalDataError.invalid("Safe-place restore stopped at \(halt.program)")
            }
            play?.stop()
            saveError = nil
            recoveryNotice = "Play returned to the last safe place. The unfinished interaction may need to be repeated."
            attachPlay(next)
        } catch {
            recoveryNotice = "The last safe place could not be restored. Play returned to the beginning."
            saveError = "The safe-place checkpoint could not be restored: \(error)"
            startOriginalGame()
        }
    }

    private func persist(_ checkpoint: OriginalResumeSave) {
        guard checkpoint.state != resumeSave?.state || checkpoint.checkpointFacing != resumeSave?.checkpointFacing ||
              checkpoint.conditionGlobalByte != resumeSave?.conditionGlobalByte ||
              checkpoint.musicSequenceID != resumeSave?.musicSequenceID ||
              checkpoint.progress != resumeSave?.progress || saveError != nil else { return }
        do {
            try resumeStore.save(checkpoint)
            resumeSave = checkpoint
            saveError = nil
        } catch { saveError = "Progress could not be saved: \(error)" }
    }

    @discardableResult
    public func saveCurrentPlace() -> Bool {
        guard let play else { return true }
        if case .halted = play.runner.phase, resumeSave != nil { return true }
        do {
            persist(try play.progressCheckpoint())
            return saveError == nil
        } catch {
            saveError = "Progress could not be saved: \(error)"
            return false
        }
    }

    @discardableResult
    public func saveWalkingProgress() -> Bool { saveCurrentPlace() }

    public func continueSavedGame() {
        do {
            guard let checkpoint = try resumeStore.load() else { return }
            let next = try OriginalPlaySession.restoring(checkpoint, audio: audioController, saveStore: saveStore,
                mapRendererFactory: mapRendererFactory)
            play?.stop()
            if let sequence = checkpoint.musicSequenceID { try? audioController.playOriginalSequence(id: sequence) }
            saveError = nil
            attachPlay(next)
            if let sequence = checkpoint.musicSequenceID { try? audioController.playOriginalSequence(id: sequence) }
            updatePlayActivity()
        } catch { saveError = "The resume checkpoint could not be loaded: \(error)" }
    }

    public func reviewConversations() {
        guard let play, play.canReviewConversations, !isPauseMenuOpen else { return }
        play.dialogueNotebook.beginReview()
        isReviewingConversations = true
        updatePlayActivity()
    }

    public func closeConversationHistory() {
        play?.dialogueNotebook.endReview()
        isReviewingConversations = false
        updatePlayActivity()
    }

    public func openPauseMenu() {
        guard play != nil else { return }
        isPauseMenuOpen = true
        updatePlayActivity()
    }

    public func closePauseMenu() {
        isPauseMenuOpen = false
        updatePlayActivity()
    }

    public func setApplicationActive(_ active: Bool) {
        isAppActive = active
        updatePlayActivity()
        if !active { saveCurrentPlace() }
    }

    private func updatePlayActivity(bookClosed: Bool? = nil) {
        if (bookClosed ?? isBookClosed) || !isAppActive || isPauseMenuOpen || isReviewingConversations { play?.pause() }
        else { play?.resume() }
    }

    private func observeFoldEvents() {
        audioController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        hingeManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        jigsawPuzzleManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        hingeManager.$foldState.removeDuplicates().dropFirst()
            .sink { [weak self] state in
                guard let self else { return }
                if state == .closed {
                    if self.isAppActive && !self.isPauseMenuOpen { self.play?.receiveJigsawFold(isClosed: true) }
                    else { self.play?.cancelPendingJigsawFold() }
                } else if !self.isPauseMenuOpen {
                    self.play?.receiveJigsawFold(isClosed: false)
                } else { self.play?.cancelPendingJigsawFold() }
                if !self.isPauseMenuOpen {
                    self.play?.receiveCPRFold(isClosed: state == .closed,
                                              isFullyOpen: state == .fullyOpen)
                }
                // A closed book pauses the original update loop and audio.
                self.updatePlayActivity(bookClosed: state == .closed)
                guard self.isJigsawPuzzleOpen else { return }
                if state == .closed { self.jigsawPuzzleManager.onDeviceFoldedShut() }
                else { self.jigsawPuzzleManager.onDeviceReopened() }
            }
            .store(in: &cancellables)
    }

    public func addMemoNote(_ note: String) {
        guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        memoNotes.append(note)
    }
}
