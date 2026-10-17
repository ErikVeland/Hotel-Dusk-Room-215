import XCTest
@testable import HotelDuskDuoKit

final class OriginalMelissaRouteTests: XCTestCase {
    private func state(_ path: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original Melissa capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func advance(_ runner: inout OriginalEventRunner) {
        for _ in 0..<300 {
            switch runner.phase {
            case .dialogue where runner.interruptAvailable: runner.pressInterrupt()
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: return
            }
        }
        XCTFail("Melissa's dialogue did not finish")
    }

    func testEntranceAndConversationReachNotebookPicture() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R213"),
            game: state("notebook-door-inspect/inspect"),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        XCTAssertTrue(runner.enterMapRegion(2))
        XCTAssertEqual(runner.eventIndex, 32)
        advance(&runner)
        XCTAssertEqual(runner.phase, .exploration(mapID: 39))
        let entered = try state("melissa-entrance-pages/page8").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != entered[$0] }, [])
        runner.talkToPerson(11)
        XCTAssertEqual(runner.eventIndex, 34)
        advance(&runner)
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected Melissa's first choice: \(runner.phase)") }
        XCTAssertEqual(choices.map(\.id), [31, 30])
        let firstChoice = try state("melissa-mother-interrupt/page2").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != firstChoice[$0] }, [])
        runner.choose(31)
        advance(&runner)
        guard case .questions(let questions) = runner.phase else { return XCTFail("Expected Melissa's questions: \(runner.phase)") }
        XCTAssertTrue(questions.contains { $0.keyword == 15 })
        let firstMenu = try state("melissa-mother-correct/page9").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != firstMenu[$0] }, [])
        runner.ask(15)
        advance(&runner)
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected the missing mother choice: \(runner.phase)") }
        XCTAssertEqual(choices.map(\.id), [32, 33])
        let secondChoice = try state("melissa-missing-mother-choice/page1").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != secondChoice[$0] }, [])
        runner.choose(33)
        advance(&runner)
        let secondMenu = try state("melissa-missing-mother-answer/page16").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != secondMenu[$0] }, [])
        runner.ask(16)
        advance(&runner)
        XCTAssertEqual(runner.phase, .picture(id: 22))
        let picture = try state("melissa-father-answer/page28").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != picture[$0] }, [])
        runner.finishPicture()
        advance(&runner)
        XCTAssertEqual(runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(runner.game.bytes[0x87B] & 1, 1)
        XCTAssertTrue(try runner.game.inventory.items.contains(3))
        let returned = try state("melissa-father-answer/page33").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != returned[$0] }, [])
        runner.talkToPerson(11)
        XCTAssertEqual(runner.eventIndex, 61)
        advance(&runner)
        XCTAssertEqual(runner.phase, .questions([]))
        let retalk = try state("melissa-piece-retalk/page4").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != retalk[$0] }, [])
        let beforeUnowned = runner.game.bytes
        runner.showItem(87)
        XCTAssertEqual(runner.phase, .questions([]))
        XCTAssertEqual(runner.game.bytes, beforeUnowned)
        runner.showItem(3)
        XCTAssertEqual(runner.eventIndex, 50)
        advance(&runner)
        XCTAssertEqual(runner.phase, .questions([]))
        XCTAssertFalse(try runner.game.inventory.items.contains(3))
        let returnedPiece = try state("melissa-piece-show/page7").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != returnedPiece[$0] }, [])
        runner.leave()
        advance(&runner)
        XCTAssertEqual(runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(runner.game.value(for: .eventFlag(group: 39, index: 55)), true)
        XCTAssertNil(runner.game.personMarker(11))
        let departed = try state("melissa-piece-departure/page11").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != departed[$0] }, [])
    }
}
