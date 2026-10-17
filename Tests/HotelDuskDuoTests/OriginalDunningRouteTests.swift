import XCTest
@testable import HotelDuskDuoKit

final class OriginalDunningRouteTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func state(_ path: String) throws -> OriginalGameState {
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original Dunning capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    func testNameAndWishInterruptsPreserveBrochureHandover() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let initial = try state("dunning-name-pages/start")
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: initial,
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")),
            selection: .init(sceneID: 2, blockID: 2, modeID: 3, eventID: 19, nowTime: initial.nowTime, mapID: 2))
        var pictures: [UInt16] = [], choices: [UInt16] = []
        for _ in 0..<400 {
            switch runner.phase {
            case .dialogue where runner.interruptAvailable: runner.pressInterrupt()
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .choice(let options):
                let choice = try XCTUnwrap(options.first(where: { [5, 6].contains($0.id) }))
                choices.append(choice.id)
                runner.choose(choice.id)
            case .picture(let id): pictures.append(id); runner.finishPicture()
            case .waiting: runner.advanceWait()
            case .questions(let topics):
                XCTAssertEqual(choices, [5, 6])
                XCTAssertEqual(pictures, [2, 3])
                XCTAssertEqual(topics.map(\.keyword), [0, 1, 2])
                let original = try state("dunning-question-menu/page25").bytes
                XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != original[$0] }, [])
                return
            default: return XCTFail("Dunning stopped at \(runner.phase)")
            }
        }
        XCTFail("Dunning did not reach the question menu")
    }
    func testRequiredQuestionAnswersMatchOriginalReturnToLobby() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let initial = try state("dunning-question-menu/page25")
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: initial,
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")),
            selection: .init(sceneID: 2, blockID: 4, modeID: 8, eventID: 28, nowTime: initial.nowTime, mapID: 2))
        var asked: [Int16] = []
        let checkpoints = ["dunning-package-answer/page25", "dunning-other-name-answer/page35"]
        for _ in 0..<400 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            case .questions(let topics):
                if !asked.isEmpty {
                    guard asked.count <= checkpoints.count else { return XCTFail("An answered question returned unexpectedly") }
                    let original = try state(checkpoints[asked.count - 1]).bytes
                    XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != original[$0] }, [], "After question \(asked.last!)")
                }
                let topic = try XCTUnwrap(topics.first)
                asked.append(topic.keyword)
                runner.ask(topic.keyword)
            case .exploration:
                XCTAssertEqual(asked, [0, 1, 2])
                XCTAssertTrue((0...2).allSatisfy { runner.game.keywordUsed($0) })
                let original = try state("dunning-room-wish-answer/page35").bytes
                XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != original[$0] }, [])
                return
            default: return XCTFail("Dunning's answers stopped at \(runner.phase)")
            }
        }
        XCTFail("Dunning's answers did not return to the lobby")
    }

    func testSkippingOptionalPackageQuestionLeavesOnlyItsHallwayReminder() throws {
        let initial = try state("dunning-hallway-entry/r103")
        XCTAssertTrue((0...2).allSatisfy { initial.keywordUsed($0) })
        XCTAssertFalse(initial.keywordUsed(3))
        var runner = try OriginalEventRunner(program: OriginalScriptCatalog.bundled().loadProgram("EP1_R103"), game: initial)
        XCTAssertTrue(runner.enterMapRegion(2))
        XCTAssertEqual(runner.eventIndex, 2)
        for _ in 0..<60 {
            guard case .dialogue = runner.phase else { break }
            runner.acknowledgeDialogue()
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 3))
        let original = try state("dunning-r103-reminders/reminder1").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != original[$0] }, [])
        XCTAssertFalse(runner.enterMapRegion(2))
    }

}
