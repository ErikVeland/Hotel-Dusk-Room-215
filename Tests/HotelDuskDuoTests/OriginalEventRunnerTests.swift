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

    func testCompletedArrivalReturnsToExplorationInsteadOfReplaying() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(2, previous: 1)
        game.markEventCompleted(group: 2, event: 0)
        // With the arrival already seen, no arrival event remains.
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: game)
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
    }

    // MARK: R102 counter bell and Dunning's first conversation

    /// Events 0-2 with the entrance returning 0, ending in lobby exploration.
    private func lobbyExploration() throws -> OriginalEventRunner {
        var runner = try arrival()
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        runner.finishProcess(returnValue: 0)
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
        return runner
    }

    private func readAllDialogue(_ runner: inout OriginalEventRunner) -> [String] {
        var lines: [String] = []
        while case .dialogue = runner.phase {
            if let line = firstLine(runner.phase) { lines.append(line) }
            runner.acknowledgeDialogue()
        }
        return lines
    }

    func testR102SearchTableGivesTheBellNoUpView() throws {
        let table = try OriginalSearchTable.bundled(map: "R102")
        XCTAssertEqual(table.areas.map(\.areaID), [1, 2, 3])
        XCTAssertEqual(table.areas[1].name, "R102_03")
        XCTAssertEqual(table.upViewID(area: 2, subarea: 2), 0xFFFF)
        XCTAssertEqual(table.upViewID(area: 2, subarea: 3), 0x0B)
        XCTAssertNil(table.upViewID(area: 9, subarea: 2))
        guard case .look(let context) = OriginalSearchSelection.look(table: table, mapID: 2, nowTime: 0,
                                                                     area: 2, subarea: 2) else {
            return XCTFail("Expected the look branch")
        }
        XCTAssertEqual(context.sceneID, 0xFFFE)
        XCTAssertEqual(context.modeID, 10)
        XCTAssertEqual(context.upViewID, -1)
        guard case .closeup(let entry, let view) = OriginalSearchSelection.look(
            table: table, mapID: 2, nowTime: 0, area: 2, subarea: 3) else {
            return XCTFail("Expected a close-up entry event")
        }
        XCTAssertEqual(view, 0x0B)
        XCTAssertEqual(entry.modeID, 10)
        XCTAssertEqual(entry.upViewID, -1)
        XCTAssertEqual(entry.subareaID, 3)
    }

    func testBellCloseupRunsEvent3ThenProcess24() throws {
        var runner = try lobbyExploration()
        runner.lookInSearchView(area: 2, subarea: 2, table: try .bundled(map: "R102"))
        XCTAssertEqual(runner.eventIndex, 3)
        XCTAssertEqual(firstLine(runner.phase), "Guy's got a bell on the\ncounter. Nice touch.")
        runner.acknowledgeDialogue()
        // Exit (mode 15, scene 0xFFFE, event 4); byte 16 = 1, so process 24.
        XCTAssertEqual(runner.phase, .process(id: 24))
        XCTAssertEqual(runner.eventIndex, 4)
    }

    func testRingingTheBellLeadsToDunningsFirstConversation() throws {
        var runner = try lobbyExploration()
        runner.lookInSearchView(area: 2, subarea: 2, table: try .bundled(map: "R102"))
        runner.acknowledgeDialogue()
        runner.finishProcess(returnValue: 0)
        XCTAssertEqual(runner.eventIndex, 7)
        var pagesByEvent: [Int: Int] = [:]
        while case .dialogue = runner.phase {
            pagesByEvent[runner.eventIndex ?? -1, default: 0] += 1
            runner.acknowledgeDialogue()
        }
        // Event 7 exits to event 8; event 8 (with opcode 9 at offset 2984)
        // exits to event 12.
        // Paired pages (byte 1 = 2) consume the next record: 2 and 16 packets.
        XCTAssertEqual(pagesByEvent[7], 2)
        XCTAssertEqual(pagesByEvent[8], 16)
        XCTAssertNotNil(pagesByEvent[12])
        XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 7)), true)
        XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 8)), true)
        XCTAssertEqual(runner.eventIndex, 12)
        guard case .choice(let options) = runner.phase else { return XCTFail("Expected Dunning's suite offer") }
        XCTAssertEqual(options.map(\.eventID), [14, 13])
    }

    func testQuittingTheBellAsksTheSearchViewToReload() throws {
        var runner = try lobbyExploration()
        runner.lookInSearchView(area: 2, subarea: 2, table: try .bundled(map: "R102"))
        runner.acknowledgeDialogue()
        runner.finishProcess(returnValue: 1)
        XCTAssertEqual(runner.phase, .exploration(mapID: 2))
        XCTAssertEqual(runner.processRequests, [.init(kind: 5, value: 0)])
        XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 5)), true)
        XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 7)), false)
    }

    /// CHK key 3 requires event flag (2, 7) clear. Quitting leaves it clear;
    /// event 7 sets it, so the closeup no longer selects event 3.
    func testBellCloseupIsGatedByEvent7() throws {
        let table = try OriginalSearchTable.bundled(map: "R102")
        var runner = try lobbyExploration()
        runner.lookInSearchView(area: 2, subarea: 2, table: table)
        runner.acknowledgeDialogue()
        runner.finishProcess(returnValue: 1)
        runner.lookInSearchView(area: 2, subarea: 2, table: table)
        XCTAssertEqual(runner.eventIndex, 3)

        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        var game = runner.game
        game.markEventCompleted(group: 2, event: 7)
        guard case .look(let context) = OriginalSearchSelection.look(table: table, mapID: 2,
            nowTime: game.nowTime, area: 2, subarea: 2) else { return XCTFail("Expected the look branch") }
        var session = OriginalEventSession.mapSession(nowTime: game.nowTime, mapID: 2)
        session.selection = context
        let conditions = try program.conditions, state = game
        let outcome = try OriginalEventSelector.select(graph: try program.blocks, context: context,
            evaluate: { try session.evaluate($0, conditions: conditions, game: state) },
            applyEffect: { session.apply($0) })
        XCTAssertEqual(outcome, .noMatch)
    }
}


final class OriginalChoiceTests: XCTestCase {
    /// Lobby arrival, bell closeup, three rings, and Dunning's introduction.
    private func dunningOffer() throws -> OriginalEventRunner {
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: .bundled(), defaults: .bundled())
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        runner.finishProcess(returnValue: 0)
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        runner.lookInSearchView(area: 2, subarea: 2, table: try .bundled(map: "R102"))
        runner.acknowledgeDialogue()
        runner.finishProcess(returnValue: 0)
        while case .dialogue = runner.phase { runner.acknowledgeDialogue() }
        return runner
    }

    func testDunningsSuiteOfferListsTheOriginalOptions() throws {
        let runner = try dunningOffer()
        XCTAssertEqual(runner.eventIndex, 12)
        XCTAssertEqual(runner.phase, .choice([
            .init(id: 3, eventID: 14, label: "Say, a suite sounds nice."),
            .init(id: 2, eventID: 13, label: "Suites are for chumps."),
        ]))
        XCTAssertTrue(runner.game.itemCheckFlag(2), "The menu marks each option before an answer")
        XCTAssertTrue(runner.game.itemCheckFlag(3))
    }

    func testEitherAnswerReturnsToTheRegistrationCard() throws {
        for (id, event, pages) in [(UInt16(2), 13, 5), (UInt16(3), 14, 11)] {
            var runner = try dunningOffer()
            runner.choose(id)
            XCTAssertEqual(runner.eventIndex, event)
            var count = 0
            while case .dialogue = runner.phase, runner.eventIndex == event { count += 1; runner.acknowledgeDialogue() }
            XCTAssertEqual(count, pages)
            // The saved frame resumes event 12 after its last operation; its
            // exit then selects event 15.
            XCTAssertEqual(runner.eventIndex, 15)
            XCTAssertTrue(runner.session.savedFrames.isEmpty)
            XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: 12)), true)
            XCTAssertEqual(runner.game.value(for: .eventFlag(group: 2, index: Int16(event) == 13 ? 13 : 14)), true)
            XCTAssertNotEqual(runner.game.bytes[0x812] & 0b1100_0000, 0, "option 3 marked")
            XCTAssertNotEqual(runner.game.bytes[0x812] & 0b0011_0000, 0, "option 2 marked")
        }
    }
}

final class OriginalInterruptTests: XCTestCase {
    /// Plays to the start of event 19 with the card signed (process 25 returns 0).
    private func registration() throws -> OriginalEventRunner {
        var runner = try OriginalEventRunner.chapterOneArrival(catalog: .bundled(), defaults: .bundled())
        let table = try OriginalSearchTable.bundled(map: "R102")
        for _ in 0..<400 {
            if runner.eventIndex == 19 { break }
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .exploration: runner.lookInSearchView(area: 2, subarea: 2, table: table)
            case .process: runner.finishProcess(returnValue: 0)
            case .choice: runner.choose(2)
            default: return runner
            }
        }
        return runner
    }

    private func line(_ runner: OriginalEventRunner) -> String? {
        guard case .dialogue(let packet) = runner.phase else { return nil }
        return packet.pages.compactMap { String(data: $0.visibleBytes, encoding: .isoLatin1)?
            .trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
    }

    func testDunningsDodgeCanBeInterrupted() throws {
        var runner = try registration()
        XCTAssertEqual(runner.eventIndex, 19)
        var armedLine: String?
        for _ in 0..<20 {
            if runner.interruptAvailable { armedLine = line(runner); break }
            runner.acknowledgeDialogue()
        }
        XCTAssertEqual(armedLine?.hasPrefix("Yeah, sure!"), true)
        runner.pressInterrupt()
        XCTAssertEqual(runner.eventIndex, 20)
        XCTAssertEqual(line(runner), "Hold on.")
        runner.acknowledgeDialogue()
        guard case .choice(let options) = runner.phase else { return XCTFail("Expected the mode-6 choice") }
        XCTAssertEqual(options.map(\.eventID), [21, 22])
        runner.choose(5)
        XCTAssertEqual(runner.eventIndex, 22)
        XCTAssertFalse(runner.game.keywordAvailable(1))
        while case .dialogue = runner.phase, runner.eventIndex == 22 { runner.acknowledgeDialogue() }
        XCTAssertTrue(runner.game.keywordAvailable(1))
        // Event 19 resumes in replay: its remaining pages are skipped, and
        // its exit selects event 23.
        XCTAssertEqual(runner.eventIndex, 23)
        XCTAssertEqual(runner.eventTrail.suffix(5), [20, 22, 20, 19, 23])
    }

    func testIgnoringTheInterruptPlaysTheDodge() throws {
        var runner = try registration()
        var lines: [String] = []
        while case .dialogue = runner.phase, runner.eventIndex == 19 {
            if let text = line(runner) { lines.append(text) }
            runner.acknowledgeDialogue()
        }
        XCTAssertTrue(lines.contains("Ain't nothin'."))
        XCTAssertFalse(runner.interruptAvailable)
        XCTAssertFalse(runner.game.keywordAvailable(1))
    }
}

final class OriginalBellProcessTests: XCTestCase {
    private func mask() throws -> [UInt8] {
        try OriginalBitmapLibrary.bundled().loadLinear(path: "trick/bell/bell01.bin").indices
    }

    func testBellBitmapsUseTheLinearLayout() throws {
        let library = try OriginalBitmapLibrary.bundled()
        for name in ["bell01", "bell02"] {
            let bitmap = try library.loadLinear(path: "trick/bell/\(name).bin")
            XCTAssertEqual(bitmap.width, 256)
            XCTAssertEqual(bitmap.height, 192)
            XCTAssertEqual(bitmap.palette[0], 0x03E0)
        }
        XCTAssertEqual(try mask().filter { $0 != 0 }.count, 5412)
    }

    func testBellTouchUsesTheRectangleAndTheMask() throws {
        let mask = try mask()
        typealias Touch = OriginalBellProcess.Touch
        // Right-handed: x' = 255 - x, so the rectangle is raw x 159-199, y 72-120.
        XCTAssertTrue(OriginalBellProcess.hitsBell(Touch(x: 159, y: 72), leftHanded: false, mask: mask))
        XCTAssertTrue(OriginalBellProcess.hitsBell(Touch(x: 199, y: 120), leftHanded: false, mask: mask))
        // Outside the rectangle, a nonzero bell01 pixel still hits.
        XCTAssertNotEqual(mask[96 * 256 + 140], 0)
        XCTAssertTrue(OriginalBellProcess.hitsBell(Touch(x: 140, y: 96), leftHanded: false, mask: mask))
        XCTAssertEqual(mask[10 * 256 + 10], 0)
        XCTAssertFalse(OriginalBellProcess.hitsBell(Touch(x: 10, y: 10), leftHanded: false, mask: mask))
        XCTAssertTrue(OriginalBellProcess.hitsQuit(Touch(x: 255 - 240, y: 170), leftHanded: false))
        XCTAssertFalse(OriginalBellProcess.hitsQuit(Touch(x: 240, y: 170), leftHanded: false))
    }

    /// Runs with a fade model: a fade completes `duration` updates after it starts.
    private func run(_ process: inout OriginalBellProcess, mask: [UInt8], updates: Int,
                     touchAt: Set<Int> = [], touch: OriginalBellProcess.Touch = .init(x: 180, y: 96),
                     fade: inout Int, effects: inout [OriginalBellProcess.Effect]) -> Int {
        for update in 0..<updates {
            let input = OriginalBellProcess.Input(newTouch: touchAt.contains(update) ? touch : nil,
                                                  screen0FadeComplete: fade == 0)
            if fade > 0 { fade -= 1 }
            let step = process.update(input, mask: mask)
            for case .fade(let next) in step.effects where next.screen == 0 { fade = Int(next.duration) }
            effects += step.effects
            if step.status != 0 { return step.status }
        }
        return 0
    }

    func testThreeRingsFinishWithReturnZero() throws {
        let mask = try mask()
        var process = OriginalBellProcess(), fade = 0, effects: [OriginalBellProcess.Effect] = []
        // Initialization, the 60-update fade in, then the 15-update pause.
        XCTAssertEqual(run(&process, mask: mask, updates: 80, fade: &fade, effects: &effects), 0)
        XCTAssertTrue(process.awaitingTouch)
        XCTAssertTrue(process.quitEnabled)
        var status = 0
        for _ in 0..<3 {
            status = run(&process, mask: mask, updates: 12, touchAt: [0], fade: &fade, effects: &effects)
            XCTAssertEqual(status, 0)
        }
        XCTAssertEqual(process.rings, 3)
        XCTAssertEqual(effects.filter { $0 == .sound(archive: 37, entry: 0) }.count, 3)
        XCTAssertFalse(process.quitEnabled)
        status = run(&process, mask: mask, updates: 400, fade: &fade, effects: &effects)
        XCTAssertEqual(status, 2)
        XCTAssertEqual(process.processReturn, 0)
        XCTAssertTrue(effects.contains(.sound(archive: 1, entry: 0)))
    }

    func testQuitButtonFinishesWithReturnOne() throws {
        let mask = try mask()
        var process = OriginalBellProcess(), fade = 0, effects: [OriginalBellProcess.Effect] = []
        _ = run(&process, mask: mask, updates: 80, fade: &fade, effects: &effects)
        let status = run(&process, mask: mask, updates: 100, touchAt: [0],
                         touch: .init(x: 255 - 240, y: 170), fade: &fade, effects: &effects)
        XCTAssertEqual(status, 2)
        XCTAssertEqual(process.processReturn, 1)
        XCTAssertEqual(process.rings, 0)
        XCTAssertTrue(effects.contains(.sound(archive: 8, entry: 2)))
    }
}
