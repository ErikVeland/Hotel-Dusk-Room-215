import XCTest
@testable import HotelDuskDuoKit

final class OriginalConditionsTests: XCTestCase {
    struct Context: OriginalConditionContext {
        let values: [OriginalConditionProbe: Bool]
        func value(for probe: OriginalConditionProbe) -> Bool? { values[probe] }
    }

    func testOriginalConditionFixturesAndTheirInversion() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let fixtures: [(String, Int16, OriginalConditionProbe, Bool, Int)] = [
            ("EP10_R102", 0, .eventFlag(group: 2, index: 0), false, 144),
            ("EP10_R103", 1, .gameFlag(index: 52), false, 80),
            ("EP10_R102", 6, .inventoryContains(index: 81), true, 272),
            ("EP10_R304", 10, .doorOpen(index: 50), false, 720),
            ("EP10_R102", 5, .trickFlag(index: 39), true, 240)
        ]
        for (name, key, probe, required, offset) in fixtures {
            let conditions = try catalog.loadProgram(name).conditions
            XCTAssertEqual(try conditions.evaluatePredicates(eventKey: key, context: Context(values: [probe: required])), .pass)
            XCTAssertEqual(try conditions.evaluatePredicates(eventKey: key, context: Context(values: [probe: !required])),
                           .fail(sourceOffset: offset))
            XCTAssertEqual(try conditions.evaluatePredicates(eventKey: key, context: Context(values: [:])),
                           .unresolvedState(probe, sourceOffset: offset))
        }
    }

    func testUnobservedStateAndAbsentEventAreDistinct() throws {
        let conditions = try OriginalScriptCatalog.bundled().loadProgram("EP10_R301").conditions
        XCTAssertEqual(try conditions.evaluatePredicates(eventKey: 42, context: Context(values: [:])),
                       .unresolvedState(.counter1380(comparison: 0, threshold: 0), sourceOffset: 3088))
        XCTAssertEqual(try conditions.evaluatePredicates(eventKey: -1, context: Context(values: [:])), .pass)
        XCTAssertThrowsError(try conditions.evaluatePredicates(eventKey: -2, context: Context(values: [:])))
    }

    func testRecoveredConditionKindsAndOriginalEarlyReturns() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let keyword = try catalog.loadProgram("EP1_R102").conditions
        XCTAssertEqual(try keyword.evaluatePredicates(eventKey: 85,
            context: Context(values: [.keyword(index: 14, person: 3): false])), .pass)
        let status = try catalog.loadProgram("EP10_R205").conditions
        XCTAssertEqual(try status.evaluatePredicates(eventKey: 2,
            context: Context(values: [.state137F: false])), .pass)
        let chapter = try catalog.loadProgram("System").conditions
        XCTAssertEqual(try chapter.evaluatePredicates(eventKey: 235,
            context: Context(values: [.chapterEquals(3): true])), .pass)
        var commits = 0
        let unusedKind = try catalog.loadProgram("EP10_R305").conditions
        XCTAssertEqual(try unusedKind.evaluate(eventKey: 13, context: Context(values: [:]),
                                               onCommit: { commits += 1 }), .pass)
        XCTAssertEqual(commits, 0, "Original kind2 exits with initial result without committing")

        let counter = try catalog.loadProgram("EP10_R301").conditions
        let context = Context(values: [.counter1380(comparison: 0, threshold: 4): false,
                                      .counter1380(comparison: 0, threshold: 9): true])
        XCTAssertEqual(try counter.evaluate(eventKey: 43, context: context,
                                            onCommit: { commits += 1 }), .pass)
        XCTAssertEqual(commits, 1, "Failed kind13 continues; successful kind13 exits before the third check")

        let memo = try catalog.loadProgram("EP5_R113").conditions
        XCTAssertEqual(try memo.evaluate(eventKey: 6,
            context: Context(values: [.memo(index: 0): true, .eventFlag(group: 13, index: 6): true]),
            onCommit: { commits += 1 }), .fail(sourceOffset: 416))
        XCTAssertEqual(commits, 2, "The successful memo check commits before the next check fails")
    }

    func testOriginalInventoryCommandsRetainOrderAndAcquisitionState() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        func operation(_ program: String, _ offset: Int) throws -> OriginalOperation {
            let records = try catalog.loadProgram(program).blocks.tables[3]
            return try .init(record: XCTUnwrap(records.first { $0.sourceOffset == offset }))
        }
        let add = try operation("EP10_R205", 1876)
        let remove = try operation("EP10_R108", 3984)
        let erase = try operation("EP10_R108", 4112)
        let setState = try operation("EP10_R108", 2960)
        XCTAssertEqual(add, .addInventory(id: 59))
        XCTAssertEqual(remove, .removeInventory(id: 77))
        XCTAssertEqual(erase, .removeAndClearInventory(id: 77))
        XCTAssertEqual(setState, .setItemState(id: 76, value: 2))
        var states = [UInt8](repeating: 0, count: 88)
        states[77] = 2
        var inventory = try OriginalInventory(items: [1,77,2], itemStates: states)
        try inventory.apply(add)
        try inventory.apply(add)
        XCTAssertEqual(inventory.items, [1,77,2,59])
        XCTAssertEqual(inventory.itemStates[59], 1)
        try inventory.apply(remove)
        XCTAssertEqual(inventory.items, [1,2,59])
        XCTAssertEqual(inventory.itemStates[77], 2, "Removing a held item does not erase acquisition state")
        try inventory.apply(erase)
        XCTAssertEqual(inventory.itemStates[77], 0)
        try inventory.apply(setState)
        XCTAssertEqual(inventory.itemStates[76], 2)
        XCTAssertEqual(inventory.items, [1,2,59], "State changes do not give an item to Kyle")
        let preserved = inventory
        try inventory.apply(.setItemState(id: -1, value: 2))
        try inventory.apply(.setItemState(id: 88, value: 2))
        XCTAssertEqual(inventory, preserved)
        XCTAssertThrowsError(try inventory.apply(.addInventory(id: 255)))
    }
}
