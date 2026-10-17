import Foundation
import Combine

/// Core Game State Manager for the Hotel Dusk engine
@MainActor
public final class GameSession: ObservableObject {
    @Published public var currentChapter: String = "Chapter 1"
    @Published public var gameTime: String = "5:00 PM - Dec 28, 1979"
    @Published public var currentRoom: Room
    @Published public var allRooms: [Room]
    @Published public var inventory: [InventoryItem]
    @Published public var activeDialogue: DialogueNode?
    @Published public var memoNotes: [String] = []
    @Published public var suspicionLevel: Int = 0 // 0 to 3 game over
    @Published public var isGameOver: Bool = false
    @Published public var isInvestigatingCloseup: Bool = false
    @Published public var isMemoPadOpen: Bool = false
    @Published public var isJigsawPuzzleOpen: Bool = false {
        didSet {
            if !isJigsawPuzzleOpen { jigsawPuzzleManager.cancelPendingFold() }
        }
    }
    @Published public var isFloorMapOpen: Bool = false
    @Published public var isNoirFilterEnabled: Bool = true

    public let hingeManager: DuoHingeManager
    public let audioController: AudioController
    public let jigsawPuzzleManager: JigsawPuzzleManager
    /// Owned by the game, so rebuilding a page cannot reset the camera or scene.
    public let sceneManager = HotelScene3DManager()
    public let memoDraft = MemoDraft()

    public var isBookClosed: Bool { hingeManager.foldState == .closed }
    private var cancellables = Set<AnyCancellable>()

    public init(
        hingeManager: DuoHingeManager? = nil,
        audioController: AudioController = AudioController(),
        jigsawPuzzleManager: JigsawPuzzleManager? = nil,
        assetLoader: AssetLoader = AssetLoader.shared
    ) {
        self.hingeManager = hingeManager ?? DuoHingeManager()
        self.audioController = audioController
        self.jigsawPuzzleManager = jigsawPuzzleManager ?? JigsawPuzzleManager()

        let rooms = assetLoader.loadDefaultRooms()
        self.allRooms = rooms
        self.currentRoom = rooms.first ?? Room(
            id: "room_215",
            name: "Room 215",
            floor: 2,
            description: "Room 215",
            availableItems: [],
            connections: []
        )
        self.inventory = assetLoader.loadDefaultItems()

        startIntroDialogue()
        observeFoldEvents()
    }

    /// Routes physical fold events (real hinge or simulated) to the open fold puzzle.
    /// A closed-to-open transition turns the assembled jigsaw over, including a partial opening.
    private func observeFoldEvents() {
        // SwiftUI does not observe nested ObservableObjects. Views hold `session`,
        // so republish hinge changes to make the layout react to posture.
        hingeManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        jigsawPuzzleManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        hingeManager.$foldState
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] state in
                guard let self, self.isJigsawPuzzleOpen else { return }
                if state == .closed {
                    self.jigsawPuzzleManager.onDeviceFoldedShut()
                } else {
                    self.jigsawPuzzleManager.onDeviceReopened()
                }
            }
            .store(in: &cancellables)
    }

    public func navigateTo(roomId: String) {
        guard let target = allRooms.first(where: { $0.id == roomId }) else { return }
        self.currentRoom = target
        self.audioController.playSFX(name: "footstep.wav")

        switch roomId {
        case "room_219":
            currentChapter = "Chapter 3"
            gameTime = "6:20 PM - Dec 28, 1979"
            activeDialogue = nil
        case "room_215":
            startIntroDialogue()
        case "hallway_2f":
            activeDialogue = DialogueNode(
                id: "hallway_talk",
                speaker: "Louis DeNonno",
                text: "Yo! Kyle! What're you doing skulking around out here in the hallway?",
                choices: [
                    DialogueChoice(prompt: "None of your business, Louie.", targetNodeId: "louie_defensive", triggersSuspicion: true),
                    DialogueChoice(prompt: "Just stretching my legs.", targetNodeId: "louie_friendly")
                ],
                isInterrogationQuestion: true
            )
        case "front_desk":
            activeDialogue = DialogueNode(
                id: "dunning_talk",
                speaker: "Dunning Smith",
                text: "You need something, Hyde? Don't go poking your nose where it don't belong.",
                choices: [
                    DialogueChoice(prompt: "Who else is staying on the 2nd floor?", targetNodeId: "dunning_guests"),
                    DialogueChoice(prompt: "Just checking in.", targetNodeId: "dunning_ok")
                ]
            )
        case "lobby_1f":
            activeDialogue = DialogueNode(
                id: "lobby_look",
                speaker: "Kyle Hyde",
                text: "The lobby is empty. An old Wurlitzer jukebox sits silently in the corner.",
                choices: [
                    DialogueChoice(prompt: "Head to the Front Desk", targetNodeId: "go_front_desk")
                ]
            )
        case "bar_1f":
            activeDialogue = nil
        case "restaurant_1f":
            activeDialogue = DialogueNode(
                id: "restaurant_look",
                speaker: "Rosa Fox",
                text: "Oh, Mr. Hyde! Dinner won't be ready until 7:00 PM. Mind your manners until then!",
                choices: [
                    DialogueChoice(prompt: "Have you seen a girl with a white dress?", targetNodeId: "rosa_mila"),
                    DialogueChoice(prompt: "Excuse me, Rosa.", targetNodeId: "return_lobby")
                ]
            )
        case "boiler_room", "wine_cellar":
            activeDialogue = nil
        default:
            break
        }
    }

    public func startIntroDialogue() {
        self.activeDialogue = DialogueNode(
            id: "intro_01",
            speaker: "Kyle Hyde",
            text: "Room 215. The wish room, huh? Guess someone thought giving me this room was hilarious.",
            choices: [
                DialogueChoice(prompt: "Check the rotary telephone", targetNodeId: "phone_01"),
                DialogueChoice(prompt: "Head out to the hallway", targetNodeId: "hallway_01")
            ]
        )
    }

    public func selectChoice(_ choice: DialogueChoice) {
        audioController.playSFX(name: "page_turn.wav")

        if choice.triggersSuspicion {
            suspicionLevel += 1
            if suspicionLevel >= 3 {
                isGameOver = true
                return
            }
        }

        switch choice.targetNodeId {
        case "phone_01":
            activeDialogue = DialogueNode(
                id: "phone_01",
                speaker: "Kyle Hyde",
                text: "Vintage black rotary phone. Silence on the line. I'm supposed to call Rachel later tonight.",
                choices: [
                    DialogueChoice(prompt: "Hang up", targetNodeId: "intro_01")
                ]
            )
        case "hallway_01":
            navigateTo(roomId: "hallway_2f")
        case "louie_defensive":
            activeDialogue = DialogueNode(
                id: "louie_defensive",
                speaker: "Louis DeNonno",
                text: "Whoa, chill out man! You're giving me that cop glare again...",
                choices: [DialogueChoice(prompt: "Back to Room 215", targetNodeId: "return_215")]
            )
        case "louie_friendly":
            activeDialogue = DialogueNode(
                id: "louie_friendly",
                speaker: "Louis DeNonno",
                text: "Haha, yeah right. Hotel Dusk doesn't have much room to stretch anything. Catch you later, pal.",
                choices: [DialogueChoice(prompt: "Back to Room 215", targetNodeId: "return_215")]
            )
        case "dunning_guests":
            activeDialogue = DialogueNode(
                id: "dunning_guests",
                speaker: "Dunning Smith",
                text: "None of your concern, salesman. Mind your own samples.",
                choices: [DialogueChoice(prompt: "Understood.", targetNodeId: "return_lobby")]
            )
        case "dunning_ok":
            activeDialogue = DialogueNode(
                id: "dunning_ok",
                speaker: "Dunning Smith",
                text: "Hmph. Keep it down up there. Don't want no complaints.",
                choices: [DialogueChoice(prompt: "Step away", targetNodeId: "return_lobby")]
            )
        case "go_front_desk":
            navigateTo(roomId: "front_desk")
        case "rosa_mila":
            activeDialogue = DialogueNode(
                id: "rosa_mila",
                speaker: "Rosa Fox",
                text: "You mean Mila? Poor dear can't speak a word. Dunning found her wandering near the highway.",
                choices: [DialogueChoice(prompt: "Thank you, Rosa.", targetNodeId: "return_lobby")]
            )
        case "return_lobby":
            navigateTo(roomId: "lobby_1f")
        case "return_215":
            navigateTo(roomId: "room_215")
        default:
            startIntroDialogue()
        }
    }

    public func addMemoNote(_ note: String) {
        guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        memoNotes.append(note)
        audioController.playSFX(name: "pencil_scratch.wav")
    }

}
