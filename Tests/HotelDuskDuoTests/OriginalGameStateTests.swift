import XCTest
@testable import HotelDuskDuoKit

final class OriginalGameStateTests: XCTestCase {
    func testNewGameMatchesOriginalBootMemory() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/boot/boot120-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("Original boot reference has not been captured on this checkout")
        }
        let ram = Array(try Data(contentsOf: file))
        let source = Data(ram[0x11018C..<(0x11018C + OriginalGameState.byteCount)])
        var native = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 1)
        native.conditionGlobalByte = ram[0x107739]
        let mismatches = zip(native.bytes, source).enumerated().filter { $0.element.0 != $0.element.1 }
        XCTAssertEqual(mismatches.count, 0, mismatches.prefix(24).map { String(format: "%04X:%02X/%02X", $0.offset, $0.element.0, $0.element.1) }.joined(separator: " "))
        XCTAssertEqual(try native.inventory.items, [21, 22])
        XCTAssertEqual(native.value(for: .gameFlag(index: 0)), true)
        XCTAssertEqual(native.value(for: .globalByteIsZero), true)
    }

    func testInitializationPreservesUntouchedFieldsAndInventoryTail() throws {
        var bytes = [UInt8](repeating: 0, count: OriginalGameState.byteCount)
        bytes[0x137F] = 7; bytes[0xCA7] = 19; bytes[0x9D + 21] = 3
        bytes[0xD0C] = 0x80
        var state = try OriginalGameState(snapshot: Data(bytes))
        try state.initialize(defaults: .bundled(), timestamp: nil)
        XCTAssertEqual(state.bytes[0x137F], 7)
        XCTAssertEqual(state.bytes[0xCA7], 19)
        XCTAssertEqual(try state.inventory.itemStates[21], 3)
        XCTAssertEqual(state.bytes[0xD0C], 0x06, "Signed high nibble is clamped after adding six")
        XCTAssertEqual(Array(state.bytes[0x1368..<0x1370]), Array(repeating: 255, count: 8))
        try state.apply(.addInventory(id: 23))
        try state.apply(.removeInventory(id: 21))
        XCTAssertEqual(try state.inventory.items, [22, 23])
        XCTAssertEqual(state.bytes[0x46], 23, "Original middle removal leaves the old tail byte")
        try state.apply(.removeInventory(id: 23))
        XCTAssertEqual(state.bytes[0x45], 255)
    }

    func testChristmasTreeOrderUsesOverlayStatePointerOffset() throws {
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        XCTAssertEqual(game.christmasTreeDecorationOrder, 0)

        game.storeChristmasTreeDecorationOrder(0x7207)
        XCTAssertEqual(game.christmasTreeDecorationOrder, 0x7207)
        XCTAssertEqual(Array(game.bytes[0x13DA..<0x13DC]), [0x07, 0x72])

        let restored = try OriginalGameState(snapshot: game.snapshot)
        XCTAssertEqual(restored.christmasTreeDecorationOrder, 0x7207)
        XCTAssertEqual(restored.bytes[0xDA..<0xDC], [0, 0])
    }

    func testWineLabelPeelStateUsesOverlay22OffsetAndPersistsInResumeSave() throws {
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(2, previous: 1)
        game.wineLabelPeelState = 0x15C3

        XCTAssertEqual(Array(game.bytes[0x13DC..<0x13DE]), [0xC3, 0x15])
        XCTAssertEqual(Array(game.bytes[0xDC..<0xDE]), [0, 0])

        let checkpoint = try OriginalResumeSave(game: game, checkpointFacing: game.facing,
            musicSequenceID: nil, savedAt: Date(timeIntervalSince1970: 0))
        let restored = try checkpoint.gameState()

        XCTAssertEqual(restored.wineLabelPeelState, 0x15C3)
    }

    func testApplePaintingFlagsUseOverlay38SavedOffset() throws {
        var bytes = [UInt8](repeating: 0, count: OriginalGameState.byteCount)
        bytes[0x13D9] = 0xA0
        var game = try OriginalGameState(snapshot: Data(bytes))
        XCTAssertEqual(game.applePaintingFoundMask, 0)

        game.applePaintingFoundMask = 0xFFFF
        XCTAssertEqual(game.applePaintingFoundMask, 0x1F)
        XCTAssertEqual(Array(game.bytes[0x13D8..<0x13DA]), [0x1F, 0xA0])
        XCTAssertEqual(Array(game.bytes[0xD8..<0xDA]), [0, 0])
        XCTAssertEqual(game.appleNotebookPageMask, 0x1F)
        XCTAssertEqual(try OriginalGameState(snapshot: game.snapshot).applePaintingFoundMask, 0x1F)
    }

    func testCommitAndCloseupRestorationUseOriginalSessionFields() throws {
        let conditions = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102").conditions
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        var session = OriginalEventSession(selection: .init(sceneID: 0xFFFE, blockID: 9, modeID: 11,
            eventID: 0, nowTime: 0, mapID: 2), operationIndex: 7, eventCommitted: false,
            savedFrames: [.init(blockID: 2, modeID: 5, eventID: 3, operationIndex: 4)],
            restoreOverride: 0, restoredFromNonDialogue: false)
        let result = try session.evaluate(.init(modeID: 12, eventID: 8, eventKey: -1, scope: .normal),
                                          conditions: conditions, game: game)
        XCTAssertEqual(result, .pass)
        XCTAssertEqual(session.selection.blockID, 9)
        XCTAssertEqual(session.selection.modeID, 12)
        XCTAssertEqual(session.selection.eventID, 8)
        XCTAssertEqual(session.operationIndex, 7)
        XCTAssertTrue(session.eventCommitted)
        XCTAssertTrue(session.restoreCloseupContext())
        XCTAssertEqual(session.selection.blockID, 2)
        XCTAssertEqual(session.selection.modeID, 5)
        XCTAssertEqual(session.operationIndex, 4)
        XCTAssertTrue(session.restoredFromNonDialogue)
        XCTAssertFalse(session.eventCommitted)
        XCTAssertTrue(session.savedFrames.isEmpty)
    }
}
