import XCTest
@testable import HotelDuskDuoKit

final class OriginalScriptTests: XCTestCase {
    func testNativeDecompressionMatchesIndependentSourceRecovery() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        // Independent Python ring decoder, including a forward overlap and two
        // texts that cross the 64 KiB dictionary boundary.
        let expected = [
            "EP1_R102.blk": "54c44a59bb73ff6aa1abea4b49947697cc521621e3a412ced8d0ec932b981e26",
            "EP1_R205.txt": "8b88eed23c968e85c61de32e284074a826a77bb69cec13c020ceec28ff023174",
            "System.txt": "d21bb9b5496be60715c24ac6b3615af82853522cfa92b0b28c0f67329b9e8ed5",
            "EP3_R209.txt": "8c8c8b3a80555e61a9fe8a9ae7d331d7782002079944f2bca1c519e03df4887f"
        ]
        for (file, hash) in expected {
            XCTAssertEqual(OriginalScriptCatalog.digest(try catalog.decodedFile(file)), hash, file)
        }
    }

    func testEveryRecoveredChapterProgramLoadsWithoutDroppingRecords() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        XCTAssertEqual(catalog.programNames.count, 115)
        XCTAssertEqual(catalog.manifest.files.count, 610)
        for file in catalog.manifest.files { _ = try catalog.decodedFile(file.name) }
        for name in catalog.programNames {
            let program = try catalog.loadProgram(name)
            XCTAssertEqual(program.name, name)
            XCTAssertGreaterThanOrEqual(program.blockData.count, 32, name)
            let graph = try program.blocks
            XCTAssertEqual(try program.conditions.entries.count, graph.tables[2].count)
            for event in graph.tables[2] {
                for operation in try graph.operations(forEvent: event.index) {
                    _ = try OriginalOperation(record: operation)
                }
            }
        }
        let melissa = try catalog.loadProgram("EP3_R209")
        XCTAssertEqual(melissa.text.entries.count, 578)
        XCTAssertEqual(melissa.text.entries[0].offset, 2316)
        XCTAssertEqual(melissa.text.entries[0].utf8, "%c0%d1%w1%p0000102%n0%s1012010")
    }

    func testTruncatedAndUnknownContainersAreRejected() {
        for data in [Data(), Data(repeating: 0, count: 48), Data([0x12, 0x3D, 0xDA, 1])] {
            XCTAssertThrowsError(try OriginalContainer.decode(data))
        }
        XCTAssertThrowsError(try OriginalTextTable(decoded: Data([255,255,255,255])))
        XCTAssertThrowsError(try OriginalEventLabel.decode(Data([1,2,3])))
        XCTAssertThrowsError(try OriginalChoiceRecord.decode(Data(repeating: 65, count: 64)))
    }
}
