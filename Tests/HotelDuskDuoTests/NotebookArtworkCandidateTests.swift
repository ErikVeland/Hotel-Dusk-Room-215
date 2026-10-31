import Foundation
import XCTest
@testable import HotelDuskDuoKit

final class NotebookArtworkCandidateTests: XCTestCase {
    func testReadOnlyOriginalDrawingUsesCandidateWithoutChangingEditablePage() throws {
        guard let path = ProcessInfo.processInfo.environment["HOTEL_DUSK_NOTEBOOK_CANDIDATE"] else {
            throw XCTSkip("Set HOTEL_DUSK_NOTEBOOK_CANDIDATE to the isolated verification pack")
        }
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        var bytes = game.bytes
        bytes[0x87B] = 1
        game = try OriginalGameState(snapshot: Data(bytes))
        var notebook = try OriginalNotebook(game: game, load: OriginalBitmapLibrary.bundled().loadNotebookData)
        let artwork = OriginalArtwork(resourceRoot: URL(fileURLWithPath: path))
        let editable = try XCTUnwrap(OriginalNotebookImage.render(notebook, artwork: artwork))
        XCTAssertEqual(editable.width, 192)
        XCTAssertEqual(editable.height, 256)
        for _ in 0..<3 { notebook.turnPage(forward: true) }
        XCTAssertFalse(notebook.canEdit)
        let drawing = try XCTUnwrap(OriginalNotebookImage.render(notebook, artwork: artwork))
        XCTAssertEqual(drawing.width, 768)
        XCTAssertEqual(drawing.height, 1024)
        XCTAssertEqual(artwork.logicalSize(of: drawing), CGSize(width: 192, height: 256))
    }

    func testCombinedMilaNotesUseEnhancedInkAtOriginalPagePositions() throws {
        guard let path = ProcessInfo.processInfo.environment["HOTEL_DUSK_NOTEBOOK_CANDIDATE"] else {
            throw XCTSkip("Set HOTEL_DUSK_NOTEBOOK_CANDIDATE to the isolated verification pack")
        }
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        var bytes = game.bytes
        bytes[0x13CC] = 3
        game = try OriginalGameState(snapshot: Data(bytes))
        let notebook = try OriginalNotebook(game: game, load: OriginalBitmapLibrary.bundled().loadNotebookData)
        XCTAssertFalse(notebook.canEdit)
        let artwork = OriginalArtwork(resourceRoot: URL(fileURLWithPath: path))
        let image = try XCTUnwrap(OriginalNotebookImage.render(notebook, artwork: artwork))
        XCTAssertEqual(image.width, 768)
        XCTAssertEqual(image.height, 1024)
        let original = try XCTUnwrap(OriginalNotebookImage.render(notebook, artwork: OriginalArtwork(resourceRoot: nil)))
        let originalPixels = [UInt8](try XCTUnwrap(original.dataProvider?.data) as Data)
        let enhancedPixels = [UInt8](try XCTUnwrap(image.dataProvider?.data) as Data)
        var upperInk = 0
        var lowerInk = 0
        for y in 0..<1024 {
            for x in 0..<768 where enhancedPixels[(y * 768 + x) * 4 + 3] != 0 {
                XCTAssertNotEqual(originalPixels[((y / 4) * 192 + x / 4) * 4 + 3], 0)
                if y < 56 * 4 { upperInk += 1 }
                else { lowerInk += 1 }
            }
        }
        XCTAssertGreaterThan(upperInk, 0)
        XCTAssertGreaterThan(lowerInk, 0)
    }

    func testMissingEnhancedNoteFallsBackToCompleteOriginalPage() throws {
        guard let path = ProcessInfo.processInfo.environment["HOTEL_DUSK_NOTEBOOK_CANDIDATE"] else {
            throw XCTSkip("Set HOTEL_DUSK_NOTEBOOK_CANDIDATE to the isolated verification pack")
        }
        let source = URL(fileURLWithPath: path)
        let manifestData = try Data(contentsOf: source.appendingPathComponent("ArtworkManifest.json"))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let records = try XCTUnwrap(manifest["images"] as? [[String: Any]])
        let first = try XCTUnwrap(records.first { record in
            (record["sources"] as? [String])?.contains(where: { $0.hasSuffix("mila01_M.bin") }) == true
        })
        let file = try XCTUnwrap(first["file"] as? String)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(file),
            withDestinationURL: source.appendingPathComponent(file).resolvingSymlinksInPath())
        let partial: [String: Any] = ["formatVersion": 1, "scale": 4, "complete": true, "images": [first]]
        try JSONSerialization.data(withJSONObject: partial).write(to: root.appendingPathComponent("ArtworkManifest.json"))
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: nil)
        var bytes = game.bytes
        bytes[0x13CC] = 3
        game = try OriginalGameState(snapshot: Data(bytes))
        let notebook = try OriginalNotebook(game: game, load: OriginalBitmapLibrary.bundled().loadNotebookData)
        let image = try XCTUnwrap(OriginalNotebookImage.render(notebook, artwork: OriginalArtwork(resourceRoot: root)))
        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 256)
        let data = [UInt8](try XCTUnwrap(image.dataProvider?.data) as Data)
        XCTAssertTrue((0..<(56 * 192)).contains { data[$0 * 4 + 3] != 0 })
        XCTAssertTrue(((56 * 192)..<(112 * 192)).contains { data[$0 * 4 + 3] != 0 })
    }
}
