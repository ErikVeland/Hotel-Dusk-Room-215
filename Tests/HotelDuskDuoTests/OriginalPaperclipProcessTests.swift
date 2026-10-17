import XCTest
@testable import HotelDuskDuoKit

final class OriginalPaperclipProcessTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private func snapshot(_ path: String) throws -> Data {
        let url = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("The original paperclip process capture is not available") }
        return try Data(contentsOf: url)
    }

    func testInventoryTableAndPaperclipAvailability() throws {
        let table = try OriginalInventoryProcessTable.bundled()
        XCTAssertEqual(table.records.map(\.item), [8, 7, 12, 13, 65535, 63])
        XCTAssertEqual(table.records.map(\.processID), [28, 34, 34, 34, 65, 34])
        let ram = try snapshot("room215-paperclip-puzzle/puzzle")
        var game = try OriginalGameState(snapshot: ram.subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        XCTAssertEqual(try table.process(for: 8, game: game)?.index, 0)
        XCTAssertNil(try table.process(for: 9, game: game))
        try game.apply(.setFlag32(index: 26))
        XCTAssertNil(try table.process(for: 8, game: game))
        try game.apply(.clearFlag32(index: 26))
        try game.apply(.removeInventory(id: 8))
        XCTAssertNil(try table.process(for: 8, game: game))
        XCTAssertThrowsError(try OriginalInventoryProcessTable(data: Data([1, 0])))
    }

    func testInitialShapeMatchesOriginal() throws {
        let puzzle = OriginalPaperclipProcess()
        let ram = try snapshot("room215-paperclip-puzzle/puzzle"), bytes = OriginalBytes(ram)
        for index in 0..<16 {
            for axis in 0..<3 {
                let expected = Float(bitPattern: try bytes.u32(0x21F410 + 0x4D8 + index * 12 + axis * 4))
                XCTAssertEqual(puzzle.points[index][axis], expected, accuracy: 0.00001, "Point \(index), axis \(axis)")
            }
        }
        for index in 0..<14 {
            XCTAssertEqual(puzzle.angles[index], Float(bitPattern: try bytes.u32(0x21F410 + 0x790 + index * 4)), accuracy: 0.00001)
        }
    }

    func testOriginalDragSequenceReachesAllThreeStages() throws {
        var puzzle = OriginalPaperclipProcess()
        puzzle.update()
        puzzle.update()
        let commands = try String(contentsOf: root.appendingPathComponent("tools/reference/room215-paperclip-straighten.txt"), encoding: .utf8)
        var touch: SIMD3<Int32>?
        for line in commands.split(separator: "\n") {
            let fields = line.split(separator: " ")
            if fields.first == "touch", let rawX = Int(fields[1]), let rawY = Int(fields[2]) {
                touch = OriginalPaperclipProjection.hit(page: SIMD2(Float(rawY), Float(255 - rawX)))
            } else if fields.first == "release" { touch = nil }
            else if fields.first == "frames", let count = Int(fields[1]) {
                for _ in 0..<count { puzzle.update(touch: touch, fadeComplete: true) }
            } else if fields.first == "capture", fields.count > 1 {
                let name = String(fields[1])
                if name == "stage0" { XCTAssertEqual(puzzle.stage, 2) }
                if name == "stage2" { XCTAssertEqual(puzzle.stage, 4) }
                if name == "stage4" { XCTAssertEqual(puzzle.stage, 9) }
                if name.hasPrefix("stage") {
                    let bytes = OriginalBytes(try snapshot("room215-paperclip-straighten/\(name)"))
                    for index in 0..<14 {
                        let expected = Float(bitPattern: try bytes.u32(0x21F410 + 0x790 + index * 4))
                        XCTAssertEqual(puzzle.angles[index], expected, accuracy: 0.00001, "\(name), joint \(index)")
                    }
                }
            }
        }
        XCTAssertEqual(puzzle.result, 0)
    }

    func testSuccessfulReturnMatchesOriginalStoryState() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let ram = try snapshot("room215-paperclip-puzzle/puzzle")
        let game = try OriginalGameState(snapshot: ram.subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        var parent = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: game)
        XCTAssertEqual(parent.phase, .exploration(mapID: 31))
        XCTAssertTrue(try parent.beginInventoryProcess(item: 8, table: .bundled()))
        XCTAssertEqual(parent.phase, .process(id: 28))
        parent.finishProcess(returnValue: 0)
        XCTAssertEqual(parent.phase, .process(id: 28), "Inventory processes must use their System response")
        var response = try parent.finishInventoryProcess(returnValue: 0, catalog: catalog)
        XCTAssertEqual(response.eventIndex, 1)
        for _ in 0..<300 {
            switch response.phase {
            case .dialogue, .itemNotice: response.acknowledgeDialogue()
            case .waiting: response.advanceWait()
            default: break
            }
        }
        XCTAssertEqual(response.phase, .exploration(mapID: 31))
        let expectedRAM = try snapshot("room215-paperclip-aftermath/step10")
        let expected = Array(expectedRAM[0x11018C..<(0x11018C + OriginalGameState.byteCount)])
        XCTAssertTrue(response.game.bytes == expected,
            "Return differences: \(expected.indices.filter { expected[$0] != response.game.bytes[$0] })")
        XCTAssertEqual(try response.game.inventory.items, [29, 22, 1, 2, 3, 9])
        parent.resumeSearch(after: response)
        XCTAssertEqual(parent.game.bytes, response.game.bytes)
        XCTAssertFalse(try parent.beginInventoryProcess(item: 8, table: .bundled()))
        XCTAssertThrowsError(try parent.finishInventoryProcess(returnValue: 0, catalog: catalog))
    }

    func testQuitStoryResponsesMatchOriginal() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let ram = try snapshot("room215-paperclip-puzzle/puzzle")
        let game = try OriginalGameState(snapshot: ram.subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        for (result, suffix) in [(Int16(2), "untouched"), (Int16(1), "touched")] {
            var parent = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: game)
            XCTAssertTrue(try parent.beginInventoryProcess(item: 8, table: .bundled()))
            var response = try parent.finishInventoryProcess(returnValue: result, catalog: catalog)
            XCTAssertEqual(response.eventIndex, result == 2 ? 3 : 2)
            for _ in 0..<100 {
                switch response.phase {
                case .dialogue, .itemNotice: response.acknowledgeDialogue()
                case .waiting: response.advanceWait()
                default: break
                }
            }
            XCTAssertEqual(response.phase, .exploration(mapID: 31))
            let expectedRAM = try snapshot("room215-paperclip-quit-\(suffix)/step4")
            let expected = Array(expectedRAM[0x11018C..<(0x11018C + OriginalGameState.byteCount)])
            XCTAssertTrue(response.game.bytes == expected,
                "\(suffix) differences: \(expected.indices.filter { expected[$0] != response.game.bytes[$0] })")
            XCTAssertEqual(response.game.value(for: .trickFlag(index: 4)), false)
        }
    }

    func testSpringBackAndHeldTouchOutsidePlane() throws {
        var puzzle = OriginalPaperclipProcess()
        puzzle.update()
        puzzle.update()
        let start = OriginalPaperclipProjection.hit(page: SIMD2(89, 171))
        puzzle.update(touch: start)
        puzzle.update(touch: start)
        var sprang = false
        for _ in 0..<30 {
            let effects = puzzle.update(touch: OriginalPaperclipProjection.hit(page: SIMD2(65, 190)))
            sprang = sprang || effects.contains(.springBack)
        }
        XCTAssertTrue(sprang)
        XCTAssertEqual(puzzle.stage, 6)
        for _ in 0..<60 { puzzle.update() }
        let ram = OriginalBytes(try snapshot("room215-paperclip-springback/settled"))
        XCTAssertEqual(puzzle.stage, Int(try ram.u16(0x21F410 + 0x2AA)))
        for index in 0..<14 {
            XCTAssertEqual(puzzle.angles[index], Float(bitPattern: try ram.u32(0x21F410 + 0x790 + index * 4)), accuracy: 0.00001)
        }
        XCTAssertFalse(puzzle.holding)
        let point = puzzle.points[try XCTUnwrap(puzzle.activePoint)]
        let handle = SIMD3(Int32(point.x * 4096), 0, Int32(point.z * 4096))
        puzzle.update(touch: handle)
        XCTAssertTrue(puzzle.holding)
        puzzle.update(isTouchDown: true)
        XCTAssertTrue(puzzle.holding)
        puzzle.update()
        XCTAssertFalse(puzzle.holding)
    }

    func testQuitResultsAndInvalidTouches() {
        var untouched = OriginalPaperclipProcess()
        untouched.update()
        untouched.update()
        untouched.update(touch: SIMD3(30000, 0, 30000))
        XCTAssertFalse(untouched.holding)
        untouched.quit()
        for _ in 0..<4 { untouched.update(fadeComplete: true) }
        XCTAssertEqual(untouched.result, 2)
        var touched = OriginalPaperclipProcess()
        touched.update()
        touched.update()
        let point = touched.points[0]
        touched.update(touch: SIMD3(Int32(point.x * 4096), 0, Int32(point.z * 4096)))
        XCTAssertTrue(touched.holding)
        touched.quit()
        for _ in 0..<4 { touched.update(fadeComplete: true) }
        XCTAssertEqual(touched.result, 1)
    }
}
