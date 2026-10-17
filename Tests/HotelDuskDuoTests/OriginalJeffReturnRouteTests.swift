import XCTest
@testable import HotelDuskDuoKit

final class OriginalJeffReturnRouteTests: XCTestCase {
    private func state(_ path: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original Room 213 capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func advance(_ runner: inout OriginalEventRunner, interrupt: Bool = false) {
        for _ in 0..<300 {
            switch runner.phase {
            case .dialogue where interrupt && runner.interruptAvailable: runner.pressInterrupt()
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: return
            }
        }
        XCTFail("Jeff's dialogue did not finish")
    }

    private func compare(_ runner: OriginalEventRunner, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try state(path).bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], file: file, line: line)
    }

    func testRoom213KnockStartsJeffsOriginalConversation() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R213"),
            game: state("jeff-room213-inspect/near"),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        runner.interactWithDoor(area: 5)
        XCTAssertEqual(runner.phase, .exploration(mapID: 39))
        try compare(runner, "jeff-room213-inspect/door")
        runner.interactWithDoor(area: 5, upView: 334)
        XCTAssertEqual(runner.eventIndex, 76)
        advance(&runner)
        guard case .questions(let topics) = runner.phase else { return XCTFail("Expected Jeff's question menu: \(runner.phase)") }
        XCTAssertEqual(topics.map(\.keyword), [26])
        try compare(runner, "jeff-room213-knock/page16")
        runner.ask(26)
        advance(&runner, interrupt: true)
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected the Mila-request interrupt") }
        XCTAssertEqual(choices.map(\.id), [36, 37])
        try compare(runner, "jeff-room213-request-confirmed/page1")
        runner.choose(36)
        advance(&runner)
        guard case .questions(let remaining) = runner.phase else { return XCTFail("Expected the brochure question") }
        XCTAssertEqual(remaining.map(\.keyword), [27])
        try compare(runner, "jeff-room213-request-answer-correct/page16")
        runner.ask(27)
        advance(&runner)
        XCTAssertEqual(runner.phase, .exploration(mapID: 39))
        XCTAssertTrue(runner.game.keywordAsked(27, person: 6))
        try compare(runner, "jeff-room213-brochure-answer/page24")
    }
}
