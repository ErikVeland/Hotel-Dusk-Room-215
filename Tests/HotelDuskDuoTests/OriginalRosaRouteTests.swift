import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalRosaRouteTests: XCTestCase {
    private func state(_ path: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original Rosa route capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func advance(_ play: OriginalPlaySession) {
        for _ in 0..<400 {
            switch play.runner.phase {
            case .dialogue where play.runner.interruptAvailable: play.interrupt()
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return
            }
        }
        XCTFail("Rosa's dialogue did not finish")
    }

    private func compare(_ play: OriginalPlaySession, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try state(path).bytes
        XCTAssertEqual(play.runner.game.bytes.indices.filter { play.runner.game.bytes[$0] != expected[$0] }, [], file: file, line: line)
    }

    func testMilaAndRosaReachThe520TimeChange() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"),
            game: state("mila-talk-correct/near"),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        runner.talkToPerson(5)
        XCTAssertEqual(runner.eventIndex, 67)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        advance(play)
        XCTAssertEqual(play.runner.phase, .picture(id: 24))
        let picture = try state("mila-talk-correct/page3").bytes
        XCTAssertEqual(play.runner.game.bytes.indices.filter { play.runner.game.bytes[$0] != picture[$0] }, [])
        play.touchPicture(pageX: 96, pageY: 225)
        play.releasePicture()
        XCTAssertEqual(play.touchPicture?.selected, true)
        play.touchPicture(pageX: 96, pageY: 225)
        play.releasePicture()
        for _ in 0..<24 { play.advanceFrame() }
        advance(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(play.runner.game.personMarker(3), 203)
        XCTAssertEqual(play.lobby?.position, SIMD3(15811, 12288, 17285))
        try compare(play, "rosa-introduction/page21")
        // The reference's final dialogue tap moves south for three frames after event 69.
        play.holdLobbyTouch(x: 96, y: 225)
        for _ in 0..<3 { play.advanceFrame() }
        play.releaseLobbyTouch()
        play.holdLobbyTouch(x: 96, y: 45)
        // The original polls the held touch one frame after the command starts.
        for _ in 0..<29 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.position, SIMD3(16226, 12288, 12029))
        XCTAssertEqual(play.lobby?.facing, 2.9292964935302734)
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 3)
        play.talkToNearbyPerson()
        XCTAssertEqual(play.runner.eventIndex, 70)
        advance(play)
        guard case .choice(let options) = play.runner.phase else { return XCTFail("Expected Rosa's salesman interrupt: \(play.runner.phase)") }
        XCTAssertEqual(options.map(\.id), [10, 11])
        try compare(play, "rosa-salesman-interrupt/page1")
        play.choose(10)
        advance(play)
        guard case .questions(let topics) = play.runner.phase else { return XCTFail("Expected Rosa's questions") }
        XCTAssertEqual(topics.map(\.keyword), [14, 21])
        try compare(play, "rosa-salesman-answer/page20")
        play.ask(21)
        advance(play)
        try compare(play, "rosa-mila-name/page40")
        play.ask(22)
        advance(play)
        try compare(play, "rosa-room-question/page25")
        play.ask(23)
        advance(play)
        guard case .choice(let options) = play.runner.phase else { return XCTFail("Expected the Jeff answer") }
        XCTAssertEqual(options.map(\.id), [12, 13])
        try compare(play, "rosa-jeff-question/page4")
        play.choose(13)
        advance(play)
        try compare(play, "rosa-jeff-question/page14")
        play.ask(14)
        advance(play)
        XCTAssertEqual(play.runner.phase, .process(id: 126))
        try compare(play, "rosa-parcel-departure/page35")
        for _ in 0..<2000 {
            guard case .process(126) = play.runner.phase else { break }
            play.advanceFrame()
        }
        advance(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(play.runner.game.nowTime, 2)
        XCTAssertNil(play.runner.game.personMarker(3))
        XCTAssertNil(play.runner.game.personMarker(5))
        try compare(play, "rosa-parcel-departure/page36")
    }

    func testMissedSalesmanInterruptStillReachesTheOriginalQuestionMenu() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"),
            game: state("rosa-introduction/page21"),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        runner.talkToPerson(3)
        for _ in 0..<200 {
            switch runner.phase {
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: break
            }
            if case .questions = runner.phase { break }
        }
        guard case .questions(let topics) = runner.phase else { return XCTFail("Expected Rosa's questions after the missed interrupt") }
        XCTAssertEqual(topics.map(\.keyword), [14, 21])
        let expected = try state("rosa-talk-facing/page18").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [])
    }
}
