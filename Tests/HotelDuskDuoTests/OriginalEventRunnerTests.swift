import XCTest
@testable import HotelDuskDuoKit

final class OriginalEventRunnerTests: XCTestCase {
    private func arrival() throws -> OriginalEventRunner {
        try OriginalEventRunner.chapterOneArrival(catalog: .bundled(), defaults: .bundled())
    }

    private func firstLine(_ phase: OriginalEventRunner.Phase) -> String? {
        guard case .dialogue(let packet) = phase else { return nil }
        return packet.pages.compactMap { page in
            String(data: page.visibleBytes, encoding: .isoLatin1)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.first { !$0.isEmpty }
    }

    func testArrivalRunsKyleNarrationThenTheEntranceProcess() throws {
        var runner = try arrival()
        XCTAssertEqual(runner.eventIndex, 0)
        var pages = 0
        var lines: [String] = []
        while case .dialogue = runner.phase {
            if let line = firstLine(runner.phase) { lines.append(line) }
            pages += 1
            runner.acknowledgeDialogue()
        }
        // Event 0 has 13 dialogue commands; one is a two-page pair.
        XCTAssertEqual(pages, 12)
        XCTAssertTrue(lines.contains { $0.hasPrefix("The name's Kyle Hyde.") })
        XCTAssertEqual(runner.phase, .process(id: 56))
        XCTAssertEqual(runner.eventIndex, 1)
        XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 0)), true)
    }

    func testEntranceReturnEntersTheLobbyAndStopsAtExploration() throws {
        var runner = try arrival()
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        runner.finishProcess(returnValue: 0)
        XCTAssertEqual(runner.eventIndex, 2)
        XCTAssertEqual(firstLine(runner.phase), "Great.")
        var pages = 1
        runner.acknowledgeDialogue()
        while case .dialogue = runner.phase { pages += 1; runner.acknowledgeDialogue() }
        XCTAssertEqual(pages, 5)
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
        // Opcode 10 kind 1 makes keyword 0 available; opcode 13 places person 3.
        XCTAssertEqual(runner.game.bytes[0x880], 1)
        XCTAssertEqual(runner.game.bytes[0xCA4 + 3 * 4], 0x11)
        XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 2)), true)
    }

    func testCompletedArrivalHaltsInsteadOfReplaying() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(2, previous: 1)
        game.markEventCompleted(group: 2, event: 0)
        // With the arrival already seen, no arrival event remains.
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: game)
        guard case .halted(let halt) = runner.phase else { return XCTFail("Expected a halt") }
        XCTAssertNil(halt.sourceOffset)
        XCTAssertTrue(halt.reason.hasPrefix("No original event"))
    }
}
