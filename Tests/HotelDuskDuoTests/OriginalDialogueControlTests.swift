import XCTest
@testable import HotelDuskDuoKit

final class OriginalDialogueControlTests: XCTestCase {
    func testBundledRetryMarkerIsDecoded() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP2_R205")
        let markers = program.text.entries.filter { entry in
            entry.bytes == Data("%r0001".utf8)
        }
        XCTAssertFalse(markers.isEmpty)
        XCTAssertEqual(try OriginalDialogueControl.tokens(for: markers[0]).map(\.kind),
                       [.control(.retry(1))])
    }

    func testOpeningKeepsOriginalMusicAndAllThreeLines() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let operations = try program.blocks.operations(forEvent: 0)
        let music = try OriginalDialoguePacket(record: operations[0], following: operations[1], text: program.text)
        XCTAssertTrue(music.pages[0].tokens.contains { $0.kind == .control(.music(mode: 0, name: "BGM_36")) })
        let narration = try OriginalDialoguePacket(record: operations[4], following: operations[5], text: program.text)
        XCTAssertEqual(narration.pages[0].entries.map(\.index), [10,11,12])
        XCTAssertEqual(String(data: narration.pages[0].visibleBytes, encoding: .ascii),
                       "It's been three years since\nI quit the force and left\nNew York.\n")
        XCTAssertEqual(narration.presentations[0].person, 101)
    }

    func testPairedDialogueUsesConsecutiveTextGroups() throws {
        let program = try OriginalScriptCatalog.bundled().loadProgram("EP1_R102")
        let operations = try program.blocks.operations(forEvent: 0)
        let packet = try OriginalDialoguePacket(record: operations[2], following: operations[3], text: program.text)
        XCTAssertEqual(packet.consumedRecordCount, 2)
        XCTAssertEqual(packet.pages.map(\.page), [1,0])
        XCTAssertEqual(packet.pages.map { $0.entries.map(\.index) }, [[4,5,6],[7,8,9]])
        XCTAssertEqual(String(data: packet.pages[1].visibleBytes, encoding: .ascii), "The name's Kyle Hyde.\n\n\n")
    }

    func testEveryOriginalDialoguePacketRetainsItsControls() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var count = 0
        var pairedCount = 0
        for name in catalog.programNames {
            let program = try catalog.loadProgram(name)
            let graph = try program.blocks
            for event in graph.tables[2] {
                let records = try graph.operations(forEvent: event.index)
                var index = 0
                while index < records.count {
                    let record = records[index]
                    if record.raw[0] == 4 {
                        let following = index + 1 < records.count ? records[index + 1] : nil
                        let packet = try OriginalDialoguePacket(record: record, following: following, text: program.text)
                        if packet.display == 2 { pairedCount += 1 }
                        count += 1
                    }
                    index += record.raw[1] == 2 ? 2 : 1
                }
            }
        }
        XCTAssertGreaterThan(count, 10_000)
        XCTAssertGreaterThan(pairedCount, 0)
    }

    func testUnknownPercentSequenceIsLiteralAndKnownTruncationFails() throws {
        let literal = OriginalTextTable.Entry(index: 0, offset: 0, bytes: Data("100% complete".utf8))
        let tokens = try OriginalDialogueControl.tokens(for: literal)
        XCTAssertEqual(tokens.map(\.kind), Array("100% complete".utf8).map { .glyph($0) })
        let malformed = OriginalTextTable.Entry(index: 0, offset: 0, bytes: Data("%p123".utf8))
        XCTAssertThrowsError(try OriginalDialogueControl.tokens(for: malformed))
    }
}
