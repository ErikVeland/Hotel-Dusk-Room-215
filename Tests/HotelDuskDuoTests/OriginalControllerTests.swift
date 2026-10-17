import XCTest
@testable import HotelDuskDuoKit

final class OriginalControllerTests: XCTestCase {
    func testOriginalFlagCommandFixturesPreserveOtherStorage() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let set = try operation("EP10_R108", at: 4176, catalog: catalog)
        let clear = try operation("EP5_R111", at: 1564, catalog: catalog)
        let secondary = try operation("EP10_R108", at: 3008, catalog: catalog)
        XCTAssertEqual(set, .setFlag32(index: 49))
        XCTAssertEqual(clear, .clearFlag32(index: 34))
        XCTAssertEqual(secondary, .changeFlag852(value: 0, index: 77))
        var state = try OriginalControllerCore(flagSlots32: Array(repeating: 0xA504, count: 8),
                    flagSlots852: Array(repeating: 0x5AFF, count: 32), waitCounter: 0, waitLimit: 0)
        XCTAssertEqual(state.apply(set), .stateChanged)
        XCTAssertEqual(state.flagSlots32[6], 0xA506)
        XCTAssertEqual(state.apply(clear), .stateChanged)
        XCTAssertEqual(state.flagSlots32[4], 0xA500)
        XCTAssertEqual(state.flagSlots32[0], 0xA504)
        XCTAssertEqual(state.apply(secondary), .stateChanged)
        XCTAssertEqual(state.flagSlots852[9], 0x5ADF)
        XCTAssertEqual(state.flagSlots852[10], 0x5AFF)
        let preserved = state
        _ = state.apply(.setFlag32(index: 64))
        _ = state.apply(.changeFlag852(value: 1, index: 256))
        XCTAssertEqual(state, preserved, "Original helpers ignore out-of-range IDs")
    }

    func testWaitUsesOriginalUpdateCountAndDoesNotAssumeSeconds() throws {
        var state = try OriginalControllerCore(flagSlots32: Array(repeating: 0, count: 8),
                    flagSlots852: Array(repeating: 0, count: 32), waitCounter: 0, waitLimit: 0)
        // Opcode 11 has no fixture in these BLK files. Its assembly explicitly
        // blocks N+2 subsequent updates when starting from counter zero.
        _ = state.apply(.wait(counter: 3))
        for count in [1,2,3,4,0] {
            XCTAssertTrue(state.consumeWaitUpdate())
            XCTAssertEqual(state.waitCounter, UInt32(count))
        }
        XCTAssertFalse(state.consumeWaitUpdate())
        XCTAssertEqual(state.waitLimit, 0)
        _ = state.apply(.wait(counter: 0))
        XCTAssertFalse(state.consumeWaitUpdate())
    }

    func testDialogueAndUnknownHandlersDoNotInventTransitions() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let dialogue = try operation("EP10_R102", at: 324, catalog: catalog)
        XCTAssertEqual(dialogue, .dialogue(textIndex: 1))
        var state = try OriginalControllerCore(flagSlots32: Array(repeating: 0, count: 8),
                    flagSlots852: Array(repeating: 0, count: 32), waitCounter: 0, waitLimit: 0)
        let preserved = state
        XCTAssertEqual(state.apply(dialogue), .requiresDialogueHandler(textIndex: 1))
        XCTAssertEqual(state.apply(.unrecovered(opcode: 53)), .requiresHandler(opcode: 53))
        XCTAssertEqual(state, preserved)
    }

    private func operation(_ program: String, at offset: Int,
                           catalog: OriginalScriptCatalog) throws -> OriginalOperation {
        let blocks = try catalog.loadProgram(program).blocks
        return try OriginalOperation(record: XCTUnwrap(blocks.tables[3].first { $0.sourceOffset == offset }))
    }
}
