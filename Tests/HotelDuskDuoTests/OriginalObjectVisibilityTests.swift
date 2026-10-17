import XCTest
@testable import HotelDuskDuoKit

final class OriginalObjectVisibilityTests: XCTestCase {
    func testTableAndDefaultParcelFlags() throws {
        let table = try OriginalObjectVisibility.bundled()
        XCTAssertEqual(table.records.count, 84)
        let parcel = try XCTUnwrap(table.records.first)
        XCTAssertEqual(parcel.flag, 1)
        XCTAssertEqual(parcel.map, 31)
        XCTAssertEqual(parcel.area, 2)
        XCTAssertEqual(parcel.subarea, 2)
        XCTAssertEqual(parcel.roomNode, "obj0202")
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        XCTAssertFalse(game.objectVisible(1))
        XCTAssertFalse(game.objectVisible(2))
        XCTAssertTrue(game.objectVisible(3))
        XCTAssertFalse(game.objectVisible(256))
    }

    func testParcelFlagsControlRoomAndSearchNodes() throws {
        let table = try OriginalObjectVisibility.bundled()
        let models = try OriginalModelLibrary.bundled()
        let room = try models.load(path: "map/R205/R205/R205.mdf")
        let bed = try models.load(path: "map/R205/R205_s02/R205_s02.mdf")
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        for (model, area, names) in [(room, UInt16?.none, ["obj0202", "obj0203"]),
                                     (bed, UInt16?(2), ["obj02", "obj03"])] {
            let nodes = try names.map { name in try XCTUnwrap(model.nodes.firstIndex { $0.name == name }) }
            var visible = table.visibleNodes(in: model, map: 31, area: area, game: game)
            XCTAssertFalse(visible.contains(nodes[0]))
            XCTAssertFalse(visible.contains(nodes[1]))
            try game.apply(.changeFlag852(value: 1, index: 1))
            visible = table.visibleNodes(in: model, map: 31, area: area, game: game)
            XCTAssertTrue(visible.contains(nodes[0]))
            XCTAssertFalse(visible.contains(nodes[1]))
            XCTAssertEqual(table.visibleNodes(in: model, map: -1, area: area, game: game), Set(model.nodes.indices))
            try game.apply(.changeFlag852(value: 0, index: 1))
        }
    }

    func testHiddenNodesCannotBePicked() throws {
        var map = try OriginalMapExploration.bundled()
        for _ in 0..<160 { map.update(heldPageTouch: SIMD2(140, 80)) }
        for _ in 0..<46 { map.update(heldPageTouch: SIMD2(70, 75)) }
        XCTAssertTrue(map.inspectCounter())
        map.setPan(0)
        let point = SIMD2<Float>(126, 195)
        let name = try XCTUnwrap(map.pickedCounterNode(page: point))
        let node = try XCTUnwrap(map.counter.nodes.firstIndex { $0.name == name })
        XCTAssertEqual(try map.pickedCounterNode(page: point, visibleNodes: [node]), name)
        XCTAssertNil(try map.pickedCounterNode(page: point, visibleNodes: []))
        XCTAssertNotEqual(try map.pickedCounterNode(page: point,
            visibleNodes: Set(map.counter.nodes.indices).subtracting([node])), name)
    }

    func testRoomNameChangesOnlyFirstPrefixMatch() throws {
        var data = Data(repeating: 0, count: 52)
        data[0] = 1
        data[4] = 1
        data[6] = 31
        data.replaceSubrange(16..<21, with: Data("obj02".utf8))
        let table = try OriginalObjectVisibility(data: data)
        let model = try OriginalModelLibrary.bundled().load(path: "map/R205/R205/R205.mdf")
        let matching = model.nodes.indices.filter { model.nodes[$0].name.hasPrefix("obj02") }
        XCTAssertGreaterThan(matching.count, 1)
        let first = try XCTUnwrap(matching.first)
        let game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        XCTAssertEqual(table.visibleNodes(in: model, map: 31, area: nil, game: game),
            Set(model.nodes.indices).subtracting([first]))
    }

    func testRejectsMalformedTables() throws {
        XCTAssertThrowsError(try OriginalObjectVisibility(data: Data()))
        XCTAssertThrowsError(try OriginalObjectVisibility(data: Data([1, 0, 0, 0])))
        XCTAssertThrowsError(try OriginalObjectVisibility(data: Data(repeating: 0, count: 52)))
        var invalidFlag = Data(repeating: 0, count: 52)
        invalidFlag[0] = 1
        invalidFlag[5] = 1
        XCTAssertThrowsError(try OriginalObjectVisibility(data: invalidFlag))
        XCTAssertTrue(try OriginalObjectVisibility(data: Data(repeating: 0, count: 4)).records.isEmpty)
    }
}
