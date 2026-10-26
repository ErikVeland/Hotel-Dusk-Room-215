import Foundation
import Combine

/// Owns native game data and book state above the display lifecycle.
/// Owns saves, pause reasons and the supported Chapter 1–2 route.
@MainActor
public final class GameSession: ObservableObject {
    @Published public private(set) var chapterSaves: [OriginalChapterSave?] = Array(repeating: nil, count: 3)
    @Published public private(set) var saveError: String?
    private let saveStore: any OriginalChapterSaveStore
    private let resumeStore: any OriginalResumeSaveStore
    @Published public private(set) var resumeSave: OriginalResumeSave?
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
    private var cancellables = Set<AnyCancellable>()
    private var playCancellable: AnyCancellable?
    private var animationDecoder: OriginalAnimationDecoder?

    public var animationCheckpoint: OriginalAnimationCheckpoint? { animationDecoder?.checkpoint() }

    public init(hingeManager: DuoHingeManager? = nil,
                audioController: AudioController = AudioController(),
                jigsawPuzzleManager: JigsawPuzzleManager? = nil,
                saveStore: any OriginalChapterSaveStore = OriginalChapterFileStore.application,
                resumeStore: any OriginalResumeSaveStore = OriginalResumeFileStore.application) {
        self.saveStore = saveStore
        self.resumeStore = resumeStore
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
            let next = try OriginalPlaySession.chapterOne(audio: audioController, saveStore: saveStore)
            attachPlay(next)
        } catch {
            sourceError = String(describing: error)
        }
    }

    public func endOriginalGame() {
        saveWalkingProgress()
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
            play?.stop()
            let next = try OriginalPlaySession.restoring(checkpoint, audio: audioController, saveStore: saveStore)
            saveError = nil
            attachPlay(next)
        } catch { saveError = "The saved game could not be loaded: \(error)" }
    }

    private func attachPlay(_ next: OriginalPlaySession) {
        isPauseMenuOpen = false
        isReviewingConversations = false
        playCancellable = next.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        next.onWalkingCheckpoint = { [weak self] checkpoint in self?.persist(checkpoint) }
        play = next
        saveWalkingProgress()
        updatePlayActivity()
    }

    private func persist(_ checkpoint: OriginalResumeSave) {
        guard checkpoint.state != resumeSave?.state || checkpoint.checkpointFacing != resumeSave?.checkpointFacing else { return }
        do {
            try resumeStore.save(checkpoint)
            resumeSave = checkpoint
            saveError = nil
        } catch { saveError = "Progress could not be saved: \(error)" }
    }

    public func saveWalkingProgress() {
        guard let checkpoint = try? play?.walkingCheckpoint() else { return }
        persist(checkpoint)
    }

    public func continueSavedGame() {
        do {
            guard let checkpoint = try resumeStore.load() else { return }
            play?.stop()
            let next = try OriginalPlaySession.restoring(checkpoint, audio: audioController, saveStore: saveStore)
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
