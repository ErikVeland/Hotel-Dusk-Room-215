import XCTest
@testable import HotelDuskDuoKit

final class OriginalIrisRouteTests: XCTestCase {
    private func state(_ path: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original Iris capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func advance(_ runner: inout OriginalEventRunner) {
        for _ in 0..<400 {
            switch runner.phase {
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: return
            }
        }
        XCTFail("Iris's dialogue did not finish")
    }

    private func compare(_ runner: OriginalEventRunner, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try state(path).bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], file: file, line: line)
    }

    func testIrisIntroductionMatchesTheOriginalQuestionMenu() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R213"),
            game: state("iris-entrance/entrance"),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        XCTAssertTrue(runner.enterMapRegion(1))
        XCTAssertEqual(runner.eventIndex, 63)
        advance(&runner)
        guard case .questions(let topics) = runner.phase else { return XCTFail("Expected Iris's question menu: \(runner.phase)") }
        XCTAssertEqual(topics.map(\.keyword), [24])
        try compare(runner, "iris-introduction/page30")
        runner.ask(24)
        advance(&runner)
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected Iris's work question") }
        XCTAssertEqual(choices.map(\.id), [34, 35])
        try compare(runner, "iris-confirm-question/page14")
        runner.choose(34)
        advance(&runner)
        XCTAssertEqual(runner.phase, .exploration(mapID: 39))
        XCTAssertTrue(runner.game.keywordAsked(24, person: 9))
        XCTAssertTrue(runner.game.keywordAvailable(25))
        try compare(runner, "iris-salesman-departure/page55")
    }
}
