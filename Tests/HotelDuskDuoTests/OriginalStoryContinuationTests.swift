import simd
import XCTest
import CoreGraphics
@testable import HotelDuskDuoKit

final class OriginalStoryContinuationTests: XCTestCase {
    @MainActor func testChapterNineR117PaintingReturnsFourthLetter() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-downstairs-hall-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantSaveStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r117-painting-instant"))
        var instantSaveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantSaveStore.save(checkpoint) }
            catch { instantSaveErrors.append(String(describing: error)) }
        }
        play.resume()
        let room = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(room.room.nodes.first { $0.name == "s01" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14])), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01", interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 183)
        let background = try XCTUnwrap((stride(from: 16, to: 240, by: 8).flatMap { y in
            stride(from: 16, to: 184, by: 8).map { SIMD2($0, y) }
        }).first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == 0 })
        play.selectCloseupComponent(x: background.x, y: background.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 184, interrupt: true)
        XCTAssertNotNil(play.applePainting)
        play.touchApplePainting(pageX: 119, pageY: 151)
        XCTAssertEqual(play.applePainting?.phase, .revealed("N"))
        XCTAssertTrue(instantSaveErrors.isEmpty, instantSaveErrors.joined(separator: "; "))
        let revealed = try XCTUnwrap(try instantSaveStore.load(), "The R117 letter must save immediately")
        XCTAssertEqual(revealed.progress, try play.progressCheckpoint().progress)
        let resumed = try OriginalPlaySession.restoring(revealed, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.applePainting?.phase, .revealed("N"))
        resumed.acknowledgeApplePaintingLetter()
        XCTAssertEqual(resumed.runner.game.applePaintingFoundMask, (1 << 4) | (1 << 3) | (1 << 1) | (1 << 2))
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        XCTAssertNotNil(resumed.closeup, "The map event request waits for the painting close-up to close")
        resumed.leaveSearchCloseup()
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        XCTAssertEqual(resumed.runner.game.nowTime, 1)
        XCTAssertTrue(resumed.runner.eventTrail.contains(2), "The fourth painting must take its source return-0 path")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r117-fourth-letter")).save(try resumed.progressCheckpoint())
    }

    @MainActor func testChapterNineReturnsToTheLobbyAfterTheFourthLetter() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r117-fourth-letter")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.applePaintingFoundMask, (1 << 4) | (1 << 3) | (1 << 1) | (1 << 2))
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 3)
        XCTAssertEqual(play.runner.game.nowTime, 1)
        XCTAssertEqual(play.runner.game.personMarker(4), 305, "R103 arrival must place Louie in the lobby")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-louie-arrival")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterNineLouieTopicsAdvanceTheStory() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-louie-arrival")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [0, 1, 2])
        XCTAssertEqual(play.runner.game.mapID, 3)
        XCTAssertEqual(play.runner.game.nowTime, 2)
        XCTAssertTrue(play.runner.eventTrail.contains(14), "Dunning must interrupt after Louie's three topics")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-louie-topics")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterNineReachesRosasRoomAndResumesInstantly() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-louie-topics")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r118-instant"))
        var saveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantStore.save(checkpoint) }
            catch { saveErrors.append(String(describing: error)) }
        }
        play.resume()
        try OriginalChapterThreeRouteChecks.exit(play, to: 18, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 18)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 18))
        XCTAssertTrue(saveErrors.isEmpty, saveErrors.joined(separator: "; "))
        let instant = try XCTUnwrap(try instantStore.load(), "R118 arrival must save immediately")
        XCTAssertEqual(instant.progress, try play.progressCheckpoint().progress)
        let resumed = try OriginalPlaySession.restoring(instant, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 18))
        XCTAssertEqual(resumed.runner.game.nowTime, 2)
        try OriginalChapterThreeRouteChecks.exit(resumed, to: 13, interrupt: true, expectArrival: false)
        XCTAssertEqual(resumed.runner.game.mapID, 18)
        XCTAssertEqual(resumed.door?.view.id, 195)
        XCTAssertEqual(resumed.runner.game.value(for: .doorOpen(index: 46)), false)
        try OriginalChapterThreeRouteChecks.doorComponent(resumed, 1, interrupt: true)
        XCTAssertEqual(resumed.runner.game.mapID, 13)
        XCTAssertEqual(resumed.runner.program.name, "EP9_R113")
        XCTAssertNotNil(resumed.lobby?.people(in: resumed.runner.game).first { $0.id == 3 }, "Rosa must be in the hallway")
        try OriginalChapterThreeRouteChecks.talk(resumed, to: 3, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(resumed, answers: [], topics: [0])
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 13))
        XCTAssertEqual(resumed.runner.game.nowTime, 2)
        try OriginalChapterThreeRouteChecks.talk(resumed, to: 3, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(resumed, answers: [], topics: [3])
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 13))
        XCTAssertEqual(resumed.runner.game.personMarker(3), 1601)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-rosa-special-room")).save(try resumed.progressCheckpoint())
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r113-entry")).save(try resumed.progressCheckpoint())
    }

    @MainActor func testChapterNineReturnsTheKeyAndFindsTheFifthPainting() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-rosa-special-room")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        for destination: Int16 in [18, 39] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
            XCTAssertEqual(play.runner.game.mapID, destination)
        }
        let stairDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 17)
        try OriginalChapterThreeRouteChecks.walk(play, to: stairDoor, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 3)
        try OriginalChapterThreeRouteChecks.exit(play, to: 16, interrupt: true, expectArrival: false)
        XCTAssertEqual(play.door?.view.id, 26)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 2, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 16)
        XCTAssertEqual(play.runner.game.nowTime, 2)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-rosa-returns-key")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterNineEntersTheRoom111BackRoom() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-rosa-returns-key")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        try OriginalChapterThreeRouteChecks.exit(play, to: 25, interrupt: true, expectArrival: false)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 2, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 25)
        XCTAssertEqual(play.runner.program.name, "EP9_R125")
        let pictureArea = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        let picturePoint = SIMD2(Float(pictureArea.worldFixed[12]), Float(pictureArea.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: picturePoint, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: picturePoint.x, z: picturePoint.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj08", interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 153)
        XCTAssertEqual(play.runner.program.name, "EP9_R125")
        let instantStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r125-painting-instant"))
        var saveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantStore.save(checkpoint) }
            catch { saveErrors.append(String(describing: error)) }
        }
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 154, interrupt: true)
        let painting = try XCTUnwrap(play.applePainting)
        XCTAssertEqual(painting.paintingIndex, 0)
        var target: SIMD2<Int>?
        for y in 0..<256 where target == nil {
            for x in 0..<192 {
                guard let point = OriginalApplePaintingSearch.cameraPoint(pageX: Int32(x), pageY: Int32(y),
                    cameraX: painting.cameraX, cameraY: painting.cameraY),
                    OriginalApplePaintingSearch.containsPainting(at: 0, cameraPoint: point) else { continue }
                target = SIMD2(x, y)
                break
            }
        }
        let touch = try XCTUnwrap(target, "The fifth-letter painting mask must accept a touch")
        play.touchApplePainting(pageX: touch.x, pageY: touch.y)
        XCTAssertEqual(play.applePainting?.phase, .revealed("J"))
        XCTAssertTrue(saveErrors.isEmpty, saveErrors.joined(separator: "; "))
        let instant = try XCTUnwrap(try instantStore.load(), "The fifth letter must save immediately")
        let resumed = try OriginalPlaySession.restoring(instant, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.applePainting?.phase, .revealed("J"))
        resumed.acknowledgeApplePaintingLetter()
        XCTAssertEqual(resumed.runner.game.applePaintingFoundMask & 1, 1)
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        XCTAssertTrue(resumed.runner.eventTrail.contains(3), "The R125 painting success must complete event 3")
        XCTAssertEqual(resumed.runner.game.value(for: .eventFlag(group: 25, index: 3)), true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r125-letter")).save(try resumed.progressCheckpoint())
    }

    @MainActor func testChapterNineFifthLetterContinuesFromInstantSave() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r125-letter")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r116-instant-live"))
        var saveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantStore.save(checkpoint) }
            catch { saveErrors.append(String(describing: error)) }
        }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.applePaintingFoundMask & 0x1f, 0x1f)
        if case .halted = play.runner.phase { XCTFail("The fifth-letter return must continue normally") }
        play.leaveSearchCloseup()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 81))
        XCTAssertNotNil(play.appleWordEntry)
        for index in OriginalAppleWordEntryProcess.letters.indices {
            play.selectAppleWordLetter(at: index)
        }
        XCTAssertNil(play.appleWordEntry)
        XCTAssertEqual(play.runner.session.selection.eventID, 6)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if case .halted(let halt) = play.runner.phase { XCTFail(halt.reason) }
        try OriginalChapterThreeRouteChecks.exit(play, to: 16, interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.program.name, "EP9_R116")
        XCTAssertEqual(play.runner.game.personMarker(5), 1602)
        XCTAssertEqual(play.runner.phase, .process(id: 63))
        XCTAssertNotNil(play.cpr)
        XCTAssertTrue(saveErrors.isEmpty, saveErrors.joined(separator: "; "))
        let instant = try XCTUnwrap(try instantStore.load(), "The R116 arrival must save after normal input")
        let resumed = try OriginalPlaySession.restoring(instant, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        let cprInstantStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-cpr-conversation-instant"))
        var cprSaveErrors = [String]()
        resumed.enableInstantSaves()
        resumed.onProgressCheckpoint = { checkpoint in
            do { try cprInstantStore.save(checkpoint) }
            catch { cprSaveErrors.append(String(describing: error)) }
        }
        resumed.resume()
        XCTAssertEqual(resumed.runner.phase, .process(id: 63))
        XCTAssertNotNil(resumed.cpr)
        XCTAssertEqual(resumed.runner.game.personMarker(5), 1602)
        resumed.receiveCPRFold(isClosed: true, isFullyOpen: false)
        XCTAssertEqual(resumed.cpr?.phase, .awaitingReopen)
        resumed.receiveCPRFold(isClosed: false, isFullyOpen: true)
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        guard case .questions(let questions) = resumed.runner.phase,
              let memoryQuestion = questions.first(where: { $0.label == "What did you remember?" }) else {
            XCTFail("CPR must open Mila's memory questions: \(resumed.runner.phase)")
            return
        }
        XCTAssertEqual(memoryQuestion.keyword, 4)
        try OriginalChapterThreeRouteChecks.conversation(resumed, answers: [], topics: [4, 7, 8, 9, 5, 10, 6])
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 16))
        XCTAssertTrue(cprSaveErrors.isEmpty, cprSaveErrors.joined(separator: "; "))
        let afterConversation = try XCTUnwrap(try cprInstantStore.load(), "Mila's conversation must save after normal input")
        let fresh = try OriginalPlaySession.restoring(afterConversation, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { fresh.stop() }
        fresh.resume()
        XCTAssertEqual(fresh.runner.phase, .exploration(mapID: 16))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-mila-memory")).save(try fresh.progressCheckpoint())
        if case .halted(let halt) = resumed.runner.phase { XCTFail(halt.reason) }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-fifth-letter")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterNineLeavesRoom111ForKevin() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-mila-memory")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-kevin-instant"))
        var saveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantStore.save(checkpoint) }
            catch { saveErrors.append(String(describing: error)) }
        }
        play.resume()
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 3)
        XCTAssertEqual(play.runner.program.name, "EP9_R103")
        guard case .choice(let choices) = play.runner.phase,
              let aboutMila = choices.first(where: { $0.label == "You knew about Mila?" }) else {
            XCTFail("Leaving Room 111 must start Kevin's Mila scene: \(play.runner.phase)")
            return
        }
        play.choose(aboutMila.id)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: ["Did you know her family?"], topics: [11, 12, 13, 14])
        XCTAssertEqual(play.runner.game.nowTime, 4, "Kevin's scene advances the story to 12:40 A.M.")
        XCTAssertFalse(play.lobby?.people(in: play.runner.game).contains { $0.id == 10 } ?? true,
            "Kevin leaves the lobby after identifying Kyle as Mila's visitor.")
        XCTAssertTrue(saveErrors.isEmpty, saveErrors.joined(separator: "; "))
        let saved = try XCTUnwrap(try instantStore.load(), "Kevin's scene must save after ordinary inputs")
        let resumed = try OriginalPlaySession.restoring(saved, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.runner.game.mapID, 3)
        XCTAssertEqual(resumed.runner.game.nowTime, 4)
        try OriginalChapterThreeRouteChecks.exit(resumed, to: 18, interrupt: true)
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 18))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-kevin-r118")).save(try resumed.progressCheckpoint())
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-kevin-arrival")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterNineViewlessLobbyDoorUsesOriginalDoorResponse() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-kevin-instant")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()

        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true, expectArrival: false)

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
        XCTAssertNil(play.door, "A door without an up-view must not display a fabricated overlay")
        XCTAssertEqual(play.runner.session.selection.modeID, 10)
        XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 7)), true)
    }

    @MainActor func testChapterNineWalksThroughR118ToR213() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-kevin-r118")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        let marker = try OriginalChapterThreeRouteChecks.doorMarker(play, 39)
        let lobby = try XCTUnwrap(play.lobby)
        let collision = lobby.collision, y = lobby.position.y
        var candidates = [SIMD2<Float>]()
        for dz in stride(from: -10240, through: 10240, by: 1024) {
            for dx in stride(from: -10240, through: 10240, by: 1024) {
                let point = marker + SIMD2<Float>(Float(dx), Float(dz))
                let world = SIMD3<Float>(point.x, y, point.y)
                let distance = simd_distance(point, marker)
                guard distance > 3000, distance < 9000,
                      simd_distance(collision.resolve(world), world) < 1,
                      collision.firstRegion(containing: world, prefix: "in_") == nil else { continue }
                candidates.append(point)
            }
        }
        let here = SIMD2<Float>(lobby.position.x, lobby.position.z)
        candidates.sort { simd_distance($0, here) < simd_distance($1, here) }
        var reached = false
        for stand in candidates {
            try OriginalChapterThreeRouteChecks.navigate(play, to: stand, interrupt: true)
            guard let position = play.lobby?.position else { break }
            if hypot(position.x - stand.x, position.z - stand.y) < 1500 { reached = true; break }
        }
        XCTAssertTrue(reached, "Find a normal standing point near the R213 marker")
        let stand = try XCTUnwrap(play.lobby).position
        let beyond = marker + SIMD2<Float>(marker.x - stand.x, marker.y - stand.z) * 4
        try OriginalChapterThreeRouteChecks.walk(play, to: beyond, interrupt: true)

        XCTAssertEqual(play.runner.game.mapID, 39)
        XCTAssertEqual(play.runner.program.name, "EP9_R213")
        XCTAssertEqual(play.runner.game.nowTime, 4)
        try OriginalChapterThreeRouteChecks.exit(play, to: 31, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 31)
        XCTAssertEqual(play.runner.program.name, "EP9_R205")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room215-at-1240")).save(try play.walkingCheckpoint())
    }

    @MainActor func testChapterNineCallsEdAndAnswersRosasKnock() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room215-at-1240")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        var observedDialogue = [String]()
        func drainStory() {
            for _ in 0..<2000 {
                switch play.runner.phase {
                case .dialogue(let packet):
                    observedDialogue.append(packet.pages.flatMap(\.entries)
                        .map { String(decoding: $0.bytes, as: UTF8.self) }.joined(separator: " "))
                    play.advanceDialogue()
                case .itemNotice: play.advanceDialogue()
                case .waiting, .process(126): play.advanceFrame()
                case .exploration: return
                default: return
                }
            }
            XCTFail("Chapter 9 phone or door scene did not return to exploration")
        }
        try OriginalChapterThreeRouteChecks.walk(play, to: SIMD2(9500, -15000))
        try OriginalChapterThreeRouteChecks.walk(play, to: SIMD2(9000, 7800))
        try OriginalChapterThreeRouteChecks.walk(play, to: SIMD2(-15500, 7800))
        play.holdLobbyTouch(x: 20, y: 128)
        for _ in 0..<10 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true)
        drainStory()
        let phoneTranscript = observedDialogue.joined(separator: " ")
        XCTAssertTrue(phoneTranscript.contains("Guess I should give Ed a ring."), phoneTranscript)
        XCTAssertTrue(phoneTranscript.contains("Robert Evans bought himself a little"), phoneTranscript)
        XCTAssertTrue(phoneTranscript.contains("Who's that?"), phoneTranscript)
        XCTAssertTrue(phoneTranscript.contains("You got visitors at this hour?"), phoneTranscript)
        XCTAssertTrue(phoneTranscript.contains("Well, I'll leave you to it."), phoneTranscript)
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.program.name, "EP9_R205")
        XCTAssertEqual(play.runner.game.nowTime, 4)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-ed-call")).save(try play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.walk(play, to: SIMD2(9994, -15811), interrupt: true)
        let exitMarker = try OriginalChapterThreeRouteChecks.doorMarker(play, 39)
        OriginalChapterThreeRouteChecks.face(play, x: exitMarker.x, z: exitMarker.y)
        play.inspectNearbyDoor()
        drainStory()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-rosa-interruption")).save(try play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.walk(play, to: SIMD2(9994, -15811), interrupt: true)
        let secondExitMarker = try OriginalChapterThreeRouteChecks.doorMarker(play, 39)
        OriginalChapterThreeRouteChecks.face(play, x: secondExitMarker.x, z: secondExitMarker.y)
        play.inspectNearbyDoor()
        drainStory()
        let rosaTranscript = observedDialogue.joined(separator: " ")
        XCTAssertTrue(rosaTranscript.contains("Oh, Mr. Hyde, it's just terrible!"), rosaTranscript)
        XCTAssertTrue(rosaTranscript.contains("I'll go find them."), rosaTranscript)
        XCTAssertTrue(rosaTranscript.contains("Dunning and Mila are having"), rosaTranscript)
        XCTAssertEqual(play.runner.game.mapID, 39)
        XCTAssertEqual(play.runner.program.name, "EP9_R213")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-rosa-r213")).save(try play.walkingCheckpoint())
    }

    @MainActor func testChapterNineEntersDunningRoomAfterRosa() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-rosa-r213")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        try OriginalChapterThreeRouteChecks.exit(play, to: 33, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 33)
        XCTAssertEqual(play.runner.program.name, "EP9_R207")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-dunning-room")).save(try play.walkingCheckpoint())
    }

    @MainActor func testChapterNineInspectsDunningRoomDesk() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-dunning-room")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        XCTAssertEqual(play.runner.game.mapID, 33)
        let room = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(room.room.nodes.first { $0.name == "s02" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj08", interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 275)
        XCTAssertTrue(play.closeup?.view.layers.contains { $0.eventID == 276 } == true)
        XCTAssertTrue(play.closeup?.view.layers.contains { $0.eventID == 277 } == true)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 276, interrupt: true)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 277, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 275)
    }

    @MainActor func testChapterNineOpensDunningRoomPaintingThroughNormalHit() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-dunning-room")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-r207-painting-instant"))
        var saveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantStore.save(checkpoint) }
            catch { saveErrors.append(String(describing: error)) }
        }
        play.resume()
        let room = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(room.room.nodes.first { $0.name == "s01" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj02", interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 272)
        XCTAssertEqual(play.closeup?.view.layers.map(\.eventID), [273, 274])
        XCTAssertTrue(saveErrors.isEmpty, saveErrors.joined(separator: "; "))
        let saved = try XCTUnwrap(try instantStore.load(), "The painting close-up should save after normal input")
        XCTAssertEqual(saved.progress, try play.progressCheckpoint().progress)
        let restored = try OriginalPlaySession.restoring(saved, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { restored.stop() }
        restored.resume()
        XCTAssertEqual(restored.closeup?.view.id, 272)
        XCTAssertEqual(restored.closeup?.view.layers.map(\.eventID), [273, 274])
    }

    @MainActor func testChapterNineAcceptsHitOnlyDunningRoomHelperMask() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter9-dunning-room")).load() else {
            throw XCTSkip("The Chapter 9 Dunning-room checkpoint is not available")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        guard let room = play.lobby,
              let index = room.room.nodes.firstIndex(where: { $0.name == "obj9998" }) else {
            return XCTFail("The source hit-only helper mask should be present")
        }
        let node = room.room.nodes[index]
        let target = SIMD2(Float(node.worldFixed[12]), Float(node.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        let lobby = try XCTUnwrap(play.lobby)
        XCTAssertEqual(lobby.nearbySearchArea, 3)
        XCTAssertFalse(lobby.room.gameplayRenderNodes.contains(index), "The helper stays hidden from the render pass")
        let visible = lobby.objectVisibility.visibleNodes(in: lobby.room, map: lobby.mapID, area: nil, game: play.runner.game)
        XCTAssertTrue(visible.contains(index), "The helper remains available to the original hit pass")
        XCTAssertEqual(try lobby.pickedRoomObject(page: SIMD2(52, 0), visibleNodes: visible), "obj9998")
        let gameBeforeHit = play.runner.game
        play.selectLobbyRoomObject(x: 52, y: 0)
        XCTAssertEqual(play.runner.session.selection.modeID, 10)
        XCTAssertEqual(play.runner.session.selection.areaID, 3)
        XCTAssertEqual(play.runner.session.selection.subareaID, 99)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 33))
        XCTAssertEqual(play.runner.program.name, "EP9_R207")
        XCTAssertEqual(play.runner.game.bytes, gameBeforeHit.bytes,
                       "The unmatched helper hit must not change story or inventory state")
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39, "The player must still be able to leave for R213")
    }

    @MainActor func testChapterNineWalksFromDunningRoomToPantry() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-dunning-room")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantSaveStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-dunning-pantry-route-instant"))
        var instantSaveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantSaveStore.save(checkpoint) }
            catch { instantSaveErrors.append(String(describing: error)) }
        }
        play.resume()
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 3)
        try OriginalChapterThreeRouteChecks.exit(play, to: 18, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 18)
        try OriginalChapterThreeRouteChecks.exit(play, to: 12, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 12)
        XCTAssertEqual(play.runner.program.name, "EP9_R112")
        XCTAssertTrue(instantSaveErrors.isEmpty, instantSaveErrors.joined(separator: "; "))
        let saved = try XCTUnwrap(try instantSaveStore.load(), "Pantry route progress should save as it runs")
        XCTAssertEqual(saved.progress, try play.progressCheckpoint().progress)
        let room = try XCTUnwrap(play.lobby)
        let pantry = try XCTUnwrap(room.room.nodes.first { $0.name == "s04" })
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(Float(pantry.worldFixed[12]), Float(pantry.worldFixed[14])), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: Float(pantry.worldFixed[12]), z: Float(pantry.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 4)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 12))
        XCTAssertTrue(instantSaveErrors.isEmpty, instantSaveErrors.joined(separator: "; "))
        let pantrySave = try XCTUnwrap(try instantSaveStore.load(), "Pantry search-area progress should save as it runs")
        XCTAssertEqual(pantrySave.progress, try play.progressCheckpoint().progress)
        let resumed = try OriginalPlaySession.restoring(pantrySave, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 12))
        XCTAssertEqual(resumed.lobby?.nearbySearchArea, 4)
    }

    @MainActor func testChapterNineFindsDunningItemsAndCardsThroughNormalPantryDoor() throws {
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"])
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-dunning-pantry-route-instant")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-dunning-items-instant"))
        var saveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantStore.save(checkpoint) }
            catch { saveErrors.append(String(describing: error)) }
        }
        play.resume()
        XCTAssertEqual(play.runner.game.mapID, 12)
        try OriginalChapterThreeRouteChecks.exit(play, to: 23, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 23)
        XCTAssertEqual(play.runner.program.name, "EP9_R123")

        let room = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(room.room.nodes.first { $0.name == "s02" })
        let target = SIMD2(Float(marker.worldFixed[12]), Float(marker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj11", interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 87)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 89, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(41), "Old Hotel Brochure")
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 88, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(60), "Article on Osterzone")
        play.leaveSearchCloseup()
        try OriginalChapterThreeRouteChecks.search(play, node: "obj14", interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 90)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 91, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 23, index: 4)), true)
        XCTAssertTrue(saveErrors.isEmpty, saveErrors.joined(separator: "; "))

        let saved = try XCTUnwrap(try instantStore.load(), "Both desk items should persist immediately")
        let restored = try OriginalPlaySession.restoring(saved, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { restored.stop() }
        let refrigeratorInstantStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-pantry-refrigerator-instant"))
        var refrigeratorSaveErrors = [String]()
        restored.enableInstantSaves()
        restored.onProgressCheckpoint = { checkpoint in
            do { try refrigeratorInstantStore.save(checkpoint) }
            catch { refrigeratorSaveErrors.append(String(describing: error)) }
        }
        restored.resume()
        XCTAssertEqual(restored.runner.game.mapID, 23)
        XCTAssertTrue(try restored.runner.game.inventory.items.contains(41))
        XCTAssertTrue(try restored.runner.game.inventory.items.contains(60))
        XCTAssertEqual(restored.runner.game.value(for: .eventFlag(group: 23, index: 4)), true)
        OriginalChapterThreeRouteChecks.drain(restored, interrupt: true)
        restored.leaveSearchCloseup()
        restored.leaveLobbyCounter()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-dunning-items-and-cards")).save(try restored.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(restored, to: 12, interrupt: true)
        XCTAssertEqual(restored.runner.game.mapID, 12)

        let pantry = try XCTUnwrap(restored.lobby)
        let refrigeratorMarker = try XCTUnwrap(pantry.room.nodes.first { $0.name == "s04" })
        let refrigeratorTarget = SIMD2(Float(refrigeratorMarker.worldFixed[12]), Float(refrigeratorMarker.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(restored, to: refrigeratorTarget, interrupt: true)
        OriginalChapterThreeRouteChecks.face(restored, x: refrigeratorTarget.x, z: refrigeratorTarget.y)
        XCTAssertEqual(restored.lobby?.nearbySearchArea, 4)
        restored.inspectLobbyCounter()
        restored.panLobbyCounter(0)
        try OriginalChapterThreeRouteChecks.search(restored, node: "obj04", interrupt: true)
        XCTAssertEqual(restored.closeup?.view.id, 74, "The normal refrigerator hit should open view 74")

        let refrigeratorSave = try XCTUnwrap(try refrigeratorInstantStore.load())
        let resumed = try OriginalPlaySession.restoring(refrigeratorSave, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.runner.game.mapID, 12)
        XCTAssertEqual(resumed.closeup?.view.id, 74, "Instant restore should keep the refrigerator view open")
        try OriginalChapterThreeRouteChecks.closeupLayer(resumed, event: 75, interrupt: true)
        guard case .exploration(let mapID) = resumed.runner.phase else {
            XCTFail("The refrigerator layer should return control to the pantry")
            return
        }
        XCTAssertEqual(mapID, 12)
        XCTAssertEqual(resumed.closeup?.view.id, 74)
        XCTAssertTrue(refrigeratorSaveErrors.isEmpty, refrigeratorSaveErrors.joined(separator: "; "))
        resumed.leaveSearchCloseup()
        resumed.leaveLobbyCounter()
        try OriginalChapterThreeRouteChecks.exit(resumed, to: 18, interrupt: true)
        XCTAssertEqual(resumed.runner.game.mapID, 18)
        XCTAssertEqual(resumed.runner.program.name, "EP9_R118")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-after-dunning-pantry-exit")).save(try resumed.walkingCheckpoint())
    }

    @MainActor func testChapterNineRoom215ApplePaintingUsesNormalHitAndInstantRestores() throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] ?? ".build/story-checkpoints")
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: directory
            .appendingPathComponent("chapter9-normal-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantSaveStore = OriginalResumeFileStore(directory: directory
            .appendingPathComponent("chapter9-room215-photo-instant"))
        var instantSaveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantSaveStore.save(checkpoint) }
            catch { instantSaveErrors.append(String(describing: error)) }
        }
        play.resume()
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2<Float>(0, 0), interrupt: true)
        let room = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(room.room.nodes.first { $0.name == "s01" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2<Float>(Float(marker.worldFixed[12]), Float(marker.worldFixed[14])), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        play.inspectLobbyCounter()
        let search = try XCTUnwrap(play.lobby)
        let targetIndex = try XCTUnwrap(search.counter.nodes.firstIndex { $0.name == "obj06" })
        var targetPoint: SIMD2<Float>?
        for pan in [Float(0), 0.25, 0.5, 0.75, 1] {
            play.panLobbyCounter(pan)
            let current = try XCTUnwrap(play.lobby)
            let mask = try OriginalModelProjectedMask(model: current.counter,
                viewProjection: current.viewProjection, width: 192, height: 256,
                visibleNodes: [targetIndex])
            let bounds = mask.bounds.intersection(CGRect(x: 0, y: 0, width: 192, height: 256))
            for y in stride(from: Int(bounds.minY), to: Int(bounds.maxY), by: 4) where targetPoint == nil {
                for x in stride(from: Int(bounds.minX), to: Int(bounds.maxX), by: 4) {
                    let point = SIMD2(Float(x), Float(y))
                    if try current.pickedCounterNode(page: point) == "obj06" {
                        targetPoint = point
                        break
                    }
                }
            }
            if targetPoint != nil { break }
        }
        let hit = try XCTUnwrap(targetPoint, "The photo should remain selectable through its source hit mesh")
        play.selectLobbyObject(x: hit.x, y: hit.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 264)
        XCTAssertTrue(instantSaveErrors.isEmpty, instantSaveErrors.joined(separator: "; "))
        let saved = try XCTUnwrap(try instantSaveStore.load(), "The close-up must save after input")
        XCTAssertEqual(saved.progress, try play.progressCheckpoint().progress)
        let restored = try OriginalPlaySession.restoring(saved, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { restored.stop() }
        restored.resume()
        XCTAssertEqual(restored.closeup?.view.id, 264)
        var background: SIMD2<Int>?
        for y in stride(from: 16, to: 240, by: 8) where background == nil {
            for x in stride(from: 16, to: 184, by: 8) {
                if restored.closeupImage?.hit(pageX: x, pageY: y) == 0 {
                    background = SIMD2(x, y)
                    break
                }
            }
        }
        let backgroundHit = try XCTUnwrap(background)
        restored.selectCloseupComponent(x: backgroundHit.x, y: backgroundHit.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(restored, interrupt: true)
        try OriginalChapterThreeRouteChecks.closeupLayer(restored, event: 265, interrupt: true)
        XCTAssertNotNil(restored.applePainting)
        let paintingSaveStore = OriginalResumeFileStore(directory: directory
            .appendingPathComponent("chapter9-room215-apple-letter-instant"))
        var paintingSaveErrors = [String]()
        restored.enableInstantSaves()
        restored.onProgressCheckpoint = { checkpoint in
            do { try paintingSaveStore.save(checkpoint) }
            catch { paintingSaveErrors.append(String(describing: error)) }
        }
        restored.touchApplePainting(pageX: 118, pageY: 113)
        XCTAssertEqual(restored.applePainting?.phase, .revealed("Y"))
        XCTAssertTrue(paintingSaveErrors.isEmpty, paintingSaveErrors.joined(separator: "; "))
        let revealed = try XCTUnwrap(try paintingSaveStore.load(), "The letter reveal must save immediately")
        XCTAssertEqual(revealed.progress, try restored.progressCheckpoint().progress)
        restored.acknowledgeApplePaintingLetter()
        XCTAssertEqual(restored.runner.game.applePaintingFoundMask, 1 << 4)
        OriginalChapterThreeRouteChecks.drain(restored, interrupt: true)
        XCTAssertEqual(restored.runner.phase, .exploration(mapID: 31))
    }

    @MainActor func testChapterNineTravelsFromRoom215ToRoom217AfterFirstLetter() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] else {
            throw XCTSkip("Run the Room 215 apple-painting route first")
        }
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room215-apple-letter-instant")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.applePaintingFoundMask, 1 << 4)
        XCTAssertEqual(play.runner.game.mapID, 31)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2<Float>(8000, -5000), interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalChapterThreeRouteChecks.exit(play, to: 33, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 33)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room217-entry")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterNineRoom217PaintingReturnsSecondLetter() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] else {
            throw XCTSkip("Run the Room 215 apple-painting route first")
        }
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room217-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantSaveStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room217-painting-instant"))
        var instantSaveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantSaveStore.save(checkpoint) }
            catch { instantSaveErrors.append(String(describing: error)) }
        }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 33)
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2<Float>(-28_000, -39_000), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: -40_099, z: -29_279)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj02", interrupt: true)
        let painting = try XCTUnwrap(play.closeup)
        XCTAssertEqual(painting.view.id, 272)
        let paintingBackground = try XCTUnwrap((stride(from: 16, to: 240, by: 8).flatMap { y in
            stride(from: 16, to: 184, by: 8).map { SIMD2($0, y) }
        }).first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == 0 })
        play.selectCloseupComponent(x: paintingBackground.x, y: paintingBackground.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 273, interrupt: true)
        XCTAssertNotNil(play.applePainting)
        play.touchApplePainting(pageX: 109, pageY: 113)
        XCTAssertEqual(play.applePainting?.phase, .revealed("N"))
        XCTAssertTrue(instantSaveErrors.isEmpty, instantSaveErrors.joined(separator: "; "))
        let revealed = try XCTUnwrap(try instantSaveStore.load(), "The Room 217 letter must save immediately")
        XCTAssertEqual(revealed.progress, try play.progressCheckpoint().progress)
        let resumed = try OriginalPlaySession.restoring(revealed, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.applePainting?.phase, .revealed("N"))
        resumed.acknowledgeApplePaintingLetter()
        XCTAssertEqual(resumed.runner.game.applePaintingFoundMask, (1 << 4) | (1 << 3))
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room217-second-letter")).save(try resumed.progressCheckpoint())
    }

    @MainActor func testChapterNineLeavesRoom217ForTheUpstairsHallway() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] else {
            throw XCTSkip("Complete the Room 217 painting first")
        }
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room217-second-letter")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.applePaintingFoundMask, (1 << 4) | (1 << 3))
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-upstairs-hall-entry")).save(try play.progressCheckpoint())
    }

    @MainActor func testChapterNineUpstairsHallPaintingReturnsThirdLetter() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] else {
            throw XCTSkip("Reach the upstairs hallway through the Chapter 9 route first")
        }
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-upstairs-hall-entry")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantSaveStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-upstairs-painting-instant"))
        var instantSaveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantSaveStore.save(checkpoint) }
            catch { instantSaveErrors.append(String(describing: error)) }
        }
        play.resume()
        let room = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(room.room.nodes.first { $0.name == "s02" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2<Float>(Float(marker.worldFixed[12]), Float(marker.worldFixed[14])), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01", interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 323)
        let background = try XCTUnwrap((stride(from: 16, to: 240, by: 8).flatMap { y in
            stride(from: 16, to: 184, by: 8).map { SIMD2($0, y) }
        }).first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == 0 })
        play.selectCloseupComponent(x: background.x, y: background.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 324, interrupt: true)
        XCTAssertNotNil(play.applePainting)
        play.touchApplePainting(pageX: 67, pageY: 163)
        XCTAssertEqual(play.applePainting?.phase, .revealed("E"))
        XCTAssertTrue(instantSaveErrors.isEmpty, instantSaveErrors.joined(separator: "; "))
        let revealed = try XCTUnwrap(try instantSaveStore.load(), "The upstairs letter must save immediately")
        XCTAssertEqual(revealed.progress, try play.progressCheckpoint().progress)
        let resumed = try OriginalPlaySession.restoring(revealed, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        resumed.resume()
        XCTAssertEqual(resumed.applePainting?.phase, .revealed("E"))
        resumed.acknowledgeApplePaintingLetter()
        XCTAssertEqual(resumed.runner.game.applePaintingFoundMask, (1 << 4) | (1 << 3) | (1 << 1))
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-upstairs-third-letter")).save(try resumed.progressCheckpoint())
    }

    @MainActor func testChapterNineTravelsDownstairsForTheFourthPainting() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] else {
            throw XCTSkip("Complete the upstairs painting first")
        }
        let checkpoint = try XCTUnwrap(OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-upstairs-third-letter")).load())
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.applePaintingFoundMask, (1 << 4) | (1 << 3) | (1 << 1))
        let stair = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "in_r117" })
        let stairPoint = SIMD2<Float>(Float(stair.worldFixed[12]), Float(stair.worldFixed[14]))
        try OriginalChapterThreeRouteChecks.navigate(play, to: stairPoint, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: SIMD2<Float>(14_000, -7_000), interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-downstairs-hall-entry")).save(try play.progressCheckpoint())
    }

    @MainActor private final class RouteMusicOutput: OriginalMusicOutput {
        var outputVolume: Float = 0
        var isActive = true
        var position: TimeInterval = 0
        func seek(to seconds: TimeInterval) throws { position = seconds }
        func resume() throws { isActive = true }
        func pause() { isActive = false }
        func stop() { isActive = false }
    }

    @MainActor private final class BitmapRouteMapRenderer: OriginalMapRendering {
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

    @MainActor private final class RouteThinWireRenderer: OriginalThinWireRendering {
        private let image: CGImage

        init() throws {
            guard let context = CGContext(data: nil, width: 192, height: 256, bitsPerComponent: 8,
                bytesPerRow: 768, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                let image = context.makeImage() else {
                throw OriginalDataError.invalid("Route wire-lock image")
            }
            self.image = image
        }

        func render(_ puzzle: OriginalThinWireProcess) throws -> CGImage { image }
    }

    @MainActor private final class RouteBowlingRenderer: OriginalBowlingRendering {
        private let image: CGImage

        init() throws {
            guard let image = CGContext(data: nil, width: 256, height: 192, bitsPerComponent: 8,
                bytesPerRow: 256 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage() else {
                throw OriginalDataError.invalid("Route bowling image")
            }
            self.image = image
        }

        func render(_ state: OriginalBowlingRenderer.SceneState) throws -> CGImage { image }
    }

    @MainActor private final class BitmapRouteCassetteRenderer: OriginalCassetteRendering {
        private let image: CGImage

        init() throws { image = try BitmapRouteMapRenderer(mapName: "R205").map }

        func render() throws -> CGImage { image }
    }

    @MainActor private final class BitmapCassetteDeckRenderer: OriginalCassetteDeckRendering {
        private let image: CGImage

        init() throws { image = try BitmapRouteMapRenderer(mapName: "R205").map }

        func render(camera: OriginalCassetteDeckCamera,
                    state: OriginalCassetteDeckProcess.SceneState) throws -> CGImage { image }

        func hasHit(pageX: Int, pageY: Int, camera: OriginalCassetteDeckCamera,
                    state: OriginalCassetteDeckProcess.SceneState) throws -> Bool { true }
    }

    @MainActor private final class BitmapSuitcaseContentsRenderer: OriginalSuitcaseContentsRendering {
        let initialContents: OriginalSuitcaseContents
        private let image: CGImage

        init() throws {
            image = try BitmapRouteMapRenderer(mapName: "R205").map
            let bitmaps = try OriginalBitmapLibrary.bundled()
            let masks = try OriginalSuitcaseContents.lowerObjects.map { object in
                try bitmaps.loadTexture(path: "trick/searchbag/\(object.texture).bin").originalPixelData
            }
            initialContents = try OriginalSuitcaseContents(lowerHitMasks: masks)
        }

        func render(_ process: OriginalSuitcaseContentsProcess, game: OriginalGameState) throws -> CGImage { image }
    }

    @MainActor func testChapterSix01ReachesBarFromChapterFiveSave() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-entry")).load() else {
            throw XCTSkip("Generate the Chapter 6 save through the Chapter 5 route first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }

        XCTAssertEqual(play.runner.game.chapter, 5)
        XCTAssertEqual(play.runner.program.name, "EP6_R205")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))

        // The first exit attempt starts the Chapter 6 phone event and cancels
        // departure. Answer the ringing phone in Room 215, then try the door again.
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true, expectArrival: false)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-16687, 7450), interrupt: true)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)

        for destination: Int16 in [39, 17, 26, 4] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
            XCTAssertEqual(play.runner.game.mapID, destination)
        }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-bar")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSix02TravelsFromR104ThroughR105ToR126() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-bar")).load() else {
            throw XCTSkip("Generate the Chapter 6 bar checkpoint through the Chapter 5 route first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let instantSaveDirectory = URL(fileURLWithPath: directory).appendingPathComponent("chapter6-instant-current")
        let instantSaveStore = OriginalResumeFileStore(directory: instantSaveDirectory)
        var instantSaveErrors = [String]()
        play.enableInstantSaves()
        play.onProgressCheckpoint = { checkpoint in
            do { try instantSaveStore.save(checkpoint) }
            catch { instantSaveErrors.append(String(describing: error)) }
        }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 4))
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        guard case .choice(let choices) = play.runner.phase else {
            return XCTFail("Expected the Chapter 6 first bar choice: \(play.runner.phase)")
        }
        XCTAssertEqual(choices.map(\.id), [1, 0])
        play.choose(1)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let topics) = play.runner.phase else {
            return XCTFail("Expected Louie's Chapter 6 bar topics: \(play.runner.phase)")
        }
        XCTAssertEqual(topics.map(\.keyword), [0, 1, 2])
        for topic: Int16 in [0, 1, 2] {
            play.ask(topic)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        play.leaveConversation()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        try OriginalChapterThreeRouteChecks.talk(play, to: 4)
        if case .questions = play.runner.phase { play.leaveConversation() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 7)
        guard case .questions(let helenTopics) = play.runner.phase else { return XCTFail("Expected Helen's topic menu") }
        XCTAssertEqual(helenTopics.map(\.keyword), [4, 5])
        play.ask(4)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let helenTopicsAfterFamily) = play.runner.phase else {
            return XCTFail("Expected Helen's wish and family topics")
        }
        XCTAssertEqual(helenTopicsAfterFamily.map(\.keyword), [5, 6])
        play.ask(5)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(6)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 51))
        try OriginalChapterThreeRouteChecks.solveCoins(play)
        guard case .choice(let helenChoices) = play.runner.phase else {
            return XCTFail("Expected Helen's first post-game choice")
        }
        XCTAssertEqual(helenChoices.map(\.id), [2, 3])
        play.choose(3)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let helenHistoryChoices) = play.runner.phase else {
            return XCTFail("Expected Helen's history choice")
        }
        XCTAssertEqual(helenHistoryChoices.map(\.id), [4, 5])
        play.choose(4)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(15_000, 20_000))
        let bar = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(bar.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        for node in ["obj02", "obj03", "obj04"] {
            try OriginalChapterThreeRouteChecks.search(play, node: node)
        }
        try OriginalChapterThreeRouteChecks.search(play, node: "obj05")
        XCTAssertEqual(play.runner.phase, .process(id: 53))
        try OriginalChapterThreeRouteChecks.solveMatchsticks(play)
        guard case .choice(let irisChoices) = play.runner.phase else {
            return XCTFail("Expected Iris's drink offer")
        }
        XCTAssertEqual(irisChoices.map(\.id), [6, 7])
        play.choose(6)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(15_000, 20_000))
        let secondBar = try XCTUnwrap(play.lobby)
        let secondMarker = try XCTUnwrap(secondBar.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(secondMarker.worldFixed[12]), z: Float(secondMarker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        try OriginalChapterThreeRouteChecks.search(play, node: "obj06")
        XCTAssertEqual(play.runner.phase, .process(id: 54))
        try OriginalChapterThreeRouteChecks.solveMatchsticks(play)
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        guard case .choice(let summerChoices) = play.runner.phase else {
            return XCTFail("Expected Summer's opening choice: \(play.runner.phase)")
        }
        XCTAssertEqual(summerChoices.map(\.id), [8, 9])
        play.choose(8)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let summerTopics) = play.runner.phase else {
            return XCTFail("Expected Summer's topics: \(play.runner.phase)")
        }
        for topic in summerTopics.map(\.keyword) {
            play.ask(topic)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        if case .questions(let remaining) = play.runner.phase {
            for topic in remaining.map(\.keyword) {
                play.ask(topic)
                OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
            }
        }
        if case .questions = play.runner.phase {
            play.leaveConversation()
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(15_000, 20_000))
        let bourbonBar = try XCTUnwrap(play.lobby)
        let bourbonMarker = try XCTUnwrap(bourbonBar.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(bourbonMarker.worldFixed[12]),
            z: Float(bourbonMarker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj05", interrupt: true)
        let bourbonEventTrail = play.runner.eventTrail.suffix(4)
        XCTAssertTrue(bourbonEventTrail.suffix(2).elementsEqual([72, 108]))
        XCTAssertTrue(instantSaveErrors.isEmpty, instantSaveErrors.joined(separator: "; "))
        let diskCheckpoint = try XCTUnwrap(instantSaveStore.load(), "The route must persist progress immediately")
        XCTAssertEqual(diskCheckpoint.progress, try play.progressCheckpoint().progress)
        let resumed = try OriginalPlaySession.restoring(diskCheckpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 5))
        resumed.resume()
        XCTAssertFalse(resumed.isPaused)
        try OriginalChapterThreeRouteChecks.exit(resumed, to: 26, interrupt: true)
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 26))
        XCTAssertEqual(resumed.runner.game.nowTime, 1)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-r105-return")).save(resumed.walkingCheckpoint())
    }

    @MainActor func testChapterSix03FromBarExitThroughRosaErrand() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-r105-return")).load() else {
            throw XCTSkip("Generate the Rosa checkpoint through the earlier Chapter 6 route first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.talk(play, to: 3)
        guard case .questions = play.runner.phase else { return XCTFail("Expected Rosa's topic menu") }
        play.ask(9)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let topics) = play.runner.phase else { return XCTFail("Expected Rosa's story topic") }
        XCTAssertEqual(topics.map(\.keyword), [10])
        play.ask(10)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.exit(play, to: 4, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 4))
        try OriginalChapterThreeRouteChecks.talk(play, to: 2)
        guard case .choice(let choices) = play.runner.phase else { return XCTFail("Expected Dunning's history choice") }
        XCTAssertEqual(choices.map(\.id), [12, 13])
        play.choose(12)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let historyTopics) = play.runner.phase else { return XCTFail("Expected Dunning's history topics") }
        XCTAssertEqual(historyTopics.map(\.keyword), [11, 12])
        play.ask(11)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(12)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let remaining) = play.runner.phase else { return XCTFail("Expected Dunning's final topic") }
        XCTAssertEqual(remaining.map(\.keyword), [13])
        play.ask(13)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let pastChoices) = play.runner.phase else { return XCTFail("Expected Dunning's past choice") }
        XCTAssertEqual(pastChoices.map(\.id), [14, 15])
        play.choose(15)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 4))
        XCTAssertEqual(play.runner.game.nowTime, 2)
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.talk(play, to: 3)
        guard case .choice(let rosaChoices) = play.runner.phase else { return XCTFail("Expected Rosa's favour choice") }
        XCTAssertEqual(rosaChoices.map(\.id), [10, 11])
        play.choose(10)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let rosaTopics) = play.runner.phase else { return XCTFail("Expected Rosa's favour topics") }
        XCTAssertEqual(rosaTopics.map(\.keyword), [14])
        play.ask(14)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let sonComparison) = play.runner.phase else { return XCTFail("Expected Rosa's comparison topic") }
        XCTAssertEqual(sonComparison.map(\.keyword), [15])
        play.ask(15)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let sonTopic) = play.runner.phase else { return XCTFail("Expected Rosa's son topic") }
        XCTAssertEqual(sonTopic.map(\.keyword), [16])
        play.ask(16)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        XCTAssertEqual(play.runner.game.nowTime, 3)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-rosa-errand")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSix04MatchsticksAndKitchenWineBottles() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-normal-rosa-errand")).load() else {
            throw XCTSkip("Generate the post-Rosa Chapter 6 checkpoint first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 4, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(15_000, 20_000))
        let bar = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(bar.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        for node in ["obj02", "obj03", "obj04"] {
            try OriginalChapterThreeRouteChecks.search(play, node: node)
        }
        try OriginalChapterThreeRouteChecks.search(play, node: "obj05")
        XCTAssertEqual(play.runner.phase, .process(id: 53))
        try OriginalChapterThreeRouteChecks.solveMatchsticks(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-after-matchsticks")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 6, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 6))
        func inspectWine(area: Int, point: SIMD2<Float>, object: String) throws {
            try OriginalChapterThreeRouteChecks.navigate(play, to: point)
            let room = try XCTUnwrap(play.lobby)
            let marker = try XCTUnwrap(room.room.nodes.first { $0.name == String(format: "s%02d", area) })
            OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
            XCTAssertEqual(play.lobby?.nearbySearchArea, UInt16(area))
            try OriginalChapterThreeRouteChecks.search(play, node: object)
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 6))
            if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        }
        try inspectWine(area: 3, point: .init(-50_000, 15_000), object: "obj06")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-red-wine")).save(play.walkingCheckpoint())
        try inspectWine(area: 1, point: .init(-15_000, 5_000), object: "obj09")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-white-wine")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSix05FindRoseWine() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-normal-white-wine")).load() else {
            throw XCTSkip("Generate the Chapter 6 white-wine checkpoint first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(-50_000, -10_000))
        let lobby = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(lobby.room.nodes.first { $0.name == "s02" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01")
        XCTAssertEqual(play.runner.phase, .process(id: 58))
        try OriginalChapterThreeRouteChecks.playJukebox(play, record: 24)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 4, interrupt: true)
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(5_000, 0))
        let restaurant = try XCTUnwrap(play.lobby)
        let tableMarker = try XCTUnwrap(restaurant.room.nodes.first { $0.name == "s04" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(tableMarker.worldFixed[12]), z: Float(tableMarker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 4)
        for object in ["obj01", "obj02", "obj03", "obj04", "obj05"] {
            try OriginalChapterThreeRouteChecks.search(play, node: object)
            XCTAssertEqual(play.runner.phase, .exploration(mapID: 4))
            if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-rose-wine")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSix06GetsAdhesiveRemoverFromEdPackage() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-normal-rose-wine")).load() else {
            throw XCTSkip("Generate the Chapter 6 rosé checkpoint first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        for destination: Int16 in [26, 17, 39, 31] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
        }
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(0, 20_000))
        OriginalChapterThreeRouteChecks.face(play, x: 14, z: 24_407)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj03", closeupEvent: 257)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(50), "Adhesive remover from Ed's package")
        for _ in 0..<4 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        XCTAssertTrue(play.canSaveWalkingCheckpoint)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-with-adhesive-remover")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSix07IdentifiesWinesAndStartsLabelPeel() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-normal-with-adhesive-remover")).load() else {
            throw XCTSkip("Generate the Chapter 6 adhesive-remover checkpoint first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        let target = try OriginalChapterThreeRouteChecks.doorMarker(play, 32)
        try OriginalChapterThreeRouteChecks.navigate(play, to: target + SIMD2<Float>(0, -8_000))
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.nearbyDoor, 32)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        guard case .questions(let irisTopics) = play.runner.phase,
              irisTopics.contains(where: { $0.keyword == 17 }) else {
            return XCTFail("Expected Iris's wine question: \(play.runner.phase)")
        }
        play.ask(17)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertTrue(play.runner.game.keywordAsked(17, person: 9), "Iris's wine answer")
        let summerDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 27)
        try OriginalChapterThreeRouteChecks.navigate(play, to: summerDoor + SIMD2<Float>(0, -8_000))
        OriginalChapterThreeRouteChecks.face(play, x: summerDoor.x, z: summerDoor.y)
        XCTAssertEqual(play.nearbyDoor, 27)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        guard case .questions(let summerTopics) = play.runner.phase,
              let wineTopic = summerTopics.first(where: { $0.label.localizedCaseInsensitiveContains("wine") }) else {
            return XCTFail("Expected Summer's wine question: \(play.runner.phase)")
        }
        play.ask(wineTopic.keyword)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertTrue(play.runner.game.keywordAsked(Int(wineTopic.keyword), person: 8), "Summer's wine answer")
        for destination: Int16 in [17, 26, 6] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
        }
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(-50_000, 15_000))
        let kitchen = try XCTUnwrap(play.lobby)
        let marker = try XCTUnwrap(kitchen.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-normal-wine-clues")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.useItem(play, 50, on: "obj06")
        XCTAssertEqual(play.runner.phase, .process(id: 46))

        for _ in 0..<65 { play.advanceFrame() }
        for y in stride(from: 52, through: 204, by: 8) {
            play.holdLabelPeelTouch(x: 36, y: Float(y))
            play.advanceFrame()
            for x in stride(from: 38, through: 156, by: 2) {
                play.holdLabelPeelTouch(x: Float(x), y: Float(y))
                play.advanceFrame()
            }
            play.releaseLabelPeelTouch()
            play.advanceFrame()
        }
        for _ in 0..<65 where play.labelPeel != nil { play.advanceFrame() }
        XCTAssertEqual(play.runner.session.selection.eventID, 9)
        play.advanceDialogue()
        XCTAssertEqual(play.labelPeel?.stage, .peel)
        for _ in 0..<65 { play.advanceFrame() }
        play.holdLabelPeelTouch(x: 150, y: 75)
        play.advanceFrame()
        play.holdLabelPeelTouch(x: 145, y: 75)
        play.advanceFrame()
        play.releaseLabelPeelTouch()
        play.advanceFrame()
        play.holdLabelPeelTouch(x: 150, y: 75)
        play.advanceFrame()
        play.holdLabelPeelTouch(x: 132, y: 75)
        play.advanceFrame()
        play.releaseLabelPeelTouch()
        play.advanceFrame()
        for _ in 0..<65 where play.labelPeel != nil { play.advanceFrame() }
        XCTAssertEqual(play.runner.session.selection.eventID, 10)
        play.advanceDialogue()
        guard case .itemNotice(let itemID, _) = play.runner.phase else {
            return XCTFail("Successful label peel should award the wine label: \(play.runner.phase)")
        }
        XCTAssertEqual(itemID, 66)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(66))
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 6))
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-after-label-peel")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        let helenDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 28)
        try OriginalChapterThreeRouteChecks.navigate(play, to: helenDoor + SIMD2<Float>(0, -8_000))
        OriginalChapterThreeRouteChecks.face(play, x: helenDoor.x, z: helenDoor.y)
        XCTAssertEqual(play.nearbyDoor, 28)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        if play.runner.game.mapID == 39 {
            try OriginalChapterThreeRouteChecks.doorComponent(play, 2, interrupt: true)
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 28))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(66))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter6-helen-room")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSix08HelenStoryAndChapterSevenEntryFromHandoffSave() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter6-helen-room")).load() else {
            throw XCTSkip("Generate the Helen-room handoff save through the Chapter 6 route first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        func assertChoiceIDs(_ expected: [UInt16]) {
            guard case .choice(let choices) = play.runner.phase else {
                XCTFail("Expected choices \(expected): \(play.runner.phase)")
                return
            }
            XCTAssertEqual(choices.map(\.id), expected)
        }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 28))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(66), "Helen's wine label handoff")
        try OriginalChapterThreeRouteChecks.talk(play, to: 7)
        play.ask(18)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.showItemInConversation(66)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.leaveConversation()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.choose(32)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.choose(34)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(19)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.choose(36)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(21)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(20)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.choose(38)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(22)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(23)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))

        let summerDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 27)
        try OriginalChapterThreeRouteChecks.navigate(play, to: summerDoor + SIMD2<Float>(0, -8_000), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: summerDoor.x, z: summerDoor.y)
        XCTAssertEqual(play.nearbyDoor, 27)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 35))
        try OriginalChapterThreeRouteChecks.picture(play, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(27), "Summer's fountain pen")
        try OriginalChapterThreeRouteChecks.exit(play, to: 28, interrupt: true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 7)
        play.showItemInConversation(27)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(25)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        play.ask(24)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let review) = play.runner.phase else {
            return XCTFail("Expected the Chapter 6 memory review: \(play.runner.phase)")
        }
        XCTAssertEqual(review.map(\.id), [16, 17, 18])
        play.choose(17)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        assertChoiceIDs([19, 20, 21])
        play.choose(19)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        assertChoiceIDs([22, 23, 24])
        play.choose(24)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        assertChoiceIDs([25, 26, 27])
        play.choose(26)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        assertChoiceIDs([28, 29, 30])
        play.choose(28)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)

        XCTAssertTrue(play.chapterTransition?.stage == .prompt || play.chapterTransition?.stage == .title)
        XCTAssertEqual(play.runner.game.chapter, 6)
        XCTAssertEqual(play.runner.game.nowTime, 0)
        play.answerChapterSave(false)
        play.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-normal-entry")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenLeavesRoom215ForSecondFloorHallway() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-normal-entry")).load() else {
            throw XCTSkip("Complete the Chapter 6 review through the normal title transition first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.game.chapter, 6)
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-second-floor-hallway")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenReachesCentralHallwayFromSecondFloorHallway() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-second-floor-hallway")).load() else {
            throw XCTSkip("Leave Room 215 through the normal hallway route first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        XCTAssertEqual(play.runner.program.name, "EP7_R117")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-central-hallway")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenReachesBarFromCentralHallway() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-central-hallway")).load() else {
            throw XCTSkip("Reach R117 from Room 215 through the normal Chapter 7 route first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 26)
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 5)
        XCTAssertEqual(play.runner.program.name, "EP7_R105")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-bar")).save(play.walkingCheckpoint())
        XCTAssertTrue(play.lobby?.people(in: play.runner.game).contains { $0.id == 4 } == true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 4)
        guard case .choice(let drinks) = play.runner.phase else { return XCTFail("Expected Louie's drink menu") }
        XCTAssertEqual(drinks.map(\.label), ["Give me a scotch.", "I'll have a martini."])
        try OriginalChapterThreeRouteChecks.choose(play, "Give me a scotch.")
        guard case .choice(let secrets) = play.runner.phase else { return XCTFail("Expected Louie's follow-up choice") }
        XCTAssertEqual(secrets.map(\.label), ["Not this guy!", "I might..."])
        try OriginalChapterThreeRouteChecks.choose(play, "I might...")
        guard case .questions(let storyTopics) = play.runner.phase else { return XCTFail("Expected Louie's story topic") }
        XCTAssertEqual(storyTopics.map(\.label), ["What story did I tell you?"])
        play.ask(0)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let memoryChoices) = play.runner.phase else { return XCTFail("Expected Louie's story response") }
        XCTAssertEqual(memoryChoices.map(\.label), ["I don't remember this...", "I yelled at you, huh?"])
        try OriginalChapterThreeRouteChecks.choose(play, "I don't remember this...")
        guard case .questions(let fatherTopics) = play.runner.phase else { return XCTFail("Expected Louie's father topic") }
        XCTAssertEqual(fatherTopics.map(\.label), ["I told you about my father?"])
        play.ask(1)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let beliefTopics) = play.runner.phase else { return XCTFail("Expected Louie's belief topic") }
        XCTAssertEqual(beliefTopics.map(\.label), ["You believed my story?"])
        play.ask(2)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let beliefChoices) = play.runner.phase else { return XCTFail("Expected Louie's belief response") }
        XCTAssertEqual(beliefChoices.map(\.label), ["...It's a lie.", "It's true."])
        try OriginalChapterThreeRouteChecks.choose(play, "It's true.")
        guard case .choice(let bowlingChoices) = play.runner.phase else { return XCTFail("Expected Louie's bowling prompt") }
        XCTAssertEqual(bowlingChoices.map(\.label), ["I don't get it.", "I REALLY don't get it."])
        try OriginalChapterThreeRouteChecks.choose(play, "I don't get it.")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        try OriginalChapterThreeRouteChecks.talk(play, to: 8)
        guard case .choice(let summerTopics) = play.runner.phase else { return XCTFail("Expected Summer's topic choice") }
        XCTAssertEqual(summerTopics.map(\.label), ["Talk about Alan.", "Talk about plagiarism."])
        try OriginalChapterThreeRouteChecks.choose(play, "Talk about Alan.")
        guard case .choice(let summerTruth) = play.runner.phase else { return XCTFail("Expected Summer's truth choice") }
        XCTAssertEqual(summerTruth.map(\.label), ["I'll tell him the truth.", "I better lie to him."])
        try OriginalChapterThreeRouteChecks.choose(play, "I'll tell him the truth.")
        guard case .questions(let summerNews) = play.runner.phase else { return XCTFail("Expected Summer's news topic") }
        XCTAssertEqual(summerNews.map(\.label), ["What do you want to talk about?"])
        play.ask(3)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let cecilyTopic) = play.runner.phase else { return XCTFail("Expected Summer's Cecily topic") }
        XCTAssertEqual(cecilyTopic.map(\.label), ["Who is Cecily Lee?"])
        play.ask(4)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        XCTAssertEqual(play.runner.game.nowTime, 0)
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 26)
        XCTAssertEqual(play.runner.program.name, "EP7_R126")
        XCTAssertTrue(play.lobby?.people(in: play.runner.game).contains { $0.id == 11 } == true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 11)
        guard case .choice(let presents) = play.runner.phase else { return XCTFail("Expected Melissa's presents choice") }
        XCTAssertEqual(presents.map(\.label), ["I'm not a presents guy.", "Oh, yeah. Tons."])
        try OriginalChapterThreeRouteChecks.choose(play, "I'm not a presents guy.")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        let rosaRegion = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "event03" })
        try OriginalChapterThreeRouteChecks.navigate(play,
            to: SIMD2(Float(rosaRegion.worldFixed[12]), Float(rosaRegion.worldFixed[14])), interrupt: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let rosaTopics) = play.runner.phase else { return XCTFail("Expected Rosa's Melissa response") }
        XCTAssertEqual(rosaTopics.map(\.label), ["Her dad's a jerk.", "She misses her mom."])
        try OriginalChapterThreeRouteChecks.choose(play, "She misses her mom.")
        XCTAssertEqual(play.runner.phase, .questions([]))
        play.leaveConversation()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let treeChoices) = play.runner.phase else { return XCTFail("Expected Rosa's tree answer") }
        XCTAssertEqual(treeChoices.map(\.label), ["She didn't get one.", "Don't know. Don't care."])
        try OriginalChapterThreeRouteChecks.choose(play, "She didn't get one.")
        XCTAssertEqual(play.runner.game.nowTime, 1)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-after-rosa")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 3)
        try OriginalChapterThreeRouteChecks.exit(play, to: 18, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 18)
        try OriginalChapterThreeRouteChecks.exit(play, to: 22, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 22)
        XCTAssertEqual(play.runner.program.name, "EP7_R122")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-storage")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenStorageSearchAreaFromCheckpoint() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-storage")).load() else {
            throw XCTSkip("Reach Chapter 7 storage through the normal route first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) },
            bagSearchRendererFactory: { try OriginalRouteBitmapBagSearchRenderer() })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2(13598, -1065), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: 13598, z: -1065)
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let hits = try stride(from: 8, to: 248, by: 8).flatMap { y in
            stride(from: 8, to: 184, by: 8).map { SIMD2<Float>(Float($0), Float(y)) }
        }.compactMap { try counter.pickedCounterNode(page: $0, visibleNodes: visible) }
        XCTAssertTrue(hits.contains { $0 == "obj01_08" })
        try OriginalChapterThreeRouteChecks.search(play, node: "obj01_08", interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 55))
        let bagSearch = try XCTUnwrap(play.bagSearch)
        let library = try OriginalModelLibrary.bundled()
        let model = try library.load(path: "trick/searchshed/soko.mdf")
        let projection = try OriginalBagSearchProjection(models: [model])
        let treeBox = try XCTUnwrap(bagSearch.objects.firstIndex { $0.type == 3 })
        func visibleTouchPoints(_ process: OriginalBagSearchProcess) throws -> [Int: SIMD2<Float>] {
            let masks = try projection.objectMasks(process: process)
            var points = [Int: SIMD2<Float>]()
            for y in stride(from: 0, to: 256, by: 4) {
                for x in stride(from: 0, to: 192, by: 4) {
                    let point = SIMD2<Float>(Float(x), Float(y))
                    guard projection.planePointFixed(at: point) != nil else { continue }
                    let nearest = masks.compactMap { index, mask in
                        mask.depth(at: point).map { (index, $0) }
                    }.min { $0.1 < $1.1 }
                    if let nearest, points[nearest.0] == nil { points[nearest.0] = point }
                }
            }
            return points
        }

        var visiblePoints = try visibleTouchPoints(bagSearch)
        let destination = SIMD2<Float>(0, 255)
        XCTAssertNotNil(projection.planePointFixed(at: destination))
        for _ in 0..<30 where visiblePoints[treeBox] == nil {
            guard let blocker = visiblePoints.keys.sorted().first(where: { $0 != treeBox }),
                  let start = visiblePoints[blocker] else { break }
            play.holdBagSearchTouch(x: start.x, y: start.y)
            play.holdBagSearchTouch(x: destination.x, y: destination.y)
            play.releaseBagSearchTouch()
            visiblePoints = try visibleTouchPoints(XCTUnwrap(play.bagSearch))
        }
        let start = try XCTUnwrap(visiblePoints[treeBox])
        let startPlane = try XCTUnwrap(projection.planePointFixed(at: start))
        let initialPosition = bagSearch.objects[treeBox].positionFixed
        let targetPlane = SIMD2(startPlane.x - initialPosition.x, startPlane.y - initialPosition.z)
        let clip = projection.viewProjection * SIMD4(Float(targetPlane.x) / 4096, 0,
                                                     Float(targetPlane.y) / 4096, 1)
        let target = SIMD2((clip.x / clip.w + 1) * 96, (1 - clip.y / clip.w) * 128)
        let roundTrip = try XCTUnwrap(projection.planePointFixed(at: target))
        XCTAssertLessThanOrEqual(abs(Int64(roundTrip.x) - Int64(targetPlane.x)), 256)
        XCTAssertLessThanOrEqual(abs(Int64(roundTrip.y) - Int64(targetPlane.y)), 256)
        play.holdBagSearchTouch(x: start.x, y: start.y)
        play.holdBagSearchTouch(x: target.x, y: target.y)
        play.releaseBagSearchTouch()
        XCTAssertEqual(play.bagSearch?.phase, .found)
        play.openBagSearchMenu()
        for _ in 0..<70 where play.bagSearch != nil { play.advanceFrame() }
        XCTAssertNil(play.bagSearch)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 43))
        for _ in 0..<70 { play.advanceFrame() }
        let treeRenderer = try OriginalChristmasTreeRenderer(library: .bundled())
        for (slot, decoration) in try XCTUnwrap(play.christmasTree).decorationOrder.enumerated() {
            let tree = try XCTUnwrap(play.christmasTree)
            let centreX = 9 + slot * 17
            let start = try XCTUnwrap((232..<249).lazy.flatMap { y in
                (max(0, centreX - 8)..<min(192, centreX + 9)).lazy.map { SIMD2<Float>(Float($0), Float(y)) }
            }.first { treeRenderer.decoration(at: $0, process: tree) == decoration })
            let destination = OriginalChristmasTreeLayout.pageDecorationTargets[slot]
            play.holdChristmasTreeTouch(x: start.x, y: start.y)
            play.releaseChristmasTreeTouch(x: destination.x, y: destination.y)
        }
        XCTAssertEqual(play.christmasTree?.arrangement.decorationAtTarget.compactMap { $0 }, Array(0..<11))
        for _ in 0..<100 where play.christmasTree != nil { play.advanceFrame() }
        XCTAssertNil(play.christmasTree)
        XCTAssertEqual(play.runner.game.christmasTreeDecorationOrder, 0xE400)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 4, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 22))
        XCTAssertEqual(play.runner.eventTrail, [13])
        try OriginalChapterThreeRouteChecks.talk(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 22))
        XCTAssertEqual(play.runner.eventTrail, [13, 14])
        func walkInput(to target: SIMD2<Float>) {
            for _ in 0..<500 {
                guard case .exploration = play.runner.phase, let position = play.lobby?.position else { break }
                let dx = target.x - position.x, dz = target.y - position.z, distance = hypot(dx, dz)
                if distance < 500 { break }
                play.holdLobbyTouch(x: 96 + dx / distance * 80, y: 128 + dz / distance * 80)
                play.advanceFrame()
            }
            play.releaseLobbyTouch()
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        walkInput(to: SIMD2(-5000, 11000))
        walkInput(to: SIMD2(-20000, 8000))
        OriginalChapterThreeRouteChecks.face(play, x: -14254, z: 7700)
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 11)
        play.talkToNearbyPerson()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 22))
        try OriginalChapterThreeRouteChecks.talk(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 16))
        try OriginalChapterThreeRouteChecks.picture(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 22))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-after-tree")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenDunningAndKevinAtTenForty() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-after-tree")).load() else {
            throw XCTSkip("Complete the Chapter 7 tree scene through the normal route first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 18, interrupt: true, expectArrival: false)
        XCTAssertEqual(play.runner.game.mapID, 18)
        XCTAssertEqual(play.runner.program.name, "EP7_R118")
        XCTAssertEqual(play.runner.game.nowTime, 1)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-right-hallway")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 12, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 12)
        XCTAssertEqual(play.runner.program.name, "EP7_R112")
        let room = try XCTUnwrap(play.lobby)
        let photoMarker = try XCTUnwrap(room.room.nodes.first { $0.name == "s04" })
        func walkInput(to target: SIMD2<Float>) {
            for _ in 0..<500 {
                guard case .exploration = play.runner.phase, let position = play.lobby?.position else { break }
                let dx = target.x - position.x, dz = target.y - position.z, distance = hypot(dx, dz)
                if distance < 500 { break }
                play.holdLobbyTouch(x: 96 + dx / distance * 80, y: 128 + dz / distance * 80)
                play.advanceFrame()
            }
            play.releaseLobbyTouch()
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        walkInput(to: SIMD2(-9500, -8000))
        walkInput(to: SIMD2(-9500, 25000))
        OriginalChapterThreeRouteChecks.face(play, x: Float(photoMarker.worldFixed[12]), z: Float(photoMarker.worldFixed[14]))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 4)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj03", closeupEvent: 73, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 12)
        XCTAssertEqual(play.runner.program.name, "EP7_R112")
        XCTAssertEqual(play.runner.game.nowTime, 1)
        try OriginalChapterThreeRouteChecks.exit(play, to: 18, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 18)
        walkInput(to: SIMD2(10_000, -10_000))
        walkInput(to: SIMD2(10_000, 5_000))
        walkInput(to: SIMD2(-25_000, 5_000))
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 3)
        try OriginalChapterThreeRouteChecks.exit(play, to: 2, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 2)
        XCTAssertEqual(play.runner.game.nowTime, 2)
        XCTAssertTrue(play.lobby?.people(in: play.runner.game).contains { $0.id == 10 } == true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 10, interrupt: true)
        guard case .choice(let kyleConcerns) = play.runner.phase else { return XCTFail("Expected Kevin's first conversation choices") }
        XCTAssertEqual(kyleConcerns.map(\.label), ["You OK?", "You're really plowed, doc!"])
        try OriginalChapterThreeRouteChecks.choose(play, "You OK?")
        guard case .questions(let kevinTopics) = play.runner.phase else { return XCTFail("Expected Kevin's drinking topic") }
        XCTAssertEqual(kevinTopics.map(\.label), ["Who were you drinking with?"])
        play.ask(7)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        walkInput(to: SIMD2(10_000, -5_000))
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 3)
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 26)
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 5)
        XCTAssertEqual(play.runner.game.nowTime, 2)
        XCTAssertTrue(play.lobby?.people(in: play.runner.game).contains { $0.id == 4 } == true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 4, interrupt: true)
        guard case .questions(let louieTopics) = play.runner.phase else { return XCTFail("Expected Louie's 10:40 topics") }
        XCTAssertEqual(louieTopics.map(\.keyword), [6, 8])
        play.ask(8)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let galleryLead) = play.runner.phase else { return XCTFail("Expected Louie's drinking follow-up") }
        XCTAssertEqual(galleryLead.map(\.keyword), [6, 9])
        play.ask(9)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let galleryTopic) = play.runner.phase else { return XCTFail("Expected Louie's Gallery May topic") }
        XCTAssertEqual(galleryTopic.map(\.keyword), [6, 10])
        play.ask(10)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let photoTopic) = play.runner.phase else { return XCTFail("Expected Louie's photo topic") }
        XCTAssertEqual(photoTopic.map(\.keyword), [6])
        play.ask(6)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-after-louie-10-40")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterSevenLeavesBarForIris() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter7-after-louie-10-40")).load() else {
            throw XCTSkip("Complete the Chapter 7 Louie conversation first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 26)
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        try OriginalChapterThreeRouteChecks.exit(play, to: 19, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 19)
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39)
        let irisDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 32)
        try OriginalChapterThreeRouteChecks.navigate(play, to: irisDoor + SIMD2<Float>(0, -8_000), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: irisDoor.x, z: irisDoor.y)
        XCTAssertEqual(play.nearbyDoor, 32, "Iris's Room 216 door at \(irisDoor), Kyle at \(play.lobby?.position as Any)")
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 32)
        XCTAssertEqual(play.runner.program.name, "EP7_R206")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-iris-room-arrival")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.talk(play, to: 9, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "What's odd?")
        guard case .questions(let irisTopics) = play.runner.phase else {
            return XCTFail("Expected Iris's odd-suitcase topic: \(play.runner.phase)")
        }
        XCTAssertEqual(irisTopics.map(\.label), ["Was anything stolen?", "What about the gallery?"])
        play.ask(11)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let envelopeTopics) = play.runner.phase else {
            return XCTFail("Expected Iris's envelope topics: \(play.runner.phase)")
        }
        XCTAssertEqual(envelopeTopics.map(\.keyword), [12, 13])
        play.ask(13)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let whoGaveIt) = play.runner.phase else {
            return XCTFail("Expected Iris's envelope source topic: \(play.runner.phase)")
        }
        XCTAssertEqual(whoGaveIt.map(\.keyword), [12, 14])
        play.ask(14)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let graceTopics) = play.runner.phase else {
            return XCTFail("Expected Iris's Grace topic: \(play.runner.phase)")
        }
        XCTAssertEqual(graceTopics.map(\.keyword), [12, 15])
        play.ask(15)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let galleryTopics) = play.runner.phase else {
            return XCTFail("Expected Iris's gallery topic: \(play.runner.phase)")
        }
        XCTAssertEqual(galleryTopics.map(\.keyword), [12])
        play.ask(12)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let galleryFollowUps) = play.runner.phase else {
            return XCTFail("Expected Iris's gallery follow-up choice: \(play.runner.phase)")
        }
        XCTAssertEqual(galleryFollowUps.map(\.label), ["What's the owner's name?", "How do you know it?"])
        play.choose(galleryFollowUps[0].id)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter7-after-iris")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 2, interrupt: true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 10, interrupt: true)
        guard case .choice(let kevinOpening) = play.runner.phase else {
            return XCTFail("Expected Kevin's Chapter 7 opening: \(play.runner.phase)")
        }
        XCTAssertEqual(kevinOpening.map(\.label), ["Don't get mad at me!", "You two had business?"])
        try OriginalChapterThreeRouteChecks.choose(play, "You two had business?", interrupt: true)
        guard case .choice(let kevinReason) = play.runner.phase else {
            return XCTFail("Expected Kevin's reason follow-up: \(play.runner.phase)")
        }
        XCTAssertEqual(kevinReason.map(\.label), ["You're a loser, doc!", "I got reasons for asking."])
        try OriginalChapterThreeRouteChecks.choose(play, "I got reasons for asking.", interrupt: true)
        guard case .questions(let kevinTopics) = play.runner.phase else {
            return XCTFail("Expected Kevin's story topics: \(play.runner.phase)")
        }
        XCTAssertEqual(kevinTopics.map(\.keyword), [16, 17])
        play.ask(16)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let irisChoices) = play.runner.phase else {
            return XCTFail("Expected Kevin's Iris response choices: \(play.runner.phase)")
        }
        XCTAssertEqual(irisChoices.map(\.label), ["I believe you just met.", "I bet you're lovers!"])
        try OriginalChapterThreeRouteChecks.choose(play, "I believe you just met.", interrupt: true)
        guard case .questions(let graceQuestion) = play.runner.phase else {
            return XCTFail("Expected Kevin's Grace topics: \(play.runner.phase)")
        }
        XCTAssertEqual(graceQuestion.map(\.keyword), [17, 19])
        play.ask(19)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let afterGrace) = play.runner.phase else {
            return XCTFail("Expected Kevin's follow-up topics: \(play.runner.phase)")
        }
        XCTAssertEqual(afterGrace.map(\.keyword), [17, 20])
        play.ask(20)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .questions(let galleryOnly) = play.runner.phase else {
            return XCTFail("Expected Gallery May as Kevin's remaining topic: \(play.runner.phase)")
        }
        XCTAssertEqual(galleryOnly.map(\.keyword), [17])
        play.ask(17)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let galleryResponses) = play.runner.phase else {
            return XCTFail("Expected Kevin's Gallery May response: \(play.runner.phase)")
        }
        XCTAssertEqual(galleryResponses.map(\.label), ["You worked there, too.", "You never worked there."])
        try OriginalChapterThreeRouteChecks.choose(play, "You never worked there.", interrupt: true)
        guard case .questions(let graceTopic) = play.runner.phase else {
            return XCTFail("Expected Kevin's Grace topic: \(play.runner.phase)")
        }
        XCTAssertEqual(graceTopic.map(\.keyword), [18])
        play.ask(18)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let graceChoices) = play.runner.phase else {
            return XCTFail("Expected Kevin's fault choices: \(play.runner.phase)")
        }
        XCTAssertEqual(graceChoices.map(\.label), ["It was Melissa.", "It was you."])
        try OriginalChapterThreeRouteChecks.choose(play, "It was you.", interrupt: true)
        guard case .questions(let faultTopic) = play.runner.phase else {
            return XCTFail("Expected Kevin's malpractice question: \(play.runner.phase)")
        }
        XCTAssertEqual(faultTopic.map(\.keyword), [21])
        play.ask(21)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard case .choice(let firstReviewAnswers) = play.runner.phase else {
            return XCTFail("Expected Chapter 7 review question 1: \(play.runner.phase)")
        }
        XCTAssertEqual(firstReviewAnswers.map(\.label), ["Rosa", "Melissa", "Iris"])
        try OriginalChapterThreeRouteChecks.choose(play, "Melissa", interrupt: true)
        guard case .choice(let secondReviewAnswers) = play.runner.phase else {
            return XCTFail("Expected Chapter 7 review question 2: \(play.runner.phase)")
        }
        XCTAssertEqual(secondReviewAnswers.map(\.label), ["Storage", "Rosa's room", "Kitchen"])
        try OriginalChapterThreeRouteChecks.choose(play, "Storage", interrupt: true)
        guard case .choice(let thirdReviewAnswers) = play.runner.phase else {
            return XCTFail("Expected Chapter 7 review question 3: \(play.runner.phase)")
        }
        XCTAssertEqual(thirdReviewAnswers.map(\.label), ["Kevin", "Dunning", "Louie"])
        try OriginalChapterThreeRouteChecks.choose(play, "Louie", interrupt: true)
        guard case .choice(let fourthReviewAnswers) = play.runner.phase else {
            return XCTFail("Expected Chapter 7 review question 4: \(play.runner.phase)")
        }
        XCTAssertEqual(fourthReviewAnswers.map(\.label), ["Seven Stars", "Gallery May", "Moonlight Grill"])
        try OriginalChapterThreeRouteChecks.choose(play, "Gallery May", interrupt: true)
        guard case .choice(let fifthReviewAnswers) = play.runner.phase else {
            return XCTFail("Expected Chapter 7 review question 5: \(play.runner.phase)")
        }
        XCTAssertEqual(fifthReviewAnswers.map(\.label), ["A small envelope", "A matchbook", "A fountain pen"])
        try OriginalChapterThreeRouteChecks.choose(play, "A small envelope", interrupt: true)
        XCTAssertTrue(play.chapterTransition?.stage == .prompt || play.chapterTransition?.stage == .title)
        XCTAssertEqual(play.runner.game.chapter, 7)
        XCTAssertEqual(play.runner.game.nowTime, 0)
        play.answerChapterSave(false)
        play.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-normal-entry")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightAnswersEdPhoneCallAndEntersCorridor() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-normal-entry")).load() else {
            throw XCTSkip("Complete the Chapter 7 review through its normal title transition first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.game.chapter, 7)
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true, expectArrival: false)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(-16_687, 7_450), interrupt: true)
        play.inspectLobbyCounter()
        play.selectLobbyObject(x: 86, y: 165, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.eventTrail, [1, 2, 3, 4, 5, 7])
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(play.runner.program.name, "EP8_R213")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-r213-entry")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightEntersUtilityClosetFromCorridor() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r213-entry")).load() else {
            throw XCTSkip("Reach R213 through the normal Chapter 8 route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 38, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 38))
        XCTAssertEqual(play.runner.game.chapter, 7)
        XCTAssertEqual(play.runner.program.name, "EP8_R212")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-r212-utility-closet")).save(play.walkingCheckpoint())
    }

    @MainActor func testWalkingViewPicksVisibleRoomObjectByHitMask() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r213-entry")).load() else {
            throw XCTSkip("Reach R213 through the normal Chapter 8 route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(-86_000, 4_000), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: -102_662, z: 3_539)
        let lobby = try XCTUnwrap(play.lobby)
        let visible = lobby.objectVisibility.visibleNodes(in: lobby.room, map: lobby.mapID, area: nil,
            game: play.runner.game).intersection(lobby.room.gameplayRenderNodes)
        let node = try XCTUnwrap(lobby.room.nodes.first { $0.name == "obj05" })
        let world = SIMD4<Float>(Float(node.worldFixed[12]) / 4096,
            Float(node.worldFixed[13]) / 4096, Float(node.worldFixed[14]) / 4096, 1)
        let clip = lobby.viewProjection * world
        let centre = SIMD2<Float>((clip.x / clip.w + 1) * 96, (1 - clip.y / clip.w) * 128)
        let points = stride(from: -12, through: 12, by: 2).flatMap { y in
            stride(from: -12, through: 12, by: 2).map { x in centre + SIMD2(Float(x), Float(y)) }
        }
        let hit = try XCTUnwrap(try points.first {
            try lobby.pickedRoomObject(page: $0, visibleNodes: visible) == "obj05"
        }, "The visible room-object mesh must accept a direct 3D tap")
        XCTAssertEqual(try lobby.pickedRoomObject(page: hit, visibleNodes: visible), "obj05")
    }

    @MainActor func testChapterEightInspectsUtilityClosetSearchArea() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r212-utility-closet")).load() else {
            throw XCTSkip("Enter the utility closet through the normal Chapter 8 route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.navigate(play, to: .init(4096, 16138))
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s04" })
        play.turnFirstPerson(by: atan2(Float(marker.worldFixed[12]) - (play.lobby?.position.x ?? 0),
            Float(marker.worldFixed[14]) - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 4)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let points = stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }
        let trashBin = try XCTUnwrap(try points.first {
            try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj04"
        }, "The utility-closet trash bin must be selectable through its original hit mesh")
        play.selectLobbyObject(x: trashBin.x, y: trashBin.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 315)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 316, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(69))
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 319, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(42))
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-r212-items-recovered")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightReturnsToRoom215AfterFindingEnvelopeAndTape() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r212-items-recovered")).load() else {
            throw XCTSkip("Find the envelope and tape through the Chapter 8 utility-closet route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 31, interrupt: true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-r205-after-closet")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightTravelsFromRoom215ToTheBar() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r205-after-closet")).load() else {
            throw XCTSkip("Return to Room 215 after searching the utility closet first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        XCTAssertEqual(play.runner.program.name, "EP8_R105")
        try OriginalChapterThreeRouteChecks.talk(play, to: 4, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "Someone else wanted it?", interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 5))
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 29)), true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-bar-after-closet")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightReturnsToTheCorridorFromTheBar() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-bar-after-closet")).load() else {
            throw XCTSkip("Reach the Chapter 8 bar and ask Louie about the cassette player first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 26, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 26))
        XCTAssertEqual(play.runner.program.name, "EP8_R126")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-r126-after-bar")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightReturnsToRoom215AfterLouieTopic() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r126-after-bar")).load() else {
            throw XCTSkip("Reach R126 after asking Louie about the cassette player first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) },
            suitcaseContentsRendererFactory: { try BitmapSuitcaseContentsRenderer() })
        defer { play.stop() }

        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 31, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.game.value(for: .gameFlag(index: 29)), true)
        XCTAssertFalse(try play.runner.game.inventory.items.contains(44))
        let lobby = try XCTUnwrap(play.lobby)
        let collision = lobby.collision
        let searchPoints = stride(from: -60_000, through: 60_000, by: 1_024).flatMap { x in
            stride(from: -60_000, through: 60_000, by: 1_024).compactMap { z -> SIMD2<Float>? in
                let point = SIMD3<Float>(Float(x), lobby.position.y, Float(z))
                return collision.matchingRegions(containing: point, prefix: "search").contains("search03")
                    ? SIMD2<Float>(Float(x), Float(z)) : nil
            }
        }
        let searchPoint = try XCTUnwrap(searchPoints.min {
            simd_distance($0, SIMD2(lobby.position.x, lobby.position.z))
                < simd_distance($1, SIMD2(lobby.position.x, lobby.position.z))
        }, "Room 215 must contain a third search area")
        try OriginalChapterThreeRouteChecks.navigate(play, to: searchPoint, interrupt: true)
        let marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(marker.worldFixed[12]), z: Float(marker.worldFixed[14]))
        for _ in 0..<100 where play.lobby?.nearbySearchArea != 3 {
            guard case .exploration(mapID: 31) = play.runner.phase, let position = play.lobby?.position else { break }
            let dx = searchPoint.x - position.x, dz = searchPoint.y - position.z
            let distance = hypot(dx, dz)
            if distance < 5 { break }
            play.holdLobbyTouch(x: 96 + dx / distance * 80, y: 128 + dz / distance * 80)
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj04", interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 35))
        try OriginalChapterThreeRouteChecks.takeFromSuitcase(play, lowerIndex: 5, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(44))
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        XCTAssertEqual(play.lobby?.mode, .walking)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-r205-pencil-collected")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightRewindsAndUsesCassetteDeck() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r205-pencil-collected")).load() else {
            throw XCTSkip("Collect the pencil from the open suitcase first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) },
            cassetteRendererFactory: { _ in try BitmapRouteCassetteRenderer() },
            cassetteDeckRendererFactory: { try BitmapCassetteDeckRenderer() })
        defer { play.stop() }

        XCTAssertTrue(try play.runner.game.inventory.items.contains(44))
        for destination: Int16 in [39, 17, 26, 5, 26, 17, 19, 14] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
            XCTAssertEqual(play.runner.game.mapID, destination)
        }
        XCTAssertEqual(play.runner.program.name, "EP8_R114")

        let deskLobby = try XCTUnwrap(play.lobby)
        let deskSearchPoints = stride(from: -60_000, through: 60_000, by: 1_024).flatMap { x in
            stride(from: -60_000, through: 60_000, by: 1_024).compactMap { z -> SIMD2<Float>? in
                let point = SIMD3<Float>(Float(x), deskLobby.position.y, Float(z))
                return deskLobby.collision.matchingRegions(containing: point, prefix: "search").contains("search03")
                    && simd_distance(deskLobby.collision.resolve(point), point) < 1
                    ? SIMD2<Float>(Float(x), Float(z)) : nil
            }
        }
        let deskTarget = try XCTUnwrap(deskSearchPoints.min {
            simd_distance($0, SIMD2(deskLobby.position.x, deskLobby.position.z))
                < simd_distance($1, SIMD2(deskLobby.position.x, deskLobby.position.z))
        }, "R114 search area 3 is missing")
        try OriginalChapterThreeRouteChecks.navigate(play, to: deskTarget, interrupt: true)
        let deskMarker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s03" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(deskMarker.worldFixed[12]), z: Float(deskMarker.worldFixed[14]))
        for _ in 0..<100 where play.lobby?.nearbySearchArea != 3 {
            guard case .exploration(mapID: 14) = play.runner.phase, let position = play.lobby?.position else { break }
            let dx = deskTarget.x - position.x, dz = deskTarget.y - position.z
            let distance = hypot(dx, dz)
            if distance < 5 { break }
            play.holdLobbyTouch(x: 96 + dx / distance * 80, y: 128 + dz / distance * 80)
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let deskCounter = try XCTUnwrap(play.lobby)
        let deskVisible = deskCounter.objectVisibility.visibleNodes(in: deskCounter.counter,
            map: deskCounter.mapID, area: deskCounter.searchAreaID, game: play.runner.game)
        let deskPoint = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { (try? deskCounter.pickedCounterNode(page: $0, visibleNodes: deskVisible)) == "obj06" },
            "Louie's desk hit mask is missing")
        play.selectLobbyObject(x: deskPoint.x, y: deskPoint.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 110)
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 112, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(74),
            "Inspecting the desk should award the ballpoint pen through its original item notice")
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()

        let lobby = try XCTUnwrap(play.lobby)
        let searchPoints = stride(from: -60_000, through: 60_000, by: 1_024).flatMap { x in
            stride(from: -60_000, through: 60_000, by: 1_024).compactMap { z -> SIMD2<Float>? in
                let point = SIMD3<Float>(Float(x), lobby.position.y, Float(z))
                return lobby.collision.matchingRegions(containing: point, prefix: "search").contains("search01")
                    && simd_distance(lobby.collision.resolve(point), point) < 1
                    ? SIMD2<Float>(Float(x), Float(z)) : nil
            }
        }
        let target = try XCTUnwrap(searchPoints.min {
            simd_distance($0, SIMD2(lobby.position.x, lobby.position.z))
                < simd_distance($1, SIMD2(lobby.position.x, lobby.position.z))
        }, "R114 search area 1 is missing")
        try OriginalChapterThreeRouteChecks.navigate(play, to: target, interrupt: true)
        let r114Marker = try XCTUnwrap(play.lobby?.room.nodes.first { $0.name == "s01" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(r114Marker.worldFixed[12]), z: Float(r114Marker.worldFixed[14]))
        for _ in 0..<100 where play.lobby?.nearbySearchArea != 1 {
            guard case .exploration(mapID: 14) = play.runner.phase, let position = play.lobby?.position else { break }
            let dx = target.x - position.x, dz = target.y - position.z
            let distance = hypot(dx, dz)
            if distance < 5 { break }
            play.holdLobbyTouch(x: 96 + dx / distance * 80, y: 128 + dz / distance * 80)
            play.advanceFrame()
        }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbySearchArea, 1)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let radioPoint = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { (try? counter.pickedCounterNode(page: $0, visibleNodes: visible)) == "obj06" },
            "The radio hit mask must be visible")
        play.selectLobbyObject(x: radioPoint.x, y: radioPoint.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 107)
        XCTAssertEqual(Set(play.closeup?.view.layers.map(\.eventID) ?? []), Set([108, 109]))
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 108, item: 42, interrupt: true)
        XCTAssertFalse(try play.runner.game.inventory.items.contains(42), "Placing the tape on the deck should remove it from inventory")
        XCTAssertTrue(play.runner.game.objectVisible(34), "Placing the tape should reveal the exposed tape layer")
        XCTAssertEqual(play.closeup?.view.id, 107)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(74), "The ballpoint must be available for the first tape attempt")
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 109, item: 74, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 76), "The ballpoint selector routes to the original process 76")
        play.holdCassetteTouch(pageX: 170, pageY: 240)
        play.advanceFrame()
        play.releaseCassetteTouch()
        for _ in 0..<70 { play.advanceFrame() }
        XCTAssertNotEqual(play.runner.phase, .process(id: 76), "The normal slot-5 exit must return from the ballpoint process")
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 107, "The ballpoint response should return to the cassette close-up")
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 109, item: 44, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 45), "The pencil selector routes to the original rewind process")
        for raw in [SIMD2(141, 130)] + stride(from: 140, through: 135, by: -1).map({ SIMD2($0, 130) })
            + stride(from: 129, through: 100, by: -1).map({ SIMD2(135, $0) })
            + Array(repeating: SIMD2(135, 100), count: 5) {
            play.holdCassetteTouch(pageX: raw.y, pageY: 255 - raw.x)
            play.advanceFrame()
        }
        play.releaseCassetteTouch()
        for _ in 0..<24 { play.advanceFrame() }
        XCTAssertNotEqual(play.runner.phase, .process(id: 45), "The matched pencil stroke must return from the rewind process")
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(43), "Successful rewinding returns the repaired cassette item")
        try OriginalChapterThreeRouteChecks.closeupLayer(play, event: 108, item: 43, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 52), "The repaired cassette launches its Cassette02 process")

        play.holdCassetteTouch(pageX: 156, pageY: 179)
        play.advanceFrame()
        play.releaseCassetteTouch()
        for rawY in stride(from: 155, through: 108, by: -1) {
            play.holdCassetteTouch(pageX: rawY, pageY: 179)
            play.advanceFrame()
        }
        play.releaseCassetteTouch()
        for _ in 0..<OriginalCassetteDeckProcess.controlsTransitionUpdates { play.advanceFrame() }
        play.holdCassetteTouch(pageX: 143, pageY: 208)
        play.advanceFrame()
        play.releaseCassetteTouch()
        play.activateCassetteDeckControl()
        play.holdCassetteTouch(pageX: 177, pageY: 240)
        play.advanceFrame()
        play.releaseCassetteTouch()
        for _ in 0..<OriginalCassetteDeckProcess.exitFadeUpdates { play.advanceFrame() }
        XCTAssertNotEqual(play.runner.phase, .process(id: 52), "Cassette playback must return through the story CHK table")
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertTrue(play.runner.eventTrail.contains(20), "Side B should advance the Chapter 8 time block through R114 event 20")
        play.leaveSearchCloseup()
        play.leaveLobbyCounter()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 19))
        XCTAssertEqual(play.runner.program.name, "EP8_R119")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-r119-after-cassette")).save(play.walkingCheckpoint())
        XCTAssertEqual(play.runner.program.name, "EP8_R119")
    }

    @MainActor func testChapterEightCassetteRouteContinuesThroughIrisConversation() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r119-after-cassette")).load() else {
            throw XCTSkip("Complete the cassette-deck route and reach Louie's room first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        XCTAssertEqual(play.runner.game.mapID, 19)
        XCTAssertEqual(play.runner.program.name, "EP8_R119")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 19))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(43), "The repaired cassette remains available after playback")
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 3, index: 9)), false,
            "Chapter 8 starts with this event-completion bit clear")
        XCTAssertEqual(play.runner.game.nowTime, 1)
        for destination: Int16 in [17, 39] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
        }
        let irisDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 32)
        try OriginalChapterThreeRouteChecks.navigate(play, to: irisDoor + SIMD2<Float>(0, -8_000))
        OriginalChapterThreeRouteChecks.face(play, x: irisDoor.x, z: irisDoor.y)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(69))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(43))
        play.ask(0)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [], show: [69, 43])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 32))
        XCTAssertTrue(play.lobby?.people(in: play.runner.game).contains(where: { $0.id == 9 }) == true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 9, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "Why bring it here?", interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "You didn't know?", interrupt: true)
        play.ask(1)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "The tape is insurance.", interrupt: true)
        play.ask(2)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "You recognized it.", interrupt: true)
        play.ask(3)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "It's because she vanished.", interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: ["I bet it was dirty money."], topics: [4, 6, 5])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        for topic in [1, 2, 3, 4, 5, 6] {
            XCTAssertTrue(play.runner.game.keywordAsked(topic, person: 9), "Iris topic \(topic) should be covered")
        }
        XCTAssertEqual(play.runner.game.nowTime, 2, "Iris's completed conversation advances the chapter to 11:20 PM")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-iris")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightReturnsToLouiesCorridorAfterIris() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-after-iris")).load() else {
            throw XCTSkip("Complete Iris's Chapter 8 conversation first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        XCTAssertEqual(play.runner.game.nowTime, 2)
        for destination: Int16 in [17, 19] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
        }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 19))
        XCTAssertEqual(play.runner.program.name, "EP8_R119")
        XCTAssertEqual(play.runner.game.nowTime, 2)
        let louieDoor = try OriginalChapterThreeRouteChecks.doorMarker(play, 14)
        try OriginalChapterThreeRouteChecks.navigate(play, to: louieDoor + SIMD2<Float>(0, -8_000), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: louieDoor.x, z: louieDoor.y)
        XCTAssertEqual(play.nearbyDoor, 14)
        play.inspectNearbyDoor()
        let knockTrail = play.runner.eventTrail.count
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        XCTAssertEqual(play.runner.eventTrail.dropFirst(knockTrail), [4], "Louie's door knock should run R119 event 4")
        XCTAssertEqual(play.runner.game.mapID, 19)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 2, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 14, "The door handle should enter Louie's room")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-louie-room")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightTalksToLouieAfterIris() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-louie-room")).load() else {
            throw XCTSkip("Enter Louie's room after Iris's conversation first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        XCTAssertEqual(play.runner.game.mapID, 14)
        XCTAssertEqual(play.runner.program.name, "EP8_R114")
        let priorTrail = play.runner.eventTrail.count
        try OriginalChapterThreeRouteChecks.talk(play, to: 4, interrupt: true)
        XCTAssertEqual(play.runner.eventTrail.dropFirst(priorTrail), [22])
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 14, index: 22)), true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-louie-briefing")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightBowlingRouteResumesAfterProgressCheckpoint() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-after-louie-briefing")).load() else {
            throw XCTSkip("Talk to Louie in his room first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) },
            bowlingRendererFactory: { try RouteBowlingRenderer() })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 19, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 19))
        XCTAssertEqual(play.runner.program.name, "EP8_R119")
        XCTAssertTrue(play.lobby?.people(in: play.runner.game).contains { $0.id == 4 } == true)
        let priorTrail = play.runner.eventTrail.count
        try OriginalChapterThreeRouteChecks.talk(play, to: 4, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 44))
        XCTAssertEqual(play.runner.eventTrail.dropFirst(priorTrail), [6, 8])
        XCTAssertNotNil(play.bowlingMatch)
        XCTAssertEqual(play.bowlingMatch?.phase, .ready)
        let resumeCheckpoint = try play.progressCheckpoint()
        XCTAssertNotNil(resumeCheckpoint.progress)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-bowling-ready")).save(resumeCheckpoint)
        play.stop()

        let resumedAudio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        resumedAudio.isMuted = true
        try resumedAudio.applyOriginalCommand(.disableNewEffects(true))
        let resumed = try OriginalPlaySession.restoring(resumeCheckpoint, audio: resumedAudio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) },
            bowlingRendererFactory: { try RouteBowlingRenderer() })
        defer { resumed.stop() }
        XCTAssertEqual(resumed.runner.phase, .process(id: 44))
        XCTAssertEqual(resumed.bowlingMatch?.phase, .ready)
        resumed.resume()
        try resumedAudio.applyOriginalCommand(.disableNewEffects(false))
        try playCapturedBowlingThrow(0, in: resumed)
        XCTAssertEqual(resumed.bowlingMatch?.phase, .betweenThrows)
        XCTAssertEqual(resumed.bowlingMatch?.results.throwScores[0], 4)
        let throwCheckpoint = try resumed.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-bowling-after-throw-one")).save(throwCheckpoint)
        resumed.stop()

        let continuedAudio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        continuedAudio.isMuted = true
        try continuedAudio.applyOriginalCommand(.disableNewEffects(true))
        let continued = try OriginalPlaySession.restoring(throwCheckpoint, audio: continuedAudio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) },
            bowlingRendererFactory: { try RouteBowlingRenderer() })
        defer { continued.stop() }
        XCTAssertEqual(continued.runner.phase, .process(id: 44))
        XCTAssertEqual(continued.bowlingMatch?.phase, .betweenThrows)
        XCTAssertEqual(continued.bowlingMatch?.results.throwScores[0], 4)
        continued.resume()
        continued.enableInstantSaves()
        let instantSaveStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-bowling-instant-save-\(UUID().uuidString)"))
        var instantSaveError: Error?
        continued.onProgressCheckpoint = {
            do { try instantSaveStore.save($0) }
            catch { instantSaveError = error }
        }
        try continuedAudio.applyOriginalCommand(.disableNewEffects(false))

        for matchIndex in 0..<3 {
            for throwIndex in (matchIndex == 0 ? 1 : 0)..<5 {
                if throwIndex > 0 { continued.advanceFrame() }
                try playCapturedBowlingThrow(throwIndex, in: continued)
                if matchIndex == 0 && throwIndex == 1 {
                    XCTAssertNil(instantSaveError)
                    let throwCheckpoint = try XCTUnwrap(instantSaveStore.load(),
                        "Completing a bowling throw should persist an instant progress checkpoint")
                    XCTAssertNotNil(throwCheckpoint.progress)
                    XCTAssertEqual(throwCheckpoint.progress?.phase, "process-44")
                    XCTAssertEqual(throwCheckpoint.progress?.session, continued.runner.session)
                    continued.onProgressCheckpoint = nil
                    try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                        .appendingPathComponent("chapter8-bowling-after-throw-one")).save(throwCheckpoint)
                }
            }
            XCTAssertEqual(continued.bowlingMatch?.phase, .showingResult)
            XCTAssertEqual(continuedAudio.soundEffectsHistory,
                           Array(repeating: "SE_EVENT_BROKE_UEKIBACHI", count: matchIndex + 1))
            XCTAssertNil(continued.bowlingMatch?.returnValue)
            for _ in 0..<OriginalBowlingMatchProcess.resultAnimationFrames { continued.advanceFrame() }
            XCTAssertEqual(continued.bowlingMatch?.phase, .presentingResult)
            for _ in 0..<OriginalBowlingMatchProcess.resultPresentationFrames { continued.advanceFrame() }
            XCTAssertEqual(continued.bowlingMatch?.phase, .completed)
            XCTAssertEqual(continued.bowlingMatch?.returnValue, 2)
            continued.advanceFrame()
            XCTAssertEqual(continued.runner.session.selection.eventID, 11)
            try continuedAudio.applyOriginalCommand(.disableNewEffects(true))
            OriginalChapterThreeRouteChecks.drain(continued)
            XCTAssertEqual(continued.runner.phase, .process(id: 44))
            XCTAssertEqual(continued.runner.eventTrail.last, 8)
            try continuedAudio.applyOriginalCommand(.disableNewEffects(false))
        }
    }

    @MainActor func testChapterEightBowlingResultBranchesReachPlantOrRepeat() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-after-louie-briefing")).load() else {
            throw XCTSkip("Talk to Louie in his room first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) },
            bowlingRendererFactory: { try RouteBowlingRenderer() })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.exit(play, to: 19, interrupt: true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 4, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 44))

        var lostRunner = play.runner
        lostRunner.finishProcess(returnValue: 0)
        var lostDialogue = [String]()
        for _ in 0..<100 {
            guard case .dialogue(let packet) = lostRunner.phase else { break }
            lostDialogue += packet.pages.compactMap { String(data: $0.visibleBytes, encoding: .isoLatin1) }
            lostRunner.acknowledgeDialogue()
        }
        XCTAssertTrue(lostRunner.eventTrail.suffix(2).elementsEqual([9, 12]))
        XCTAssertTrue(lostDialogue.joined().contains("Dunning's plant"))
        guard case .picture(id: 26) = lostRunner.phase else {
            return XCTFail("Bowling result 0 should open the plant picture: \(lostRunner.phase)")
        }

        let postPlant = OriginalPlaySession(runner: lostRunner, audio: audio, catalog: try .bundled(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { postPlant.stop() }
        try OriginalChapterThreeRouteChecks.picture(postPlant)
        XCTAssertTrue(postPlant.runner.eventTrail.suffix(3).elementsEqual([9, 12, 13]))
        XCTAssertEqual(postPlant.runner.phase, .exploration(mapID: 19))
        XCTAssertEqual(postPlant.runner.program.name, "EP8_R119")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-bowling-plant")).save(postPlant.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(postPlant, to: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(postPlant, to: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(postPlant, to: 45, interrupt: true)
        XCTAssertEqual(postPlant.runner.phase, .exploration(mapID: 45))
        XCTAssertEqual(postPlant.runner.program.name, "EP8_R401")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-rooftop-entry")).save(postPlant.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.talk(postPlant, to: 5, interrupt: true)
        XCTAssertEqual(postPlant.runner.phase, .picture(id: 40))
        try OriginalChapterThreeRouteChecks.picture(postPlant, interrupt: true)
        XCTAssertEqual(postPlant.runner.phase, .picture(id: 16))
        try OriginalChapterThreeRouteChecks.picture(postPlant, interrupt: true)
        XCTAssertEqual(postPlant.runner.phase, .questions([]))
        try OriginalChapterThreeRouteChecks.conversation(postPlant, answers: [], topics: [])
        XCTAssertEqual(postPlant.runner.phase, .exploration(mapID: 45))
        XCTAssertEqual(postPlant.runner.game.nowTime, 3, "Reading Mila's rooftop message advances to 11:40 pm")
        XCTAssertEqual(postPlant.runner.game.value(for: .eventFlag(group: 45, index: 15)), true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-rooftop-meeting")).save(postPlant.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(postPlant, to: 39, interrupt: true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-rooftop-exit")).save(postPlant.walkingCheckpoint())

        var runner = play.runner
        runner.finishProcess(returnValue: 1)
        var dialogue = [String]()
        for _ in 0..<100 {
            guard case .dialogue(let packet) = runner.phase else { break }
            dialogue += packet.pages.compactMap { String(data: $0.visibleBytes, encoding: .isoLatin1) }
            runner.acknowledgeDialogue()
        }

        XCTAssertTrue(runner.eventTrail.suffix(2).elementsEqual([10, 8]))
        XCTAssertTrue(dialogue.joined().contains("Once more?"))
        XCTAssertEqual(runner.phase, .process(id: 44))
    }

    @MainActor func testChapterEightReturnsToR205AfterRooftopMeeting() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-after-rooftop-exit")).load() else {
            throw XCTSkip("Reach the Chapter 8 post-bowling rooftop branch first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(play.runner.game.chapter, 7)
        try OriginalChapterThreeRouteChecks.exit(play, to: 31, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(play.runner.program.name, "EP8_R205")
        let resumeCheckpoint = try play.progressCheckpoint()
        XCTAssertNotNil(resumeCheckpoint.progress)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-rooftop-r205")).save(resumeCheckpoint)

        let resumed = try OriginalPlaySession.restoring(resumeCheckpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(resumed.runner.program.name, "EP8_R205")
    }

    @MainActor func testChapterEightReturnsToR118AfterRooftopAt1140() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-after-rooftop-exit")).load() else {
            throw XCTSkip("Reach the Chapter 8 rooftop scene first")
        }
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        XCTAssertEqual(play.runner.game.nowTime, 3)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
        try OriginalChapterThreeRouteChecks.exit(play, to: 18, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 18))
        XCTAssertEqual(play.runner.program.name, "EP8_R118")
        XCTAssertEqual(play.runner.game.nowTime, 3)
        let savedPosition = try XCTUnwrap(play.lobby?.position)
        let resume = try play.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-rooftop-r118")).save(resume)
        let resumed = try OriginalPlaySession.restoring(resume, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 18))
        XCTAssertEqual(resumed.runner.game.nowTime, 3)
        XCTAssertEqual(resumed.lobby?.position, savedPosition, "Instant restore must keep the active map position")
        resumed.resume()
        XCTAssertTrue(resumed.canSaveWalkingCheckpoint)
    }

    @MainActor func testChapterEightReturnsToR119At1140AfterRooftop() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-after-rooftop-r118")).load() else {
            throw XCTSkip("Reach R118 after the rooftop branch first")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }

        XCTAssertEqual(play.runner.phase, .exploration(mapID: 18))
        XCTAssertEqual(play.runner.program.name, "EP8_R118")
        XCTAssertEqual(play.runner.game.nowTime, 3)
        play.resume()
        try OriginalChapterThreeRouteChecks.exit(play, to: 3, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 3))
        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 17))
        try OriginalChapterThreeRouteChecks.exit(play, to: 19, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 19))
        XCTAssertEqual(play.runner.program.name, "EP8_R119")
        XCTAssertEqual(play.runner.game.nowTime, 3)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-rooftop-r119")).save(play.walkingCheckpoint())
    }

    @MainActor private func playCapturedBowlingThrow(_ throwIndex: Int,
                                                     in play: OriginalPlaySession) throws {
        func hold(_ point: SIMD2<Int>, for frames: Int) throws {
            let pagePoint = try XCTUnwrap(OriginalBowlingTouchRay.pagePoint(
                touchPoint: point, orientation: .unrotated))
            for _ in 0..<frames {
                play.holdBowlingTouch(pageX: pagePoint.x, pageY: pagePoint.y)
                play.advanceFrame()
            }
        }

        try hold(SIMD2(15, 90), for: 1)
        for _ in 0..<7 { play.advanceFrame() }
        try hold(SIMD2(23, 90), for: 8)
        XCTAssertEqual(play.bowlingMatch?.phase, .dragging)
        for rawX in stride(from: 31, through: 119, by: 8) {
            try hold(SIMD2(rawX, 90), for: 8)
        }
        try hold(SIMD2(125, 90), for: 8)
        play.releaseBowlingTouch()
        XCTAssertEqual(play.bowlingMatch?.phase, .rolling)

        let scoreIndex = try XCTUnwrap(OriginalBowlingResult.slot(for: throwIndex)).scoreOffset / 4
        for _ in 0..<5_000 where play.bowlingMatch?.results.throwScores[scoreIndex] == nil {
            play.advanceFrame()
        }
        XCTAssertEqual(play.bowlingMatch?.results.throwScores[scoreIndex], 4)
        for _ in 0..<40 {
            guard play.bowlingMatch?.nextCommentaryRequest != nil else { return }
            if case .process(id: 44) = play.runner.phase { play.advanceFrame() }
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            default: throw OriginalDataError.invalid("Bowling commentary did not start its recovered response")
            }
        }
        throw OriginalDataError.invalid("Bowling commentary did not return to the match")
    }

    @MainActor func testBowlingTouchDragStrengthSelectsThreeStoryResults() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-bowling-ready")).load() else {
            throw XCTSkip("Reach the ready bowling checkpoint first")
        }
        for (endX, expectedResult): (Int, Int16) in [(39, 0), (47, 0), (55, 0), (63, 1), (71, 1), (79, 2)] {
            let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
                saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)),
                mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) },
                bowlingRendererFactory: { try RouteBowlingRenderer() })
            defer { play.stop() }
            play.resume()
            func hold(_ rawX: Int, for frames: Int) throws {
                let point = try XCTUnwrap(OriginalBowlingTouchRay.pagePoint(
                    touchPoint: SIMD2(rawX, 90), orientation: .unrotated))
                for _ in 0..<frames {
                    play.holdBowlingTouch(pageX: point.x, pageY: point.y)
                    play.advanceFrame()
                }
            }
            try hold(15, for: 1)
            for _ in 0..<7 { play.advanceFrame() }
            try hold(23, for: 8)
            for rawX in stride(from: 31, through: endX, by: 8) { try hold(rawX, for: 8) }
            play.releaseBowlingTouch()
            XCTAssertEqual(play.bowlingMatch?.turn.routeResult, expectedResult)
        }
    }

    @MainActor func testChapterEightLowSpeedBowlingAndRosaSearchCallUseNormalInputs() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-bowling-ready")).load() else {
            throw XCTSkip("Reach the ready bowling checkpoint first")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) },
            bowlingRendererFactory: { try RouteBowlingRenderer() })
        defer { play.stop() }
        play.resume()

        func hold(_ rawX: Int, for frames: Int) throws {
            let point = try XCTUnwrap(OriginalBowlingTouchRay.pagePoint(
                touchPoint: SIMD2(rawX, 90), orientation: .unrotated))
            for _ in 0..<frames {
                play.holdBowlingTouch(pageX: point.x, pageY: point.y)
                play.advanceFrame()
            }
        }
        for throwIndex in 0..<5 {
            if throwIndex > 0 { play.advanceFrame() }
            try hold(15, for: 1)
            for _ in 0..<7 { play.advanceFrame() }
            try hold(23, for: 8)
            for rawX in stride(from: 31, through: 55, by: 8) { try hold(rawX, for: 8) }
            play.releaseBowlingTouch()
            XCTAssertEqual(play.bowlingMatch?.turn.routeResult, 0)
            let scoreIndex = try XCTUnwrap(OriginalBowlingResult.slot(for: throwIndex)).scoreOffset / 4
            for _ in 0..<5_000 where play.bowlingMatch?.results.throwScores[scoreIndex] == nil {
                play.advanceFrame()
            }
            XCTAssertNotNil(play.bowlingMatch?.results.throwScores[scoreIndex])
            for _ in 0..<40 {
                guard play.bowlingMatch?.nextCommentaryRequest != nil else { break }
                if case .process(id: 44) = play.runner.phase { play.advanceFrame() }
                switch play.runner.phase {
                case .dialogue, .itemNotice: play.advanceDialogue()
                default: throw OriginalDataError.invalid("Bowling commentary did not start its recovered response")
                }
            }
        }
        XCTAssertEqual(play.bowlingMatch?.phase, .showingResult)
        for _ in 0..<OriginalBowlingMatchProcess.resultAnimationFrames { play.advanceFrame() }
        for _ in 0..<OriginalBowlingMatchProcess.resultPresentationFrames { play.advanceFrame() }
        XCTAssertEqual(play.bowlingMatch?.returnValue, 0)
        play.advanceFrame()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 26))
        try OriginalChapterThreeRouteChecks.picture(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 19))
        try OriginalChapterThreeRouteChecks.talk(play, to: 4, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: Array(0..<128))
        XCTAssertEqual(Array(play.runner.eventTrail.suffix(6)), [6, 8, 9, 12, 13, 7])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 19))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-rosa-search-call")).save(play.walkingCheckpoint())

        try OriginalChapterThreeRouteChecks.exit(play, to: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.exit(play, to: 45, interrupt: true)
        try OriginalChapterThreeRouteChecks.talk(play, to: 5, interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 40))
        try OriginalChapterThreeRouteChecks.picture(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 16))
        try OriginalChapterThreeRouteChecks.picture(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .questions([]))
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 45))
        XCTAssertEqual(play.runner.game.nowTime, 3)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 45, index: 15)), true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-rooftop-meeting-normal")).save(play.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.exit(play, to: 39, interrupt: true)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-after-rooftop-exit-normal")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightNormalRouteReachesR118At1140() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-after-rooftop-exit-normal")).load() else {
            throw XCTSkip("Complete the normal bowling and rooftop route first")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        XCTAssertEqual(play.runner.game.nowTime, 3)
        XCTAssertEqual(play.runner.game.mapID, 39)
        for destination: Int16 in [17, 3, 18] {
            try OriginalChapterThreeRouteChecks.exit(play, to: destination, interrupt: true)
            XCTAssertEqual(play.runner.game.mapID, destination)
        }
        XCTAssertEqual(play.runner.program.name, "EP8_R118")
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-r118-after-rooftop-meeting-normal")).save(play.walkingCheckpoint())
    }

    @MainActor func testChapterEightNormalRouteEntersRosaRoomAfterMila() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-r118-after-rooftop-meeting-normal")).load() else {
            throw XCTSkip("Reach R118 at 11:40 through the normal-input route first")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        let target = try OriginalChapterThreeRouteChecks.doorMarker(play, 13)
        try OriginalChapterThreeRouteChecks.navigate(play, to: target + SIMD2<Float>(0, -8_000), interrupt: true)
        OriginalChapterThreeRouteChecks.face(play, x: target.x, z: target.y)
        XCTAssertEqual(play.nearbyDoor, 13)
        XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 10)), true)
        XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 46)), true)
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertNotNil(play.door)
        try OriginalChapterThreeRouteChecks.doorComponent(play, 1, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 13))
        XCTAssertEqual(play.runner.program.name, "EP8_R113")
        XCTAssertEqual(play.runner.game.nowTime, 3)
        XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 10)), false)
        XCTAssertEqual(play.runner.game.value(for: .doorOpen(index: 46)), false)
        let progress = try play.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-rosa-room-entry-normal")).save(progress)
        let resumed = try OriginalPlaySession.restoring(progress, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 13))
        XCTAssertEqual(resumed.runner.game.value(for: .doorOpen(index: 10)), false)
        resumed.resume()
        let backroomDoor = try OriginalChapterThreeRouteChecks.doorMarker(resumed, 24)
        do {
            try OriginalChapterThreeRouteChecks.walk(resumed,
                to: backroomDoor + SIMD2<Float>(-10_000, 0), interrupt: true)
        } catch {
            OriginalChapterThreeRouteChecks.face(resumed, x: backroomDoor.x, z: backroomDoor.y)
            guard resumed.nearbyDoor == 24 else { throw error }
        }
        OriginalChapterThreeRouteChecks.face(resumed, x: backroomDoor.x, z: backroomDoor.y)
        XCTAssertEqual(resumed.nearbyDoor, 24)
        resumed.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        XCTAssertEqual(resumed.door?.view.id, 95)
        try OriginalChapterThreeRouteChecks.doorComponent(resumed, 2, interrupt: true)
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 24))
        XCTAssertEqual(resumed.runner.program.name, "EP8_R124")
        let backroom = try resumed.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-rosa-backroom-entry-normal")).save(backroom)
        let restoredBackroom = try OriginalPlaySession.restoring(backroom, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { restoredBackroom.stop() }
        XCTAssertEqual(restoredBackroom.runner.phase, .exploration(mapID: 24))
        XCTAssertEqual(restoredBackroom.runner.game.nowTime, 3)
    }

    @MainActor func testChapterEightNormalRouteSearchesRosaPhotographsAndResumes() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-rosa-backroom-entry-normal")).load() else {
            throw XCTSkip("Open Rosa's back room through normal input first")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2<Float>(8000, -4000), interrupt: true)
        try OriginalChapterThreeRouteChecks.search(play, node: "obj07", interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .eventFlag(group: 24, index: 0)), true)
        let photoCheckpoint = try play.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-rosa-photographs-normal")).save(photoCheckpoint)
        let resumed = try OriginalPlaySession.restoring(photoCheckpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { resumed.stop() }
        XCTAssertEqual(resumed.runner.game.value(for: .eventFlag(group: 24, index: 0)), true)
        XCTAssertEqual(resumed.runner.phase, .exploration(mapID: 24))
        resumed.resume()
        try OriginalChapterThreeRouteChecks.navigate(resumed, to: SIMD2<Float>(16000, 4000), interrupt: true)
        try OriginalChapterThreeRouteChecks.navigate(resumed, to: SIMD2<Float>(12000, 12000), interrupt: true)
        try OriginalChapterThreeRouteChecks.search(resumed, node: "obj05", interrupt: true)
        XCTAssertEqual(resumed.closeup?.view.id, 105)
        resumed.leaveSearchCloseup()
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        if resumed.lobby?.mode == .counter { resumed.leaveLobbyCounter() }
        try OriginalChapterThreeRouteChecks.search(resumed, node: "obj06", interrupt: true)
        XCTAssertEqual(resumed.closeup?.view.id, 106)
        resumed.leaveSearchCloseup()
        OriginalChapterThreeRouteChecks.drain(resumed, interrupt: true)
        let photoViewsCheckpoint = try resumed.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-rosa-photo-views-normal")).save(photoViewsCheckpoint)
        let photoViewsResumed = try OriginalPlaySession.restoring(photoViewsCheckpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { photoViewsResumed.stop() }
        XCTAssertEqual(photoViewsResumed.runner.phase, .exploration(mapID: 24))
    }

    @MainActor func testChapterEightRosaConversationNormalAnswers() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter8-rosa-photo-views-normal")).load() else {
            throw XCTSkip("Inspect Rosa's photographs through normal input first")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 24))
        play.resume()
        try OriginalChapterThreeRouteChecks.exit(play, to: 13, interrupt: true, expectArrival: false)
        XCTAssertEqual(play.nearbyDoor, 13)
        try OriginalChapterThreeRouteChecks.choose(play, "C'mon, Rosa. Don't lie.", interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "Rosa... Come on, now.", interrupt: true)
        XCTAssertEqual(play.runner.phase, .questions([
            .init(keyword: 7, label: "Talk about the pamphlet."),
            .init(keyword: 8, label: "Talk about Mila's father."),
            .init(keyword: 9, label: "Talk about the promise.")
        ]))
        play.ask(7)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "Mila's brochure.", interrupt: true)
        play.ask(8)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "You DO know something!", interrupt: true)
        play.ask(9)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "Someone I know.", interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [10, 11, 12])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 24))
        let rosaDone = try play.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-rosa-conversation-complete")).save(rosaDone)
        let afterRosa = try OriginalPlaySession.restoring(rosaDone, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { afterRosa.stop() }
        afterRosa.resume()
        try OriginalChapterThreeRouteChecks.exit(afterRosa, to: 13, interrupt: true)
        XCTAssertEqual(afterRosa.runner.game.mapID, 13)
        XCTAssertEqual(afterRosa.lobby?.people(in: afterRosa.runner.game).map(\.id), [5])
        try OriginalChapterThreeRouteChecks.talk(afterRosa, to: 5, interrupt: true)
        XCTAssertEqual(afterRosa.runner.phase, .exploration(mapID: 13))
        let milaSpoken = try afterRosa.progressCheckpoint()
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-mila-room-conversation")).save(milaSpoken)
        let afterMila = try OriginalPlaySession.restoring(milaSpoken, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { afterMila.stop() }
        afterMila.resume()
        try OriginalChapterThreeRouteChecks.exit(afterMila, to: 18, interrupt: true)
        XCTAssertEqual(afterMila.runner.game.mapID, 18)
        try OriginalChapterThreeRouteChecks.walk(afterMila, to: SIMD2<Float>(12000, -28000), interrupt: true)
        for destination: Int16 in [39, 31] {
            try OriginalChapterThreeRouteChecks.exit(afterMila, to: destination, interrupt: true)
            XCTAssertEqual(afterMila.runner.game.mapID, destination)
        }
        XCTAssertEqual(afterMila.runner.game.mapID, 31)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter8-back-in-room215-after-rosa")).save(afterMila.walkingCheckpoint())
        try OriginalChapterThreeRouteChecks.navigate(afterMila, to: SIMD2<Float>(-16_687, 7_450), interrupt: true)
        try OriginalChapterThreeRouteChecks.search(afterMila, node: "obj01", interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(afterMila, "Robert Evans", interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(afterMila, "Grace", interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(afterMila, "An old key", interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(afterMila, "On the roof", interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(afterMila, "Seven years ago", interrupt: true)
        XCTAssertTrue(afterMila.chapterTransition?.stage == .prompt || afterMila.chapterTransition?.stage == .title)
        XCTAssertEqual(afterMila.runner.game.chapter, 8)
        afterMila.answerChapterSave(false)
        afterMila.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(afterMila, interrupt: true)
        XCTAssertEqual(afterMila.runner.program.name, "EP9_R205")
        XCTAssertEqual(afterMila.runner.game.nowTime, 0)
        XCTAssertEqual(afterMila.runner.game.mapID, 31)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-normal-entry")).save(afterMila.walkingCheckpoint())
    }

    @MainActor func testChapterNineRoom215CardboardBoxUsesRoomHitMesh() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter9-normal-entry")).load() else {
            throw XCTSkip("Reach the Chapter 9 title through normal play first")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { play.stop() }
        play.resume()
        try OriginalChapterThreeRouteChecks.navigate(play, to: SIMD2<Float>(-12_000, 11_000), interrupt: true)
        let lobby = try XCTUnwrap(play.lobby)
        XCTAssertEqual(lobby.nearbySearchArea, 2)
        let target = try XCTUnwrap(lobby.room.nodes.first { $0.name == "obj0202" })
        OriginalChapterThreeRouteChecks.face(play, x: Float(target.worldFixed[12]), z: Float(target.worldFixed[14]))
        let facingLobby = try XCTUnwrap(play.lobby)
        let visible = facingLobby.objectVisibility.visibleNodes(in: facingLobby.room, map: facingLobby.mapID,
            area: nil, game: play.runner.game).intersection(facingLobby.room.gameplayRenderNodes)
        var hit: SIMD2<Float>?
        for y in stride(from: 0, to: 256, by: 8) where hit == nil {
            for x in stride(from: 0, to: 192, by: 8) {
                let point = SIMD2(Float(x), Float(y))
                if try facingLobby.pickedRoomObject(page: point, visibleNodes: visible) == "obj0202" {
                    hit = point
                    break
                }
            }
        }
        guard let hit else {
            XCTFail("The cardboard box hit mesh should remain visible after facing it")
            return
        }
        play.selectLobbyRoomObject(x: hit.x, y: hit.y)
        guard case .dialogue(let packet) = play.runner.phase else {
            XCTFail("A normal hit on the cardboard box should start its room response")
            return
        }
        let response = packet.pages.flatMap(\.entries).map { String(decoding: $0.bytes, as: UTF8.self) }
            .joined(separator: " ")
        XCTAssertTrue(response.localizedCaseInsensitiveContains("cardboard box"))
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        guard play.runner.phase == .exploration(mapID: 31) else {
            XCTFail("The room response should return to exploration before checkpointing")
            return
        }
        let checkpointStore = OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter9-room215-cardboard-box"))
        try checkpointStore.save(try play.progressCheckpoint())
        let savedCheckpoint = try XCTUnwrap(try checkpointStore.load())
        let restored = try OriginalPlaySession.restoring(savedCheckpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try BitmapRouteMapRenderer(mapName: mapName) })
        defer { restored.stop() }
        restored.resume()
        XCTAssertEqual(restored.runner.program.name, "EP9_R205")
        XCTAssertEqual(restored.runner.phase, .exploration(mapID: 31))
    }

    @MainActor func testChapterThreeFromPlayedCheckpoint() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
                .appendingPathComponent("chapter3-entry")).load() else {
            throw XCTSkip("Generate the Chapter 3 save with the full opening route first")
        }
        let play = try OriginalPlaySession.restoring(checkpoint, audio: originalRouteTestAudio(),
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.run(play)
    }

    @MainActor func testChapterThreeAfterDinner() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("dinner")).load() else {
            throw XCTSkip("Generate the dinner checkpoint through the full native route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000))
        play.turnFirstPerson(by: atan2(64423 - (play.lobby?.position.x ?? 0), -28450 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17)
        if let mila = play.lobby?.people(in: play.runner.game).first(where: { $0.id == 5 }) {
            try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, mila.position.z - 8000))
            play.turnFirstPerson(by: atan2(mila.position.x - (play.lobby?.position.x ?? 0), mila.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
            play.talkToNearbyPerson()
            OriginalChapterThreeRouteChecks.drain(play)
        }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -48000), interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "Well...maybe...")
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 30000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8500, 30885), interrupt: true)
        try OriginalChapterThreeRouteChecks.door(play, destination: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-30000, -27000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-35000, 10000), interrupt: true)
        try OriginalChapterThreeRouteChecks.choose(play, "A free drink? I'm in!")
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-30000, -27000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000), interrupt: true)
        XCTAssertEqual(play.runner.phase, .picture(id: 27))
        let penPoint = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Int>($0, y) }
        }.first { play.touchPicture?.contains(pageX: $0.x, pageY: $0.y) == true })
        play.activatePicture(pageX: penPoint.x, pageY: penPoint.y)
        for _ in 0..<100 where play.touchPicture != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000))
        play.turnFirstPerson(by: atan2(64423 - (play.lobby?.position.x ?? 0), -28450 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(27))
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-4000, 20000))
        play.turnFirstPerson(by: -.pi / 2 - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let boardPoint = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try ["obj01", "obj04", "obj05"].contains(counter.pickedCounterNode(page: $0, visibleNodes: visible) ?? "") })
        play.selectLobbyObject(x: boardPoint.x, y: boardPoint.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.closeup?.view.id, 171)
        play.useItemInCloseup(27)
        let chalk = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Int>($0, y) }
        }.first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == 2 })
        play.selectCloseupComponent(x: chalk.x, y: chalk.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertEqual(play.runner.phase, .process(id: 42))
        for _ in 0..<65 { play.advanceFrame() }
        for x in stride(from: 45, through: 145, by: 4) {
            for y in stride(from: 80, through: 212, by: 4) where play.fountainPen?.phase == 1 && play.fountainPen?.stage == 0 {
                play.releaseFountainPenTouch(); play.advanceFrame()
                play.holdFountainPenTouch(x: 90, y: 140); play.advanceFrame()
                play.holdFountainPenTouch(x: Float(x), y: Float(y)); play.advanceFrame()
            }
        }
        play.releaseFountainPenTouch()
        for _ in 0..<200 where play.fountainPen?.stage != 2 || play.fountainPen?.phase != 2 { play.advanceFrame() }
        XCTAssertEqual(play.fountainPen?.phase, 2)
        XCTAssertEqual(play.fountainPen?.stage, 2)
        for _ in 0..<100 where play.fountainPen?.stage == 2 {
            play.releaseFountainPenTouch(); play.advanceFrame()
            play.holdFountainPenTouch(x: 96, y: 140); play.advanceFrame()
        }
        play.releaseFountainPenTouch()
        for _ in 0..<400 where play.fountainPen != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play)
        XCTAssertNil(play.fountainPen)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 18)), true)
        if play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        if let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"] {
            try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("pen"))
                .save(play.walkingCheckpoint())
        }

    }

    @MainActor func testChapterThreeAfterPen() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("pen")).load() else {
            throw XCTSkip("Generate the pen checkpoint through the native route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 30000))
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8500, 30885))
        try OriginalChapterThreeRouteChecks.door(play, destination: 26)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(50000, -27000))
        let louie = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 4 }))
        play.turnFirstPerson(by: atan2(louie.position.x - (play.lobby?.position.x ?? 0), louie.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [])
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000))
        play.turnFirstPerson(by: atan2(64423 - (play.lobby?.position.x ?? 0), -28450 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -20000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -48000), interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(45000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(44332, -1676), interrupt: true)
        play.turnFirstPerson(by: .pi - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.nearbyDoor, 35)
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        play.showItemInConversation(24)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [23])
        XCTAssertEqual(play.runner.game.mapID, 35)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(0, -10000), interrupt: true)
        if let melissa = play.lobby?.people(in: play.runner.game).first(where: { $0.id == 11 }) {
            play.turnFirstPerson(by: atan2(melissa.position.x - (play.lobby?.position.x ?? 0), melissa.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
            play.talkToNearbyPerson()
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(37500, -23000), interrupt: true)
        play.turnFirstPerson(by: atan2(51033 - (play.lobby?.position.x ?? 0), -27394 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 3)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let puzzlePoint = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj05" })
        play.selectLobbyObject(x: puzzlePoint.x, y: puzzlePoint.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.closeup?.view.id, 285)
        let lid = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Int>($0, y) }
        }.first { play.closeupImage?.hit(pageX: $0.x, pageY: $0.y) == 1 })
        play.selectCloseupComponent(x: lid.x, y: lid.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 39))
        for _ in 0..<65 { play.advanceFrame() }
        for _ in 0..<20 {
            let puzzle = try XCTUnwrap(play.jigsaw)
            let index = try XCTUnwrap(puzzle.pieces.indices.filter { !puzzle.isPlaced($0) }
                .max { puzzle.pieces[$0].depth < puzzle.pieces[$1].depth })
            let centre = OriginalJigsawProjection.centre(puzzle.pieces[index])
            play.dragJigsaw(pageX: centre.x, pageY: centre.y)
            XCTAssertEqual(play.jigsaw?.selected, index)
            play.releaseJigsaw()
            for _ in 0..<2 { play.advanceFrame() }
            for _ in 0..<4 where play.jigsaw?.pieces[index].angle != 1.5 {
                play.rotateJigsaw(increasing: false)
                for _ in 0..<20 { play.advanceFrame() }
            }
            play.dragJigsaw(pageX: centre.x, pageY: centre.y)
            let target = OriginalJigsawProcess.target(index)
            play.dragJigsaw(pageX: 96 + Float(target.x + 2048) / 4096 * OriginalJigsawProjection.pixelsPerUnit,
                pageY: 128 - (Float(target.y + 2048) / 4096 + 0.5) * OriginalJigsawProjection.pixelsPerUnit)
            play.releaseJigsaw()
            XCTAssertEqual(play.jigsaw?.isPlaced(index), true)
            for _ in 0..<2 { play.advanceFrame() }
        }
        for _ in 0..<350 where play.jigsaw?.variant == .full { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 40))
        for _ in 0..<65 { play.advanceFrame() }
        play.receiveJigsawFold(isClosed: true)
        play.receiveJigsawFold(isClosed: false)
        for _ in 0..<500 where play.jigsaw != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 15)), true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 16)), true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: ["Easy! Don't scare Melissa."], topics: [2, 24])
        for _ in 0..<5 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        if play.runner.game.mapID == 35 {
            try OriginalChapterThreeRouteChecks.walk(play, to: .init(0, -10000), interrupt: true)
        }
        if play.runner.game.mapID == 35 {
            try OriginalChapterThreeRouteChecks.walk(play, to: .init(82, 3277), interrupt: true)
        }
        if play.runner.game.mapID == 35 {
            play.turnFirstPerson(by: -(play.lobby?.facing ?? 0))
            try OriginalChapterThreeRouteChecks.door(play, destination: 39, interrupt: true)
        }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(play.runner.game.nowTime, 3)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("jigsaw"))
            .save(play.walkingCheckpoint())

    }

    @MainActor func testChapterThreeAfterJigsaw() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("jigsaw")).load() else {
            throw XCTSkip("Generate the jigsaw checkpoint through the native route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) },
            bookmarkBoxRender: { _ in try OriginalInventoryArtwork.shared.image(for: 25) })
        defer { play.stop() }
        XCTAssertEqual(play.runner.game.mapID, 39)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(45000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-77000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-77419, 11630), interrupt: true)
        play.turnFirstPerson(by: -(play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 31, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(0, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-10353, 8041), interrupt: true)
        play.turnFirstPerson(by: -(play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let box = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj02" })
        play.selectLobbyObject(x: box.x, y: box.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 47))
        for _ in 0..<65 { play.advanceFrame() }
        func press(_ point: SIMD2<Float>) {
            play.releaseBookmarkBoxTouch(); play.advanceFrame()
            play.holdBookmarkBoxTouch(x: point.x, y: point.y); play.advanceFrame()
            play.releaseBookmarkBoxTouch(); play.advanceFrame()
        }
        for point: SIMD2<Float> in [.init(16, 128), .init(96, 240), .init(16, 128)] {
            press(point)
            for _ in 0..<45 { play.advanceFrame() }
        }
        for _ in 0..<10 { press(.init(96, 128)) }
        press(.init(176, 128))
        for _ in 0..<45 { play.advanceFrame() }
        press(.init(96, 128))
        for _ in 0..<130 { play.advanceFrame() }
        XCTAssertEqual(play.bookmarkBox?.phase, 2)
        play.holdBookmarkBoxTouch(x: 50, y: 140); play.advanceFrame()
        for x in stride(from: 52, through: 150, by: 2) {
            play.holdBookmarkBoxTouch(x: Float(x), y: 140); play.advanceFrame()
        }
        play.releaseBookmarkBoxTouch()
        for _ in 0..<700 where play.bookmarkBox != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertNil(play.bookmarkBox)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 23)), true)
        XCTAssertTrue(try play.runner.game.inventory.items.contains(25))
        for _ in 0..<5 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("bookmark"))
            .save(play.walkingCheckpoint())
    }

    @MainActor func testChapterThreeAfterBookmark() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("bookmark")).load() else {
            throw XCTSkip("Generate the bookmark checkpoint through the native route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) },
            bookmarkBoxRender: { _ in try OriginalInventoryArtwork.shared.image(for: 25) })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(0, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(9994, -15811), interrupt: true)
        play.turnFirstPerson(by: .pi - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-77000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(87000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(87270, 10765), interrupt: true)
        play.turnFirstPerson(by: -(play.lobby?.facing ?? 0))
        XCTAssertEqual(play.nearbyDoor, 27)
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        play.showItemInConversation(25)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: ["Angel Opening a Door?"], topics: [21, 22])
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertTrue(play.runner.game.keywordAsked(21, person: 8))
        XCTAssertTrue(play.runner.game.keywordAsked(22, person: 8))
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(87000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(16000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, -1500), interrupt: true)
        play.turnFirstPerson(by: .pi - (play.lobby?.facing ?? 0))
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
            play.leaveDoor()
        }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(20700, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(20700, -48000), interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 17)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 30000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8500, 30885), interrupt: true)
        try OriginalChapterThreeRouteChecks.door(play, destination: 26, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(50000, -27000), interrupt: true)
        let louie = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 4 }))
        play.turnFirstPerson(by: atan2(louie.position.x - (play.lobby?.position.x ?? 0), louie.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: ["I know enough."], topics: [])
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(55000, -28000), interrupt: true)
        play.turnFirstPerson(by: atan2(64423 - (play.lobby?.position.x ?? 0), -28450 - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -27000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8110, -27116), interrupt: true)
        play.turnFirstPerson(by: -.pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 19, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5000, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5249, -53128), interrupt: true)
        play.turnFirstPerson(by: .pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 9, interrupt: true)
        print("AT ELECTRICAL ROOM", play.runner.phase, play.lobby?.position as Any)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 9))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("electrical"))
            .save(play.walkingCheckpoint())
    }

    @MainActor func testChapterThreeElectricalRescue() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("electrical")).load() else {
            throw XCTSkip("Generate the electrical-room checkpoint through the native route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) },
            thinWireRendererFactory: { _ in try RouteThinWireRenderer() })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(12533, -10453), interrupt: true)
        play.turnFirstPerson(by: .pi / 2 - (play.lobby?.facing ?? 0))
        XCTAssertEqual(play.lobby?.nearbySearchArea, 2)
        play.inspectLobbyCounter()
        let counter = try XCTUnwrap(play.lobby)
        let visible = counter.objectVisibility.visibleNodes(in: counter.counter, map: counter.mapID,
            area: counter.searchAreaID, game: play.runner.game)
        let panel = try XCTUnwrap(stride(from: 8, to: 248, by: 4).flatMap { y in
            stride(from: 8, to: 184, by: 4).map { SIMD2<Float>(Float($0), Float(y)) }
        }.first { try counter.pickedCounterNode(page: $0, visibleNodes: visible) == "obj01" })
        play.selectLobbyObject(x: panel.x, y: panel.y, confirmImmediately: true)
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.phase, .process(id: 41))
        for _ in 0..<65 { play.advanceFrame() }
        for point: SIMD2<Float> in [.init(48, 170), .init(96, 170), .init(96, 160)] {
            play.holdSwitchboardTouch(x: point.x, y: point.y); play.advanceFrame()
        }
        play.releaseSwitchboardTouch()
        for _ in 0..<400 where play.switchboard != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 17)), true)
        for _ in 0..<5 where play.closeup != nil { play.leaveSearchCloseup() }
        if play.lobby?.mode == .counter { play.leaveLobbyCounter() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5652, 0), interrupt: true)
        play.turnFirstPerson(by: -.pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 19, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5000, 0), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(25289, 0), interrupt: true)
        play.turnFirstPerson(by: .pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 17, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -27000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(6000, -48000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(16000, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, -1500), interrupt: true)
        play.turnFirstPerson(by: .pi - (play.lobby?.facing ?? 0))
        play.inspectNearbyDoor()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.door != nil {
            play.selectDoorComponent(x: 96, y: 135, confirmImmediately: true)
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        }
        XCTAssertEqual(play.runner.phase, .process(id: 77))
        for _ in 0..<65 { play.advanceFrame() }
        let paths: [[SIMD2<Float>]] = [
            [.init(88, 121), .init(84, 121), .init(84, 86)],
            [.init(88, 106), .init(84, 118), .init(124, 118)],
            [.init(104, 88), .init(155, 98), .init(155, 138), .init(108, 138), .init(108, 180)],
            [.init(88, 154), .init(110, 154), .init(110, 138), .init(70, 138)]
        ]
        let frames = [[4, 4, 40], [4, 4, 40], [1, 24, 16, 18, 40], [1, 12, 8, 40]]
        for index in 0..<4 {
            play.releaseThinWireTouch(); play.advanceFrame()
            for (step, point) in paths[index].enumerated() {
                play.holdThinWireTouch(x: point.x, y: point.y)
                for _ in 0..<frames[index][step] where play.thinWire?.pins[index].reached == false { play.advanceFrame() }
            }
            XCTAssertEqual(play.thinWire?.pins[index].reached, true)
        }
        play.releaseThinWireTouch()
        for _ in 0..<400 where play.thinWire != nil { play.advanceFrame() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        XCTAssertEqual(play.runner.game.value(for: .trickFlag(index: 53)), true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: [])
        if play.door != nil { play.leaveDoor() }
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        if play.runner.game.mapID == 39 { try OriginalChapterThreeRouteChecks.door(play, destination: 34, interrupt: true) }
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 34))
        XCTAssertFalse(try play.runner.game.inventory.items.contains(16))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("rescue"))
            .save(play.walkingCheckpoint())
    }

    @MainActor func testChapterThreeMelissaAfterRescue() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("rescue")).load() else {
            throw XCTSkip("Generate the rescued-room checkpoint through the native route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        let melissa = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 11 }))
        print("RESCUED MELISSA", melissa.position)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(melissa.position.x, melissa.position.z + 8500), interrupt: true)
        play.turnFirstPerson(by: atan2(melissa.position.x - (play.lobby?.position.x ?? 0), melissa.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [
            "Things aren't going well?", "Why do you think that?", "Did Dad know this place?",
            "He hated to see you sad.", "It wasn't your fault.", "I'm sure your dad knows."
        ], topics: Array(0..<128))
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 34))
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("melissa"))
            .save(play.walkingCheckpoint())
    }

    @MainActor func testChapterThreeRooftopAfterMelissa() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let checkpoint = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("melissa")).load() else {
            throw XCTSkip("Generate the post-Melissa checkpoint through the native route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            mapRendererFactory: { mapName, _ in try OriginalRouteBitmapMapRenderer(mapName: mapName) })
        defer { play.stop() }
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(82, 6308), interrupt: true)
        play.turnFirstPerson(by: 0 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 39, interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-5653, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(48000, 7000), interrupt: true)
        let kevin = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 10 }))
        play.turnFirstPerson(by: atan2(kevin.position.x - (play.lobby?.position.x ?? 0), kevin.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        try OriginalChapterThreeRouteChecks.conversation(play, answers: [], topics: Array(0..<128))
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(148877, 7000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(148877, 4638), interrupt: true)
        play.turnFirstPerson(by: .pi / 2 - (play.lobby?.facing ?? 0))
        try OriginalChapterThreeRouteChecks.door(play, destination: 45, interrupt: true)
        XCTAssertEqual(play.runner.game.mapID, 45)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(103055, 50000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8848, 50000), interrupt: true)
        try OriginalChapterThreeRouteChecks.walk(play, to: .init(-8848, 59000), interrupt: true)
        let iris = try XCTUnwrap(play.lobby?.people(in: play.runner.game).first(where: { $0.id == 9 }))
        play.turnFirstPerson(by: atan2(iris.position.x - (play.lobby?.position.x ?? 0), iris.position.z - (play.lobby?.position.z ?? 0)) - (play.lobby?.facing ?? 0))
        play.talkToNearbyPerson()
        let answers = ["Just needed some air.", "You need air too?", "Melissa", "A bookmark", "Osterzone", "Room 218", "On the roof"]
        for _ in 0..<20 where play.chapterTransition == nil {
            OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
            if play.chapterTransition != nil { break }
            guard case .choice(let choices) = play.runner.phase,
                  let choice = choices.first(where: { answers.contains($0.label) }) else {
                throw OriginalDataError.invalid("Rooftop/review stopped: \(play.runner.phase)")
            }
            play.choose(choice.id)
        }
        XCTAssertTrue(play.chapterTransition?.stage == .prompt || play.chapterTransition?.stage == .title)
        XCTAssertEqual(play.runner.game.chapter, 3)
        if play.chapterTransition?.stage == .prompt { play.answerChapterSave(false) }
        play.continueChapterTitle()
        OriginalChapterThreeRouteChecks.drain(play, interrupt: true)
        print("CHAPTER FOUR", play.runner.phase, play.lobby?.position as Any)
        try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory)
            .appendingPathComponent("chapter4-roof")).save(play.walkingCheckpoint())

    }

    @MainActor func testLouieEndingFromPlayedCheckpoint() throws {
        guard let directory = ProcessInfo.processInfo.environment["HOTEL_DUSK_ROUTE_CHECKPOINTS"],
              let save = try OriginalResumeFileStore(directory: URL(fileURLWithPath: directory).appendingPathComponent("louie")).load() else {
            throw XCTSkip("Generate the checkpoint with the full opening route first")
        }
        let audio = AudioController(musicOutputFactory: { _, _, _ in RouteMusicOutput() })
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(save, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        defer { play.stop() }
        try OriginalLouieRoomRouteChecks.finishConversation(play)
    }
}
