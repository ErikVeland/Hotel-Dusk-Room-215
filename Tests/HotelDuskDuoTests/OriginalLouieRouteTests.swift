import XCTest
@testable import HotelDuskDuoKit

final class OriginalLouieRouteTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func ram(_ path: String) throws -> Data {
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original Louie capture is not available") }
        return try Data(contentsOf: file)
    }

    private func state(_ path: String) throws -> OriginalGameState {
        try OriginalGameState(snapshot: ram(path).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func assertState(_ runner: OriginalEventRunner, _ path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let original = try state(path).bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != original[$0] }, [], path, file: file, line: line)
    }

    private func arrival() throws -> OriginalEventRunner {
        let catalog = try OriginalScriptCatalog.bundled()
        let initial = try state("delivery-door-fixture/inspect")
        return try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: initial,
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")),
            selection: .init(sceneID: .max, blockID: 0, modeID: 3, eventID: 32, nowTime: 1, mapID: 31))
    }

    private func advanceDialogue(_ runner: inout OriginalEventRunner) {
        for _ in 0..<100 {
            guard case .dialogue = runner.phase else { return }
            runner.acknowledgeDialogue()
        }
    }

    private func confirmPicture(_ id: UInt16, x: Int, y: Int, capture: String) throws {
        let record = try XCTUnwrap(OriginalTouchPictureTable.bundled().records.first { $0.id == id })
        let bitmap = try OriginalBitmapLibrary.bundled().loadLinear(path: "check/TouchEvent/\(record.foreground).bin")
        var picture = try OriginalTouchPicture(record: record, indices: bitmap.indices, width: bitmap.width, height: bitmap.height)
        let original = try ram(capture)
        XCTAssertNotNil(original.range(of: Data(picture.mask)), "The original process retains the same complete hit mask")
        XCTAssertEqual(picture.touch(pageX: x, pageY: y), [.selectSound])
        picture.release()
        XCTAssertEqual(picture.touch(pageX: x, pageY: y), [.confirmSound])
        picture.release()
        for _ in 0..<22 { picture.update() }
        XCTAssertEqual(picture.phase, .complete)
    }

    private func voiceChoice() throws -> OriginalEventRunner {
        var runner = try arrival()
        advanceDialogue(&runner)
        XCTAssertEqual(runner.phase, .picture(id: 5))
        try assertState(runner, "louie-arrival-pages/page12")
        try confirmPicture(5, x: 96, y: 155, capture: "louie-arrival-pages/page12")
        runner.finishPicture()
        try assertState(runner, "louie-parcel/taken")
        for _ in 0..<100 {
            if runner.interruptAvailable { runner.pressInterrupt(); break }
            guard case .dialogue = runner.phase else { XCTFail("Expected Louie's interrupt: \(runner.phase)"); return runner }
            runner.acknowledgeDialogue()
        }
        advanceDialogue(&runner)
        guard case .choice(let choices) = runner.phase else { XCTFail("Expected the voice choice: \(runner.phase)"); return runner }
        XCTAssertEqual(choices.map(\.id), [40, 41])
        try assertState(runner, "louie-voice-choice/page1")
        return runner
    }

    func testParcelAndVoiceInterruptMatchOriginalState() throws {
        _ = try voiceChoice()
    }

    private func questionMenu() throws -> OriginalEventRunner {
        var runner = try voiceChoice()
        runner.choose(40)
        advanceDialogue(&runner)
        XCTAssertEqual(runner.phase, .picture(id: 7))
        try assertState(runner, "louie-recognition/page20")
        try confirmPicture(7, x: 120, y: 95, capture: "louie-recognition/page20")
        runner.finishPicture()
        try assertState(runner, "louie-chin/recognised")
        for _ in 0..<100 {
            if runner.interruptAvailable { runner.pressInterrupt(); break }
            guard case .dialogue = runner.phase else { XCTFail("Expected the memories interrupt: \(runner.phase)"); return runner }
            runner.acknowledgeDialogue()
        }
        advanceDialogue(&runner)
        guard case .choice(let choices) = runner.phase else { XCTFail("Expected the memories choice: \(runner.phase)"); return runner }
        XCTAssertEqual(choices.map(\.id), [42, 43])
        XCTAssertEqual(runner.game.bytes[0xF9], 2)
        try assertState(runner, "louie-memories-choice/page1")
        runner.choose(42)
        advanceDialogue(&runner)
        guard case .choice(let workChoices) = runner.phase else { XCTFail("Expected the work choice: \(runner.phase)"); return runner }
        XCTAssertEqual(workChoices.map(\.id), [44, 45])
        try assertState(runner, "louie-memories-answer/page12")
        runner.choose(44)
        advanceDialogue(&runner)
        guard case .questions(let topics) = runner.phase else { XCTFail("Expected Louie's questions: \(runner.phase)"); return runner }
        XCTAssertEqual(topics.map(\.keyword), [10, 12, 13])
        try assertState(runner, "louie-work-answer/page18")
        return runner
    }

    func testRecognitionPictureMatchesOriginalStateAndInput() throws {
        _ = try questionMenu()
    }

    func testQuestionAnswersAndDepartureMatchOriginalState() throws {
        var runner = try questionMenu()
        runner.ask(12)
        advanceDialogue(&runner)
        guard case .questions(let topics) = runner.phase else { return XCTFail("Expected the remaining questions: \(runner.phase)") }
        XCTAssertEqual(topics.map(\.keyword), [10, 13])
        try assertState(runner, "louie-vibe-answer/page25")
        runner.ask(10)
        for _ in 0..<100 {
            if runner.interruptAvailable { runner.pressInterrupt(); break }
            guard case .dialogue = runner.phase else { return XCTFail("Expected the street-work interrupt: \(runner.phase)") }
            runner.acknowledgeDialogue()
        }
        advanceDialogue(&runner)
        guard case .choice(let choices) = runner.phase else { return XCTFail("Expected the street-work choices: \(runner.phase)") }
        XCTAssertEqual(choices.map(\.id), [47, 46])
        try assertState(runner, "louie-better-choice/page1")
        runner.choose(46)
        advanceDialogue(&runner)
        guard case .questions(let remaining) = runner.phase else { return XCTFail("Expected the remaining questions: \(runner.phase)") }
        XCTAssertEqual(remaining.map(\.keyword), [13, 11])
        try assertState(runner, "louie-better-answer/page18")
        runner.ask(11)
        advanceDialogue(&runner)
        guard case .questions(let lastTopics) = runner.phase else { return XCTFail("Expected the last question: \(runner.phase)") }
        XCTAssertEqual(lastTopics.map(\.keyword), [13])
        try assertState(runner, "louie-secret-answer2/page10")
        runner.ask(13)
        advanceDialogue(&runner)
        guard case .choice(let careerChoices) = runner.phase else { return XCTFail("Expected the career choices: \(runner.phase)") }
        XCTAssertEqual(careerChoices.map(\.id), [48, 49])
        try assertState(runner, "louie-career-choice/page2")
        runner.choose(48)
        advanceDialogue(&runner)
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        XCTAssertTrue((10...13).allSatisfy { runner.game.keywordUsed($0) })
        try assertState(runner, "louie-departure-boundary/completed")
    }
}
