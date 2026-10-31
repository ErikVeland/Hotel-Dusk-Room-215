import Foundation

enum OriginalProgressInput: Codable, Equatable, Sendable {
    case frames(count: Int, microphone: UInt32)
    case receiveJigsawFold(isClosed: Bool)
    case cancelPendingJigsawFold
    case receiveCPRFold(isClosed: Bool, isFullyOpen: Bool)
    case advanceDialogue
    case beginInventoryBrowsing
    case endInventoryBrowsing
    case choose(id: UInt16)
    case interrupt
    case ask(keyword: Int16)
    case leaveConversation
    case showItemInConversation(item: UInt8)
    case openNotebook
    case closeNotebook
    case turnNotebookPage(forward: Bool)
    case clearNotebookPage
    case setNativeNotebookInk(page: Int, drawing: Data, packed: Data)
    case undoNotebookEdit
    case toggleNotebookEraser
    case holdNotebookTouch(x: Int, y: Int)
    case releaseNotebook
    case touchEntrance(pageX: Int, pageY: Int)
    case touchCodeNotice(pageX: Int, pageY: Int)
    case touchNumberSeal(pageX: Int, pageY: Int)
    case vendingMachine(action: OriginalVendingMachineProcess.Action)
    case touchVSScene
    case tapTypewriter(pageX: Int, pageY: Int)
    case adjustTypewriterShift(amount: Int)
    case quitTypewriter
    case tapPencilSharpener(pageX: Int, pageY: Int)
    case holdPencilSharpenerTouch(pageX: Int, pageY: Int)
    case releasePencilSharpenerTouch
    case holdTouch(pageX: Int, pageY: Int)
    case releaseTouch
    case holdBrickWallTouch(x: Float, y: Float)
    case releaseBrickWallTouch
    case leaveBrickWall
    case holdBowlingTouch(pageX: Float, pageY: Float)
    case releaseBowlingTouch
    case dragJigsaw(pageX: Float, pageY: Float)
    case releaseJigsaw
    case rotateJigsaw(increasing: Bool)
    case quitJigsaw
    case holdSuitcaseTouch(x: Float, y: Float)
    case releaseSuitcaseTouch
    case holdCassetteTouch(pageX: Int, pageY: Int)
    case releaseCassetteTouch
    case touchApplePainting(pageX: Int, pageY: Int)
    case moveApplePaintingCamera(horizontalSteps: Int, verticalSteps: Int)
    case acknowledgeApplePaintingLetter
    case selectAppleWordLetter(index: Int)
    case activateCassetteDeckControl
    case exitCassetteDeck
    case loungeTV(action: OriginalLoungeTVProcess.Action)
    case quitSuitcaseKey
    case holdThinWireTouch(x: Float, y: Float)
    case holdFountainPenTouch(x: Float, y: Float)
    case releaseFountainPenTouch
    case quitFountainPen
    case holdDifferencesTouch(x: Float, y: Float)
    case releaseDifferencesTouch
    case clearDifferences
    case quitDifferences
    case holdToiletTankTouch(x: Float, y: Float)
    case releaseToiletTankTouch
    case quitToiletTank
    case holdLinenWagonTouch(x: Float, y: Float)
    case releaseLinenWagonTouch
    case quitLinenWagon
    case holdMatchsticksTouch(x: Float, y: Float)
    case releaseMatchsticksTouch
    case quitMatchsticks
    case resetMatchsticks
    case holdCoinPuzzleTouch(x: Float, y: Float)
    case releaseCoinPuzzleTouch
    case quitCoinPuzzle
    case selectJukeboxRecord(record: Int)
    case quitJukebox
    case checkCoinPuzzle
    case holdDollRepairTouch(x: Float, y: Float)
    case releaseDollRepairTouch
    case quitDollRepair
    case holdBookmarkBoxTouch(x: Float, y: Float)
    case releaseBookmarkBoxTouch
    case quitBookmarkBox
    case holdSwitchboardTouch(x: Float, y: Float)
    case releaseSwitchboardTouch
    case quitSwitchboard
    case holdLabelPeelTouch(x: Float, y: Float)
    case releaseLabelPeelTouch
    case holdPicturePeelTouch(x: Float, y: Float)
    case releasePicturePeelTouch
    case quitPicturePeel
    case openChristmasTreeMenu
    case holdChristmasTreeTouch(x: Float, y: Float)
    case releaseChristmasTreeTouch(x: Float, y: Float)
    case cancelChristmasTreeTouch
    case holdSearchShedTouch(x: Float, y: Float)
    case releaseSearchShedTouch
    case openSearchShedMenu
    case openSearchShedTreeBox
    case holdBagSearchTouch(x: Float, y: Float)
    case releaseBagSearchTouch
    case cancelBagSearchTouch
    case openBagSearchMenu
    case releaseThinWireTouch
    case quitThinWire
    case holdPaperclipTouch(x: Float, y: Float)
    case holdHangerTouch(x: Float, y: Float)
    case releaseHangerTouch
    case holdSuitcaseContentsTouch(x: Float, y: Float)
    case releaseSuitcaseContentsTouch
    case leaveSuitcaseContents
    case quitHanger
    case releasePaperclipTouch
    case holdCabinetDialTouch(x: Float, y: Float)
    case releaseCabinetDialTouch
    case quitCabinetDial
    case holdCrowbarTouch(x: Float, y: Float)
    case releaseCrowbarTouch
    case quitCrowbar
    case holdMemoPullTouch(x: Float, y: Float)
    case releaseMemoPullTouch
    case holdMemoDrawingTouch(x: Float, y: Float)
    case releaseMemoDrawingTouch
    case clearMemoDrawing
    case quitMemoDrawing
    case quitMemoPull
    case quitPaperclip
    case touchPicture(pageX: Int, pageY: Int)
    case activatePicture(pageX: Int, pageY: Int)
    case releasePicture
    case pause
    case resume
    case holdLobbyTouch(x: Float, y: Float)
    case holdFirstPersonMovement(strafe: Float, forward: Float)
    case turnFirstPerson(radians: Float)
    case finishFirstPersonLook
    case releaseLobbyTouch
    case inspectNearbyDoor
    case selectDoorComponent(x: Int, y: Int, confirmImmediately: Bool)
    case useItemAtDoor(item: UInt8?)
    case confirmDoorComponent
    case leaveDoor
    case talkToNearbyPerson
    case inspectLobbyCounter
    case panLobbyCounter(value: Float)
    case leaveLobbyCounter
    case selectLobbyObject(x: Float, y: Float, confirmImmediately: Bool)
    case selectLobbyRoomObject(x: Float, y: Float)
    case useItemInSearchView(item: UInt8?)
    case confirmLobbyObject
    case selectCloseupComponent(x: Int, y: Int, confirmImmediately: Bool)
    case useItemInCloseup(item: UInt8?)
    case confirmCloseupComponent
    case leaveSearchCloseup
    case answerChapterSave(save: Bool)
    case selectChapterSaveSlot(slot: Int)
    case confirmChapterSaveSlot
    case confirmChapterOverwrite(overwrite: Bool)
    case cancelChapterSave
    case continueChapterTitle
}

struct OriginalPlayProgress: Codable, Equatable, Sendable {
    struct ChapterWrite: Codable, Equatable, Sendable {
        let date: Date
        let failure: String?
    }
    enum Origin: String, Codable, Sendable { case arrival, walking, chapter }
    var origin: Origin
    var base: Data
    var baseSession: OriginalEventSession?
    var baseRuntimePosition: SIMD3<Float>?
    var baseRuntimeFacing: Float?
    var usesInstantSaves = false
    var qualityOfLifeVersion: Int? = 1
    var timestamp: Int64 = 0
    var inputs: [OriginalProgressInput] = []
    var jigsawSeeds: [UInt32] = []
    var puzzleSeeds: [UInt32] = []
    var chapterSlotReads: [[OriginalChapterSave?]] = []
    var chapterWrites: [ChapterWrite] = []
    var notebook: DialogueNotebook.SavedState?
    var nativeNotebookPages: [String: Data]?
    var program = ""
    var eventIndex: Int?
    var phase = ""
    var session: OriginalEventSession?

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    func validate() throws {
        guard qualityOfLifeVersion == nil || qualityOfLifeVersion == 1 else {
            throw OriginalDataError.unsupported("Interaction presentation version")
        }
        guard inputs.count <= 1_000_000, base.count < 16_000_000,
              (nativeNotebookPages?.count ?? 0) <= 3,
              nativeNotebookPages?.allSatisfy({ ["0", "1", "2"].contains($0.key) && $0.value.count <= 8_000_000 }) ?? true else {
            throw OriginalDataError.invalid("Interaction progress size")
        }
        var frames = 0
        for input in inputs {
            if case let .frames(count, microphone) = input {
                guard count > 0, count <= 1_000_000, microphone <= 32767 else {
                    throw OriginalDataError.invalid("Interaction update count")
                }
                frames += count
            }
        }
        guard frames <= 1_000_000 else { throw OriginalDataError.invalid("Interaction duration") }
        if origin == .walking {
            let checkpoint = try JSONDecoder().decode(OriginalResumeSave.self, from: base)
            guard checkpoint.version == 1 else { throw OriginalDataError.invalid("Interaction base") }
            _ = try checkpoint.gameState()
        } else if origin == .chapter {
            _ = try JSONDecoder().decode(OriginalChapterSave.self, from: base).gameState()
        }
        if let notebook {
            let length = notebook.ink.reduce(0) { $0 + ($1.text as NSString).length }
            guard (0...length).contains(notebook.readingAnchor), (0...length).contains(notebook.revealedEnd) else {
                throw OriginalDataError.invalid("Saved reading position")
            }
            for offset in [notebook.retraceEnd, notebook.furthestRevealedEnd,
                           notebook.reviewPassageEnd, notebook.reviewRevealedEnd].compactMap({ $0 }) {
                guard (0...length).contains(offset) else {
                    throw OriginalDataError.invalid("Saved dialogue position")
                }
            }
            if let review = notebook.reviewAnchor, !(0...length).contains(review) {
                throw OriginalDataError.invalid("Saved conversation bookmark")
            }
        }
    }
}

extension OriginalPlaySession {
    func applyProgressInput(_ input: OriginalProgressInput) {
        switch input {
        case let .receiveJigsawFold(isClosed): receiveJigsawFold(isClosed: isClosed)
        case .cancelPendingJigsawFold: cancelPendingJigsawFold()
        case let .receiveCPRFold(isClosed, isFullyOpen): receiveCPRFold(isClosed: isClosed, isFullyOpen: isFullyOpen)
        case let .frames(count, microphone):
            replayMicrophoneEnergy = microphone
            for _ in 0..<count { advanceFrame() }
        case .advanceDialogue: advanceDialogue()
        case .beginInventoryBrowsing: beginInventoryBrowsing()
        case .endInventoryBrowsing: endInventoryBrowsing()
        case let .choose(id): choose(id)
        case .interrupt: interrupt()
        case let .ask(keyword): ask(keyword)
        case .leaveConversation: leaveConversation()
        case let .showItemInConversation(item): showItemInConversation(item)
        case .openNotebook: openNotebook()
        case .closeNotebook: closeNotebook()
        case let .turnNotebookPage(forward): turnNotebookPage(forward: forward)
        case .clearNotebookPage: clearNotebookPage()
        case let .setNativeNotebookInk(page, drawing, packed): setNativeNotebookInk(page: page, drawing: drawing, packed: packed)
        case .undoNotebookEdit: undoNotebookEdit()
        case .toggleNotebookEraser: toggleNotebookEraser()
        case let .holdNotebookTouch(x, y): holdNotebookTouch(x: x, y: y)
        case .releaseNotebook: releaseNotebook()
        case let .touchEntrance(pageX, pageY): touchEntrance(pageX: pageX, pageY: pageY)
        case let .touchCodeNotice(pageX, pageY): touchCodeNotice(pageX: pageX, pageY: pageY)
        case let .touchNumberSeal(pageX, pageY): touchNumberSeal(pageX: pageX, pageY: pageY)
        case let .vendingMachine(action): vendingMachineAction(action)
        case .touchVSScene: touchVSScene()
        case let .tapTypewriter(pageX, pageY): tapTypewriter(pageX: pageX, pageY: pageY)
        case let .adjustTypewriterShift(amount): adjustTypewriterShift(by: amount)
        case .quitTypewriter: quitTypewriter()
        case let .tapPencilSharpener(pageX, pageY): tapPencilSharpener(pageX: pageX, pageY: pageY)
        case let .holdPencilSharpenerTouch(pageX, pageY):
            holdPencilSharpenerTouch(pageX: pageX, pageY: pageY)
        case .releasePencilSharpenerTouch: releasePencilSharpenerTouch()
        case let .holdTouch(pageX, pageY): holdTouch(pageX: pageX, pageY: pageY)
        case .releaseTouch: releaseTouch()
        case let .holdBrickWallTouch(x, y): holdBrickWallTouch(x: x, y: y)
        case .releaseBrickWallTouch: releaseBrickWallTouch()
        case .leaveBrickWall: leaveBrickWall()
        case let .holdBowlingTouch(pageX, pageY): holdBowlingTouch(pageX: pageX, pageY: pageY)
        case .releaseBowlingTouch: releaseBowlingTouch()
        case let .dragJigsaw(pageX, pageY): dragJigsaw(pageX: pageX, pageY: pageY)
        case .releaseJigsaw: releaseJigsaw()
        case let .rotateJigsaw(increasing): rotateJigsaw(increasing: increasing)
        case .quitJigsaw: quitJigsaw()
        case let .holdSuitcaseTouch(x, y): holdSuitcaseTouch(x: x, y: y)
        case .releaseSuitcaseTouch: releaseSuitcaseTouch()
        case let .holdCassetteTouch(pageX, pageY): holdCassetteTouch(pageX: pageX, pageY: pageY)
        case .releaseCassetteTouch: releaseCassetteTouch()
        case let .touchApplePainting(pageX, pageY): touchApplePainting(pageX: pageX, pageY: pageY)
        case let .moveApplePaintingCamera(horizontalSteps, verticalSteps): moveApplePaintingCamera(horizontalSteps: horizontalSteps, verticalSteps: verticalSteps)
        case .acknowledgeApplePaintingLetter: acknowledgeApplePaintingLetter()
        case let .selectAppleWordLetter(index): selectAppleWordLetter(at: index)
        case .activateCassetteDeckControl: activateCassetteDeckControl()
        case .exitCassetteDeck: exitCassetteDeck()
        case let .loungeTV(action): loungeTVAction(action)
        case .quitSuitcaseKey: quitSuitcaseKey()
        case let .holdThinWireTouch(x, y): holdThinWireTouch(x: x, y: y)
        case let .holdFountainPenTouch(x, y): holdFountainPenTouch(x: x, y: y)
        case .releaseFountainPenTouch: releaseFountainPenTouch()
        case .quitFountainPen: quitFountainPen()
        case let .holdDifferencesTouch(x, y): holdDifferencesTouch(x: x, y: y)
        case .releaseDifferencesTouch: releaseDifferencesTouch()
        case .clearDifferences: clearDifferences()
        case .quitDifferences: quitDifferences()
        case let .holdToiletTankTouch(x, y): holdToiletTankTouch(x: x, y: y)
        case .releaseToiletTankTouch: releaseToiletTankTouch()
        case .quitToiletTank: quitToiletTank()
        case let .holdLinenWagonTouch(x, y): holdLinenWagonTouch(x: x, y: y)
        case .releaseLinenWagonTouch: releaseLinenWagonTouch()
        case .quitLinenWagon: quitLinenWagon()
        case let .holdMatchsticksTouch(x, y): holdMatchsticksTouch(x: x, y: y)
        case .releaseMatchsticksTouch: releaseMatchsticksTouch()
        case .quitMatchsticks: quitMatchsticks()
        case .resetMatchsticks: resetMatchsticks()
        case let .holdCoinPuzzleTouch(x, y): holdCoinPuzzleTouch(x: x, y: y)
        case .releaseCoinPuzzleTouch: releaseCoinPuzzleTouch()
        case .quitCoinPuzzle: quitCoinPuzzle()
        case let .selectJukeboxRecord(record): selectJukeboxRecord(record)
        case .quitJukebox: quitJukebox()
        case .checkCoinPuzzle: checkCoinPuzzle()
        case let .holdDollRepairTouch(x, y): holdDollRepairTouch(x: x, y: y)
        case .releaseDollRepairTouch: releaseDollRepairTouch()
        case .quitDollRepair: quitDollRepair()
        case let .holdBookmarkBoxTouch(x, y): holdBookmarkBoxTouch(x: x, y: y)
        case .releaseBookmarkBoxTouch: releaseBookmarkBoxTouch()
        case .quitBookmarkBox: quitBookmarkBox()
        case let .holdSwitchboardTouch(x, y): holdSwitchboardTouch(x: x, y: y)
        case .releaseSwitchboardTouch: releaseSwitchboardTouch()
        case .quitSwitchboard: quitSwitchboard()
        case let .holdLabelPeelTouch(x, y): holdLabelPeelTouch(x: x, y: y)
        case .releaseLabelPeelTouch: releaseLabelPeelTouch()
        case let .holdPicturePeelTouch(x, y): holdPicturePeelTouch(x: x, y: y)
        case .releasePicturePeelTouch: releasePicturePeelTouch()
        case .quitPicturePeel: quitPicturePeel()
        case .openChristmasTreeMenu: openChristmasTreeMenu()
        case let .holdChristmasTreeTouch(x, y): holdChristmasTreeTouch(x: x, y: y)
        case let .releaseChristmasTreeTouch(x, y): releaseChristmasTreeTouch(x: x, y: y)
        case .cancelChristmasTreeTouch: cancelChristmasTreeTouch()
        case let .holdSearchShedTouch(x, y): holdSearchShedTouch(x: x, y: y)
        case .releaseSearchShedTouch: releaseSearchShedTouch()
        case .openSearchShedMenu: openSearchShedMenu()
        case .openSearchShedTreeBox: openSearchShedTreeBox()
        case let .holdBagSearchTouch(x, y): holdBagSearchTouch(x: x, y: y)
        case .releaseBagSearchTouch: releaseBagSearchTouch()
        case .cancelBagSearchTouch: cancelBagSearchTouch()
        case .openBagSearchMenu: openBagSearchMenu()
        case .releaseThinWireTouch: releaseThinWireTouch()
        case .quitThinWire: quitThinWire()
        case let .holdPaperclipTouch(x, y): holdPaperclipTouch(x: x, y: y)
        case let .holdHangerTouch(x, y): holdHangerTouch(x: x, y: y)
        case .releaseHangerTouch: releaseHangerTouch()
        case let .holdSuitcaseContentsTouch(x, y): holdSuitcaseContentsTouch(x: x, y: y)
        case .releaseSuitcaseContentsTouch: releaseSuitcaseContentsTouch()
        case .leaveSuitcaseContents: leaveSuitcaseContents()
        case .quitHanger: quitHanger()
        case .releasePaperclipTouch: releasePaperclipTouch()
        case let .holdCabinetDialTouch(x, y): holdCabinetDialTouch(x: x, y: y)
        case .releaseCabinetDialTouch: releaseCabinetDialTouch()
        case .quitCabinetDial: quitCabinetDial()
        case let .holdCrowbarTouch(x, y): holdCrowbarTouch(x: x, y: y)
        case .releaseCrowbarTouch: releaseCrowbarTouch()
        case .quitCrowbar: quitCrowbar()
        case let .holdMemoPullTouch(x, y): holdMemoPullTouch(x: x, y: y)
        case .releaseMemoPullTouch: releaseMemoPullTouch()
        case let .holdMemoDrawingTouch(x, y): holdMemoDrawingTouch(x: x, y: y)
        case .releaseMemoDrawingTouch: releaseMemoDrawingTouch()
        case .clearMemoDrawing: clearMemoDrawing()
        case .quitMemoDrawing: quitMemoDrawing()
        case .quitMemoPull: quitMemoPull()
        case .quitPaperclip: quitPaperclip()
        case let .touchPicture(pageX, pageY): touchPicture(pageX: pageX, pageY: pageY)
        case let .activatePicture(pageX, pageY): activatePicture(pageX: pageX, pageY: pageY)
        case .releasePicture: releasePicture()
        case .pause: pause()
        case .resume: resume()
        case let .holdLobbyTouch(x, y): holdLobbyTouch(x: x, y: y)
        case let .holdFirstPersonMovement(strafe, forward): holdFirstPersonMovement(strafe: strafe, forward: forward)
        case let .turnFirstPerson(radians): turnFirstPerson(by: radians)
        case .finishFirstPersonLook: finishFirstPersonLook()
        case .releaseLobbyTouch: releaseLobbyTouch()
        case .inspectNearbyDoor: inspectNearbyDoor()
        case let .selectDoorComponent(x, y, confirmImmediately): selectDoorComponent(x: x, y: y, confirmImmediately: confirmImmediately)
        case let .useItemAtDoor(item): useItemAtDoor(item)
        case .confirmDoorComponent: confirmDoorComponent()
        case .leaveDoor: leaveDoor()
        case .talkToNearbyPerson: talkToNearbyPerson()
        case .inspectLobbyCounter: inspectLobbyCounter()
        case let .panLobbyCounter(value): panLobbyCounter(value)
        case .leaveLobbyCounter: leaveLobbyCounter()
        case let .selectLobbyObject(x, y, confirmImmediately): selectLobbyObject(x: x, y: y, confirmImmediately: confirmImmediately)
        case let .selectLobbyRoomObject(x, y): selectLobbyRoomObject(x: x, y: y)
        case let .useItemInSearchView(item): useItemInSearchView(item)
        case .confirmLobbyObject: confirmLobbyObject()
        case let .selectCloseupComponent(x, y, confirmImmediately): selectCloseupComponent(x: x, y: y, confirmImmediately: confirmImmediately)
        case let .useItemInCloseup(item): useItemInCloseup(item)
        case .confirmCloseupComponent: confirmCloseupComponent()
        case .leaveSearchCloseup: leaveSearchCloseup()
        case let .answerChapterSave(save): answerChapterSave(save)
        case let .selectChapterSaveSlot(slot): selectChapterSaveSlot(slot)
        case .confirmChapterSaveSlot: confirmChapterSaveSlot()
        case let .confirmChapterOverwrite(overwrite): confirmChapterOverwrite(overwrite)
        case .cancelChapterSave: cancelChapterSave()
        case .continueChapterTitle: continueChapterTitle()
        }
    }
}
