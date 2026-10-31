import XCTest
@testable import HotelDuskDuoKit

final class OriginalNotebookTests: XCTestCase {
    private func capture(_ name: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original notebook capture is not available") }
        return try Data(contentsOf: path)
    }

    private func state(_ name: String) throws -> OriginalGameState {
        try .init(snapshot: capture(name).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    func testDrawingAndPageNavigationMatchOriginalState() throws {
        var game = try state("melissa-piece-show/page7")
        let library = try OriginalBitmapLibrary.bundled()
        var notebook = try OriginalNotebook(game: game, load: library.loadNotebookData)
        XCTAssertEqual(notebook.pageCount, 4)
        game.openNotebook()
        XCTAssertEqual(game.bytes, try state("melissa-notebook-open/opened").bytes)
        for _ in 0..<3 { notebook.turnPage(forward: true) }
        XCTAssertEqual(notebook.page, 3)
        XCTAssertFalse(notebook.canEdit)
        let original = try capture("melissa-notebook-pages/page4")
        XCTAssertNotNil(original.range(of: Data(notebook.pixels)))
        XCTAssertNotNil(original.range(of: Data(notebook.pages[3])))
        let drawing = notebook.pixels
        notebook.touch(x: 100, y: 100)
        notebook.touch(x: 100, y: 120)
        notebook.clear()
        notebook.undo()
        notebook.storePage()
        XCTAssertEqual(notebook.pixels, drawing)
        game.storeNotebook(notebook)
        XCTAssertEqual(game.bytes, try state("melissa-notebook-pages/page4").bytes)
        notebook.turnPage(forward: true)
        XCTAssertEqual(notebook.page, 0)
        notebook.turnPage(forward: false)
        XCTAssertEqual(notebook.page, 3)
    }

    func testStrokeUndoRedoAndStorageMatchOriginal() throws {
        var game = try state("melissa-notebook-open/opened")
        var notebook = try OriginalNotebook(game: game, load: OriginalBitmapLibrary.bundled().loadNotebookData)
        for _ in 0..<3 { notebook.touch(x: 100, y: 100) }
        for _ in 0..<3 { notebook.touch(x: 100, y: 120) }
        notebook.release()
        let stroke = notebook.pixels
        XCTAssertNotNil(try capture("notebook-strokes/stroke").range(of: Data(stroke)))
        notebook.undo()
        XCTAssertEqual(notebook.pixels, [UInt8](repeating: 0, count: 0xC000))
        notebook.undo()
        XCTAssertEqual(notebook.pixels, stroke)
        notebook.turnPage(forward: true)
        game.storeNotebook(notebook)
        let stored = try state("notebook-strokes/stored")
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != stored.bytes[$0] }, [])
        notebook.turnPage(forward: false)
        XCTAssertEqual(notebook.pixels, stroke)
        notebook.clear()
        XCTAssertFalse(notebook.pixels.contains(1))
        notebook.undo()
        XCTAssertEqual(notebook.pixels, stroke)
    }

    func testEraserBoundsAndMalformedDrawing() throws {
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        var notebook = try OriginalNotebook(game: game) { _ in XCTFail("No drawing is acquired"); return Data() }
        notebook.touch(x: 100, y: 100)
        XCTAssertFalse(notebook.pixels.contains(1))
        notebook.touch(x: 100, y: 100)
        XCTAssertEqual(notebook.pixels.filter { $0 == 1 }.count, 4)
        notebook.toggleEraser()
        notebook.touch(x: 100, y: 100)
        notebook.touch(x: 100, y: 100)
        XCTAssertFalse(notebook.pixels.contains(1))
        notebook.release()
        notebook.toggleEraser()
        for point in [SIMD2(Int.min, Int.max), SIMD2(192, 256), SIMD2(0, 0)] {
            notebook.touch(x: point.x, y: point.y)
            notebook.touch(x: point.x, y: point.y)
            notebook.release()
        }
        XCTAssertFalse(notebook.pixels.contains(1))
        var bytes = game.bytes
        bytes[0x87B] = 1
        game = try OriginalGameState(snapshot: Data(bytes))
        XCTAssertThrowsError(try OriginalNotebook(game: game) { _ in Data([0]) })
        bytes[0x13CC] = 1
        game = try OriginalGameState(snapshot: Data(bytes))
        XCTAssertThrowsError(try OriginalNotebook(game: game) { _ in Data(repeating: 0, count: 0x1800) })
    }

    func testAppleNotebookPagesUseCollectedBitsAndSourceSlots() throws {
        var bytes = [UInt8](repeating: 0, count: OriginalGameState.byteCount)
        bytes[0x13D8] = 0b01001
        let game = try OriginalGameState(snapshot: Data(bytes))
        var loaded = [String]()
        let notebook = try OriginalNotebook(game: game) { path in
            loaded.append(path)
            if path == "system/note/memo/appmem_M.bin" {
                return Data(repeating: 0xA5, count: OriginalNotebook.packedSize)
            }
            if path == "system/note/memo/apppic4_M.bin" {
                return Data(repeating: 0x4A, count: OriginalNotebook.packedSize)
            }
            throw OriginalDataError.missing(path)
        }

        XCTAssertEqual(game.appleNotebookPageMask, 0b01001)
        XCTAssertEqual(notebook.pageCount, 5)
        XCTAssertEqual(loaded, ["system/note/memo/appmem_M.bin", "system/note/memo/apppic4_M.bin"])
        XCTAssertEqual(notebook.pages[4], [UInt8](repeating: 0x4A, count: OriginalNotebook.packedSize))

        let overview = notebook.pages[3]
        let slots = [(16, 14), (4, 18), (14, 24), (8, 5), (1, 2)]
        for (index, (x, y)) in slots.enumerated() {
            let start = x * 0x100 + y * 8
            let found = game.appleNotebookPageMask & (1 << index) != 0
            for row in 0..<5 {
                let lowerBound = start + row * 0x100
                let range = lowerBound..<(lowerBound + 0x28)
                XCTAssertEqual(overview[range].allSatisfy { $0 == 0 }, !found,
                               "Apple page slot \(index), row \(row) must match its found bit")
            }
        }

        var allApplePages = bytes
        allApplePages[0x13D8] = 0x1F
        let completeGame = try OriginalGameState(snapshot: Data(allApplePages))
        let completeNotebook = try OriginalNotebook(game: completeGame, load: OriginalBitmapLibrary.bundled().loadNotebookData)
        XCTAssertEqual(completeNotebook.pageCount, 8)
    }

    func testAngledStrokesAndErasureMatchOriginalStorage() throws {
        var game = try state("melissa-notebook-open/opened")
        var notebook = try OriginalNotebook(game: game, load: OriginalBitmapLibrary.bundled().loadNotebookData)
        for point in [SIMD2(20, 30), SIMD2(70, 43), SIMD2(30, 110), SIMD2(90, 60), SIMD2(150, 180), SIMD2(90, 60)] {
            for _ in 0..<3 { notebook.touch(x: point.x, y: point.y) }
        }
        notebook.release()
        notebook.turnPage(forward: true)
        game.storeNotebook(notebook)
        let stored = try state("notebook-angled-strokes/stored")
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != stored.bytes[$0] }, [])
        notebook.turnPage(forward: false)
        notebook.toggleEraser()
        for point in [SIMD2(20, 30), SIMD2(70, 43), SIMD2(30, 110)] {
            for _ in 0..<3 { notebook.touch(x: point.x, y: point.y) }
        }
        notebook.release()
        notebook.turnPage(forward: true)
        game.storeNotebook(notebook)
        let erased = try state("notebook-angled-strokes/erasureStored")
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != erased.bytes[$0] }, [])
    }
}
