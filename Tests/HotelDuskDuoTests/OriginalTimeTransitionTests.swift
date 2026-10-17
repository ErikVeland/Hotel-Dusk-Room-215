import XCTest
@testable import HotelDuskDuoKit

final class OriginalTimeTransitionTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func state(_ name: String) throws -> OriginalGameState {
        let path = root.appendingPathComponent("extracted/reference/time-transition-fixture/\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("The original time-transition component capture is not available")
        }
        return try OriginalGameState(snapshot: Data(contentsOf: path).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func record(label: [UInt8]) -> OriginalBlockGraph.Record {
        var bytes: [UInt8] = [16, 255, 3, 0, 1, 0]
        bytes += label
        bytes += Array(repeating: 0, count: max(0, 16 - bytes.count))
        return .init(index: 0, sourceOffset: 0, raw: Data(bytes), children: nil)
    }

    func testSentinelAndEmptyLabelUseOriginalRules() throws {
        let suppressed = try OriginalTimeTransition(record: record(label: Array("NONE".utf8)))
        XCTAssertFalse(suppressed.presentsClock)
        XCTAssertEqual(suppressed.request, .init(kind: 3, value: 1))
        let empty = try OriginalTimeTransition(record: record(label: []))
        XCTAssertTrue(empty.presentsClock)
        XCTAssertEqual(empty.clockLabel, "05:00PM")
        XCTAssertTrue(try OriginalTimeTransition(record: record(label: Array("none".utf8))).presentsClock)
        XCTAssertThrowsError(try OriginalTimeTransition(record: record(label: Array(repeating: 65, count: 10))))
    }

    func testDeliveryCommandMatchesOriginalBeforeAndAfterClock() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let initial = try state("knock")
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: initial,
            selection: .init(sceneID: .max, blockID: 0, modeID: 3, eventID: 30, nowTime: initial.nowTime, mapID: 31))
        for _ in 0..<20 {
            guard case .dialogue = runner.phase else { break }
            runner.acknowledgeDialogue()
        }
        XCTAssertEqual(runner.phase, .process(id: 126))
        XCTAssertEqual(runner.timeTransition?.clockLabel, "05:10PM")
        XCTAssertEqual(runner.game.nowTime, 0)
        XCTAssertEqual(runner.game.previousMapID, 0)
        XCTAssertEqual(runner.processRequests, [.init(kind: 3, value: 1)])
        let during = try state("page3").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != during[$0] }, [])

        var clock = try OriginalClockProcess(label: XCTUnwrap(runner.timeTransition).clockLabel)
        for frame in 1...500 where !clock.isComplete {
            clock.update(tick: UInt64(frame / 60), draw: frame % 2 == 0)
        }
        XCTAssertTrue(clock.isComplete)
        // The recovered child has completed. This comparison excludes bitmap upload latency.
        runner.finishProcess(returnValue: 2)
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        XCTAssertNil(runner.timeTransition)
        XCTAssertEqual(runner.game.nowTime, 0)
        for request in runner.processRequests.reversed() where request.kind == 3 {
            runner.consumeTimeRequest(request.value)
        }
        XCTAssertEqual(runner.game.nowTime, 1)
        XCTAssertEqual(runner.session.selection.nowTime, 1)
        let returned = try state("page4").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != returned[$0] }, [])
    }

    func testTimeChangeClearsAllConversationSlotsAndPreservesOtherState() throws {
        var game = try OriginalGameState(snapshot: Data(repeating: 0xA5, count: OriginalGameState.byteCount))
        var expected = game.bytes
        game.applyTimeChange(1)
        expected[2] = 1
        expected[3] = 0
        for offset in 0x176..<0x812 { expected[offset] = 0 }
        XCTAssertEqual(game.bytes, expected)
        try game.setTimeLabel("05:10PM")
        expected.replaceSubrange(0x1346..<0x134E, with: Array("05:10PM".utf8) + [0])
        XCTAssertEqual(game.bytes, expected)
    }
}
