import XCTest
@testable import HotelDuskDuoKit

final class OriginalCinematicQueueTests: XCTestCase {
    func testCompleteInitializedOpeningAndSourceAudioCommands() throws {
        let program = try OriginalCinematicProgram.bundledOpening()
        XCTAssertEqual(program.commands.count, 459)
        XCTAssertEqual(Set(program.commands.map(\.handlerAddress)).count, 32)
        XCTAssertEqual(try program.commands[0].string(4, capacity: 32), "/data/show/op2/0829OPImg.tbl")
        XCTAssertEqual(try program.commands[1].string(4, capacity: 32), "/data/show/op2/0829OPAni.tbl")
        XCTAssertEqual(try program.commands.compactMap { try $0.audioCommand }.count, 26)
        let waits = program.commands.filter { $0.handlerAddress == 0x020A3B34 }
        XCTAssertEqual(waits.count, 64)
        XCTAssertTrue(try waits.allSatisfy { try $0.unsigned16(6) == 0 })
    }

    func testFirstUpdatesMatchOriginalQueueCaptures() throws {
        let program = try OriginalCinematicProgram.bundledOpening()
        var queue = OriginalCinematicQueue(program: program)
        var handlers: [UInt32] = []
        for expectedIndex in 0...3 {
            try queue.update { command, active in
                handlers.append(command.handlerAddress)
                XCTAssertEqual(active.updateCount, 0)
                return .complete
            }
            // Original captures init04...init07: activate, then execute exactly
            // one archive command on each following frame.
            XCTAssertEqual(queue.state.active?.commandIndex, expectedIndex)
        }
        XCTAssertEqual(handlers, [0x020A3F84, 0x020A3FCC, 0x020A3F84])
    }

    func testPartialWaitCheckpointPreservesExactRemainingUpdates() throws {
        let program = try OriginalCinematicProgram.bundledOpening()
        let index = try XCTUnwrap(program.commands.firstIndex { $0.handlerAddress == 0x020A3B34 })
        let limit = try program.commands[index].unsigned16(4)
        XCTAssertEqual(limit, 48)
        var queue = OriginalCinematicQueue(program: program)
        var snapshot = queue.state
        snapshot.nextCommandIndex = index + 1
        snapshot.active = .init(commandIndex: index, updateCount: 17, waitCounter: 17, handlerState: Data())
        try queue.restore(snapshot)
        let saved = try JSONEncoder().encode(queue.state)
        var reopened = OriginalCinematicQueue(program: program)
        try reopened.restore(JSONDecoder().decode(OriginalCinematicQueue.Checkpoint.self, from: saved))
        for remaining in stride(from: 30, through: 0, by: -1) {
            try reopened.update { _, _ in XCTFail("A native wait must not call the scene host"); return .complete }
            if remaining > 0 { XCTAssertEqual(reopened.state.active?.commandIndex, index) }
        }
        XCTAssertEqual(reopened.state.active?.commandIndex, index + 1)
        XCTAssertEqual(reopened.state.active?.updateCount, 0)
    }

    func testMissingHandlerStopsWithoutSkippingOriginalAction() throws {
        let program = try OriginalCinematicProgram.bundledOpening()
        var queue = OriginalCinematicQueue(program: program)
        try queue.update { _, _ in XCTFail("Activation cannot execute a command"); return .complete }
        let before = queue.state
        XCTAssertThrowsError(try queue.update { _, _ in throw OriginalDataError.invalid("Unported action") })
        XCTAssertEqual(queue.state, before)
        var invalid = before
        invalid.nextCommandIndex += 1
        XCTAssertThrowsError(try queue.restore(invalid))
        XCTAssertEqual(queue.state, before)
    }
}
