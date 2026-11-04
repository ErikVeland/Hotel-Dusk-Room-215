import XCTest
import SwiftUI
import ImageIO
@testable import HotelDuskDuoKit

@MainActor
final class NotebookPortraitLayoutTests: XCTestCase {
    func testWritingDoesNotPaintOverVisiblePortraits() throws {
        try checkWriting(restoringLegacyBook: false)
    }

    func testWritingFromAnOlderSaveDoesNotPaintOverLivePortraits() throws {
        try checkWriting(restoringLegacyBook: true)
    }

    private func checkWriting(restoringLegacyBook: Bool) throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(2, previous: 1)
        try game.apply(.keywordAvailable([0, 1, 2]))
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R102"), game: game,
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP1_.ttk")),
            selection: .init(sceneID: 2, blockID: 4, modeID: 8, eventID: 28,
                             nowTime: game.nowTime, mapID: 2))
        let play = OriginalPlaySession(runner: runner, audio: originalRouteTestAudio(), catalog: catalog)
        defer { play.stop() }
        play.ask(0)
        play.pause()
        XCTAssertEqual(Set(play.encounterPortraits.map(\.screen)), [0, 1])
        for (size, stacked) in [(CGSize(width: 951, height: 669), false),
                                (CGSize(width: 669, height: 951), true)] {
            let metrics = DialogueSpreadMetrics(size: size, stacked: stacked)
            let book = DialogueNotebook()
            let message = String(repeating: "Room two fifteen keeps its secrets. ", count: 40)
            let tokens = message.utf8.enumerated().map {
                OriginalDialogueToken(textIndex: 0, byteOffset: $0.offset, kind: .glyph($0.element))
            }
            book.record(.itemNotice(itemID: 1, page: .init(page: 0, entries: [], tokens: tokens)),
                        program: "test", portraits: [
                            .init(screen: 1, animationID: "Hy_hanas_", frameIndex: 0),
                            .init(screen: 0, animationID: "Jf_hanas_", frameIndex: 0)
                        ])
            if restoringLegacyBook {
                var saved = book.savedState()
                saved.book = nil
                book.restore(try JSONDecoder().decode(DialogueNotebook.SavedState.self,
                    from: JSONEncoder().encode(saved)))
            }
            let layout = DialogueNotebookLayout(runs: book.ink, size: metrics.textSize, fontSize: 18,
                                                portraitSize: metrics.portraitSize, book: book.book)
            book.configure(layout)
            XCTAssertGreaterThan(layout.pages.count, 1)
            func snapshot(_ index: Int) throws -> CGImage {
                let renderer = ImageRenderer(content: NotebookDialogueLeaf(play: play, notebook: book,
                    layout: layout, metrics: metrics, pageIndex: index))
                renderer.scale = 1
                return try XCTUnwrap(renderer.cgImage)
            }
            let before = try (0...1).map { try pixels(snapshot($0)) }
            book.finishWriting()
            for index in 0...1 {
                let image = try snapshot(index)
                let after = try pixels(image)
                XCTAssertNotEqual(before[index], after, "The page must reveal dialogue")
                if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
                    let name = "portrait_writing_\(restoringLegacyBook ? "legacy" : "current")_\(stacked ? "stacked" : "wide")_\(index).png"
                    let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                    CGImageDestinationAddImage(destination, image, nil)
                    XCTAssertTrue(CGImageDestinationFinalize(destination))
                }
                let frame = layout.portraitFrame(pageIndex: index)
                    .offsetBy(dx: metrics.textOrigin.x, dy: metrics.textOrigin.y)
                var changed = 0
                for y in Int(ceil(frame.minY))..<Int(floor(frame.maxY)) {
                    for x in Int(ceil(frame.minX))..<Int(floor(frame.maxX)) {
                        let offset = (y * image.width + x) * 4
                        // Allow one colour step from rounding in the portrait's multiply blend.
                        if (0..<4).contains(where: { abs(Int(before[index][offset + $0]) - Int(after[offset + $0])) > 1 }) {
                            changed += 1
                        }
                    }
                }
                XCTAssertEqual(changed, 0, "Writing crossed the visible portrait on leaf \(index), stacked: \(stacked)")
            }
        }
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Array(UnsafeBufferPointer(start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self),
                                        count: image.width * image.height * 4))
    }
}
