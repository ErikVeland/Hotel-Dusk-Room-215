import Foundation
import Combine

/// Owns native game data and book state above the display lifecycle.
/// The recovered route currently reaches the start of Chapter 2.
@MainActor
public final class GameSession: ObservableObject {
    @Published public private(set) var chapterSaves: [OriginalChapterSave?] = Array(repeating: nil, count: 3)
    @Published public private(set) var saveError: String?
    private let saveStore: any OriginalChapterSaveStore
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
                saveStore: any OriginalChapterSaveStore = OriginalChapterFileStore.application) {
        self.saveStore = saveStore
        self.hingeManager = hingeManager ?? DuoHingeManager()
        self.audioController = audioController
        self.jigsawPuzzleManager = jigsawPuzzleManager ?? JigsawPuzzleManager()
        do { scriptCatalog = try OriginalScriptCatalog.bundled() }
        catch {
            scriptCatalog = nil
            sourceError = String(describing: error)
        }
        refreshChapterSaves()
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
            playCancellable = next.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
            play = next
            if isBookClosed { next.pause() }
        } catch {
            sourceError = String(describing: error)
        }
    }

    public func endOriginalGame() {
        play?.stop()
        playCancellable = nil
        play = nil
        refreshChapterSaves()
    }

    private func refreshChapterSaves() {
        saveError = nil
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
            let next = try OriginalPlaySession.restoring(checkpoint, audio: audioController, saveStore: saveStore)
            play?.stop()
            playCancellable = next.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
            play = next
            saveError = nil
            if isBookClosed { next.pause() }
        } catch { saveError = "The saved game could not be loaded: \(error)" }
    }

    private func observeFoldEvents() {
        hingeManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        jigsawPuzzleManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        hingeManager.$foldState.removeDuplicates().dropFirst()
            .sink { [weak self] state in
                guard let self else { return }
                // A closed book pauses the original update loop and audio.
                if state == .closed { self.play?.pause() } else { self.play?.resume() }
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
