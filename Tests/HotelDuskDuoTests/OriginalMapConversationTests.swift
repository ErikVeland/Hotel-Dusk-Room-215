import XCTest
@testable import HotelDuskDuoKit

final class OriginalMapConversationTests: XCTestCase {
    /**
     * Diagnostic story setup. Embedded processes return success in this state-only check.
     */
    private func afterRegistration(holding items: [UInt8] = []) throws -> OriginalEventRunner {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        for item in items { try game.apply(.addInventory(id: UInt16(item))) }
        game.setMap(2, previous: 1)
        let program = try catalog.loadProgram("EP1_R102")
        let keywords = try OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk"))
        var runner = try OriginalEventRunner(program: program, game: game, keywords: keywords)
        for _ in 0..<600 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .choice(let choices): runner.choose(choices[0].id)
            case .process: runner.finishProcess(returnValue: 0)
            case .waiting: runner.advanceWait()
            case .exploration:
                runner.lookInSearchView(area: 2, subarea: 2, table: try .bundled(map: "R102"))
            case .questions: return runner
            case .picture: runner.finishPicture()
            case .halted(let halt): XCTFail("Unexpected halt: \(halt)"); return runner
            }
        }
        XCTFail("Registration did not reach its question menu")
        return runner
    }

    private func advanceToExploration(_ runner: inout OriginalEventRunner) {
        for _ in 0..<300 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            case .exploration: return
            default: XCTFail("Shared response stopped at \(runner.phase)"); return
            }
        }
        XCTFail("Shared response did not return to exploration")
    }

    func testMapConversationResumesSavedPersonBlock() throws {
        var runner = try afterRegistration()
        for _ in 0..<600 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .choice(let choices): runner.choose(choices[0].id)
            case .questions(let topics):
                if let topic = topics.first { runner.ask(topic.keyword) }
                else { runner.leave() }
            case .exploration:
                XCTAssertEqual(runner.game.conversationBlock(map: 2, person: 2), 6)
                XCTAssertEqual(runner.game.personMarker(2), 201)
                runner.talkToPerson(2)
                XCTAssertEqual(runner.eventIndex, 50)
                XCTAssertEqual(runner.partner, 2)
                XCTAssertEqual(runner.session.selection.sceneID, 2)
                XCTAssertEqual(runner.session.selection.blockID, 6)
                XCTAssertEqual(runner.session.selection.modeID, 0)
                XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 0)), true)
                return
            default: return XCTFail("Unexpected conversation state: \(runner.phase)")
            }
        }
        XCTFail("Conversation did not return to exploration")
    }

    func testConversationBlockStorageMatchesOriginalOffsets() throws {
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(2, previous: 1)
        game.rememberConversationBlock(scene: 2, block: 6)
        XCTAssertEqual(game.conversationBlock(map: 2, person: 2), 6)
        XCTAssertEqual(game.bytes[0x1C2], 6)
        XCTAssertEqual(game.conversationBlock(map: 3, person: 2), 0)
        game.rememberConversationBlock(scene: 0xFFFE, block: 7)
        XCTAssertEqual(game.conversationBlock(map: 2, person: 0), 7)
        XCTAssertEqual(game.conversationBlock(map: 2, person: 2), 6)
    }

    func testOwnedUnrelatedItemUsesSystemResponseAndReturnsToDunningMenu() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try afterRegistration(holding: [0])
        guard case .questions = runner.phase else { return XCTFail("Expected Dunning's question menu") }
        XCTAssertTrue(try runner.game.inventory.items.contains(0))

        let response = try XCTUnwrap(runner.showItem(0, catalog: catalog))
        XCTAssertEqual(response.program.name, "System")
        XCTAssertEqual(response.eventIndex, 32)
        var sharedResponse = response
        advanceToExploration(&sharedResponse)
        XCTAssertEqual(sharedResponse.phase, .exploration(mapID: 2))

        runner.resumeConversation(after: sharedResponse)
        guard case .questions = runner.phase else {
            return XCTFail("The shared item response must return to Dunning's question menu")
        }
        XCTAssertEqual(runner.game.bytes, sharedResponse.game.bytes)
    }

    func testItemWithoutChapterOrSystemResponseLeavesQuestionMenuOpen() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let chapter = try catalog.loadProgram("EP1_R102").blocks
        let system = try catalog.loadProgram("System").blocks
        var unmatched: UInt8?
        for rawItem in 0..<88 {
            let item = UInt8(rawItem)
            let chapterOutcome = try OriginalShownItemSelector.select(graph: chapter, person: 2,
                item: item, nowTime: 0) { _ in .pass }
            let systemOutcome = try OriginalShownItemSelector.select(graph: system, person: 2,
                item: item, nowTime: 0, scope: .system) { _ in .pass }
            if chapterOutcome == .noMatch, systemOutcome == .noMatch {
                unmatched = item
                break
            }
        }
        let item = try XCTUnwrap(unmatched, "Expected a bundled item with no response row")
        var runner = try afterRegistration(holding: [item])
        let gameBefore = runner.game.bytes
        guard case .questions = runner.phase else { return XCTFail("Expected Dunning's question menu") }

        XCTAssertNil(runner.showItem(item, catalog: catalog))
        guard case .questions = runner.phase else {
            return XCTFail("An unmatched item must leave the question menu open")
        }
        XCTAssertEqual(runner.game.bytes, gameBefore)
    }

    @MainActor
    func testPlaySessionShowsSystemResponseAndRestoresConversationMenu() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let runner = try afterRegistration(holding: [0])
        let audio = AudioController()
        try audio.applyOriginalCommand(.disableMusic(true))
        try audio.applyOriginalCommand(.disableNewEffects(true))
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }

        play.showItemInConversation(0)
        XCTAssertEqual(play.runner.program.name, "System")
        XCTAssertEqual(play.runner.eventIndex, 32)
        for _ in 0..<300 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            case .exploration: play.advanceFrame()
            default: XCTFail("Shared response stopped at \(play.runner.phase)"); return
            }
            if case .questions = play.runner.phase { break }
        }

        XCTAssertEqual(play.runner.program.name, "EP1_R102")
        guard case .questions = play.runner.phase else {
            return XCTFail("The player must return to Dunning's question menu")
        }
    }

    func testNearbyPersonUsesOriginalPlacementDistanceAndFacing() throws {
        let runner = try afterRegistration()
        var lobby = try OriginalMapExploration.bundled()
        XCTAssertNil(lobby.nearbyPerson(in: runner.game))
        for _ in 0..<160 { lobby.update(heldPageTouch: .init(140, 80)) }
        for _ in 0..<46 { lobby.update(heldPageTouch: .init(70, 75)) }
        XCTAssertEqual(lobby.nearbyPerson(in: runner.game), 2)
        XCTAssertFalse(lobby.canInspectCounter(in: runner.game))
        XCTAssertTrue(lobby.inspectCounter())
        XCTAssertNil(lobby.nearbyPerson(in: runner.game))
        XCTAssertNil(runner.game.conversationBlock(map: -1, person: 2))
        XCTAssertNil(runner.game.conversationBlock(map: 47, person: 2))
        XCTAssertNil(runner.game.personMarker(18))
    }

    func testStandingPositionSearchRestrictions() throws {
        let rules = try OriginalMapRestrictions.bundled()
        XCTAssertEqual(rules.places.count, 87)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(2, previous: 1)
        XCTAssertTrue(rules.permitsSearch(area: 2, game: game))
        try game.apply(.setPersonLocation(index: 2, location: 2, field6: 1, field7: 0))
        XCTAssertFalse(rules.permitsSearch(area: 2, game: game))
        XCTAssertTrue(rules.permitsSearch(area: 1, game: game))
        try game.apply(.setPersonLocation(index: 2, location: 2, field6: 2, field7: 0))
        XCTAssertTrue(rules.permitsSearch(area: 2, game: game))
        XCTAssertFalse(rules.permitsSearch(area: 1, game: game))
        try game.apply(.setPersonLocation(index: 2, location: 3, field6: 1, field7: 0))
        XCTAssertTrue(rules.permitsSearch(area: 1, game: game))
        XCTAssertThrowsError(try OriginalMapRestrictions(standPlaces: Data([1, 0, 0, 0]),
            occupiedMapSearchPermissions: Data(repeating: 1, count: 47)))
    }

    func testRegionSelectorUsesOriginalTimeAndConditions() throws {
        let graph = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102").blocks
        var requests: [OriginalConditionRequest] = []
        let selected = try OriginalRegionSelector.select(graph: graph, region: 3, nowTime: 0) {
            requests.append($0)
            return .pass
        }
        guard case .selected(let row) = selected else { return XCTFail("Expected region event") }
        XCTAssertEqual(row.eventIndex, 55)
        XCTAssertEqual(requests.map(\.eventKey), [55])
        XCTAssertEqual(try OriginalRegionSelector.select(graph: graph, region: 3, nowTime: 0) { _ in .fail(sourceOffset: 0) }, .noMatch)
        guard case .selected(let later) = try OriginalRegionSelector.select(graph: graph, region: 3, nowTime: 1, evaluate: { _ in .pass }) else {
            return XCTFail("Expected the later region event")
        }
        XCTAssertEqual(later.eventIndex, 66)
        XCTAssertEqual(try OriginalRegionSelector.select(graph: graph, region: 99, nowTime: 0) { _ in
            XCTFail("An absent region must not evaluate conditions")
            return .pass
        }, .noMatch)
    }

    func testRegionEventStartsOnlyWhenItsStoryConditionsPass() throws {
        let setup = try afterRegistration()
        var game = setup.game
        game.markKeywordAsked(0, person: 2)
        try game.apply(.setFlag32(index: 16))
        var runner = try OriginalEventRunner(program: setup.program, game: game, keywords: setup.keywords)
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
        XCTAssertFalse(runner.enterMapRegion(1))
        XCTAssertTrue(runner.enterMapRegion(3))
        XCTAssertEqual(runner.eventIndex, 55)
        XCTAssertEqual(runner.session.selection.sceneID, 0xFFFF)
        guard case .dialogue = runner.phase else { return XCTFail("Expected region dialogue") }
        XCTAssertFalse(runner.enterMapRegion(3), "A running conversation cannot be restarted by a region")
        for _ in 0..<100 {
            guard case .dialogue = runner.phase else { break }
            runner.acknowledgeDialogue()
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 55)), true)
        XCTAssertEqual(runner.game.personMarker(7), 205)
        XCTAssertFalse(runner.enterMapRegion(3), "The completed one-time event must not restart")
    }

    func testDepartureCancellationAndEntryMarkers() throws {
        let setup = try afterRegistration()
        var game = setup.game
        try game.apply(.setFlag32(index: 16))
        var runner = try OriginalEventRunner(program: setup.program, game: game, keywords: setup.keywords)
        XCTAssertTrue(runner.beginMapDeparture(to: 3))
        XCTAssertEqual(runner.eventIndex, 54)
        for _ in 0..<30 {
            guard case .dialogue = runner.phase else { break }
            runner.acknowledgeDialogue()
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
        XCTAssertTrue(runner.processRequests.contains(.init(kind: 2, value: -1)))
        game.markKeywordAsked(0, person: 2)
        runner = try OriginalEventRunner(program: setup.program, game: game, keywords: setup.keywords)
        XCTAssertFalse(runner.beginMapDeparture(to: 3))
        let catalog = try OriginalScriptCatalog.bundled()
        let moved = try runner.moving(to: 3, program: catalog.loadProgram("EP1_R103"))
        XCTAssertEqual(moved.phase, .exploration(mapID: 3))
        XCTAssertEqual(moved.game.previousMapID, 2)
        XCTAssertEqual(moved.game.conversationBlock(map: 2, person: 2), game.conversationBlock(map: 2, person: 2))
        let lobby = try OriginalMapExploration.bundled(mapID: 3, previousMapID: 2)
        XCTAssertEqual(lobby.position, SIMD3(28, 12288, 16679))
        XCTAssertEqual(lobby.facing, .pi, accuracy: 0.002)
        XCTAssertEqual(lobby.mapOrigin, SIMD2(257, 330))
        var returning = try OriginalMapExploration.bundled(mapID: 2, previousMapID: 3)
        XCTAssertEqual(returning.position, SIMD3(-8190, 12288, -26467))
        XCTAssertEqual(returning.facing, 0, accuracy: 0.002)
        let previous = returning.position
        returning.update(heldPageTouch: SIMD2(96, 210))
        XCTAssertNotEqual(returning.position, previous)
        returning.cancelDeparture()
        XCTAssertEqual(returning.position, previous)
        XCTAssertEqual(try OriginalMapExploration.bundled(mapID: 4, previousMapID: 3).mapID, 4)
        XCTAssertThrowsError(try OriginalMapExploration.bundled(mapID: 0, previousMapID: 3))
        XCTAssertThrowsError(try OriginalMapExploration.bundled(mapID: 47, previousMapID: 3))
        var corridor = try OriginalMapExploration.bundled(mapID: 17, previousMapID: 3)
        XCTAssertEqual(corridor.position, SIMD3(6636, 12288, 4014))
        XCTAssertEqual(corridor.facing, -1.572017, accuracy: 0.002)
        for _ in 0..<31 { corridor.update(heldPageTouch: SIMD2(96, 45)) }
        XCTAssertEqual(corridor.position, SIMD3(6636, 12288, -7301))
        XCTAssertEqual(corridor.eventRegion, 1)
    }

    func testR103RemindersMatchOriginalRoute() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/r103-entry/entry-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("The original R103 entry capture is not available")
        }
        let ram = try OriginalBytes(Data(contentsOf: file))
        let game = try OriginalGameState(snapshot: Data(ram.range(0x11018C, OriginalGameState.byteCount)))
        var runner = try OriginalEventRunner(program: OriginalScriptCatalog.bundled().loadProgram("EP1_R103"), game: game)
        for event in 0..<3 {
            XCTAssertTrue(runner.enterMapRegion(2))
            XCTAssertEqual(runner.eventIndex, event)
            for _ in 0..<60 {
                guard case .dialogue = runner.phase else { break }
                runner.acknowledgeDialogue()
            }
            XCTAssertEqual(runner.phase, .exploration(mapID: 3))
            XCTAssertEqual(runner.game.value(for: .eventFlag(group: 3, index: UInt16(event))), true)
        }
        XCTAssertFalse(runner.enterMapRegion(2))
    }

    func testTalkAndInspectionMatchOriginalPostRegistrationCapture() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/post-registration-lobby/lobby-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("The original post-registration capture is not available")
        }
        let ram = try Data(contentsOf: file), bytes = OriginalBytes(ram)
        let game = try OriginalGameState(snapshot: Data(bytes.range(0x11018C, OriginalGameState.byteCount)))
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: game)
        var lobby = try OriginalMapExploration.bundled()
        for _ in 0..<160 { lobby.update(heldPageTouch: .init(140, 80)) }
        for _ in 0..<46 { lobby.update(heldPageTouch: .init(70, 75)) }
        for axis in 0..<3 {
            XCTAssertEqual(lobby.position[axis], Float(Int32(bitPattern: try bytes.u32(0x27CFA0 + 0x168 + axis * 4))), accuracy: 4)
        }
        XCTAssertEqual(lobby.facing, Float(bitPattern: try bytes.u32(0x27CFA0 + 0x184)), accuracy: 0.02)
        XCTAssertEqual(lobby.nearbyPerson(in: game), Int16(truncatingIfNeeded: try bytes.u32(0x27CFA0 + 0x1460C)))
        XCTAssertEqual(try bytes.u32(0x27CFA0 + 0x145F8), UInt32.max)
        XCTAssertFalse(lobby.canInspectCounter(in: game))
        XCTAssertEqual(game.conversationBlock(map: 2, person: 2), 6)
        var departing = runner
        for _ in 0..<110 { lobby.update(heldPageTouch: .init(20, 128)) }
        XCTAssertEqual(lobby.position.x, -7304, accuracy: 4)
        var entered = false
        for _ in 0..<110 {
            lobby.update(heldPageTouch: .init(96, 45))
            if let region = lobby.eventRegion, departing.enterMapRegion(region) { entered = true; break }
        }
        XCTAssertTrue(entered)
        XCTAssertEqual(departing.eventIndex, 55)
        XCTAssertEqual(lobby.position.z, -7777, accuracy: 4)
        runner.talkToPerson(2)
        XCTAssertEqual(runner.eventIndex, 50, "The original Talk capture selects event key 50, mode 0, event ID 49")
    }
}
