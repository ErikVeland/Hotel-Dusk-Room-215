import XCTest
@testable import HotelDuskDuoKit

final class OriginalStateCommandTests: XCTestCase {
    func testOriginalStateCommandsWriteTheirRecoveredFields() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        func command(_ name: String, _ offset: Int) throws -> OriginalStateCommand {
            let rows = try catalog.loadProgram(name).blocks.tables[3]
            return try XCTUnwrap(OriginalStateCommand(record: XCTUnwrap(rows.first { $0.sourceOffset == offset })))
        }
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        let keyword = try command("EP10_R305", 3424)
        XCTAssertEqual(keyword, .keywordAvailable([1]))
        try game.apply(keyword)
        XCTAssertEqual(game.bytes[0x884], 1)
        let door = try command("EP10_R205", 1988)
        XCTAssertEqual(door, .door(index: 15, value: 1))
        try game.apply(door)
        XCTAssertEqual(game.value(for: .doorOpen(index: 15)), true)
        try game.apply(command("EP1_General", 120))
        XCTAssertEqual(game.bytes[0xF5 + 11], 2)
        try game.apply(command("EP1_R213", 9768))
        XCTAssertEqual(game.bytes[0x87B] & 1, 1)
        XCTAssertEqual(game.bytes[0x87D], 1)
        try game.apply(command("EP10_R304", 1908))
        XCTAssertEqual(game.bytes[0x87E], 1)
        try game.apply(command("EP3_R209", 1152))
        XCTAssertEqual(game.bytes[0x87F], 1)
        try game.apply(command("EP5_R113", 1384))
        XCTAssertEqual(game.bytes[0x13CC] & 1, 1)
        try game.apply(command("EP10_R301", 5384))
        XCTAssertEqual(game.value(for: .counter1380(comparison: 0, threshold: 1)), true)
        XCTAssertEqual(try game.apply(.door(index: 42, value: 0)), [.door42Changed])
        XCTAssertEqual(game.value(for: .doorOpen(index: 42)), false)
    }

    func testKeywordRemovalPreservesUsedAndAskedFields() throws {
        let rows = try OriginalScriptCatalog.bundled().loadProgram("EP2_R119").blocks.tables[3]
        let command = try XCTUnwrap(OriginalStateCommand(record: XCTUnwrap(rows.first { $0.sourceOffset == 644 })))
        XCTAssertEqual(command, .keywordUnavailable(13))
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        try game.apply(.keywordAvailable([13, 127]))
        game.markKeywordUsed(13)
        game.markKeywordAsked(13, person: 2)
        let before = game.bytes
        try game.apply(command)
        XCTAssertFalse(game.keywordAvailable(13))
        XCTAssertTrue(game.keywordUsed(13))
        XCTAssertTrue(game.keywordAsked(13, person: 2))
        XCTAssertEqual(before.indices.filter { before[$0] != game.bytes[$0] }, [0x880 + 13 * 4])
        try game.apply(.keywordUnavailable(127))
        XCTAssertFalse(game.keywordAvailable(127))
        let unchanged = game
        try game.apply(.keywordUnavailable(-1))
        try game.apply(.keywordUnavailable(128))
        XCTAssertEqual(game, unchanged)
    }

    func testInventoryReplacementPreservesOriginalPositionAndState() throws {
        let rows = try OriginalScriptCatalog.bundled().loadProgram("EP10_R301").blocks.tables[3]
        let command = try XCTUnwrap(OriginalStateCommand(record: XCTUnwrap(rows.first { $0.sourceOffset == 4424 })))
        XCTAssertEqual(command, .replaceInventory(new: 70, old: 44))
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        try game.apply(.addInventory(id: 44))
        try game.apply(.addInventory(id: 45))
        try game.apply(command)
        XCTAssertEqual(try game.inventory.items, [21,22,70,45])
        XCTAssertEqual(try game.inventory.itemStates[70], 1)
        XCTAssertEqual(try game.inventory.itemStates[44], 1)
        let unchanged = game
        try game.apply(command)
        XCTAssertEqual(game, unchanged, "The original replacement requires the old held item")
    }
}
