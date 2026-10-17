import XCTest
@testable import HotelDuskDuoKit

final class OriginalUpstairsTests: XCTestCase {
    func testJeffConversationRoute() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/dropped-piece-combined/upstairs-ram.bin")
        let finalFile = root.appendingPathComponent("extracted/reference/jeff-complete/complete-ram.bin")
        guard [file, finalFile].allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
            throw XCTSkip("The original Jeff captures are not available")
        }
        let ram = try Data(contentsOf: file)
        let game = try OriginalGameState(snapshot: ram.subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        let catalog = try OriginalScriptCatalog.bundled(), program = try catalog.loadProgram("EP1_R213")
        var runner = try OriginalEventRunner(program: program, game: game,
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        XCTAssertTrue(runner.enterMapRegion(2))
        var events: [Int] = [], choices: [UInt16] = [], asked: [Int16] = []
        for _ in 0..<500 {
            if let event = runner.eventIndex, events.last != event { events.append(event) }
            switch runner.phase {
            case .dialogue where runner.interruptAvailable: runner.pressInterrupt()
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .choice(let options):
                choices.append(options[0].id)
                runner.choose(options[0].id)
            case .questions(let topics):
                if let topic = topics.first(where: { $0.keyword == 9 }) ?? topics.first { asked.append(topic.keyword); runner.ask(topic.keyword) }
                else { runner.leave() }
            case .waiting: runner.advanceWait()
            case .exploration:
                XCTAssertEqual(events, [2, 3, 4, 5, 9, 10, 11, 13, 14, 15, 16, 21, 18, 23, 24])
                XCTAssertEqual(choices, [24, 26, 28])
                XCTAssertEqual(asked, [9, 4])
                XCTAssertEqual(runner.phase, .exploration(mapID: 39))
                XCTAssertEqual(runner.game.value(for: .gameFlag(index: 35)), true)
                XCTAssertTrue(runner.game.keywordAsked(9, person: 6))
                XCTAssertTrue(runner.game.keywordAsked(4, person: 6))
                let finished = try Data(contentsOf: finalFile)
                let reference = Array(finished[0x11018C..<(0x11018C + OriginalGameState.byteCount)])
                XCTAssertEqual(runner.game.bytes, reference)
                return
            default: return XCTFail("Jeff route stopped: \(runner.phase), events \(events)")
            }
        }
        XCTFail("Jeff's conversation did not finish")
    }
    func testMissedFirstInterruptReturnsToHallwayWithoutMeetingJeff() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let start = root.appendingPathComponent("extracted/reference/dropped-piece-combined/upstairs-ram.bin")
        let finish = root.appendingPathComponent("extracted/reference/jeff-missed/missed-ram.bin")
        guard [start, finish].allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
            throw XCTSkip("The original missed-interrupt captures are not available")
        }
        let range = 0x11018C..<(0x11018C + OriginalGameState.byteCount)
        let game = try OriginalGameState(snapshot: Data(contentsOf: start).subdata(in: range))
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R213"), game: game,
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        XCTAssertTrue(runner.enterMapRegion(2))
        var events: [Int] = [], interruptOffered = false
        for _ in 0..<100 {
            if let event = runner.eventIndex, events.last != event { events.append(event) }
            switch runner.phase {
            case .dialogue:
                interruptOffered = interruptOffered || runner.interruptAvailable
                runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            case .exploration:
                XCTAssertTrue(interruptOffered)
                XCTAssertEqual(events, [2, 3, 7])
                XCTAssertEqual(runner.phase, .exploration(mapID: 39))
                XCTAssertEqual(runner.game.value(for: .gameFlag(index: 35)), false)
                XCTAssertEqual(runner.game.bytes, Array(try Data(contentsOf: finish).subdata(in: range)))
                return
            default: return XCTFail("Unexpected missed-interrupt phase: \(runner.phase)")
            }
        }
        XCTFail("The missed interrupt did not return to the hallway")
    }

    func testEntryAndWestwardTriggerMatchOriginalRAM() throws {
        var map = try OriginalMapExploration.bundled(mapID: 39, previousMapID: 17)
        XCTAssertEqual(map.mapOrigin, .init(525, 140))
        XCTAssertEqual(map.position, .init(16449, 12288, 6766))
        XCTAssertEqual(map.mapBitmapOffset, .init(-497, 24))
        XCTAssertFalse(map.canInspectCounter)
        for _ in 0..<21 { map.update(heldPageTouch: .init(20, 128)) }
        XCTAssertEqual(map.position, .init(8784, 12288, 6766))
        XCTAssertEqual(map.eventRegion, 2)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/r213-west/west-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original upstairs capture is not available") }
        let ram = try OriginalBytes(Data(contentsOf: file))
        let base = 0x27CFA0
        XCTAssertEqual(try ram.u32(base + 0x360), 39)
        for (axis, value) in [map.position.x, map.position.y, map.position.z].enumerated() {
            XCTAssertEqual(Int32(value), Int32(bitPattern: try ram.u32(base + 0x15514 + axis * 4)))
        }
        let event = Int(try ram.u32(0x376FB0 + 0x13C)) - 0x02000000
        XCTAssertEqual(try ram.u16(event), 3)
        XCTAssertEqual(try ram.u16(event + 2), 2)
    }

    func testLargeHallwayFloorPlanAndMalformedBounds() throws {
        let bitmap = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/R213.bin")
        XCTAssertEqual(bitmap.width, 1280)
        XCTAssertEqual(bitmap.height, 256)
        XCTAssertEqual(bitmap.rgba.count, 1280 * 256 * 4)
        XCTAssertNotNil(bitmap.makeCGImage())
        var invalid = Data(repeating: 0, count: 16)
        invalid[3] = 1
        invalid[4] = 8
        invalid[7] = 16
        XCTAssertThrowsError(try OriginalMapBitmap(data: invalid))
    }

    func testFloorPlanViewportMatchesOriginalColourSamples() throws {
        let map = try OriginalMapExploration.bundled(mapID: 39, previousMapID: 17)
        let bitmap = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/R213.bin")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/dropped-piece-combined/upstairs-bottom.ppm")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original floor-plan capture is not available") }
        let capture = try Data(contentsOf: path)
        let header = Data("P6\n256 192\n255\n".utf8)
        XCTAssertTrue(capture.starts(with: header))
        XCTAssertEqual(capture.count, header.count + 256 * 192 * 3)
        let pixels = Array(capture.dropFirst(header.count)), rgba = Array(bitmap.rgba)
        for x in stride(from: 25, to: 170, by: 11) {
            for y in stride(from: 80, to: 210, by: 13) {
                // The original cursor overlays the floor plan around its centre.
                if (84...108).contains(x), (116...150).contains(y) { continue }
                let reference = (x * 256 + 255 - y) * 3
                let native = ((y - Int(map.mapBitmapOffset.y)) * bitmap.width + x - Int(map.mapBitmapOffset.x)) * 4
                for channel in 0..<3 {
                    XCTAssertEqual(pixels[reference + channel] >> 3, rgba[native + channel] >> 3, "Page \(x),\(y)")
                }
            }
        }
    }
}
