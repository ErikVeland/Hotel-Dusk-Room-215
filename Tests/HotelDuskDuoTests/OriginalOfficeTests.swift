import XCTest
@testable import HotelDuskDuoKit

final class OriginalOfficeTests: XCTestCase {
    func testCabinetPaperCanBeSelectedAtTheOriginalApproach() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/chapter-two-office-cabinet-approach/near-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original cabinet approach is unavailable") }
        let ram = try Data(contentsOf: path)
        var game = try OriginalGameState(snapshot: ram.subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        game.setMapPosition(SIMD3(-8223, 12288, 17141), facing: 0)
        var map = try OriginalMapExploration.bundled(mapID: 15, previousMapID: 3, savedGame: game)
        XCTAssertTrue(map.inspectCounter())
        let visible = map.objectVisibility.visibleNodes(in: map.counter, map: 15, area: 2, game: game)
        XCTAssertEqual(try map.pickedCounterNode(page: SIMD2(95, 220), visibleNodes: visible), "obj02")
        map.setPan(1)
        XCTAssertNotEqual(try map.pickedCounterNode(page: SIMD2(95, 220), visibleNodes: visible), "obj02")
    }

    func testDetailSelectionUsesTheDeclaredAsset() throws {
        let view = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R115").views.first { $0.id == 127 })
        var closeup = try OriginalSearchCloseup(area: 4, subarea: 1, view: view)
        XCTAssertFalse(closeup.select(0))
        XCTAssertNil(closeup.selectedDetailAsset)
        XCTAssertFalse(closeup.select(1))
        XCTAssertEqual(closeup.selectedDetailAsset, "115meibup")
        XCTAssertEqual(closeup.selectedEvent, 128)
        XCTAssertTrue(closeup.select(1))
        XCTAssertFalse(closeup.select(2))
        XCTAssertNil(closeup.selectedDetailAsset)
        closeup.clearSelection()
        XCTAssertNil(closeup.selectedDetailAsset)
    }

    @MainActor func testGuestLedgerPixelsMatchOriginalDetailImage() throws {
        let bitmap = try OriginalBitmapLibrary.bundled().loadLinear(path: "map/sdata/SearchUp/115meibup.bin")
        let image = try OriginalUpViewImage(bitmaps: [bitmap], visible: [true])
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/chapter-two-office-ledger/page4-bottom.ppm")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original ledger capture is unavailable") }
        let capture = try Data(contentsOf: path), header = Data("P6\n256 192\n255\n".utf8)
        XCTAssertTrue(capture.starts(with: header))
        let pixels = Array(capture.dropFirst(header.count)), rgba = Array(image.rgba)
        for point in [SIMD2(30, 50), .init(90, 70), .init(100, 150), .init(150, 100), .init(170, 160)] {
            let index = point.x * 256 + 255 - point.y
            for channel in 0..<3 {
                XCTAssertEqual(pixels[index * 3 + channel] >> 3, rgba[index * 4 + channel] >> 3, "Page \(point)")
            }
        }
    }

    func testOfficeEntryUsesOriginalMarkersScaleAndFloorPlan() throws {
        let map = try OriginalMapExploration.bundled(mapID: 15, previousMapID: 3)
        XCTAssertEqual(map.position, SIMD3(-19579, 12288, 15319))
        XCTAssertEqual(map.mapOrigin, SIMD2(12, 1))
        XCTAssertEqual(map.mapScale, 16.2)
        XCTAssertEqual(map.searchAreaID, 2)
        let bitmap = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/R115.bin")
        XCTAssertEqual(bitmap.width, 256)
        XCTAssertEqual(bitmap.height, 256)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/chapter-two-office-arrival/room-bottom.ppm")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original office capture is unavailable") }
        let data = try Data(contentsOf: path), header = Data("P6\n256 192\n255\n".utf8)
        XCTAssertTrue(data.starts(with: header))
        let pixels = Array(data.dropFirst(header.count)), rgba = Array(bitmap.rgba)
        for point in [SIMD2(80, 160), .init(100, 160), .init(150, 150), .init(100, 190), .init(150, 180)] {
            let reference = (point.x * 256 + 255 - point.y) * 3
            let native = ((point.y - Int(map.mapBitmapOffset.y)) * bitmap.width + point.x - Int(map.mapBitmapOffset.x)) * 4
            for channel in 0..<3 {
                XCTAssertEqual(pixels[reference + channel] >> 3, rgba[native + channel] >> 3, "Page \(point)")
            }
        }
    }
}
