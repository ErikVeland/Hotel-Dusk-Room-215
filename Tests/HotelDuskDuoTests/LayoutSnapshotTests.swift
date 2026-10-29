import XCTest
import SwiftUI
#if os(macOS)
import AppKit
#endif
@testable import HotelDuskDuoKit

/// Renders the container at iPhone Duo inner-display sizes so the open layouts
/// can be checked without unfolding a simulator. Set SNAPSHOT_DIR to write PNGs.
@MainActor
final class LayoutSnapshotTests: XCTestCase {
    private final class SimulatedMusicOutput: OriginalMusicOutput {
        var outputVolume: Float = 1
        private var storedPosition: TimeInterval = 0
        private var resumedAt: TimeInterval?
        private(set) var isActive = false

        var position: TimeInterval {
            storedPosition + (resumedAt.map { ProcessInfo.processInfo.systemUptime - $0 } ?? 0)
        }

        func seek(to seconds: TimeInterval) throws {
            storedPosition = seconds
            if isActive { resumedAt = ProcessInfo.processInfo.systemUptime }
        }

        func resume() throws {
            guard !isActive else { return }
            resumedAt = ProcessInfo.processInfo.systemUptime
            isActive = true
        }

        func pause() {
            guard isActive else { return }
            storedPosition = position
            resumedAt = nil
            isActive = false
        }

        func stop() {
            pause()
            storedPosition = 0
        }
    }

    private final class BitmapMapRenderer: OriginalMapRendering {
        let map: CGImage

        init(mapName: String) throws {
            guard let image = try OriginalBitmapLibrary.bundled()
                .loadMap(path: "map/fmapscr/\(mapName).bin").makeCGImage() else {
                throw OriginalDataError.invalid("Route map image")
            }
            map = image
        }

        func render(_ state: OriginalMapExploration, game: OriginalGameState) throws -> CGImage { map }
    }

    private final class BitmapSuitcaseRenderer: OriginalSuitcaseRendering {
        private let image: CGImage

        init(image: CGImage) { self.image = image }

        func render(_ puzzle: OriginalSuitcaseKeyProcess) throws -> CGImage { image }
    }

    private final class BitmapHangerRenderer: OriginalHangerRendering {
        private let image: CGImage

        init(image: CGImage) { self.image = image }

        func render(_ puzzle: OriginalHangerProcess) throws -> CGImage { image }
    }

    private final class BitmapThinWireRenderer: OriginalThinWireRendering {
        private let image: CGImage

        init(image: CGImage) { self.image = image }

        func render(_ puzzle: OriginalThinWireProcess) throws -> CGImage { image }
    }

    private final class BitmapSuitcaseContentsRenderer: OriginalSuitcaseContentsRendering {
        let initialContents: OriginalSuitcaseContents
        private let image: CGImage

        init(image: CGImage) throws {
            self.image = image
            let bitmaps = try OriginalBitmapLibrary.bundled()
            let masks = try OriginalSuitcaseContents.lowerObjects.map { object in
                try bitmaps.loadTexture(path: "trick/searchbag/\(object.texture).bin").originalPixelData
            }
            initialContents = try OriginalSuitcaseContents(lowerHitMasks: masks)
        }

        func render(_ process: OriginalSuitcaseContentsProcess, game: OriginalGameState) throws -> CGImage { image }
    }

    private final class BitmapMemoPullRenderer: OriginalMemoPullRendering {
        private let image: CGImage

        init(image: CGImage) { self.image = image }

        func render(_ puzzle: OriginalMemoPullProcess) throws -> CGImage { image }
    }

    private final class BitmapCrowbarRenderer: OriginalCrowbarRendering {
        private let image: CGImage

        init(image: CGImage) { self.image = image }

        func render(_ puzzle: OriginalCrowbarProcess) throws -> CGImage { image }
    }

    private final class BitmapCabinetDialRenderer: OriginalCabinetDialRendering {
        private let image: CGImage

        init(image: CGImage) { self.image = image }

        func render(_ puzzle: OriginalCabinetDialProcess) throws -> CGImage { image }
    }

    func testRenderGraphicalInventoryAndItemInspection() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(2, previous: 1)
        for item: UInt16 in [1, 2, 3, 5, 6, 8, 10, 15, 18, 24, 49, 65] {
            try game.apply(.addInventory(id: item))
        }
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: game, deferArrival: true)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        let bytes = play.runner.game.bytes
        for size in [CGSize(width: 400, height: 540), CGSize(width: 270, height: 460)] {
            try capture(OriginalInventoryView(play: play, onSelect: { _ in
                XCTFail("Looking at inventory must not select an item")
            }, onClose: {}).padding(16).background(PaperSurface()), size: size,
                name: "inventory_grid_\(Int(size.width))", settlingTime: 0.1)
            try capture(ScrollView { OriginalInventoryInspection(item: 1).padding(16) }
                .background(PaperSurface()), size: size,
                name: "inventory_key_inspection_\(Int(size.width))", settlingTime: 0.1)
        }
        try capture(OriginalInventoryInspection(item: 18).padding(16).background(PaperSurface()),
            size: CGSize(width: 400, height: 540), name: "inventory_photo_inspection", settlingTime: 0.1)
        try capture(OriginalInventoryInspection(item: 51).padding(16).background(PaperSurface()),
            size: CGSize(width: 400, height: 540), name: "inventory_missing_source_picture", settlingTime: 0.1)
        XCTAssertEqual(play.runner.game.bytes, bytes)
    }

    func testRenderConversationParticipantInk() throws {
        let audio = AudioController()
        audio.isMuted = true
        let play = try OriginalPlaySession.chapterOne(audio: audio)
        defer { play.stop() }
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let book = DialogueNotebook()
        for start in [120] + Array(stride(from: 178, through: 211, by: 3)) {
            let entries = Array(program.text.entries[start..<(start + 3)])
            let tokens = try entries.flatMap { entry in
                try OriginalDialogueControl.tokens(for: entry) + [
                    OriginalDialogueToken(textIndex: entry.index, byteOffset: entry.bytes.count, kind: .glyph(10))
                ]
            }
            book.record(.itemNotice(itemID: 1, page: .init(page: 0, entries: entries, tokens: tokens)), program: program.name)
        }
        let size = CGSize(width: 951, height: 669)
        let metrics = DialogueSpreadMetrics(size: size)
        let layout = DialogueNotebookLayout(runs: book.ink, size: metrics.textSize, fontSize: 18)
        book.configure(layout)
        book.finishWriting()
        try capture(HStack(spacing: 0) {
            NotebookDialogueLeaf(play: play, notebook: book, layout: layout, metrics: metrics, pageIndex: 0)
            NotebookDialogueLeaf(play: play, notebook: book, layout: layout, metrics: metrics, pageIndex: 1)
        }, size: size, name: "conversation_participant_ink")
    }

    func testRenderWrittenDialoguePages() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = GameSession(saveStore: OriginalChapterFileStore(directory: root),
                                  resumeStore: OriginalResumeFileStore(directory: root))
        session.startOriginalGame()
        defer { session.endOriginalGame() }
        let play = try XCTUnwrap(session.play)
        for _ in 0..<10 where play.dialogueNotebook.ink.isEmpty { play.advanceDialogue() }
        XCTAssertFalse(play.dialogueNotebook.ink.isEmpty)
        let openingSize = CGSize(width: 951, height: 669)
        play.dialogueNotebook.configure(DialogueNotebookLayout(runs: play.dialogueNotebook.ink,
            size: DialogueSpreadMetrics(size: openingSize).textSize, fontSize: 18))
        play.dialogueNotebook.finishWriting()
        _ = try capture(DuoBookContainerView(session: session), size: openingSize,
                        name: "book_dialogue_opening", settlingTime: 0.15)
        session.hingeManager.toggleHandedness()
        _ = try capture(DuoBookContainerView(session: session), size: openingSize,
                        name: "book_dialogue_swapped", settlingTime: 0.15)
        // A test hosting window can report an inactive scene to the container.
        play.resume()
        for _ in 0..<20 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        play.pause()
        let book = play.dialogueNotebook
        for size in [CGSize(width: 951, height: 669), CGSize(width: 640, height: 800)] {
            let metrics = DialogueSpreadMetrics(size: size)
            let layout = DialogueNotebookLayout(runs: book.ink, size: metrics.textSize, fontSize: 18)
            book.configure(layout)
            book.finishWriting()
            XCTAssertGreaterThan(layout.pages.count, 1, "Opening text must reach the right leaf")
            _ = try capture(NotebookDialogueSpread(play: play, notebook: book), size: size,
                            name: "written_spread_\(Int(size.width))", settlingTime: 0.15)
        }
        // A compact spread exercises overflow and the curved front/reverse faces.
        let size = CGSize(width: 640, height: 480)
        let metrics = DialogueSpreadMetrics(size: size)
        let layout = DialogueNotebookLayout(runs: book.ink, size: metrics.textSize, fontSize: 18)
        book.configure(layout)
        book.finishWriting()
        XCTAssertTrue(book.reader.hasNextSpread)
        let oldIndex = book.reader.leftIndex
        func leaf(_ index: Int) -> NotebookDialogueLeaf {
            NotebookDialogueLeaf(play: play, notebook: book, layout: layout, metrics: metrics, pageIndex: index)
        }
        func snapshot(_ index: Int) throws -> CGImage {
            let renderer = ImageRenderer(content: leaf(index))
            renderer.scale = 2
            return try XCTUnwrap(renderer.cgImage)
        }
        let images = try NotebookCurlImages(left: snapshot(oldIndex), front: snapshot(oldIndex + 1), reverse: snapshot(oldIndex + 2))
        XCTAssertFalse(book.consumeTap())
        for progress in [0.25, 0.5, 0.75] {
            let view = HStack(spacing: 0) { leaf(oldIndex + 2); leaf(oldIndex + 3) }
                .overlay { DesktopNotebookCurl(images: images, pageSize: metrics.pageSize, progress: progress) }
            _ = try capture(view, size: size, name: "spread_curl_\(Int(progress * 100))")
        }
        _ = try capture(NotebookDialogueSpread(play: play, notebook: book), size: size,
                        name: "spread_curl_completed", settlingTime: 1.2)
        XCTAssertFalse(book.isTurning, "The mounted curl must complete and unlock the next spread")
        book.finishWriting()
        _ = try capture(NotebookDialogueSpread(play: play, notebook: book), size: size,
                        name: "written_next_spread", settlingTime: 0.15)
        let reverseImages = try NotebookCurlImages(left: snapshot(oldIndex + 3),
            front: snapshot(oldIndex + 2), reverse: snapshot(oldIndex + 1))
        book.turnBack()
        XCTAssertTrue(book.turnsBackward)
        for progress in [0.25, 0.5, 0.75] {
            let view = HStack(spacing: 0) { leaf(oldIndex); leaf(oldIndex + 1) }
                .overlay { DesktopNotebookCurl(images: reverseImages, pageSize: metrics.pageSize,
                                              progress: progress, backward: true) }
            _ = try capture(view, size: size, name: "spread_back_curl_\(Int(progress * 100))")
        }
        _ = try capture(NotebookDialogueSpread(play: play, notebook: book), size: size,
                        name: "spread_back_completed", settlingTime: 1.2)
        XCTAssertFalse(book.isTurning)
        XCTAssertEqual(book.reader.leftIndex, oldIndex)
    }

    func testRenderNoirNotebookExploration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = GameSession(saveStore: OriginalChapterFileStore(directory: root),
                                  resumeStore: OriginalResumeFileStore(directory: root))
        session.startOriginalGame()
        defer { session.endOriginalGame() }
        let play = try XCTUnwrap(session.play)
        for _ in 0..<20 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        for _ in 0..<900 {
            guard case .process(56) = play.runner.phase else { break }
            if play.entrance?.awaitingHandle == true { play.touchEntrance(pageX: 92, pageY: 175) }
            play.advanceFrame()
        }
        for _ in 0..<10 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        play.pause()
        for size in [CGSize(width: 951, height: 669), CGSize(width: 640, height: 800), CGSize(width: 768, height: 600)] {
            let view = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(view, size: size, name: "noir_lobby_\(Int(size.width))"))
        }
    }

    func testPlayableTitleAndPauseMenuFitDuoPages() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = AudioController(musicOutputFactory: { _, _, _ in SimulatedMusicOutput() })
        audio.isMuted = true
        let session = GameSession(audioController: audio, saveStore: OriginalChapterFileStore(directory: root),
                                  resumeStore: OriginalResumeFileStore(directory: root))
        for size in [CGSize(width: 768, height: 600), CGSize(width: 640, height: 800)] {
            _ = try capture(DuoBookContainerView(session: session).frame(width: size.width, height: size.height),
                            size: size, name: "playable_title_\(Int(size.width))")
        }
        session.startOriginalGame()
        defer { session.endOriginalGame() }
        session.openPauseMenu()
        for size in [CGSize(width: 768, height: 600), CGSize(width: 640, height: 800)] {
            _ = try capture(DuoBookContainerView(session: session).frame(width: size.width, height: size.height),
                            size: size, name: "playable_pause_\(Int(size.width))")
        }
    }

    func testRenderPlayableLobbyAndRingBellThroughSession() throws {
        try runChapterOneRoute(completeDunningQuestions: false)
    }

    func testRenderRequiredDunningQuestionsAndDeliveryKnock() throws {
        try runChapterOneRoute(completeDunningQuestions: true)
    }

    private func runChapterOneRoute(completeDunningQuestions: Bool) throws {
        let audio = AudioController(musicOutputFactory: { _, _, _ in SimulatedMusicOutput() })
        audio.isMuted = true
        _ = try audio.applyOriginalCommand(.disableNewEffects(true))
        let runner = try OriginalEventRunner.chapterOneArrival(catalog: .bundled(), defaults: .bundled())
        let routeImage = try BitmapMapRenderer(mapName: "R102").map
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: try .bundled(),
                                       jigsawSeed: { 0x3DEAC027 }, mapRendererFactory: { mapName, _ in
                                           try BitmapMapRenderer(mapName: mapName)
                                       }, suitcaseRendererFactory: { BitmapSuitcaseRenderer(image: routeImage) },
                                       hangerRendererFactory: { BitmapHangerRenderer(image: routeImage) },
                                       thinWireRendererFactory: { _ in BitmapThinWireRenderer(image: routeImage) },
                                       suitcaseContentsRendererFactory: { try BitmapSuitcaseContentsRenderer(image: routeImage) },
                                       memoPullRendererFactory: { BitmapMemoPullRenderer(image: routeImage) },
                                       crowbarRendererFactory: { _ in BitmapCrowbarRenderer(image: routeImage) },
                                       cabinetDialRendererFactory: { _ in BitmapCabinetDialRenderer(image: routeImage) })
        var walkingSaves: [String: OriginalResumeSave] = [:]
        play.onWalkingCheckpoint = { checkpoint in
            guard let game = try? checkpoint.gameState() else { return }
            walkingSaves["\(game.chapter)-\(game.mapID)"] = checkpoint
        }
        defer { play.stop() }
        for _ in 0..<20 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        XCTAssertEqual(play.runner.phase, .process(id: 56))
        for _ in 0..<900 {
            guard case .process(56) = play.runner.phase else { break }
            if play.entrance?.awaitingHandle == true { play.touchEntrance(pageX: 92, pageY: 175) }
            play.advanceFrame()
        }
        for _ in 0..<10 {
            guard case .dialogue = play.runner.phase else { break }
            play.advanceDialogue()
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        XCTAssertNotNil(play.lobby)
        let size = CGSize(width: 768, height: 600)
        let hingeManager = DuoHingeManager()
        func pages() -> some View {
            HStack {
                ZStack {
                    Color.clear
                    OriginalPlayPage(play: play, hingeManager: hingeManager, screen: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Group {
                    switch play.runner.phase {
                    case .choice(let choices): OriginalChoiceView(play: play, choices: choices)
                    case .questions(let topics): OriginalQuestionMenuView(play: play, topics: topics)
                    default: OriginalPlayPage(play: play, hingeManager: hingeManager, screen: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }.padding(24).background(Color.white).frame(width: size.width, height: size.height)
        }
        play.pause()
        _ = try capture(pages(), size: size, name: "play_lobby_arrival")
        play.resume()
        play.holdLobbyTouch(x: 140, y: 80)
        for _ in 0..<160 { play.advanceFrame() }
        play.holdLobbyTouch(x: 70, y: 75)
        for _ in 0..<46 { play.advanceFrame() }
        let position = try XCTUnwrap(play.lobby?.position)
        play.pause()
        play.advanceFrame()
        XCTAssertEqual(play.lobby?.position, position)
        play.resume()
        play.advanceFrame()
        XCTAssertEqual(play.lobby?.position, position, "Resume must clear held movement")
        play.inspectLobbyCounter()
        XCTAssertEqual(play.lobby?.mode, .counter)
        play.panLobbyCounter(0)
        play.selectLobbyObject(x: 126, y: 195, confirmImmediately: true)
        guard case .dialogue = play.runner.phase else { return XCTFail("One tap must inspect the bell") }
        XCTAssertEqual(play.runner.eventIndex, 3)
        play.advanceDialogue()
        XCTAssertEqual(play.runner.phase, .process(id: 24))
        for _ in 0..<80 { play.advanceFrame() }
        XCTAssertEqual(play.bell?.awaitingTouch, true)
        // Quit the bell and return to the same counter camera.
        play.touchEntrance(pageX: 170, pageY: 240)
        for _ in 0..<100 { play.advanceFrame() }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(play.lobby?.mode, .counter)
        XCTAssertEqual(play.lobby?.pan, 0)
        play.selectLobbyObject(x: 126, y: 195, confirmImmediately: true)
        XCTAssertEqual(play.runner.eventIndex, 3)
        play.advanceDialogue()
        for _ in 0..<80 { play.advanceFrame() }
        play.pause()
        _ = try capture(pages(), size: size, name: "play_bell")
        play.resume()
        for _ in 0..<3 {
            play.touchEntrance(pageX: 96, pageY: 75)
            for _ in 0..<12 { play.advanceFrame() }
        }
        for _ in 0..<400 { play.advanceFrame() }
        XCTAssertEqual(play.runner.eventIndex, 7)
        guard case .dialogue = play.runner.phase else { return XCTFail("Expected Dunning's arrival") }
        var signed = false
        var collectedPictures: [UInt16] = []
        for _ in 0..<600 {
            switch play.runner.phase {
            case .dialogue where completeDunningQuestions && play.runner.interruptAvailable: play.interrupt()
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .choice(let options):
                let selected = completeDunningQuestions ? (options.first(where: { [1, 5, 6, 9].contains($0.id) }) ?? options[0]) : options[0]
                play.choose(selected.id)
            case .questions(let topics):
                if let topic = topics.first { play.ask(topic.keyword) }
                else { play.leaveConversation() }
            case .waiting: play.advanceFrame()
            case .picture(let id):
                collectedPictures.append(id)
                play.activatePicture(pageX: 96, pageY: 215)
                XCTAssertEqual(play.touchPicture?.phase, .fading)
                for _ in 0..<22 { play.advanceFrame() }
            case .process(25):
                for _ in 0..<40 { play.advanceFrame() }
                for row in [100, 140, 175, 200] {
                    play.holdTouch(pageX: 60, pageY: row)
                    play.advanceFrame()
                    play.holdTouch(pageX: 70, pageY: row)
                    play.advanceFrame()
                    play.releaseTouch()
                    for _ in 0..<300 { play.advanceFrame() }
                }
                signed = true
            case .exploration(2):
                XCTAssertTrue(signed)
                XCTAssertEqual(collectedPictures, [1, 2, 3])
                XCTAssertEqual(play.lobby?.mode, .walking)
                XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 2)
                XCTAssertEqual(play.lobby?.canInspectCounter(in: play.runner.game), false)
                play.inspectLobbyCounter()
                XCTAssertEqual(play.lobby?.mode, .walking)
                play.pause()
                play.talkToNearbyPerson()
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
                _ = try capture(pages(), size: size, name: "play_lobby_after_registration")
                play.resume()
                play.talkToNearbyPerson()
                XCTAssertEqual(play.runner.eventIndex, 50)
                XCTAssertEqual(play.runner.partner, 2)
                for _ in 0..<100 {
                    if case .dialogue = play.runner.phase { play.advanceDialogue() }
                    else if case .questions = play.runner.phase { play.leaveConversation() }
                    else { break }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
                if completeDunningQuestions { XCTAssertTrue((0...2).allSatisfy { play.runner.game.keywordUsed($0) }) }
                play.holdLobbyTouch(x: 20, y: 128)
                for _ in 0..<110 { play.advanceFrame() }
                play.holdLobbyTouch(x: 96, y: 45)
                for _ in 0..<110 {
                    guard case .exploration = play.runner.phase else { break }
                    play.advanceFrame()
                }
                XCTAssertEqual(play.runner.eventIndex, 55)
                XCTAssertEqual(try XCTUnwrap(play.lobby?.position.z), -7777, accuracy: 4)
                for _ in 0..<100 {
                    guard case .dialogue = play.runner.phase else { break }
                    play.advanceDialogue()
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
                play.holdLobbyTouch(x: 96, y: 45)
                for _ in 0..<110 {
                    guard play.runner.game.mapID == 2 else { break }
                    play.advanceFrame()
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
                XCTAssertEqual(play.runner.game.previousMapID, 2)
                XCTAssertEqual(play.lobby?.mapID, 3)
                XCTAssertEqual(play.lobby?.position, .init(28, 12288, 16679))
                XCTAssertEqual(try XCTUnwrap(play.lobby?.facing), .pi, accuracy: 0.002)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_r103_entry")
                play.resume()
                play.holdLobbyTouch(x: 96, y: 210)
                for _ in 0..<60 {
                    guard play.runner.game.mapID == 3 else { break }
                    play.advanceFrame()
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
                XCTAssertEqual(play.runner.game.previousMapID, 3)
                XCTAssertEqual(play.lobby?.position, .init(-8190, 12288, -26467))
                XCTAssertEqual(try XCTUnwrap(play.lobby?.facing), 0, accuracy: 0.002)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_r102_return")
                play.resume()
                play.holdLobbyTouch(x: 96, y: 45)
                for _ in 0..<60 {
                    guard play.runner.game.mapID == 2 else { break }
                    play.advanceFrame()
                }
                XCTAssertEqual(play.runner.game.mapID, 3)
                play.holdLobbyTouch(x: 96, y: 45)
                for _ in 0..<61 { play.advanceFrame() }
                if !completeDunningQuestions {
                    for event in 0..<3 {
                        play.holdLobbyTouch(x: 20, y: 128)
                        for _ in 0..<120 {
                            guard case .exploration = play.runner.phase else { break }
                            play.advanceFrame()
                        }
                        XCTAssertEqual(play.runner.eventIndex, event)
                        for _ in 0..<60 {
                            guard case .dialogue = play.runner.phase else { break }
                            play.advanceDialogue()
                        }
                        XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
                    }
                }
                play.holdLobbyTouch(x: 20, y: 128)
                for _ in 0..<100 {
                    guard play.runner.game.mapID == 3 else { break }
                    play.advanceFrame()
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
                XCTAssertEqual(play.runner.game.previousMapID, 3)
                XCTAssertEqual(play.lobby?.position, .init(6636, 12288, 4014))
                XCTAssertEqual(try XCTUnwrap(play.lobby?.facing), -1.572017, accuracy: 0.002)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_r117_entry")
                play.resume()
                play.holdLobbyTouch(x: 96, y: 45)
                for _ in 0..<140 {
                    guard case .exploration = play.runner.phase else { break }
                    play.advanceFrame()
                }
                XCTAssertEqual(play.runner.eventIndex, 15)
                XCTAssertEqual(play.lobby?.position, .init(6636, 12288, -7301))
                for _ in 0..<20 {
                    guard case .dialogue = play.runner.phase else { break }
                    play.advanceDialogue()
                }
                play.holdLobbyTouch(x: 96, y: 45)
                for _ in 0..<130 {
                    guard case .exploration = play.runner.phase else { break }
                    play.advanceFrame()
                }
                XCTAssertEqual(play.runner.eventIndex, 10)
                for _ in 0..<100 {
                    guard case .dialogue = play.runner.phase else { break }
                    play.advanceDialogue()
                }
                play.pause()
                _ = try capture(pages(), size: size, name: "play_r117_stairs_conversation")
                XCTAssertEqual(play.runner.eventIndex, 35)
                guard case .questions(let topics) = play.runner.phase else { return XCTFail("Expected Melissa's question menu") }
                XCTAssertEqual(topics.map(\.keyword), [8])
                play.resume()
                play.ask(8)
                for _ in 0..<100 {
                    guard case .dialogue = play.runner.phase else { break }
                    if play.runner.eventIndex == 41, play.runner.interruptAvailable {
                        play.interrupt()
                        break
                    }
                    play.advanceDialogue()
                }
                XCTAssertEqual(play.runner.eventIndex, 44)
                for _ in 0..<20 {
                    guard case .dialogue = play.runner.phase else { break }
                    play.advanceDialogue()
                }
                guard case .choice(let options) = play.runner.phase else { return XCTFail("Expected the help choice") }
                XCTAssertEqual(options.map(\.id), [23, 22])
                play.choose(22)
                for _ in 0..<100 {
                    guard case .dialogue = play.runner.phase else { break }
                    play.advanceDialogue()
                }
                XCTAssertEqual(play.runner.eventIndex, 48)
                XCTAssertEqual(play.runner.phase, .process(id: 26))
                for _ in 0..<4 { play.advanceFrame() }
                XCTAssertEqual(play.jigsaw?.placedCount, 15)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_jigsaw")
                play.resume()
                // Release a loose piece, then allow the original idle hint to run.
                play.dragJigsaw(pageX: 79, pageY: 239)
                XCTAssertEqual(play.jigsaw?.selected, 5)
                play.releaseJigsaw()
                for _ in 0..<340 { play.advanceFrame() }
                XCTAssertEqual(play.runner.program.name, "System")
                guard case .dialogue = play.runner.phase else { return XCTFail("Expected the jigsaw hint") }
                for _ in 0..<10 {
                    guard case .dialogue = play.runner.phase else { break }
                    play.advanceDialogue()
                }
                XCTAssertEqual(play.runner.program.name, "EP1_R117")
                XCTAssertEqual(play.runner.eventIndex, 48)
                for _ in 0..<32 { play.advanceFrame() }
                for index in [3, 5, 6, 9, 10] {
                    let piece = try XCTUnwrap(play.jigsaw?.pieces[index])
                    let centre = OriginalJigsawProjection.centre(piece)
                    let x = centre.x, y = centre.y
                    XCTAssertTrue((0..<192).contains(x) && (0..<256).contains(y))
                    play.dragJigsaw(pageX: x, pageY: y)
                    XCTAssertEqual(play.jigsaw?.selected, index)
                    if piece.angle != 1.5 {
                        play.releaseJigsaw()
                        for _ in 0..<2 { play.advanceFrame() }
                        play.rotateJigsaw(increasing: false)
                        for _ in 0..<20 { play.advanceFrame() }
                        play.dragJigsaw(pageX: x, pageY: y)
                    }
                    let target = OriginalJigsawProcess.target(index)
                    play.dragJigsaw(pageX: 96 + Float(target.x + 2048) / 4096 * OriginalJigsawProjection.pixelsPerUnit,
                                    pageY: 128 - (Float(target.y + 2048) / 4096 + 0.5) * OriginalJigsawProjection.pixelsPerUnit)
                    play.releaseJigsaw()
                    XCTAssertEqual(play.jigsaw?.isPlaced(index), true)
                    for _ in 0..<2 { play.advanceFrame() }
                }
                XCTAssertEqual(play.jigsaw?.placedCount, 20)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_jigsaw_complete")
                play.resume()
                for _ in 0..<250 { play.advanceFrame() }
                XCTAssertNil(play.jigsaw)
                XCTAssertEqual(play.runner.game.chapterOneJigsawMask, 0)
                XCTAssertEqual(play.runner.eventIndex, 51)
                guard case .dialogue = play.runner.phase else { return XCTFail("Expected the completed jigsaw conversation: \(play.runner.phase)") }
                for _ in 0..<200 {
                    switch play.runner.phase {
                    case .dialogue, .itemNotice: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .picture(id: 4))
                XCTAssertFalse(try play.runner.game.inventory.items.contains(3))
                play.advanceDialogue()
                XCTAssertEqual(play.runner.phase, .picture(id: 4))
                play.pause()
                _ = try capture(pages(), size: size, name: "play_dropped_piece")
                play.touchPicture(pageX: 100, pageY: 128)
                XCTAssertEqual(play.touchPicture?.selected, false)
                play.resume()
                play.touchPicture(pageX: 100, pageY: 128)
                play.releasePicture()
                XCTAssertEqual(play.touchPicture?.selected, true)
                play.touchPicture(pageX: 100, pageY: 128)
                play.releasePicture()
                for _ in 0..<22 { play.advanceFrame() }
                guard case .itemNotice(3, _) = play.runner.phase else { return XCTFail("Expected the dropped-piece item notice: \(play.runner.phase)") }
                XCTAssertTrue(try play.runner.game.inventory.items.contains(3))
                play.pause()
                _ = try capture(pages(), size: size, name: "play_dropped_piece_acquired")
                play.resume()
                for _ in 0..<200 {
                    switch play.runner.phase {
                    case .dialogue, .itemNotice: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                XCTAssertEqual(play.lobby?.mapID, 39)
                XCTAssertEqual(play.lobby?.position, .init(16449, 12288, 6766))
                play.pause()
                _ = try capture(pages(), size: size, name: "play_r213_entry")
                play.resume()
                play.holdLobbyTouch(x: 20, y: 128)
                for _ in 0..<21 { play.advanceFrame() }
                XCTAssertEqual(play.lobby?.position, .init(8784, 12288, 6766))
                XCTAssertEqual(play.runner.eventIndex, 2)
                guard case .dialogue = play.runner.phase else { return XCTFail("Expected Jeff's entrance: \(play.runner.phase)") }
                play.releaseLobbyTouch()
                var jeffChoices: [UInt16] = [], jeffTopics: [Int16] = []
                for _ in 0..<300 {
                    if case .exploration = play.runner.phase { break }
                    switch play.runner.phase {
                    case .dialogue where play.runner.interruptAvailable: play.interrupt()
                    case .dialogue, .itemNotice: play.advanceDialogue()
                    case .choice(let options):
                        let option = try XCTUnwrap(options.first)
                        jeffChoices.append(option.id)
                        play.choose(option.id)
                    case .questions(let topics):
                        if let topic = topics.first(where: { $0.keyword == 9 }) ?? topics.first {
                            jeffTopics.append(topic.keyword)
                            play.ask(topic.keyword)
                        } else { play.leaveConversation() }
                    case .waiting: play.advanceFrame()
                    default: return XCTFail("Jeff's conversation stopped: \(play.runner.phase)")
                    }
                }
                XCTAssertEqual(jeffChoices, [24, 26, 28])
                XCTAssertEqual(jeffTopics, [9, 4])
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                XCTAssertEqual(play.lobby?.position, .init(8784, 12288, 6766))
                XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 35)), true)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_jeff_complete")
                play.resume()
                play.holdLobbyTouch(x: 20, y: 128)
                for _ in 0..<233 { play.advanceFrame() }
                play.holdLobbyTouch(x: 96, y: 210)
                for _ in 0..<9 { play.advanceFrame() }
                play.releaseLobbyTouch()
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                XCTAssertEqual(play.lobby?.position, .init(-76261, 12288, 10051))
                XCTAssertEqual(play.lobby?.nearbyDoor(in: play.runner.game, table: try OriginalStateDefaults.bundled().doorTable), 31)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_door_near")
                play.resume()
                play.inspectNearbyDoor()
                XCTAssertEqual(play.runner.eventIndex, 25)
                for _ in 0..<20 { if case .dialogue = play.runner.phase { play.advanceDialogue() } }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                XCTAssertEqual(play.door?.doorID, 32)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_door")
                play.useItemAtDoor(1)
                play.selectDoorComponent(x: 160, y: 175)
                XCTAssertNil(play.door?.item)
                XCTAssertNil(play.door?.selected)
                play.resume()
                play.leaveDoor()
                XCTAssertNil(play.door)
                XCTAssertEqual(play.lobby?.position, .init(-76261, 12288, 10051))
                play.inspectNearbyDoor()
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                XCTAssertEqual(play.door?.doorID, 32)
                play.useItemAtDoor(1)
                XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 32)), true)
                play.selectDoorComponent(x: 160, y: 175, confirmImmediately: true)
                XCTAssertEqual(play.runner.eventIndex, 26)
                for _ in 0..<20 { if case .dialogue = play.runner.phase { play.advanceDialogue() } }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 32)), false)
                XCTAssertTrue(try play.runner.game.inventory.items.contains(1))
                play.selectDoorComponent(x: 160, y: 175, confirmImmediately: true)
                XCTAssertEqual(play.runner.eventIndex, 27)
                for _ in 0..<20 {
                    if play.door != nil, case .dialogue = play.runner.phase { play.advanceDialogue() }
                }
                XCTAssertNil(play.door)
                XCTAssertEqual(play.runner.program.name, "EP1_R205")
                for _ in 0..<300 {
                    switch play.runner.phase {
                    case .dialogue: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                XCTAssertEqual(play.lobby?.position, .init(7291, 12288, 16630))
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_entered")
                play.resume()
                play.holdLobbyTouch(x: 20, y: 128)
                for _ in 0..<60 { play.advanceFrame() }
                play.holdLobbyTouch(x: 96, y: 45)
                for _ in 0..<34 { play.advanceFrame() }
                play.holdLobbyTouch(x: 20, y: 128)
                for _ in 0..<110 { play.advanceFrame() }
                play.releaseLobbyTouch()
                XCTAssertEqual(play.lobby?.position, .init(-16687, 12288, 7450))
                play.inspectLobbyCounter()
                XCTAssertEqual(play.lobby?.mode, .counter)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_telephone")
                play.resume()
                play.selectLobbyObject(x: 86, y: 165)
                XCTAssertEqual(play.lobby?.selectedNode, "obj01")
                play.selectLobbyObject(x: 86, y: 165)
                XCTAssertEqual(play.runner.eventIndex, 9)
                for _ in 0..<500 {
                    switch play.runner.phase {
                    case .dialogue: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 12)), true)
                if completeDunningQuestions {
                    XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 14)), true)
                    play.selectLobbyObject(x: 86, y: 165)
                    play.selectLobbyObject(x: 86, y: 165)
                    XCTAssertEqual(play.runner.eventIndex, 10)
                    for _ in 0..<500 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                    }
                    XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 15)), true)
                }
                XCTAssertEqual(play.lobby?.mode, .counter)
                play.leaveLobbyCounter()
                XCTAssertEqual(play.lobby?.mode, .walking)
                XCTAssertEqual(play.lobby?.position, .init(-16687, 12288, 7450))
                play.holdLobbyTouch(x: 170, y: 128)
                for _ in 0..<98 { play.advanceFrame() }
                play.holdLobbyTouch(x: 96, y: 210)
                for _ in 0..<49 { play.advanceFrame() }
                play.releaseLobbyTouch()
                XCTAssertEqual(play.lobby?.position, .init(9773, 12288, 18858))
                play.inspectLobbyCounter()
                XCTAssertEqual(play.lobby?.searchAreaID, 3)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_suitcase")
                play.resume()
                play.selectLobbyObject(x: 130, y: 155)
                play.selectLobbyObject(x: 130, y: 155)
                XCTAssertEqual(play.runner.eventIndex, 16)
                for _ in 0..<100 {
                    switch play.runner.phase {
                    case .dialogue: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                play.useItemInSearchView(21)
                XCTAssertEqual(play.searchItem, 21)
                play.useItemInSearchView(nil)
                XCTAssertNil(play.searchItem)
                play.useItemInSearchView(21)
                play.selectLobbyObject(x: 130, y: 155)
                play.selectLobbyObject(x: 130, y: 155)
                XCTAssertEqual(play.runner.phase, .process(id: 37))
                XCTAssertNotNil(play.suitcaseKey)
                play.advanceFrame()
                play.advanceFrame()
                play.holdSuitcaseTouch(x: 110, y: 240)
                for _ in 0..<3 { play.advanceFrame() }
                for y in stride(from: 225, through: 95, by: -10) {
                    play.holdSuitcaseTouch(x: 100, y: Float(y))
                    for _ in 0..<8 { play.advanceFrame() }
                }
                for _ in 0..<180 { play.advanceFrame() }
                play.releaseSuitcaseTouch()
                play.advanceFrame()
                XCTAssertEqual(play.suitcaseKey?.stage, 5)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_suitcase_key_inserted")
                play.resume()
                for _ in 0..<21 {
                    play.holdSuitcaseTouch(x: 86, y: 130)
                    for _ in 0..<3 { play.advanceFrame() }
                    play.releaseSuitcaseTouch()
                    for _ in 0..<8 { play.advanceFrame() }
                }
                XCTAssertTrue(play.suitcaseKey?.isBroken == true)
                for _ in 0..<600 { play.advanceFrame() }
                XCTAssertNil(play.suitcaseKey)
                for _ in 0..<300 {
                    switch play.runner.phase {
                    case .dialogue, .itemNotice: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 13)), true)
                XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 25)), true)
                XCTAssertTrue(try play.runner.game.inventory.items.contains(29))
                XCTAssertFalse(try play.runner.game.inventory.items.contains(21))
                XCTAssertEqual(Array(play.runner.game.bytes[0..<0x1AAC]), Array(play.runner.game.bytes[0x1AAC..<0x3558]))
                if completeDunningQuestions {
                    play.leaveLobbyCounter()
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<180 {
                        guard case .exploration = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.eventIndex, 30)
                    XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 28)), true)
                    guard case .dialogue = play.runner.phase else { return XCTFail("Expected the parcel knock") }
                    for _ in 0..<3 { play.advanceDialogue() }
                    guard case .dialogue(let parcel) = play.runner.phase else { return XCTFail("Expected the parcel announcement") }
                    XCTAssertEqual(parcel.pages.first?.entries.first?.index, 751)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_room215_delivery_knock")
                    play.resume()
                    play.advanceDialogue()
                    XCTAssertEqual(play.runner.timeTransition?.clockLabel, "05:10PM")
                    XCTAssertEqual(play.runner.game.previousMapID, 0)
                    XCTAssertEqual(play.runner.game.nowTime, 0)
                    XCTAssertNotNil(play.clock)
                    for _ in 0..<240 { play.advanceFrame() }
                    XCTAssertTrue(try XCTUnwrap(play.clock).showsLabel)
                    play.pause()
                    let pausedClock = play.clock
                    for _ in 0..<30 { play.advanceFrame() }
                    XCTAssertEqual(play.clock, pausedClock)
                    _ = try capture(pages(), size: size, name: "play_room215_clock")
                    play.resume()
                    for _ in 0..<300 where play.clock != nil { play.advanceFrame() }
                    XCTAssertNil(play.clock)
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                    XCTAssertEqual(play.runner.game.nowTime, 1)
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<180 {
                        guard case .exploration = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.nearbyDoor, 39)
                    play.inspectNearbyDoor()
                    XCTAssertNil(play.door)
                    for _ in 0..<30 where play.runner.eventIndex != 32 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.eventIndex, 32)
                    guard case .dialogue = play.runner.phase else { return XCTFail("Expected Louie's arrival") }
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_room215_louie_arrival")
                    play.resume()
                    for _ in 0..<30 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .picture(id: 5))
                    play.touchPicture(pageX: 96, pageY: 155)
                    play.releasePicture()
                    XCTAssertEqual(play.touchPicture?.selected, true)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_louie_parcel_selected")
                    play.resume()
                    play.touchPicture(pageX: 96, pageY: 155)
                    play.releasePicture()
                    for _ in 0..<24 { play.advanceFrame() }
                    guard case .dialogue = play.runner.phase else { return XCTFail("Expected the parcel handover dialogue") }
                    for _ in 0..<50 {
                        if play.runner.interruptAvailable { play.interrupt(); break }
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    for _ in 0..<20 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    guard case .choice(let louieChoices) = play.runner.phase else { return XCTFail("Expected Louie's voice choices: \(play.runner.phase)") }
                    XCTAssertEqual(louieChoices.map(\.id), [40, 41])
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_louie_voice_choice")
                    play.resume()
                    play.choose(40)
                    for _ in 0..<50 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .picture(id: 7))
                    play.touchPicture(pageX: 120, pageY: 95)
                    play.releasePicture()
                    XCTAssertEqual(play.touchPicture?.selected, true)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_louie_chin_selected")
                    play.resume()
                    play.touchPicture(pageX: 120, pageY: 95)
                    play.releasePicture()
                    for _ in 0..<24 { play.advanceFrame() }
                    for _ in 0..<200 {
                        switch play.runner.phase {
                        case .dialogue where play.runner.interruptAvailable: play.interrupt()
                        case .dialogue: play.advanceDialogue()
                        case .choice(let choices):
                            let choice = try XCTUnwrap(choices.first { [42, 44].contains($0.id) })
                            play.choose(choice.id)
                        case .questions: break
                        default: return XCTFail("Louie's introduction stopped at \(play.runner.phase)")
                        }
                        if case .questions = play.runner.phase { break }
                    }
                    guard case .questions(let louieTopics) = play.runner.phase else { return XCTFail("Expected Louie's question menu") }
                    XCTAssertEqual(louieTopics.map(\.keyword).sorted(), [10, 12, 13])
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_louie_questions")
                    play.resume()
                    var louieAsked: [Int16] = []
                    for _ in 0..<300 {
                        switch play.runner.phase {
                        case .dialogue where play.runner.interruptAvailable: play.interrupt()
                        case .dialogue: play.advanceDialogue()
                        case .choice(let choices):
                            let choice = try XCTUnwrap(choices.first { [46, 48].contains($0.id) })
                            play.choose(choice.id)
                        case .questions(let topics):
                            if let keyword = [Int16(12), 10, 11, 13].first(where: { id in topics.contains { $0.keyword == id } }) {
                                louieAsked.append(keyword)
                                play.ask(keyword)
                            } else { play.leaveConversation() }
                        case .exploration: break
                        default: return XCTFail("Louie's answers stopped at \(play.runner.phase)")
                        }
                        if case .exploration = play.runner.phase { break }
                    }
                    XCTAssertEqual(louieAsked, [12, 10, 11, 13])
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                    XCTAssertTrue((10...13).allSatisfy { play.runner.game.keywordUsed($0) })
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_room215_after_louie")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<65 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<30 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 20, y: 210)
                    for _ in 0..<25 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
                    play.inspectLobbyCounter()
                    XCTAssertEqual(play.lobby?.mode, .counter)
                    XCTAssertEqual(play.lobby?.searchAreaID, 2)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_wrong_parcel_bed")
                    play.resume()
                    play.selectLobbyObject(x: 135, y: 170)
                    XCTAssertEqual(play.lobby?.selectedNode, "obj02")
                    play.selectLobbyObject(x: 135, y: 170)
                    for _ in 0..<20 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.closeup?.view.id, 251)
                    XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 31, index: 71)), true)
                    XCTAssertTrue(play.runner.game.objectVisible(1))
                    XCTAssertFalse(play.runner.game.objectVisible(2))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_wrong_parcel_notebook")
                    play.resume()
                    play.selectCloseupComponent(x: 95, y: 150, confirmImmediately: true)
                    XCTAssertEqual(play.runner.eventIndex, 74)
                    for _ in 0..<40 {
                        switch play.runner.phase {
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        default: break
                        }
                    }
                    XCTAssertTrue(try play.runner.game.inventory.items.contains(5))
                    XCTAssertTrue(play.runner.game.keywordAvailable(14))
                    XCTAssertEqual(play.closeupImage?.hit(pageX: 95, pageY: 150), 0)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_wrong_parcel_empty")
                    play.resume()
                    play.leaveSearchCloseup()
                    play.leaveLobbyCounter()
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<65 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<45 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<80 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.nearbyDoor, 39)
                    play.inspectNearbyDoor()
                    XCTAssertNil(play.door)
                    XCTAssertEqual(play.runner.game.mapID, 39)
                    XCTAssertEqual(play.lobby?.mapName, "R213")
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_notebook_hallway")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<18 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<250 {
                        guard case .exploration = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.eventIndex, 32)
                    for _ in 0..<20 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<150 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 20, y: 45)
                    for _ in 0..<18 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 11)
                    play.talkToNearbyPerson()
                    XCTAssertEqual(play.runner.eventIndex, 34)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_melissa_conversation")
                    play.resume()
                    var melissaChoices: [UInt16] = []
                    var melissaQuestions: [Int16] = []
                    for _ in 0..<500 {
                        switch play.runner.phase {
                        case .dialogue where play.runner.interruptAvailable: play.interrupt()
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        case .choice(let options):
                            guard let choice = options.first(where: { [31, 33].contains($0.id) }) else {
                                return XCTFail("Unexpected Melissa choice")
                            }
                            melissaChoices.append(choice.id)
                            play.choose(choice.id)
                        case .questions(let topics):
                            guard let topic = topics.first(where: { [15, 16].contains($0.keyword) }) else {
                                return XCTFail("Expected Melissa's next question")
                            }
                            melissaQuestions.append(topic.keyword)
                            play.ask(topic.keyword)
                        case .picture: break
                        default: return XCTFail("Melissa's conversation stopped at \(play.runner.phase)")
                        }
                        if case .picture = play.runner.phase { break }
                    }
                    XCTAssertEqual(melissaChoices, [31, 33])
                    XCTAssertEqual(melissaQuestions, [15, 16])
                    XCTAssertEqual(play.runner.phase, .picture(id: 22))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_melissa_notebook")
                    play.resume()
                    play.touchPicture(pageX: 96, pageY: 225)
                    play.releasePicture()
                    XCTAssertEqual(play.touchPicture?.selected, true)
                    play.touchPicture(pageX: 96, pageY: 225)
                    play.releasePicture()
                    for _ in 0..<24 { play.advanceFrame() }
                    for _ in 0..<30 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    XCTAssertEqual(play.runner.game.bytes[0x87B] & 1, 1)
                    XCTAssertTrue(try play.runner.game.inventory.items.contains(3))
                    play.talkToNearbyPerson()
                    for _ in 0..<20 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .questions([]))
                    play.pause()
                    _ = try capture(OriginalQuestionMenuView(play: play, topics: [])
                        .padding(24).frame(width: size.width / 2, height: size.height)
                        .background(Color.white), size: CGSize(width: size.width / 2, height: size.height),
                        name: "play_melissa_piece_return_menu")
                    play.resume()
                    play.showItemInConversation(3)
                    XCTAssertEqual(play.runner.eventIndex, 50)
                    for _ in 0..<40 {
                        switch play.runner.phase {
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                        if case .questions = play.runner.phase { break }
                    }
                    XCTAssertEqual(play.runner.phase, .questions([]))
                    XCTAssertFalse(try play.runner.game.inventory.items.contains(3))
                    play.openNotebook()
                    XCTAssertEqual(play.notebook?.pageCount, 4)
                    XCTAssertEqual(play.runner.game.bytes[0x87D], 0)
                    for _ in 0..<3 { play.turnNotebookPage(forward: true) }
                    XCTAssertEqual(play.notebook?.page, 3)
                    XCTAssertEqual(play.notebook?.canEdit, false)
                    XCTAssertNotNil(play.notebookImage)
                    let memoPhase = play.runner.phase
                    play.leaveConversation()
                    XCTAssertEqual(play.runner.phase, memoPhase, "The notebook retains its parent conversation")
                    play.pause()
                    play.turnNotebookPage(forward: true)
                    XCTAssertEqual(play.notebook?.page, 3)
                    _ = try capture(pages(), size: size, name: "play_melissa_drawing")
                    play.resume()
                    play.closeNotebook()
                    XCTAssertNil(play.notebook)
                    XCTAssertEqual(play.runner.phase, memoPhase)
                    play.leaveConversation()
                    for _ in 0..<100 {
                        switch play.runner.phase {
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                        if case .exploration = play.runner.phase { break }
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 39, index: 55)), true)
                    XCTAssertNil(play.runner.game.personMarker(11))
                    play.openNotebook()
                    XCTAssertEqual(play.notebook?.page, 0)
                    play.holdNotebookTouch(x: 100, y: 100)
                    for _ in 0..<3 { play.advanceFrame() }
                    play.holdNotebookTouch(x: 100, y: 120)
                    for _ in 0..<3 { play.advanceFrame() }
                    play.releaseNotebook()
                    let ink = play.notebook?.pixels
                    XCTAssertTrue(ink?.contains(1) == true)
                    play.closeNotebook()
                    play.openNotebook()
                    XCTAssertEqual(play.notebook?.pixels, ink)
                    play.clearNotebookPage()
                    play.closeNotebook()
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_melissa_departure")
                    play.resume()
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<200 {
                        if (play.lobby?.position.x ?? 0) <= 21000 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<160 {
                        if play.lobby?.mapID != 39 { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
                    XCTAssertEqual(play.lobby?.mapID, 17)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_after_melissa_downstairs")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<120 {
                        if (play.lobby?.position.z ?? 0) >= 4500 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<160 {
                        if play.lobby?.mapID != 17 { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
                    XCTAssertEqual(play.lobby?.mapID, 3)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_after_melissa_r103")
                    play.resume()
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<100 {
                        if (play.lobby?.position.x ?? -1) >= 0 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<160 {
                        if play.lobby?.mapID != 3 { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
                    XCTAssertEqual(play.lobby?.mapID, 2)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_mila_lobby_return")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<20 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<150 {
                        guard case .exploration = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<60 {
                        guard case .exploration = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.eventIndex, 66)
                    for _ in 0..<30 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
                    XCTAssertEqual(play.lobby?.position, SIMD3(15811, 12288, -737))
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<35 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 170, y: 210)
                    for _ in 0..<14 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 5)
                    play.talkToNearbyPerson()
                    XCTAssertEqual(play.runner.eventIndex, 67)
                    for _ in 0..<40 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .picture(id: 24))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_mila_shoulder")
                    play.resume()
                    play.touchPicture(pageX: 96, pageY: 225)
                    play.releasePicture()
                    XCTAssertEqual(play.touchPicture?.selected, true)
                    play.touchPicture(pageX: 96, pageY: 225)
                    play.releasePicture()
                    for _ in 0..<24 { play.advanceFrame() }
                    for _ in 0..<100 {
                        switch play.runner.phase {
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                        if case .exploration = play.runner.phase { break }
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
                    XCTAssertEqual(play.runner.game.personMarker(3), 203)
                    XCTAssertEqual(play.lobby?.position, SIMD3(15811, 12288, 17285))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_rosa_introduction")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<30 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 3)
                    play.talkToNearbyPerson()
                    XCTAssertEqual(play.runner.eventIndex, 70)
                    var rosaChoices: [UInt16] = []
                    var rosaQuestions: [Int16] = []
                    for _ in 0..<500 {
                        switch play.runner.phase {
                        case .dialogue where play.runner.interruptAvailable: play.interrupt()
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        case .choice(let options):
                            guard let choice = options.first(where: { [10, 13].contains($0.id) }) else {
                                return XCTFail("Unexpected Rosa choice")
                            }
                            rosaChoices.append(choice.id)
                            play.choose(choice.id)
                        case .questions(let topics):
                            guard let keyword = [Int16(21), 22, 23, 14].first(where: { keyword in topics.contains { $0.keyword == keyword } }) else {
                                return XCTFail("Expected Rosa's next question")
                            }
                            rosaQuestions.append(keyword)
                            play.ask(keyword)
                        case .process(126): break
                        default: return XCTFail("Rosa's conversation stopped at \(play.runner.phase)")
                        }
                        if case .process(126) = play.runner.phase { break }
                    }
                    XCTAssertEqual(rosaChoices, [10, 13])
                    XCTAssertEqual(rosaQuestions, [21, 22, 23, 14])
                    XCTAssertEqual(play.runner.phase, .process(id: 126))
                    for _ in 0..<2000 {
                        guard case .process(126) = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    for _ in 0..<30 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
                    XCTAssertEqual(play.runner.game.nowTime, 2)
                    XCTAssertNil(play.runner.game.personMarker(3))
                    XCTAssertNil(play.runner.game.personMarker(5))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_rosa_departure_520")
                    play.resume()
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<100 {
                        if (play.lobby?.position.x ?? 0) <= -8000 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<200 {
                        guard play.lobby?.mapID == 2 else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<62 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<130 {
                        guard play.lobby?.mapID == 3 else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<160 {
                        guard play.lobby?.mapID == 17 else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<40 {
                        guard case .exploration = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.eventIndex, 62)
                    for _ in 0..<10 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<80 {
                        if (play.lobby?.position.x ?? 0) <= -14500 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<9 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.nearbyDoor, 29)
                    play.inspectNearbyDoor()
                    XCTAssertEqual(play.door?.destination, 29)
                    XCTAssertEqual(play.door?.area, 5)
                    XCTAssertEqual(play.door?.view.id, 333)
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_jeff_room213_door")
                    play.resume()
                    play.selectDoorComponent(x: 96, y: 125)
                    XCTAssertEqual(play.door?.selected, 1)
                    play.selectDoorComponent(x: 96, y: 125)
                    XCTAssertEqual(play.runner.eventIndex, 76)
                    var jeffQuestions: [Int16] = []
                    var jeffChoices: [UInt16] = []
                    for _ in 0..<200 {
                        switch play.runner.phase {
                        case .dialogue where play.runner.interruptAvailable: play.interrupt()
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        case .questions(let topics):
                            guard let keyword = [Int16(26), 27].first(where: { keyword in topics.contains { $0.keyword == keyword } }) else {
                                return XCTFail("Expected Jeff's next Mila question")
                            }
                            jeffQuestions.append(keyword)
                            play.ask(keyword)
                        case .choice(let choices):
                            guard choices.contains(where: { $0.id == 36 }) else { return XCTFail("Expected Jeff's request choice") }
                            jeffChoices.append(36)
                            play.choose(36)
                        case .exploration: break
                        default: return XCTFail("Jeff's return conversation stopped at \(play.runner.phase)")
                        }
                        if case .exploration = play.runner.phase { break }
                    }
                    XCTAssertEqual(jeffQuestions, [26, 27])
                    XCTAssertEqual(jeffChoices, [36])
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    XCTAssertNil(play.door)
                    XCTAssertTrue(play.runner.game.keywordAsked(27, person: 6))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_jeff_room213_departure")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<25 {
                        if (play.lobby?.position.z ?? 0) <= 6500 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<200 {
                        guard case .exploration = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.eventIndex, 63)
                    for _ in 0..<100 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                        if case .questions = play.runner.phase { break }
                    }
                    guard case .questions(let irisTopics) = play.runner.phase else { return XCTFail("Expected Iris's question menu") }
                    XCTAssertEqual(irisTopics.map(\.keyword), [24])
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_iris_question")
                    play.resume()
                    play.ask(24)
                    for _ in 0..<100 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                        if case .choice = play.runner.phase { break }
                    }
                    guard case .choice(let irisChoices) = play.runner.phase else { return XCTFail("Expected Iris's work question") }
                    XCTAssertEqual(irisChoices.map(\.id), [34, 35])
                    play.choose(34)
                    for _ in 0..<300 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                        if case .exploration = play.runner.phase { break }
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    XCTAssertTrue(play.runner.game.keywordAsked(24, person: 9))
                    XCTAssertTrue(play.runner.game.keywordAvailable(25))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_iris_louie_departure")
                    play.resume()
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<100 {
                        if (play.lobby?.position.x ?? 0) <= -77400 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<9 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.nearbyDoor, 31)
                    play.inspectNearbyDoor()
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<40 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<120 {
                        guard case .exploration = play.runner.phase else { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.eventIndex, 78)
                    for _ in 0..<20 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                    XCTAssertTrue(play.runner.game.value(for: .eventFlag(group: 31, index: 78)) == true)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_summer_delivery_knock")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<120 {
                        if (play.lobby?.position.z ?? 0) <= -12000 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<70 {
                        if (play.lobby?.position.x ?? 0) >= 9800 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<14 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.nearbyDoor, 39)
                    play.inspectNearbyDoor()
                    var summerChoices: [UInt16] = []
                    var summerQuestions: [Int16] = []
                    var summerInterrupts: Set<UInt16> = []
                    for _ in 0..<500 {
                        switch play.runner.phase {
                        case .dialogue where play.runner.interruptAvailable && !summerInterrupts.contains(play.runner.interrupt.event):
                            summerInterrupts.insert(play.runner.interrupt.event)
                            play.interrupt()
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        case .choice(let choices):
                            guard let choice = choices.first(where: { [UInt16(52), 55, 57, 58].contains($0.id) }) else {
                                return XCTFail("Expected Summer's next guide answer")
                            }
                            summerChoices.append(choice.id)
                            play.choose(choice.id)
                        case .questions(let topics):
                            guard let keyword = [Int16(29), 30].first(where: { keyword in topics.contains { $0.keyword == keyword } }) else {
                                return XCTFail("Expected Summer's next question")
                            }
                            summerQuestions.append(keyword)
                            play.ask(keyword)
                        case .picture: break
                        default: return XCTFail("Summer's conversation stopped at \(play.runner.phase)")
                        }
                        if case .picture = play.runner.phase { break }
                    }
                    XCTAssertEqual(summerChoices, [52, 55, 57, 58])
                    XCTAssertEqual(summerInterrupts, [89, 92])
                    XCTAssertEqual(summerQuestions, [29, 30])
                    XCTAssertEqual(play.runner.phase, .picture(id: 6))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_summer_parcel")
                    play.resume()
                    play.touchPicture(pageX: 30, pageY: 100)
                    play.releasePicture()
                    XCTAssertEqual(play.touchPicture?.selected, true)
                    play.touchPicture(pageX: 30, pageY: 100)
                    play.releasePicture()
                    for _ in 0..<24 { play.advanceFrame() }
                    for _ in 0..<100 {
                        switch play.runner.phase {
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                        if case .exploration = play.runner.phase { break }
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                    XCTAssertFalse(try play.runner.game.inventory.items.contains(5))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_summer_departure")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<65 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<30 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 20, y: 210)
                    for _ in 0..<120 {
                        if play.lobby?.nearbySearchArea == 2 { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
                    play.inspectLobbyCounter()
                    play.selectLobbyObject(x: 55, y: 195)
                    XCTAssertEqual(play.lobby?.selectedNode, "obj03")
                    play.selectLobbyObject(x: 55, y: 195)
                    for _ in 0..<20 {
                        guard case .dialogue = play.runner.phase else { break }
                        play.advanceDialogue()
                    }
                    XCTAssertEqual(play.closeup?.view.id, 253)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_order_parcel_contents")
                    play.resume()
                    play.selectCloseupComponent(x: 65, y: 135)
                    play.selectCloseupComponent(x: 65, y: 135)
                    for _ in 0..<40 {
                        switch play.runner.phase {
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        default: break
                        }
                    }
                    XCTAssertTrue(try play.runner.game.inventory.items.contains(49))
                    play.selectCloseupComponent(x: 161, y: 219)
                    play.selectCloseupComponent(x: 161, y: 219)
                    XCTAssertEqual(play.runner.eventIndex, 118)
                    for _ in 0..<40 {
                        switch play.runner.phase {
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        default: break
                        }
                    }
                    XCTAssertTrue(try play.runner.game.inventory.items.contains(6))
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_order_documents_collected")
                    play.resume()
                    play.leaveSearchCloseup()
                    play.leaveLobbyCounter()
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<80 {
                        if (play.lobby?.position.z ?? 0) <= 7450 { break }
                        play.advanceFrame()
                    }
                    play.holdLobbyTouch(x: 20, y: 128)
                    for _ in 0..<100 {
                        if play.lobby?.nearbySearchArea == 1 { break }
                        play.advanceFrame()
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
                    play.inspectLobbyCounter()
                    play.selectLobbyObject(x: 86, y: 165)
                    play.selectLobbyObject(x: 86, y: 165)
                    XCTAssertEqual(play.runner.eventIndex, 121)
                    for _ in 0..<500 {
                        switch play.runner.phase {
                        case .dialogue, .itemNotice: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                    }
                    guard case .choice(let firstReview) = play.runner.phase else { return XCTFail("Expected the first chapter review question") }
                    XCTAssertEqual(firstReview.map(\.id), [60, 61, 62])
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_one_review_first")
                    play.resume()
                    for answer: UInt16 in [61, 63, 68, 70] {
                        play.choose(answer)
                        for _ in 0..<200 {
                            switch play.runner.phase {
                            case .dialogue: play.advanceDialogue()
                            case .waiting: play.advanceFrame()
                            default: break
                            }
                            if case .choice = play.runner.phase { break }
                        }
                    }
                    guard case .choice(let lastReview) = play.runner.phase else { return XCTFail("Expected the last chapter review question") }
                    XCTAssertEqual(lastReview.map(\.id), [72, 73, 74])
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_one_review_last")
                    play.resume()
                    play.choose(72)
                    for _ in 0..<200 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                    }
                    XCTAssertEqual(play.runner.reviewQuestionIndex, 5)
                    XCTAssertEqual(play.runner.processRequests.last, .init(kind: 4, value: 1))
                    XCTAssertEqual(play.chapterTransition?.stage, .prompt)
                    XCTAssertEqual(play.runner.game.chapter, 1)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_save_prompt")
                    play.resume()
                    play.answerChapterSave(false)
                    XCTAssertEqual(play.chapterTransition?.stage, .title)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_title")
                    play.resume()
                    play.continueChapterTitle()
                    XCTAssertNil(play.chapterTransition)
                    XCTAssertEqual(play.runner.program.name, "EP2_R205")
                    XCTAssertEqual(play.runner.eventIndex, 0)
                    for _ in 0..<100 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                    }
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                    XCTAssertEqual(play.lobby?.mode, .walking)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_room215")
                    play.resume()
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<114 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.nearbyDoor, 39)
                    play.inspectNearbyDoor()
                    XCTAssertEqual(play.runner.program.name, "EP2_R213")
                    play.holdLobbyTouch(x: 96, y: 45)
                    for _ in 0..<17 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<145 {
                        if case .exploration = play.runner.phase { play.advanceFrame() }
                    }
                    play.releaseLobbyTouch()
                    for _ in 0..<40 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                    }
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<85 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 3)
                    play.talkToNearbyPerson()
                    var chapterTwoRosaQuestions: [Int16] = []
                    var chapterTwoRosaAnswers: [UInt16] = []
                    var chapterTwoRosaInterrupts: Set<UInt16> = []
                    for _ in 0..<400 {
                        switch play.runner.phase {
                        case .dialogue where play.runner.interruptAvailable && !chapterTwoRosaInterrupts.contains(play.runner.interrupt.event):
                            chapterTwoRosaInterrupts.insert(play.runner.interrupt.event)
                            play.interrupt()
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        case .questions(let topics):
                            if let topic = topics.first(where: { [Int16(0), 1].contains($0.keyword) }) {
                                chapterTwoRosaQuestions.append(topic.keyword)
                                play.ask(topic.keyword)
                            } else { play.leaveConversation() }
                        case .choice(let choices):
                            guard let choice = choices.first(where: { [UInt16(1), 3, 4, 7].contains($0.id) }) else {
                                return XCTFail("Expected Rosa's Chapter 2 guide answer")
                            }
                            chapterTwoRosaAnswers.append(choice.id)
                            play.choose(choice.id)
                        case .exploration: break
                        default: return XCTFail("Rosa's Chapter 2 route stopped: \(play.runner.phase)")
                        }
                        if case .exploration = play.runner.phase { break }
                    }
                    XCTAssertEqual(chapterTwoRosaQuestions, [0, 1])
                    XCTAssertEqual(chapterTwoRosaAnswers, [1, 3, 4, 7])
                    XCTAssertEqual(chapterTwoRosaInterrupts, [4, 7, 10])
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
                    XCTAssertNil(play.runner.game.personMarker(3))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_rosa_departure")
                    play.resume()
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<125 {
                        if case .exploration = play.runner.phase { play.advanceFrame() }
                    }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.runner.eventIndex, 27)
                    for _ in 0..<200 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                    }
                    play.holdLobbyTouch(x: 170, y: 128)
                    for _ in 0..<365 { play.advanceFrame() }
                    play.holdLobbyTouch(x: 96, y: 210)
                    for _ in 0..<12 { play.advanceFrame() }
                    play.releaseLobbyTouch()
                    XCTAssertEqual(play.nearbyDoor, 37)
                    play.inspectNearbyDoor()
                    for _ in 0..<200 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                    }
                    play.selectDoorComponent(x: 158, y: 180)
                    play.confirmDoorComponent()
                    for _ in 0..<200 {
                        switch play.runner.phase {
                        case .dialogue: play.advanceDialogue()
                        case .waiting: play.advanceFrame()
                        default: break
                        }
                    }
                    XCTAssertEqual(play.runner.program.name, "EP2_R211")
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 37))
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_linens_entry")
                    play.resume()
                    try OriginalLinensRouteChecks.run(play)
                    XCTAssertEqual(play.runner.phase, .exploration(mapID: 37))
                    XCTAssertEqual(play.closeup?.view.id, 313)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_linens_complete")
                    play.resume()
                    try OriginalHelenRouteChecks.run(play)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_helen_complete")
                    play.resume()
                    try OriginalHangerRouteChecks.inspect(play)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_hanger_closeup")
                    play.resume()
                    try OriginalHangerRouteChecks.cut(play)
                    play.pause()
                    _ = try capture(pages(), size: size, name: "play_chapter_two_hanger_complete")
                    play.resume()
                    try OriginalThickWireRouteChecks.run(play)
                    XCTAssertGreaterThanOrEqual(walkingSaves.count, 10)
                    for checkpoint in walkingSaves.values {
                        let audio = AudioController(musicOutputFactory: { _, _, _ in SimulatedMusicOutput() })
                        audio.isMuted = true
                        let restored = try OriginalPlaySession.restoring(checkpoint, audio: audio,
                            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory),
                            mapRendererFactory: { mapName, _ in try BitmapMapRenderer(mapName: mapName) },
                            suitcaseRendererFactory: { BitmapSuitcaseRenderer(image: routeImage) },
                            hangerRendererFactory: { BitmapHangerRenderer(image: routeImage) },
                            thinWireRendererFactory: { _ in BitmapThinWireRenderer(image: routeImage) },
                            suitcaseContentsRendererFactory: { try BitmapSuitcaseContentsRenderer(image: routeImage) },
                            memoPullRendererFactory: { BitmapMemoPullRenderer(image: routeImage) },
                            crowbarRendererFactory: { _ in BitmapCrowbarRenderer(image: routeImage) },
                            cabinetDialRendererFactory: { _ in BitmapCabinetDialRenderer(image: routeImage) })
                        XCTAssertEqual(restored.runner.game, try checkpoint.gameState())
                        XCTAssertEqual(restored.runner.phase, .exploration(mapID: restored.runner.game.mapID))
                        XCTAssertTrue(restored.runner.eventTrail.isEmpty)
                        XCTAssertEqual(restored.lobby?.position, restored.runner.game.mapPosition)
                        XCTAssertTrue(restored.canSaveWalkingCheckpoint)
                        restored.stop()
                    }
                    return
                }
                play.leaveLobbyCounter()
                play.holdLobbyTouch(x: 96, y: 45)
                for _ in 0..<48 { play.advanceFrame() }
                play.holdLobbyTouch(x: 20, y: 128)
                for _ in 0..<98 { play.advanceFrame() }
                play.releaseLobbyTouch()
                XCTAssertEqual(play.lobby?.position, .init(-16687, 12288, 5898))
                play.inspectLobbyCounter()
                XCTAssertEqual(play.lobby?.searchAreaID, 1)
                play.selectLobbyObject(x: 133, y: 179)
                play.selectLobbyObject(x: 133, y: 179)
                for _ in 0..<300 {
                    switch play.runner.phase {
                    case .dialogue, .itemNotice: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                XCTAssertEqual(play.closeup?.view.id, 262)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_brochure")
                play.resume()
                play.selectCloseupComponent(x: 110, y: 70)
                play.selectCloseupComponent(x: 110, y: 70)
                XCTAssertEqual(play.runner.program.name, "System")
                XCTAssertEqual(play.runner.eventIndex, 929)
                for _ in 0..<300 {
                    switch play.runner.phase {
                    case .dialogue, .itemNotice: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                XCTAssertEqual(play.runner.program.name, "EP1_R205")
                XCTAssertTrue(try play.runner.game.inventory.items.contains(8))
                XCTAssertEqual(play.closeupImage?.hit(pageX: 110, pageY: 70), 0)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_paperclip_collected")
                play.resume()
                play.useItemInCloseup(8)
                XCTAssertEqual(play.runner.phase, .process(id: 28))
                for _ in 0..<65 { play.advanceFrame() }
                XCTAssertEqual(play.paperclip?.stage, 0)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_paperclip_puzzle")
                play.resume()
                let handle = OriginalPaperclipProjection.page(try XCTUnwrap(play.paperclip?.points.first))
                play.holdPaperclipTouch(x: handle.x, y: handle.y)
                play.advanceFrame()
                XCTAssertEqual(play.paperclip?.holding, true)
                let pausedPuzzle = play.paperclip
                play.pause()
                play.advanceFrame()
                XCTAssertEqual(play.paperclip, pausedPuzzle)
                play.resume()
                play.advanceFrame()
                XCTAssertEqual(play.paperclip?.holding, false, "Resume must clear the held puzzle touch")
                play.quitPaperclip()
                for _ in 0..<70 { play.advanceFrame() }
                for _ in 0..<20 { play.advanceDialogue() }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                XCTAssertNotNil(play.closeup)
                XCTAssertTrue(try play.runner.game.inventory.items.contains(8))
                XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 4)), false)
                play.useItemInCloseup(8)
                for _ in 0..<65 { play.advanceFrame() }
                let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                let commands = try String(contentsOf: root.appendingPathComponent("tools/reference/room215-paperclip-straighten.txt"), encoding: .utf8)
                for line in commands.split(separator: "\n") {
                    let fields = line.split(separator: " ")
                    if fields.first == "touch", let x = Float(fields[1]), let y = Float(fields[2]) {
                        play.holdPaperclipTouch(x: y, y: 255 - x)
                    } else if fields.first == "release" { play.releasePaperclipTouch() }
                    else if fields.first == "frames", let count = Int(fields[1]) {
                        for _ in 0..<count { play.advanceFrame() }
                    } else if fields.first == "capture", fields.count > 1 {
                        if fields[1] == "stage0" { XCTAssertEqual(play.paperclip?.stage, 2) }
                        if fields[1] == "stage2" { XCTAssertEqual(play.paperclip?.stage, 4) }
                        if fields[1] == "stage4" { XCTAssertEqual(play.paperclip?.stage, 9) }
                        play.pause()
                        _ = try capture(pages(), size: size, name: "play_room215_paperclip_\(fields[1])")
                        play.resume()
                    }
                }
                XCTAssertNil(play.paperclip)
                for _ in 0..<30 { play.advanceDialogue() }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                XCTAssertEqual(play.runner.program.name, "EP1_R205")
                XCTAssertTrue(try play.runner.game.inventory.items.contains(9))
                XCTAssertFalse(try play.runner.game.inventory.items.contains(8))
                XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 4)), true)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_wire_collected")
                play.resume()
                play.leaveSearchCloseup()
                XCTAssertNil(play.closeup)
                XCTAssertEqual(play.lobby?.mode, .counter)
                play.leaveLobbyCounter()
                play.holdLobbyTouch(x: 170, y: 128)
                for _ in 0..<98 { play.advanceFrame() }
                play.holdLobbyTouch(x: 96, y: 210)
                for _ in 0..<55 { play.advanceFrame() }
                play.releaseLobbyTouch()
                play.inspectLobbyCounter()
                XCTAssertEqual(play.lobby?.searchAreaID, 3)
                play.useItemInSearchView(9)
                play.selectLobbyObject(x: 130, y: 155)
                play.selectLobbyObject(x: 130, y: 155)
                for _ in 0..<100 {
                    switch play.runner.phase {
                    case .dialogue, .itemNotice: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .process(id: 29))
                XCTAssertNotNil(play.thinWire)
                play.advanceFrame()
                play.quitThinWire()
                for _ in 0..<180 { play.advanceFrame() }
                for _ in 0..<30 { play.advanceDialogue() }
                XCTAssertNil(play.thinWire)
                XCTAssertEqual(play.runner.program.name, "EP1_R205")
                XCTAssertEqual(play.lobby?.mode, .counter)
                XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 5)), false)
                play.useItemInSearchView(9)
                play.selectLobbyObject(x: 130, y: 155)
                play.selectLobbyObject(x: 130, y: 155)
                for _ in 0..<30 { play.advanceDialogue() }
                XCTAssertNotNil(play.thinWire)
                play.advanceFrame()
                play.advanceFrame()
                play.holdThinWireTouch(x: 110, y: 240)
                for _ in 0..<3 { play.advanceFrame() }
                XCTAssertEqual(play.thinWire?.holding, true)
                let pausedWire = play.thinWire
                play.pause()
                play.advanceFrame()
                XCTAssertEqual(play.thinWire, pausedWire)
                play.resume()
                play.advanceFrame()
                XCTAssertEqual(play.thinWire?.holding, false)
                play.pause()
                _ = try capture(pages(), size: size, name: "play_room215_thin_wire_start")
                play.resume()
                for script in ["insert", "pins"] {
                    let input = try String(contentsOf: root.appendingPathComponent("tools/reference/room215-thin-wire-\(script).txt"), encoding: .utf8)
                    for line in input.split(separator: "\n") {
                        let fields = line.split(separator: " ")
                        if fields.first == "touch", let x = Float(fields[1]), let y = Float(fields[2]) {
                            play.holdThinWireTouch(x: y, y: 255 - x)
                        } else if fields.first == "release" { play.releaseThinWireTouch() }
                        else if fields.first == "frames", let count = Int(fields[1]) {
                            for _ in 0..<count { play.advanceFrame() }
                        } else if fields.first == "capture" {
                            play.pause()
                            _ = try capture(pages(), size: size, name: "play_room215_thin_wire_\(fields[1])")
                            play.resume()
                        }
                    }
                    if script == "insert" {
                        // The native host honours the original fade durations before accepting pin input.
                        for _ in 0..<120 { play.advanceFrame() }
                        XCTAssertEqual(play.thinWire?.phase, 3)
                        XCTAssertEqual(play.thinWire?.stage, 1)
                    }
                }
                for _ in 0..<300 { play.advanceFrame() }
                XCTAssertNil(play.thinWire)
                for _ in 0..<100 {
                    switch play.runner.phase {
                    case .dialogue, .itemNotice: play.advanceDialogue()
                    case .waiting: play.advanceFrame()
                    default: break
                    }
                }
                XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
                XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 5)), true)
                XCTAssertTrue(try play.runner.game.inventory.items.contains(9))
                play.pause()
                return
            default: return XCTFail("Unexpected post-bell phase: \(play.runner.phase)")
            }
        }
        XCTFail("Registration did not return to the lobby")
    }

    func testRenderSuitcaseKeyStages() throws {
        let renderer = try OriginalSuitcaseRenderer()
        var puzzle = OriginalSuitcaseKeyProcess()
        func draw(_ name: String) throws {
            let image = try renderer.render(puzzle)
            _ = try capture(Image(decorative: image, scale: 1), size: CGSize(width: 192, height: 256), name: name)
        }
        try draw("suitcase_key_start")
        puzzle.update()
        puzzle.update()
        for _ in 0..<3 { puzzle.update(pageTouch: .init(110, 240)) }
        for y in stride(from: 225, through: 95, by: -10) {
            for _ in 0..<8 { puzzle.update(pageTouch: .init(100, Float(y))) }
        }
        for _ in 0..<180 { puzzle.update(pageTouch: .init(100, 95)) }
        puzzle.update()
        XCTAssertEqual(puzzle.stage, 5)
        try draw("suitcase_key_inserted")
        for _ in 0..<21 {
            for _ in 0..<3 { puzzle.update(pageTouch: .init(86, 130)) }
            for _ in 0..<8 { puzzle.update() }
        }
        XCTAssertTrue(puzzle.isBroken)
        try draw("suitcase_key_broken")
    }

    func testRenderInnerDisplayLayouts() throws {
        let cases: [(String, CGSize, Double, Handedness, DynamicTypeSize)] = [
            ("book_landscape", CGSize(width: 951, height: 669), 180, .rightHanded, .large),
            ("book_portrait", CGSize(width: 669, height: 951), 180, .rightHanded, .large),
            ("partly_open_book", CGSize(width: 951, height: 669), 110, .rightHanded, .large),
            ("book_left_handed", CGSize(width: 951, height: 669), 180, .leftHanded, .large),
            ("book_large_text", CGSize(width: 951, height: 669), 180, .rightHanded, .accessibility1),
            ("native_recovery", CGSize(width: 951, height: 669), 180, .rightHanded, .large),
            ("novel_notebook", CGSize(width: 951, height: 669), 180, .rightHanded, .large),
        ]
        for (name, size, angle, handedness, typeSize) in cases {
            let session = GameSession()
            if name == "novel_notebook" { session.isMemoPadOpen = true }
            session.hingeManager.setHingeAngle(angle)
            session.hingeManager.handedness = handedness
            let view = DuoBookContainerView(session: session)
                .environment(\.dynamicTypeSize, typeSize)
                .frame(width: size.width, height: size.height)
            let image = try capture(view, size: size, name: name)
            try assertPaperAtOuterEdges(image)
        }
    }

    func testRenderOriginalJigsawAssemblyAndFoldSequence() throws {
        let size = CGSize(width: 951, height: 669)
        let coverSize = CGSize(width: 420, height: 630)
        let manifest = JigsawManifest.bundled
        XCTAssertEqual(manifest.boardWidth, 192)
        XCTAssertEqual(manifest.boardHeight, 256)
        XCTAssertEqual(manifest.pieces.count, 20)
        for name in [manifest.frontImage, manifest.reverseImage, manifest.tableImage,
                     manifest.trayImage, manifest.foldTrayImage] {
            let image = try XCTUnwrap(JigsawArt.image(named: name), name)
            XCTAssertEqual(image.width, 192)
            XCTAssertEqual(image.height, 256)
        }
        for piece in manifest.pieces {
            XCTAssertNotNil(JigsawArt.image(named: piece.image), piece.image)
        }
        XCTAssertNotNil(JigsawArt.image(named: manifest.rotateLeftImage))
        XCTAssertNotNil(JigsawArt.image(named: manifest.rotateRightImage))

        for hand in Handedness.allCases {
            let suffix = hand == .rightHanded ? "right" : "left"
            let session = GameSession(hingeManager: DuoHingeManager(initialHandedness: hand))
            session.isJigsawPuzzleOpen = true
            let assembly = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(assembly, size: size, name: "jigsaw_\(suffix)_assembly"))

            assemble(session.jigsawPuzzleManager)
            XCTAssertEqual(session.jigsawPuzzleManager.phase, .assembled)
            let front = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(front, size: size, name: "jigsaw_\(suffix)_assembled"))

            session.hingeManager.receiveHardwareState(.closed, angleDegrees: 0)
            XCTAssertEqual(session.jigsawPuzzleManager.phase, .folded)
            let closed = DuoBookContainerView(session: session).frame(width: coverSize.width, height: coverSize.height)
            _ = try capture(closed, size: coverSize, name: "jigsaw_\(suffix)_closed_cover")

            session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 45)
            XCTAssertEqual(session.jigsawPuzzleManager.phase, .reverseRevealed)
            let reopened = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(reopened, size: size, name: "jigsaw_\(suffix)_revealed_45"))
        }
    }

    func testRenderJigsawWithAsymmetricSafeAreas() throws {
        let size = CGSize(width: 951, height: 669)
        for hand in Handedness.allCases {
            let session = GameSession(hingeManager: DuoHingeManager(initialHandedness: hand))
            session.isJigsawPuzzleOpen = true
            let view = ZStack {
                JigsawPuzzleView(session: session, puzzleManager: session.jigsawPuzzleManager,
                                 safeArea: EdgeInsets(top: 24, leading: 10, bottom: 34, trailing: 62))
                BookSpineView(angleDegrees: 90)
            }
            .frame(width: size.width, height: size.height)
            let suffix = hand == .rightHanded ? "right" : "left"
            let image = try capture(view, size: size, name: "jigsaw_\(suffix)_safe_areas")
            try assertPaperAtOuterEdges(image)
        }
    }

    func testRenderSpineAcrossOpeningAngles() throws {
        let size = CGSize(width: 951, height: 669)
        for angle in [30.0, 90, 180] {
            let session = GameSession()
            session.hingeManager.receiveHardwareAngle(angle)
            let view = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            let image = try capture(view, size: size, name: "book_spine_\(Int(angle))")
            try assertPaperAtOuterEdges(image)
        }
    }

    func testRenderPaperbackOnCoverDisplays() throws {
        let image = try XCTUnwrap(PaperbackCoverArt.image)
        XCTAssertEqual(image.width, 1024)
        XCTAssertEqual(image.height, 1536)
        for (name, size) in [("paperback_cover", CGSize(width: 420, height: 630)),
                             ("paperback_cover_tall", CGSize(width: 390, height: 844)),
                             ("paperback_cover_rotated", CGSize(width: 680, height: 420))] {
            let session = GameSession()
            session.hingeManager.receiveHardwareAngle(0)
            let view = DuoBookContainerView(session: session).frame(width: size.width, height: size.height)
            _ = try capture(view, size: size, name: name)
        }
    }

    func testRenderPaperMaterialAtRestAndWhileSettling() throws {
        let size = CGSize(width: 951, height: 669)
        for (name, flex) in [("paper_stock_rest", 0.0), ("paper_stock_settling", 0.4)] {
            let view = HStack(spacing: 0) {
                ForEach(0..<2) { index in
                    let side: PaperPageSide = index == 0 ? .left : .right
                    ZStack {
                        PaperSurface(side: side)
                        PaperCurvatureLight(side: side, hingeAngle: 90, flex: index == 0 ? flex : -flex)
                    }
                    .frame(width: size.width / 2, height: size.height)
                }
            }
            .overlay { BookSpineView(angleDegrees: 90) }
            .frame(width: size.width, height: size.height)
            try assertPaperAtOuterEdges(capture(view, size: size, name: name))
        }
    }

    private func assemble(_ puzzle: JigsawPuzzleManager) {
        for piece in puzzle.manifest.pieces {
            puzzle.movePiece(piece.id, to: piece.centre)
            for _ in 0..<4 {
                if puzzle.placements[piece.id]?.quarterTurns == 0 { break }
                puzzle.rotatePiece(piece.id)
            }
            XCTAssertTrue(puzzle.releasePiece(piece.id))
        }
    }

    @discardableResult
    private func capture<V: View>(_ view: V, size: CGSize, name: String, settlingTime: TimeInterval = 0) throws -> CGImage {
        let image = try snapshot(view, size: size, name: name, settlingTime: settlingTime)
        XCTAssertEqual(image.width, Int(size.width))
        XCTAssertEqual(image.height, Int(size.height))
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            let directory = URL(fileURLWithPath: dir)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(name).png")
            let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(dest))
        }
        return image
    }

    /// Paper must reach all four corners, even when the content has safe insets.
    private func assertPaperAtOuterEdges(_ image: CGImage, file: StaticString = #filePath, line: UInt = #line) throws {
        let right = CGFloat(image.width - 3)
        let bottom = CGFloat(image.height - 3)
        let points = [CGPoint(x: 2, y: 2), CGPoint(x: right, y: 2),
                      CGPoint(x: 2, y: bottom), CGPoint(x: right, y: bottom)]
        for point in points {
            let sample = try XCTUnwrap(image.cropping(to: CGRect(origin: point, size: CGSize(width: 1, height: 1))))
            let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                                  space: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let rgba = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            XCTAssertGreaterThan(rgba[0], 180, "Missing paper at \(point)", file: file, line: line)
            XCTAssertGreaterThan(rgba[1], 160, "Missing paper at \(point)", file: file, line: line)
            XCTAssertGreaterThan(rgba[2], 140, "Missing paper at \(point)", file: file, line: line)
            XCTAssertEqual(rgba[3], 255, file: file, line: line)
        }
    }

    private func snapshot<V: View>(_ view: V, size: CGSize, name: String, settlingTime: TimeInterval) throws -> CGImage {
        #if os(macOS)
        // ImageRenderer omits AppKit-backed scroll content. Host a real view so
        // previews include the dialogue, inventory and navigation rows.
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        if settlingTime > 0 {
            RunLoop.main.run(until: Date().addingTimeInterval(settlingTime))
            host.layoutSubtreeIfNeeded()
        }
        host.displayIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds), name)
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = try XCTUnwrap(bitmap.cgImage, name)
        // Native capture uses the Mac display's backing scale. Export at 1× so
        // fixture dimensions are independent of the machine running the tests.
        let context = try XCTUnwrap(CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                              bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return try XCTUnwrap(context.makeImage(), name)
        #else
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try XCTUnwrap(renderer.cgImage, name)
        #endif
    }
}
