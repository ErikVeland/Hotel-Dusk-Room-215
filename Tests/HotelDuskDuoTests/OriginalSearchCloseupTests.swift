import XCTest
@testable import HotelDuskDuoKit

final class OriginalSearchCloseupTests: XCTestCase {
    private func state(_ path: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original close-up capture is not available") }
        return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func finish(_ runner: inout OriginalEventRunner) {
        for _ in 0..<300 {
            switch runner.phase {
            case .dialogue, .itemNotice: runner.acknowledgeDialogue()
            case .waiting: runner.advanceWait()
            default: return
            }
        }
        XCTFail("The close-up response did not finish")
    }

    func testBrochureEntryAndPaperclipPickupMatchOriginalState() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var parent = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"),
            game: state("room215-paperclip-approach/inspect"))
        parent.lookInSearchView(area: 1, subarea: 4, table: try .bundled(map: "R205"))
        finish(&parent)
        if var response = try parent.searchFallback(catalog: catalog) {
            XCTAssertEqual(response.eventIndex, 927)
            finish(&response)
            XCTAssertEqual(response.phase, .exploration(mapID: 31))
            parent.resumeSearch(after: response)
        }
        XCTAssertEqual(parent.phase, .exploration(mapID: 31))
        let entry = try state("room215-paperclip-brochure/closeup")
        XCTAssertTrue(parent.game.bytes == entry.bytes,
            "Entry differences: \(entry.bytes.indices.filter { entry.bytes[$0] != parent.game.bytes[$0] })")
        parent.lookInCloseup(area: 1, subarea: 4, event: 263)
        var response = try XCTUnwrap(parent.searchFallback(catalog: catalog))
        XCTAssertEqual(response.eventIndex, 929)
        finish(&response)
        XCTAssertEqual(response.phase, .exploration(mapID: 31))
        parent.resumeSearch(after: response)
        let picked = try state("room215-paperclip-pickup/step8")
        XCTAssertEqual(try parent.game.inventory.items, [29, 22, 1, 2, 3, 8])
        XCTAssertTrue(parent.game.bytes == picked.bytes,
            "Pickup differences: \(picked.bytes.indices.filter { picked.bytes[$0] != parent.game.bytes[$0] })")
        XCTAssertNil(try parent.searchFallback(catalog: catalog))
        parent.lookInCloseup(area: 1, subarea: 4, event: 263)
        var repeatResponse = try XCTUnwrap(parent.searchFallback(catalog: catalog))
        XCTAssertEqual(repeatResponse.eventIndex, 930)
        finish(&repeatResponse)
        parent.resumeSearch(after: repeatResponse)
        XCTAssertEqual(try parent.game.inventory.items.filter { $0 == 8 }.count, 1)
    }

    func testWrongParcelAndNotebookMatchOriginalState() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let initial = try state("wrong-parcel-bed4/inspect")
        var context = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0, modeID: 10, eventID: 0,
            nowTime: initial.nowTime, mapID: initial.mapID)
        context.areaID = 2
        context.subareaID = 2
        context.upViewID = -1
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: initial, selection: context)
        XCTAssertEqual(runner.eventIndex, 69)
        finish(&runner)
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        runner.lookInCloseup(area: 2, subarea: 2, event: 251)
        XCTAssertEqual(runner.eventIndex, 71)
        finish(&runner)
        let opened = try state("wrong-parcel-open/page3").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != opened[$0] }, [])
        let entry = try state("wrong-parcel-entry/page4").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != entry[$0] }, [])
        runner.lookInCloseup(area: 2, subarea: 2, event: 252)
        XCTAssertEqual(runner.eventIndex, 74)
        finish(&runner)
        XCTAssertEqual(runner.phase, .exploration(mapID: 31))
        XCTAssertTrue(try runner.game.inventory.items.contains(5))
        XCTAssertTrue(runner.game.keywordAvailable(14))
        let picked = try state("wrong-parcel-notebook/page12").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != picked[$0] }, [])
    }

    @MainActor
    func testNotebookVisibilityAndPixelsMatchOriginal() throws {
        let view = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R205").views.first { $0.id == 251 })
        let closeup = try OriginalSearchCloseup(area: 2, subarea: 2, view: view)
        XCTAssertEqual(view.layers.map(\.eventID), [252])
        let library = try OriginalBitmapLibrary.bundled()
        let bitmaps = try ([view.background] + view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        for (capture, visible) in [("wrong-parcel-open/page3", true), ("wrong-parcel-notebook/page12", false)] {
            let game = try state(capture)
            XCTAssertEqual(try closeup.visibility(game: game), [true, visible])
            let image = try OriginalUpViewImage(bitmaps: bitmaps, visible: closeup.visibility(game: game))
            XCTAssertEqual(image.hit(pageX: 95, pageY: 150), visible ? 1 : 0)
            try compareImage(image, capture: capture)
        }
    }

    @MainActor
    private func compareImage(_ image: OriginalUpViewImage, capture: String) throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let ram = try Data(contentsOf: root.appendingPathComponent("extracted/reference/\(capture)-ram.bin"))
        XCTAssertNotNil(ram.range(of: Data(image.packedHitMap)))
        let rgba = Array(image.rgba)
        var colours = Data()
        for pixel in stride(from: 0, to: rgba.count, by: 4) {
            let colour = UInt16(rgba[pixel] >> 3) | UInt16(rgba[pixel + 1] >> 3) << 5
                | UInt16(rgba[pixel + 2] >> 3) << 10 | 0x8000
            colours.append(UInt8(truncatingIfNeeded: colour))
            colours.append(UInt8(colour >> 8))
        }
        XCTAssertNotNil(ram.range(of: colours))
    }

    func testOrderParcelAndDocumentsMatchOriginalState() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let initial = try state("order-parcel-approach/inspect")
        var context = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: 0, modeID: 10, eventID: 0,
            nowTime: initial.nowTime, mapID: initial.mapID)
        context.areaID = 2
        context.subareaID = 3
        context.upViewID = -1
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: initial, selection: context)
        XCTAssertEqual(runner.eventIndex, 113)
        finish(&runner)
        runner.lookInCloseup(area: 2, subarea: 3, event: 253)
        XCTAssertEqual(runner.eventIndex, 115)
        finish(&runner)
        let opened = try state("order-parcel-open/page5").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != opened[$0] }, [])
        runner.lookInCloseup(area: 2, subarea: 3, event: 256)
        var response = try XCTUnwrap(runner.searchFallback(catalog: catalog))
        finish(&response)
        runner.resumeSearch(after: response)
        XCTAssertTrue(try runner.game.inventory.items.contains(49))
        let collected = try state("order-client-list/page15").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != collected[$0] }, [])
        runner.lookInCloseup(area: 2, subarea: 3, event: 254)
        XCTAssertEqual(runner.eventIndex, 118)
        finish(&runner)
        XCTAssertTrue(try runner.game.inventory.items.contains(6))
        let order = try state("order-sheet/page15").bytes
        XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != order[$0] }, [])
    }

    @MainActor
    func testOrderParcelLayersMatchTheOriginal() throws {
        let view = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R205").views.first { $0.id == 253 })
        let closeup = try OriginalSearchCloseup(area: 2, subarea: 3, view: view)
        XCTAssertEqual(view.layers.map(\.eventID), [254, 255, 256, 257])
        let library = try OriginalBitmapLibrary.bundled()
        let bitmaps = try ([view.background] + view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        for capture in ["order-parcel-open/page5", "order-client-list/page15", "order-sheet/page15"] {
            let game = try state(capture)
            let image = try OriginalUpViewImage(bitmaps: bitmaps, visible: closeup.visibility(game: game))
            try compareImage(image, capture: capture)
            XCTAssertEqual(image.hit(pageX: 65, pageY: 135), capture.contains("parcel-open") ? 3 : 0)
            XCTAssertEqual(image.hit(pageX: 161, pageY: 219), capture.contains("order-sheet") ? 0 : 1)
        }
    }

    @MainActor
    func testLinensCloseupPixelsAndHitMapsMatchOriginal() throws {
        let table = try OriginalUpViewTable.bundled(map: "R211")
        let library = try OriginalBitmapLibrary.bundled()
        for (viewID, capture) in [(295, "chapter-two-linens-tools/locker"),
                                  (305, "chapter-two-linens-tools/toolbox"),
                                  (305, "chapter-two-linens-tools/pliers"),
                                  (305, "chapter-two-linens-tools/crowbar"),
                                  (305, "chapter-two-linens-tools/screwdriver"),
                                  (295, "chapter-two-linens-magazine/locker"),
                                  (313, "chapter-two-linens-magazine/magazine"),
                                  (313, "chapter-two-linens-magazine/collected")] {
            let view = try XCTUnwrap(table.views.first { $0.id == viewID })
            let scene = try OriginalSearchCloseup(area: viewID == 313 ? 3 : 1, subarea: viewID == 313 ? 4 : 1, view: view)
            let bitmaps = try ([view.background] + view.layers.map(\.asset)).map {
                try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
            }
            let image = try OriginalUpViewImage(bitmaps: bitmaps, visible: scene.visibility(game: state(capture)))
            try compareImage(image, capture: capture)
        }
    }

    func testLockerSelectsNestedToolboxViewAfterItsOwnResponse() throws {
        let table = try OriginalUpViewTable.bundled(map: "R211")
        var locker = try OriginalSearchCloseup(area: 1, subarea: 1,
            view: XCTUnwrap(table.views.first { $0.id == 295 }))
        XCTAssertFalse(locker.select(1))
        XCTAssertTrue(locker.select(1))
        XCTAssertEqual(locker.selectedEvent, 296)
        XCTAssertEqual(locker.selectedChildView, 305)
        locker.clearSelection()
        XCTAssertNil(locker.selectedChildView)
        XCTAssertFalse(locker.select(0))
        XCTAssertNil(locker.selectedChildView)
        let toolbox = try OriginalSearchCloseup(area: 1, subarea: 1,
            view: XCTUnwrap(table.views.first { $0.id == 305 }))
        XCTAssertEqual(toolbox.view.layers.map(\.itemID), [-1, 15, 10, 65])
    }

    @MainActor
    func testHangerCloseupPixelsAndHitMapMatchOriginal() throws {
        let view = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R205").views.first { $0.id == 258 })
        let scene = try OriginalSearchCloseup(area: 4, subarea: 2, view: view)
        XCTAssertEqual(view.layers.map(\.eventID), [259])
        let library = try OriginalBitmapLibrary.bundled()
        let bitmaps = try ([view.background] + view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        let image = try OriginalUpViewImage(bitmaps: bitmaps,
            visible: scene.visibility(game: state("chapter-two-hanger-inspect/hanger")))
        try compareImage(image, capture: "chapter-two-hanger-inspect/hanger")
    }

    @MainActor
    func testPaperclipVisibilityAndHitMapMatchOriginal() throws {
        let view = try XCTUnwrap(OriginalUpViewTable.bundled(map: "R205").views.first { $0.id == 262 })
        XCTAssertEqual(view.layers.map(\.detailAsset), [""])
        var closeup = try OriginalSearchCloseup(area: 1, subarea: 4, view: view)
        XCTAssertFalse(closeup.select(1))
        XCTAssertTrue(closeup.select(1))
        XCTAssertEqual(closeup.selectedEvent, 263)
        XCTAssertFalse(closeup.select(0))
        XCTAssertEqual(closeup.selectedEvent, 262)
        XCTAssertFalse(closeup.select(2))
        XCTAssertNil(closeup.selectedEvent)
        let library = try OriginalBitmapLibrary.bundled()
        let bitmaps = try ([view.background] + view.layers.map(\.asset)).map {
            try library.loadLinear(path: "map/sdata/SearchUp/\($0).bin")
        }
        let before = try state("room215-paperclip-brochure/closeup")
        XCTAssertEqual(try closeup.visibility(game: before), [true, true])
        let image = try OriginalUpViewImage(bitmaps: bitmaps, visible: closeup.visibility(game: before))
        XCTAssertEqual(image.hit(pageX: 110, pageY: 70), 1)
        try compareImage(image, capture: "room215-paperclip-brochure/closeup")
        var after = try state("room215-paperclip-pickup/step8")
        XCTAssertEqual(try closeup.visibility(game: after), [true, false])
        let empty = try OriginalUpViewImage(bitmaps: bitmaps, visible: closeup.visibility(game: after))
        XCTAssertEqual(empty.hit(pageX: 110, pageY: 70), 0)
        try compareImage(empty, capture: "room215-paperclip-pickup/step8")
        try after.apply(.removeInventory(id: 8))
        XCTAssertEqual(try closeup.visibility(game: after), [true, false])
    }
}
