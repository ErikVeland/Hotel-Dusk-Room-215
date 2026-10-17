import XCTest
@testable import HotelDuskDuoKit

final class OriginalTouchPictureTests: XCTestCase {
    private func picture(_ id: UInt16 = 4) throws -> OriginalTouchPicture {
        let record = try XCTUnwrap(OriginalTouchPictureTable.bundled().records.first { $0.id == id })
        let bitmap = try OriginalBitmapLibrary.bundled().loadLinear(path: "check/TouchEvent/\(record.foreground).bin")
        return try OriginalTouchPicture(record: record, indices: bitmap.indices, width: bitmap.width, height: bitmap.height)
    }

    func testTableAndMaskMatchOriginalCapture() throws {
        let table = try OriginalTouchPictureTable.bundled()
        XCTAssertEqual(table.records.count, 44)
        let picture = try picture()
        XCTAssertEqual(picture.record.foreground, "TCG0104")
        XCTAssertEqual(picture.record.background, "TCB0104")
        XCTAssertEqual(picture.record.mode, 0)
        XCTAssertEqual(picture.mask.count, 3072)
        XCTAssertEqual(OriginalScriptCatalog.digest(Data(picture.mask)), "4afab132aa751bc271df4280052b4d4fe5ce3d316dfcb355f06c5e6534895320")
        XCTAssertTrue(picture.contains(pageX: 100, pageY: 128))
        XCTAssertFalse(picture.contains(pageX: 20, pageY: 20))
        XCTAssertFalse(picture.contains(pageX: .max, pageY: .min))
        XCTAssertThrowsError(try OriginalTouchPictureTable(data: Data([1, 0, 0, 0])))
        let unsupported = OriginalTouchPictureTable.Record(id: 4, foreground: "TCG0104", background: "TCB0104", x: 0, y: 0, mode: 1)
        XCTAssertThrowsError(try OriginalTouchPicture(record: unsupported, indices: [], width: 0, height: 0)) {
            XCTAssertEqual($0 as? OriginalDataError, .unsupported("Touch picture mode 1"))
        }
    }

    func testTwoPressesConfirmButHoldingAndOutsideTouchesDoNot() throws {
        var picture = try picture()
        XCTAssertEqual(picture.touch(pageX: 100, pageY: 128), [.selectSound])
        XCTAssertEqual(picture.touch(pageX: 100, pageY: 128), [])
        for _ in 0..<100 { picture.update() }
        XCTAssertEqual(picture.phase, .selecting)
        picture.release()
        XCTAssertTrue(picture.selected)
        XCTAssertEqual(picture.touch(pageX: 20, pageY: 20), [])
        XCTAssertFalse(picture.selected)
        picture.release()
        XCTAssertEqual(picture.touch(pageX: 100, pageY: 128), [.selectSound])
        picture.release()
        XCTAssertEqual(picture.touch(pageX: 100, pageY: 128), [.confirmSound])
        XCTAssertEqual(picture.phase, .fading)
        for _ in 0..<20 { picture.update() }
        XCTAssertEqual(picture.phase, .fading)
        picture.update()
        XCTAssertEqual(picture.phase, .returning)
        picture.update()
        XCTAssertEqual(picture.phase, .complete)
        XCTAssertEqual(picture.touch(pageX: 100, pageY: 128), [])
    }

    func testMaskKeepsOriginalCoarseByteHitRuleAndCropOrigin() throws {
        let record = try XCTUnwrap(OriginalTouchPictureTable.bundled().records.first { $0.id == 1 })
        XCTAssertEqual(record.x, 32)
        XCTAssertEqual(record.y, 128)
        var indices = [UInt8](repeating: 0, count: 128 * 128)
        indices[10 * 128 + 16] = 1
        let picture = try OriginalTouchPicture(record: record, indices: indices, width: 128, height: 128)
        for rawX in 16...23 {
            XCTAssertTrue(picture.contains(pageX: 42, pageY: 128 + 127 - rawX))
        }
        XCTAssertFalse(picture.contains(pageX: 42, pageY: 128 + 127 - 24))
        XCTAssertFalse(picture.contains(pageX: 31, pageY: 200))
        XCTAssertThrowsError(try OriginalTouchPicture(record: record, indices: [], width: 128, height: 128))
    }

    func testPictureBlocksItemAwardAndDialogueUntilProcessReturns() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        game.setMap(17, previous: 3)
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R117"), game: game,
            selection: .init(sceneID: 11, blockID: 2, modeID: 3, eventID: 52, nowTime: 0, mapID: 17))
        for _ in 0..<20 { runner.acknowledgeDialogue() }
        XCTAssertEqual(runner.phase, .picture(id: 4))
        XCTAssertFalse(try runner.game.inventory.items.contains(3))
        runner.acknowledgeDialogue()
        runner.advanceWait()
        runner.finishProcess(returnValue: 0)
        XCTAssertEqual(runner.phase, .picture(id: 4))
        runner.finishPicture()
        guard case .itemNotice(3, _) = runner.phase else { return XCTFail("Expected item 3: \(runner.phase)") }
        XCTAssertTrue(try runner.game.inventory.items.contains(3))
        let inventory = try runner.game.inventory.items
        runner.finishPicture()
        XCTAssertEqual(try runner.game.inventory.items, inventory)
        XCTAssertFalse(runner.unrenderedPresentation.contains { $0.hasPrefix("op8@") })
    }

    func testLinearBackgroundAndItemMatchCapturedOriginalBytes() throws {
        let library = try OriginalBitmapLibrary.bundled()
        let background = try library.loadLinear(path: "check/StilBG/TCB0104.bin")
        XCTAssertEqual(background.kind, 3)
        XCTAssertEqual(OriginalScriptCatalog.digest(background.decodedPayload), "c00510952c25b783e6b3c420e67218d0f33783b444616b2a1c7bc7f017870bf6")
        let item = try library.loadLinear(path: "system/ItemImage/item003.bin")
        XCTAssertEqual(item.kind, 1)
        XCTAssertEqual(item.palette.count, 32)
        XCTAssertEqual(OriginalScriptCatalog.digest(item.decodedPayload), "8546f1b8641f678141fc7186e859c76d4f569b9bcc5a08312a065493bfadc973")
        let rgba = Array(item.rgba(transparentPaletteZero: true))
        for (index, byte) in item.indices.enumerated() {
            let alpha = byte >> 5, expanded = (alpha << 2) | (alpha >> 1)
            XCTAssertEqual(rgba[index * 4 + 3], (expanded << 3) | (expanded >> 2))
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/jigsaw-pickup2/picked-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original picture capture is not available") }
        let ram = try Data(contentsOf: path)
        XCTAssertEqual(ram.subdata(in: 0x335150..<(0x335150 + background.decodedPayload.count)), background.decodedPayload)
        XCTAssertEqual(ram.subdata(in: 0x328F30..<(0x328F30 + item.decodedPayload.count)), item.decodedPayload)
        let before = try Data(contentsOf: root.appendingPathComponent("extracted/reference/jigsaw-aftermath2/after139-ram.bin"))
        XCTAssertEqual(before.subdata(in: 0x2B6340..<(0x2B6340 + 3072)), Data(try picture().mask))
    }

    func testRunLengthRejectsTruncationOverflowAndTrailingBytes() throws {
        XCTAssertEqual(try OriginalLinearBitmap.decodeRunLength(Data([0x30, 4, 0, 0, 0x81, 7])), Data([7, 7, 7, 7]))
        for bytes: [UInt8] in [[0x30], [0x30, 4, 0, 0, 0x81], [0x30, 3, 0, 0, 0x81, 7],
                              [0x30, 4, 0, 0, 3, 1, 2], [0x30, 4, 0, 0, 0x81, 7, 0]] {
            XCTAssertThrowsError(try OriginalLinearBitmap.decodeRunLength(Data(bytes)))
        }
    }

    func testMelissasNotebookUsesTheOriginalMaskAndTwoPresses() throws {
        var notebook = try picture(22)
        XCTAssertEqual(notebook.touch(pageX: 96, pageY: 225), [.selectSound])
        notebook.release()
        XCTAssertEqual(notebook.touch(pageX: 96, pageY: 225), [.confirmSound])
        for _ in 0..<22 { notebook.update() }
        XCTAssertEqual(notebook.phase, .complete)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/melissa-father-answer/page28-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original notebook capture is not available") }
        let ram = try Data(contentsOf: path)
        XCTAssertNotNil(ram.range(of: Data(notebook.mask)), "The complete native mask must occur in the original picture process")
    }

    func testMilasShoulderMatchesTheOriginalMask() throws {
        var shoulder = try picture(24)
        XCTAssertEqual(shoulder.touch(pageX: 96, pageY: 225), [.selectSound])
        shoulder.release()
        XCTAssertEqual(shoulder.touch(pageX: 96, pageY: 225), [.confirmSound])
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/mila-talk-correct/page3-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original Mila picture capture is not available") }
        XCTAssertNotNil(try Data(contentsOf: path).range(of: Data(shoulder.mask)))
    }

    func testSummersParcelMatchesTheOriginalMask() throws {
        var parcel = try picture(6)
        XCTAssertEqual(parcel.touch(pageX: 30, pageY: 100), [.selectSound])
        parcel.release()
        XCTAssertEqual(parcel.touch(pageX: 30, pageY: 100), [.confirmSound])
        for _ in 0..<24 { parcel.update() }
        XCTAssertEqual(parcel.phase, .complete)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/summer-book-answer/page22-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original Summer parcel capture is not available") }
        XCTAssertNotNil(try Data(contentsOf: path).range(of: Data(parcel.mask)))
    }

    @MainActor
    func testSelectedPictureKeepsTheOriginalHalfOpacity() throws {
        let picture = try picture(7)
        let library = try OriginalBitmapLibrary.bundled()
        let foreground = try library.loadLinear(path: "check/TouchEvent/TCG0107.bin")
        let background = try library.loadLinear(path: "check/StilBG/TCB0107.bin")
        let images = try OriginalTouchPictureImages(picture: picture, foreground: foreground,
            background: background, highlightRGB: (198, 132, 24))
        let pixels = try XCTUnwrap(images.highlight.dataProvider?.data) as Data
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        XCTAssertEqual(Set(alpha), [0, 128])
        let occupiedBlocks = picture.mask.reduce(0) { count, byte in
            count + (0..<4).filter { byte & (3 << ($0 * 2)) != 0 }.count
        }
        XCTAssertEqual(alpha.filter { $0 == 128 }.count, occupiedBlocks * 4)
    }
}
