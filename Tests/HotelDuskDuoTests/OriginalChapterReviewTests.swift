import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterReviewTests: XCTestCase {
    private func state(_ path: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original review capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func advance(_ runner: inout OriginalEventRunner) {
        for _ in 0..<600 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: return
            }
        }
        XCTFail("The review dialogue did not finish")
    }

    private func beginCall() throws -> OriginalEventRunner {
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: state("order-leave-parcel/inspect"))
        runner.lookInSearchView(area: 1, subarea: 1, table: try .bundled(map: "R205"))
        XCTAssertEqual(runner.eventIndex, 121)
        advance(&runner)
        return runner
    }

    private func compare(_ runner: OriginalEventRunner, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try state(path).bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], file: file, line: line)
    }

    func testCallAndReviewAnswersMatchOriginalState() throws {
        var runner = try beginCall()
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected the first review question: \(runner.phase)") }
        XCTAssertEqual(choices.map(\.id), [60, 61, 62])
        XCTAssertEqual(runner.reviewQuestionIndex, 0)
        try compare(runner, "order-rachel-call/page55")
        runner.choose(61)
        advance(&runner)
        guard case .choice(let next) = runner.phase else { return XCTFail("Expected the second review question: \(runner.phase)") }
        XCTAssertEqual(next.map(\.id), [63, 64, 65])
        XCTAssertEqual(runner.reviewQuestionIndex, 1)
        try compare(runner, "chapter-one-review-first/page18")
        runner.choose(63)
        advance(&runner)
        guard case .choice(let third) = runner.phase else { return XCTFail("Expected the third review question") }
        XCTAssertEqual(third.map(\.id), [66, 67, 68])
        XCTAssertEqual(runner.reviewQuestionIndex, 2)
        try compare(runner, "chapter-one-review-second/page24")
        runner.choose(68)
        advance(&runner)
        guard case .choice(let fourth) = runner.phase else { return XCTFail("Expected the fourth review question") }
        XCTAssertEqual(fourth.map(\.id), [69, 70, 71])
        XCTAssertEqual(runner.reviewQuestionIndex, 3)
        try compare(runner, "chapter-one-review-third/page20")
        runner.choose(70)
        advance(&runner)
        guard case .choice(let last) = runner.phase else { return XCTFail("Expected the last review question") }
        XCTAssertEqual(last.map(\.id), [72, 73, 74])
        XCTAssertEqual(runner.reviewQuestionIndex, 4)
        try compare(runner, "chapter-one-review-fourth/page24")
    }

    func testAllChapterReviewTablesDecode() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        for chapter in 1...9 {
            let table = try OriginalChapterReview(decoded: catalog.decodedFile("EP\(chapter)_.spn"))
            XCTAssertFalse(table.questions.isEmpty)
            XCTAssertEqual(table.questions.last?.nextEvent, .max)
            XCTAssertTrue(table.questions.allSatisfy { $0.answers.contains { $0.advances } })
        }
        XCTAssertTrue(try catalog.decodedFile("EP10_.spn").isEmpty)
    }

    func testWrongAnswerReplaysTheSameQuestion() throws {
        var runner = try beginCall()
        runner.choose(60)
        advance(&runner)
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected the first question again") }
        XCTAssertEqual(choices.map(\.id), [60, 61, 62])
        XCTAssertEqual(runner.reviewQuestionIndex, 0)
        try compare(runner, "chapter-one-review-wrong/page18")
    }

    func testEachWrongAnswerRetriesAndCorrectAnswersRequestChapterTwo() throws {
        var runner = try beginCall()
        for (index, answers) in [(60, 61), (64, 63), (66, 68), (69, 70), (73, 72)].enumerated() {
            guard case .choice(let original) = runner.phase else { return XCTFail("Expected a review menu") }
            runner.choose(UInt16(answers.0))
            advance(&runner)
            XCTAssertEqual(runner.phase, .choice(original))
            XCTAssertEqual(runner.reviewQuestionIndex, index)
            runner.choose(UInt16(answers.1))
            advance(&runner)
            XCTAssertEqual(runner.reviewQuestionIndex, index + 1)
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(runner.processRequests.suffix(2), [.init(kind: 1, value: 31), .init(kind: 4, value: 1)])
        XCTAssertEqual(runner.game.chapter, 0, "The host consumes the chapter request after the review returns")
    }

    func testChapterResetAndTitleMatchOriginalState() throws {
        var runner = try beginCall()
        for answer: UInt16 in [61, 63, 68, 70, 72] {
            runner.choose(answer)
            advance(&runner)
        }
        var game = runner.game
        try game.beginChapter(1)
        game.setMap(31, previous: 31)
        game.setMapPosition(SIMD3(-16687, 12288, 3735), facing: 4.71238899230957)
        let save = try state("chapter-one-review-final/page32").bytes
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != save[$0] }, [])
        try game.beginChapterTitle(label: " 05:30PM")
        let title = try state("chapter-two-no-save/next").bytes
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != title[$0] }, [])
    }
}
