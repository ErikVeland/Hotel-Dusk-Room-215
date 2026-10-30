import XCTest
@testable import HotelDuskDuoKit

final class OriginalShownItemResponseTests: XCTestCase {
    private func dunningQuestions() throws -> OriginalEventRunner {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(2, previous: 1)
        var bytes = game.bytes
        for keyword in 0...2 { bytes[0x880 + keyword * 4] = 1 }
        bytes[0x13E4 + 2 * 11 + 21 / 8] = 0x60
        game = try OriginalGameState(snapshot: Data(bytes))
        return try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: game,
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")),
            selection: .init(sceneID: 2, blockID: 4, modeID: 8, eventID: 28,
                             nowTime: game.nowTime, mapID: 2))
    }

    func testMissingChapterResponseRetainsTheConversationForSystemFallback() throws {
        var parent = try dunningQuestions()
        let phase = parent.phase, session = parent.session, trail = parent.eventTrail
        guard case .questions = phase else { return XCTFail("The isolated Dunning menu did not open: \(phase)") }
        parent.showItem(21)
        XCTAssertEqual(parent.phase, phase)
        XCTAssertEqual(parent.session, session)
        XCTAssertEqual(parent.eventTrail, trail)
    }

    func testSuitcaseKeyUsesOriginalGenericSystemResponseAndReturnsToDunningQuestions() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var parent = try dunningQuestions()
        let phase = parent.phase, session = parent.session, trail = parent.eventTrail
        var response = try XCTUnwrap(parent.showItem(21, catalog: catalog))
        XCTAssertEqual(response.program.name, "System")
        XCTAssertEqual(response.eventIndex, 32)
        XCTAssertEqual(response.session.selection.checkItemID, 0)
        guard case .dialogue(let packet) = response.phase else { return XCTFail("Expected original shared dialogue: \(response.phase)") }
        XCTAssertEqual(packet.pages.flatMap(\.entries).map(\.index), [257, 258, 259])
        XCTAssertEqual(try XCTUnwrap(packet.pages.first?.entries.first?.utf8), "%c0%d1%w0%p0000215%n0The hell's that?")
        for _ in 0..<10 {
            guard case .dialogue = response.phase else { break }
            response.acknowledgeDialogue()
        }
        XCTAssertEqual(response.phase, .exploration(mapID: 2))
        parent.resumeConversation(after: response)
        XCTAssertEqual(parent.phase, phase)
        XCTAssertEqual(parent.session, session)
        XCTAssertEqual(parent.eventTrail, trail)
        XCTAssertEqual(try parent.game.inventory.items, [21, 22])
        XCTAssertEqual(parent.game.bytes[0x13E4 + 2 * 11 + 21 / 8], 0x40)
        XCTAssertEqual(parent.game.value(for: .eventFlag(group: 2, index: 32)), false)
        parent.ask(0)
        guard case .dialogue = parent.phase else { return XCTFail("The retained question could not be asked: \(parent.phase)") }
        XCTAssertEqual(parent.program.name, "EP1_R102")
    }

    func testSpecificSystemItemResponsePrecedesGenericResponseAndMergesState() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var parent = try dunningQuestions()
        var response = try XCTUnwrap(parent.showItem(22, catalog: catalog))
        XCTAssertEqual(response.eventIndex, 20)
        XCTAssertEqual(response.session.selection.checkItemID, 22)
        XCTAssertEqual(parent.phase, try dunningQuestions().phase)
        for _ in 0..<10 {
            guard case .dialogue = response.phase else { break }
            response.acknowledgeDialogue()
        }
        XCTAssertEqual(response.phase, .exploration(mapID: 2))
        parent.resumeConversation(after: response)
        XCTAssertEqual(parent.game.bytes, response.game.bytes)
        guard case .questions = parent.phase else { return XCTFail("The conversation did not resume") }
    }

    func testUnownedItemDoesNotStartAResponse() throws {
        var parent = try dunningQuestions()
        let phase = parent.phase, session = parent.session, game = parent.game.bytes
        XCTAssertNil(try parent.showItem(1, catalog: .bundled()))
        XCTAssertEqual(parent.phase, phase)
        XCTAssertEqual(parent.session, session)
        XCTAssertEqual(parent.game.bytes, game)
    }

    func testSharedMode27FinishesForItsRetainedConversationAndKeepsItemChanges() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(2, previous: 1)
        try game.apply(.addInventory(id: 79))
        var context = OriginalEventSelectionContext(sceneID: 3, blockID: 0, modeID: 27,
            eventID: 73, nowTime: game.nowTime, mapID: game.mapID)
        context.checkItemID = 79
        var response = try OriginalEventRunner(program: catalog.loadProgram("System"), game: game,
            selection: context, scope: .system)
        XCTAssertEqual(response.eventIndex, 73)
        for _ in 0..<30 {
            guard case .dialogue = response.phase else { break }
            response.acknowledgeDialogue()
        }
        XCTAssertEqual(response.phase, .exploration(mapID: 2))
        XCTAssertFalse(try response.game.inventory.items.contains(79))
        XCTAssertEqual(response.game.value(for: .eventFlag(group: 2, index: 73)), false)
    }
}
