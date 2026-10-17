import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalSummerRouteTests: XCTestCase {
    private func state(_ path: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original Summer capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func advance(_ runner: inout OriginalEventRunner, interrupts: inout Set<UInt16>) {
        for _ in 0..<400 {
            switch runner.phase {
            case .dialogue where runner.interruptAvailable && !interrupts.contains(runner.interrupt.event):
                interrupts.insert(runner.interrupt.event)
                runner.pressInterrupt()
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: return
            }
        }
        XCTFail("Summer's dialogue did not finish")
    }

    private func compare(_ runner: OriginalEventRunner, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try state(path).bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], file: file, line: line)
    }

    func testSummerConversationMatchesTheOriginalCheckpoints() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"),
            game: state("summer-arrival/near"),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        var interrupts: Set<UInt16> = []
        XCTAssertTrue(runner.beginMapDeparture(to: 39))
        XCTAssertEqual(runner.eventIndex, 79)
        advance(&runner, interrupts: &interrupts)
        guard case .choice(let first) = runner.phase else { return XCTFail("Expected Summer's privacy interrupt") }
        XCTAssertEqual(first.map(\.id), [52, 53])
        try compare(runner, "summer-private-interrupt/page1")
        runner.choose(52)
        advance(&runner, interrupts: &interrupts)
        guard case .choice(let second) = runner.phase else { return XCTFail("Expected Summer's behaviour interrupt") }
        XCTAssertEqual(second.map(\.id), [54, 55])
        try compare(runner, "summer-apology-interrupt/page1")
        runner.choose(55)
        advance(&runner, interrupts: &interrupts)
        guard case .questions(let topics) = runner.phase else { return XCTFail("Expected Summer's questions") }
        XCTAssertEqual(topics.map(\.keyword), [29])
        XCTAssertEqual(interrupts, [89, 92])
        try compare(runner, "summer-apology-answer/page22")
        runner.ask(29)
        advance(&runner, interrupts: &interrupts)
        guard case .questions(let remaining) = runner.phase else { return XCTFail("Expected the writer question") }
        XCTAssertEqual(remaining.map(\.keyword), [30])
        try compare(runner, "summer-name-question/page20")
        runner.ask(30)
        advance(&runner, interrupts: &interrupts)
        guard case .choice(let reading) = runner.phase else { return XCTFail("Expected the reading choice") }
        XCTAssertEqual(reading.map(\.id), [56, 57])
        try compare(runner, "summer-reading-choice/page1")
        runner.choose(57)
        advance(&runner, interrupts: &interrupts)
        guard case .choice(let books) = runner.phase else { return XCTFail("Expected the book choice") }
        XCTAssertEqual(books.map(\.id), [58, 59])
        try compare(runner, "summer-reading-answer/page3")
        runner.choose(58)
        advance(&runner, interrupts: &interrupts)
        XCTAssertEqual(runner.phase, .picture(id: 6))
        XCTAssertFalse(try runner.game.inventory.items.contains(5))
        try compare(runner, "summer-book-answer/page22")
        runner.finishPicture()
        advance(&runner, interrupts: &interrupts)
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        try compare(runner, "summer-parcel-departure/page15")
    }

    func testSummerKnockAndRetryMatchTheOriginalState() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"),
            game: state("iris-return-room215/room"),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
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
        XCTAssertEqual(play.lobby?.position, SIMD3(317, 12288, 119))
        XCTAssertEqual(play.lobby?.facing, Float(bitPattern: 0x40C90FDB))
        let expected = try state("summer-delivery-knock/page4").bytes
        XCTAssertEqual(play.runner.game.bytes.indices.filter { play.runner.game.bytes[$0] != expected[$0] }, [])
    }
}
