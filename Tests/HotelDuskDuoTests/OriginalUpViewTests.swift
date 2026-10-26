import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalUpViewTests: XCTestCase {
    func testCentralHallwayAcceptsFullWidthAssetName() throws {
        let table = try OriginalUpViewTable.bundled(map: "R117")
        let layer = try XCTUnwrap(table.views.flatMap(\.layers).first { $0.asset == "close_plate_rest" })
        XCTAssertEqual(layer.detailAsset, "")
        XCTAssertEqual(layer.eventID, 165)
        XCTAssertEqual(layer.itemID, -1)
        XCTAssertEqual(layer.processID, -1)
    }

    func testRoom215LayersAndOriginalHitMap() throws {
        let view = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R213").views.first { $0.id == 341 })
        XCTAssertEqual(view.background, "wall01")
        XCTAssertEqual(view.layers.map(\.asset), ["door01", "nob01R", "plate215"])
        XCTAssertEqual(view.layers.map(\.eventID), [342, 343, 344])
        let library = try OriginalBitmapLibrary.bundled()
        let bitmaps = try ([view.background] + view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        let image = try OriginalUpViewImage(bitmaps: bitmaps, visible: [true, true, true, true])
        XCTAssertEqual(image.hit(pageX: 160, pageY: 175), 2)
        XCTAssertEqual(image.hit(pageX: 96, pageY: 100), 1)
        XCTAssertEqual(image.hit(pageX: 96, pageY: 45), 3)
        XCTAssertNil(image.hit(pageX: -1, pageY: 175))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/room215-ready/ready-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original door capture is not available") }
        let ram = try Data(contentsOf: path)
        XCTAssertNotNil(ram.range(of: Data(image.sourcePackedHitMap)))
        let rgba = Array(image.rgba)
        var originalColours = Data()
        for pixel in stride(from: 0, to: rgba.count, by: 4) {
            let colour = UInt16(rgba[pixel] >> 3) | UInt16(rgba[pixel + 1] >> 3) << 5
                | UInt16(rgba[pixel + 2] >> 3) << 10 | 0x8000
            originalColours.append(UInt8(truncatingIfNeeded: colour))
            originalColours.append(UInt8(colour >> 8))
        }
        XCTAssertNotNil(ram.range(of: originalColours))
    }

    func testHitMarginExpandsOnlyTransparentPixelsAndKeepsNearestObjectBorders() {
        let width = 9, height = 5
        var source = [UInt8](repeating: 0, count: (width * height + 1) / 2)
        func set(_ x: Int, _ y: Int, _ layer: UInt8) {
            let index = y * width + x
            let shift = (index & 1) * 4
            source[index / 2] = (source[index / 2] & ~UInt8(15 << shift))
                | (layer << ((index & 1) * 4))
        }
        func get(_ packed: [UInt8], _ x: Int, _ y: Int) -> UInt8 {
            let index = y * width + x
            return (packed[index / 2] >> ((index & 1) * 4)) & 15
        }
        set(2, 2, 1)
        set(3, 2, 1)
        set(4, 0, 1)
        set(5, 2, 2)
        let expanded = OriginalUpViewImage.expandingTransparentHitPixels(
            in: source, width: width, height: height, radius: 2)
        XCTAssertEqual(get(expanded, 2, 2), 1)
        XCTAssertEqual(get(expanded, 3, 2), 1)
        XCTAssertEqual(get(expanded, 5, 2), 2)
        XCTAssertEqual(get(expanded, 1, 2), 1)
        XCTAssertEqual(get(expanded, 7, 2), 2)
        XCTAssertEqual(get(expanded, 4, 1), 1, "The nearest object wins even if the farther layer is above it")
        XCTAssertEqual(get(expanded, 4, 2), 2, "Equal-distance pixels go to the higher visible layer")
        XCTAssertEqual(get(source, 1, 2), 0)
    }

    func testLobbyIgnoresUnusedRecordsAndKeepsOfficeHitTargets() throws {
        let table = try OriginalUpViewTable.bundled(map: "R103")
        XCTAssertEqual(table.views.map(\.id), [16, 18, 22, 26])
        let view = try XCTUnwrap(table.views.first { $0.id == 22 })
        XCTAssertEqual(view.layers.map(\.asset), ["door05", "nob05L", "plate_off"])
        XCTAssertEqual(view.layers.map(\.eventID), [23, 24, 25])
        let library = try OriginalBitmapLibrary.bundled()
        let bitmaps = try ([view.background] + view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        let image = try OriginalUpViewImage(bitmaps: bitmaps, visible: [true, true, true, true])
        XCTAssertEqual(image.hit(pageX: 96, pageY: 160), 1)
        XCTAssertEqual(image.hit(pageX: 32, pageY: 175), 2)
        XCTAssertEqual(image.hit(pageX: 96, pageY: 110), 3)
    }

    func testUnusedBytesDoNotPermitTruncatedDeclaredLayers() throws {
        var header = Data([1, 0, 0, 0, 1, 0, 2, 0])
        header.append(Data(repeating: 0, count: 16))
        XCTAssertThrowsError(try OriginalUpViewTable(data: header + Data(repeating: 0, count: 39)))
        let complete = header + Data(repeating: 0, count: 40)
        XCTAssertEqual(try OriginalUpViewTable(data: complete).views.count, 1)
        XCTAssertEqual(try OriginalUpViewTable(data: complete + Data([1, 2, 3])).views.count, 1)
    }

    func testMalformedTablesFail() throws {
        XCTAssertThrowsError(try OriginalUpViewTable(data: Data()))
        XCTAssertThrowsError(try OriginalUpViewTable(data: Data([255, 255, 255, 255])))
        XCTAssertThrowsError(try OriginalUpViewTable(data: Data([1, 0, 0, 0]) + Data(repeating: 0, count: 20)))
    }
}
