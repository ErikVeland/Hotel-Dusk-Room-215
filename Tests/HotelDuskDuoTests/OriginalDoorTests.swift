import XCTest
@testable import HotelDuskDuoKit

final class OriginalDoorTests: XCTestCase {
    func testLockedDoorUsesOriginalSharedResponseAndReturnsToRoomRunner() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(39, previous: 17)
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R213"), game: game, deferArrival: true)
        runner.interactWithDoor(area: 7, upView: 343)
        XCTAssertNil(runner.eventIndex)
        var response = try XCTUnwrap(runner.searchFallback(catalog: catalog))
        XCTAssertEqual(response.program.name, "System")
        var lines = ""
        for _ in 0..<100 {
            switch response.phase {
            case .dialogue(let packet):
                lines += packet.pages.compactMap { String(data: $0.visibleBytes, encoding: .isoLatin1) }.joined()
                response.acknowledgeDialogue()
            case .waiting: response.advanceWait()
            case .exploration: break
            default: return XCTFail("Default door response stopped: \(response.phase)")
            }
            if case .exploration = response.phase { break }
        }
        XCTAssertTrue(lines.lowercased().contains("locked"), lines)
        XCTAssertEqual(response.phase, .exploration(mapID: 39))
        runner.resumeSearch(after: response)
        XCTAssertEqual(runner.program.name, "EP1_R213")
        XCTAssertEqual(runner.game.value(for: .doorOpen(index: 32)), true)
        XCTAssertEqual(try runner.game.inventory.items, try game.inventory.items)
    }

    func testRoom215EntryAndKeyMatchOriginalState() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func state(_ capture: String) throws -> Data {
            let file = root.appendingPathComponent("extracted/reference/\(capture)-ram.bin")
            guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original door capture is not available") }
            return try Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R213"),
            game: OriginalGameState(snapshot: state("room215-near/door-near")))
        runner.interactWithDoor(area: 7)
        XCTAssertEqual(runner.eventIndex, 25)
        for _ in 0..<20 { if case .dialogue = runner.phase { runner.acknowledgeDialogue() } }
        XCTAssertEqual(runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(runner.game.bytes, Array(try state("room215-ready/ready")))
        runner.interactWithDoor(area: 7, upView: 343, item: 1)
        XCTAssertEqual(runner.eventIndex, 26)
        XCTAssertEqual(runner.game.value(for: .doorOpen(index: 32)), false)
        for _ in 0..<20 { if case .dialogue = runner.phase { runner.acknowledgeDialogue() } }
        XCTAssertEqual(runner.phase, .exploration(mapID: 39))
        XCTAssertEqual(runner.game.bytes, Array(try state("room215-open/ready")))
        XCTAssertTrue(try runner.game.inventory.items.contains(1))
        runner.interactWithDoor(area: 7, upView: 343)
        XCTAssertEqual(runner.eventIndex, 27)
        for _ in 0..<20 { if case .dialogue = runner.phase { runner.acknowledgeDialogue() } }
        runner = try runner.moving(to: 31, program: catalog.loadProgram("EP1_R205"))
        for _ in 0..<300 {
            switch runner.phase {
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: break
            }
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        var map = try OriginalMapExploration.bundled(mapID: 31, previousMapID: 39)
        for request in runner.processRequests where request.kind == 9 {
            if try map.relocate(to: Int(request.value)) { runner.setMapPosition(map.position, facing: map.facing) }
        }
        XCTAssertEqual(map.position, .init(7291, 12288, 16630))
        XCTAssertEqual(runner.game.bytes, Array(try state("room215-room/room")))
        XCTAssertTrue(runner.beginMapDeparture(to: 39))
        for _ in 0..<100 {
            switch runner.phase {
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: break
            }
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(runner.processRequests.last?.kind, 2)
    }

    func testRoom215FloorPlanMatchesOriginalSamples() throws {
        var map = try OriginalMapExploration.bundled(mapID: 31, previousMapID: 39)
        XCTAssertTrue(try map.relocate(to: 0))
        XCTAssertEqual(map.mapScale, 12.7)
        let bitmap = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/R205.bin")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/room215-room/room-bottom.ppm")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original room capture is not available") }
        let capture = try Data(contentsOf: file), header = Data("P6\n256 192\n255\n".utf8)
        XCTAssertTrue(capture.starts(with: header))
        let pixels = Array(capture.dropFirst(header.count)), rgba = Array(bitmap.rgba)
        for x in stride(from: 10, to: 145, by: 11) {
            for y in stride(from: 45, to: 215, by: 13) {
                // The original cursor and suitcase icon overlay the floor-plan image.
                if (84...132).contains(x), (116...178).contains(y) { continue }
                let reference = (x * 256 + 255 - y) * 3
                let native = ((y - Int(map.mapBitmapOffset.y)) * bitmap.width + x - Int(map.mapBitmapOffset.x)) * 4
                for channel in 0..<3 {
                    XCTAssertEqual(pixels[reference + channel] >> 3, rgba[native + channel] >> 3, "Page \(x),\(y)")
                }
            }
        }
    }

    func testDoorSelectionAndItemCancellation() throws {
        let view = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R213").views.first { $0.id == 341 })
        var door = OriginalDoorScene(destination: 31, doorID: 32, area: 7, view: view)
        XCTAssertFalse(door.select(2))
        XCTAssertTrue(door.select(2))
        XCTAssertFalse(door.select(0))
        XCTAssertNil(door.selected)
        XCTAssertFalse(door.select(99))
        door.use(1)
        XCTAssertEqual(door.item, 1)
        XCTAssertFalse(door.select(2))
        door.use(nil)
        XCTAssertNil(door.item)
        XCTAssertNil(door.selected)
        XCTAssertFalse(door.select(2))
        XCTAssertTrue(door.select(2))
    }

    func testRoom215TelephoneCallMatchesOriginalState() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func state(_ path: String) throws -> Data {
            let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
            guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original telephone capture is not available") }
            return try Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"),
            game: OriginalGameState(snapshot: state("room215-room/room")),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        runner.lookInSearchView(area: 1, subarea: 1, table: try .bundled(map: "R205"))
        XCTAssertEqual(runner.eventIndex, 9)
        var events: [Int] = []
        for _ in 0..<500 {
            if let event = runner.eventIndex, events.last != event { events.append(event) }
            switch runner.phase {
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            case .exploration:
                XCTAssertEqual(events, [9, 12])
                XCTAssertEqual(runner.game.bytes, Array(try state("room215-phone-dialogue/call20")))
                XCTAssertEqual(runner.processRequests.last?.kind, 5)
                return
            default: return XCTFail("Telephone stopped: \(runner.phase), events: \(events)")
            }
        }
        XCTFail("The telephone calls did not finish")
    }

    func testWalkFromTelephoneToSuitcase() throws {
        var map = try OriginalMapExploration.bundled(mapID: 31, previousMapID: 39)
        _ = try map.relocate(to: 0)
        for _ in 0..<60 { map.update(heldPageTouch: .init(20, 128)) }
        for _ in 0..<34 { map.update(heldPageTouch: .init(96, 45)) }
        for _ in 0..<110 { map.update(heldPageTouch: .init(20, 128)) }
        for _ in 0..<98 { map.update(heldPageTouch: .init(170, 128)) }
        for _ in 0..<49 { map.update(heldPageTouch: .init(96, 210)) }
        XCTAssertEqual(map.position, .init(9773, 12288, 18858))
        XCTAssertEqual(map.nearbySearchArea, 3)
        let model = try OriginalModelLibrary.bundled().load(path: "map/R205/R205_s03/R205_s03.mdf")
        try map.prepareSearch(area: 3, model: model)
        XCTAssertTrue(map.inspectCounter())
        XCTAssertEqual(map.searchAreaID, 3)
        XCTAssertEqual(try map.pickedCounterNode(page: .init(130, 155)), "obj04")
    }

    func testSuitcaseLookAndKeyMatchOriginalState() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func state(_ path: String) throws -> Data {
            let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
            guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original suitcase capture is not available") }
            return try Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"),
            game: OriginalGameState(snapshot: state("room215-suitcase-inspect/inspect")),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")))
        runner.lookInSearchView(area: 3, subarea: 4, table: try .bundled(map: "R205"))
        XCTAssertEqual(runner.eventIndex, 16)
        for _ in 0..<100 {
            switch runner.phase {
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: break
            }
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(runner.game.bytes, Array(try state("room215-suitcase-look2/looked")))
        runner.useItemInSearchView(21, area: 3, subarea: 4)
        XCTAssertEqual(runner.eventIndex, 22)
        XCTAssertEqual(runner.phase, .process(id: 37))
        XCTAssertEqual(runner.game.bytes, Array(try state("room215-suitcase-key2/puzzle")))
        runner.finishSuitcaseKey(returnValue: 0)
        for _ in 0..<300 {
            switch runner.phase {
            case .dialogue: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            case .itemNotice: runner.acknowledgeDialogue()
            default: break
            }
        }
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        XCTAssertEqual(runner.processRequests.last?.kind, 8)
        runner.saveRetryCheckpoint()
        let expected = Array(try state("room215-suitcase-aftermath/step8"))
        XCTAssertTrue(runner.game.bytes == expected,
            "State differs at \(expected.indices.filter { expected[$0] != runner.game.bytes[$0] })")
    }

    func testWalkToRoom215Telephone() throws {
        var map = try OriginalMapExploration.bundled(mapID: 31, previousMapID: 39)
        XCTAssertTrue(try map.relocate(to: 0))
        for _ in 0..<60 { map.update(heldPageTouch: .init(20, 128)) }
        XCTAssertEqual(map.position, .init(-983, 12288, 16630))
        for _ in 0..<34 { map.update(heldPageTouch: .init(96, 45)) }
        for _ in 0..<110 { map.update(heldPageTouch: .init(20, 128)) }
        XCTAssertEqual(map.position, .init(-16687, 12288, 7450))
        XCTAssertTrue(map.canInspectCounter)
        XCTAssertTrue(map.inspectCounter())
        XCTAssertEqual(map.searchAreaID, 1)
        XCTAssertEqual(try map.pickedCounterNode(page: .init(86, 165)), "obj01")
    }

    func testSuitcaseQuitBranchesMatchOriginalStoryState() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func state(_ path: String) throws -> OriginalGameState {
            let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
            guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original suitcase quit capture is not available") }
            return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        for (result, suffix, event) in [(Int16(2), "untouched", UInt16(24)), (Int16(1), "inserted", UInt16(23))] {
            var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"),
                game: state("room215-suitcase-look2/looked"))
            runner.useItemInSearchView(21, area: 3, subarea: 4)
            runner.finishSuitcaseKey(returnValue: result)
            for _ in 0..<100 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: break
                }
            }
            let original = try state("room215-suitcase-quit-\(suffix)/returned")
            XCTAssertEqual(runner.phase, .exploration(mapID: 31))
            XCTAssertEqual(runner.game.value(for: .eventFlag(group: 31, index: event)), true)
            XCTAssertEqual(runner.game.value(for: .trickFlag(index: 13)), false)
            XCTAssertEqual(try runner.game.inventory.items, try original.inventory.items)
            // The capture includes later A presses outside the puzzle, which can store map position.
            XCTAssertTrue(runner.game.bytes.dropFirst(24) == original.bytes.dropFirst(24), suffix)
        }
    }

    func testRoom215ModelEntryLoads() throws {
        let map = try OriginalMapExploration.bundled(mapID: 31, previousMapID: 39)
        XCTAssertEqual(map.mapName, "R205")
        XCTAssertEqual(map.mapOrigin, .init(15, -27))
        XCTAssertEqual(map.position, .init(9994, 12288, -15811))
    }

    func testDoorTableKeepsOriginalSidesAndFirstMatch() throws {
        let table = try OriginalStateDefaults.bundled().doorTable
        XCTAssertEqual(table.records.count, 50)
        let room = try XCTUnwrap(table.connection(from: 39, to: 31))
        XCTAssertEqual(room.id, 32)
        XCTAssertEqual(room.initialState, 1)
        XCTAssertEqual(table.connection(from: 31, to: 39), room)
        XCTAssertEqual(table.side(from: 39, to: 31)?.viewFlag, 0)
        XCTAssertEqual(table.side(from: 31, to: 39)?.viewFlag, 1)
        XCTAssertEqual(table.connection(from: 39, to: 45)?.id, 41)
        XCTAssertEqual(table.connection(from: 45, to: 39)?.id, 41)
        XCTAssertEqual(table.side(from: 39, to: 18)?.positiveCode, 1)
        XCTAssertEqual(table.side(from: 39, to: 18)?.zeroCode, -1)
        XCTAssertEqual(table.side(from: 18, to: 39)?.positiveCode, -1)
        XCTAssertNil(table.connection(from: 39, to: 17))
        XCTAssertThrowsError(try OriginalDoorTable(data: Data()))
        XCTAssertThrowsError(try OriginalDoorTable(data: Data([1, 0]) + Data(repeating: 0, count: 14)))
        XCTAssertThrowsError(try OriginalDoorTable(data: Data([255, 255]) + Data(repeating: 0, count: 14)))
    }

    func testR108ToR304DoorUsesTheSearchTableConnection() throws {
        let doorTable = try OriginalStateDefaults.bundled().doorTable
        XCTAssertEqual(doorTable.connections(from: 8, to: 43).map(\.id), [26, 49])
        let search = try OriginalSearchTable.bundled(map: "R108")
        XCTAssertNil(search.door(id: 26))
        let passage = try XCTUnwrap(search.door(id: 49))
        XCTAssertEqual(passage.areaID, 5)
        XCTAssertEqual(passage.upViewID, 59)
    }

    func testRoom215UsesItsOriginalSearchDoorRecord() throws {
        let table = try OriginalSearchTable.bundled(map: "R213")
        XCTAssertEqual(table.doors.count, 15)
        let door = try XCTUnwrap(table.door(id: 32))
        XCTAssertEqual(door.areaID, 7)
        XCTAssertEqual(door.upViewID, 341)
        XCTAssertEqual(door.name, "R213_L")
        XCTAssertNil(table.door(id: 99))
    }

    func testUnlockedRoom215DepartsWithoutDoorInspection() throws {
        let defaults = try OriginalStateDefaults.bundled()
        var game = try OriginalGameState.newGame(defaults: defaults, timestamp: nil)
        let table = defaults.doorTable
        XCTAssertFalse(table.departsDirectly(from: 31, to: 39, game: game))
        XCTAssertFalse(table.departsDirectly(from: 39, to: 31, game: game))
        try game.apply(OriginalStateCommand.door(index: 32, value: 0))
        XCTAssertTrue(table.departsDirectly(from: 31, to: 39, game: game))
        XCTAssertTrue(table.departsDirectly(from: 39, to: 31, game: game))
        XCTAssertFalse(table.departsDirectly(from: 39, to: 17, game: game))
        let other = try XCTUnwrap(table.connection(from: 39, to: 18))
        try game.apply(OriginalStateCommand.door(index: UInt16(bitPattern: other.id), value: 0))
        XCTAssertFalse(table.departsDirectly(from: 39, to: 18, game: game))
    }

    func testStandingPeopleAndStoryGateRestrictDoors() throws {
        let defaults = try OriginalStateDefaults.bundled(), rules = try OriginalMapRestrictions.bundled()
        var game = try OriginalGameState.newGame(defaults: defaults, timestamp: nil)
        game.setMap(39, previous: 17)
        XCTAssertTrue(rules.permitsDoor(to: 29, table: defaults.doorTable, game: game))
        try game.apply(.setPersonLocation(index: 6, location: 39, field6: 1, field7: 0))
        XCTAssertFalse(rules.permitsDoor(to: 29, table: defaults.doorTable, game: game))
        XCTAssertTrue(rules.permitsDoor(to: 31, table: defaults.doorTable, game: game))
        try game.apply(.setPersonLocation(index: 6, location: 29, field6: 1, field7: 0))
        XCTAssertTrue(rules.permitsDoor(to: 29, table: defaults.doorTable, game: game))
        XCTAssertFalse(rules.permitsDoor(to: 41, table: defaults.doorTable, game: game))
        try game.apply(.setFlag32(index: 32))
        XCTAssertTrue(rules.permitsDoor(to: 41, table: defaults.doorTable, game: game))
    }

    func testRoom215SelectionMatchesOriginalPositionAndDestination() throws {
        let defaults = try OriginalStateDefaults.bundled()
        var game = try OriginalGameState.newGame(defaults: defaults, timestamp: nil)
        game.setMap(39, previous: 17)
        var map = try OriginalMapExploration.bundled(mapID: 39, previousMapID: 17)
        XCTAssertTrue(map.collision.disabledDoorMarkers.contains("in_r117"))
        for _ in 0..<254 { map.update(heldPageTouch: .init(20, 128)) }
        for _ in 0..<9 { map.update(heldPageTouch: .init(96, 210)) }
        XCTAssertEqual(map.position, .init(-76261, 12288, 10051))
        XCTAssertEqual(map.nearbyDoor(in: game, table: defaults.doorTable), 31)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/room215-near/door-near-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original door capture is not available") }
        let ram = try OriginalBytes(Data(contentsOf: file)), base = 0x27CFA0
        XCTAssertEqual(try ram.u32(base + 0x14610), 31)
        for axis in 0..<3 {
            XCTAssertEqual(map.position[axis], Float(Int32(bitPattern: try ram.u32(base + 0x15514 + axis * 4))))
        }
        for _ in 0..<8 { map.update(heldPageTouch: .init(96, 45)) }
        XCTAssertNil(map.nearbyDoor(in: game, table: defaults.doorTable))
    }
}
