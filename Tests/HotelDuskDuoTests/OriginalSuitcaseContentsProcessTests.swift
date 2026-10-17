import XCTest
@testable import HotelDuskDuoKit

final class OriginalSuitcaseContentsProcessTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func original(_ name: String) throws -> OriginalBytes {
        let file = root.appendingPathComponent("extracted/reference/chapter-two-suitcase-\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original suitcase timing capture is unavailable") }
        return OriginalBytes(try Data(contentsOf: file))
    }

    private func initial() throws -> (OriginalSuitcaseContentsProcess, OriginalGameState) {
        let library = try OriginalBitmapLibrary.bundled()
        let masks = try OriginalSuitcaseContents.lowerObjects.map {
            try OriginalTexture(data: library.loadLinear(path: "trick/searchbag/\($0.texture).bin").decodedPayload).originalPixelData
        }
        let contents = try OriginalSuitcaseContents(lowerHitMasks: masks)
        let bytes = try original("open/lower")
        let game = try OriginalGameState(snapshot: Data(bytes.range(0x11018C, OriginalGameState.byteCount)))
        return (OriginalSuitcaseContentsProcess(contents: contents), game)
    }

    private func enterLower(_ process: inout OriginalSuitcaseContentsProcess, game: OriginalGameState) throws {
        XCTAssertEqual(try process.update(game: game), [.fadeIn(60)])
        try process.update(game: game)
        XCTAssertEqual(try process.update(pageTouch: .init(96, 160), game: game), [.fadeOut(60)])
        try process.update(game: game)
        try process.update(game: game)
        for _ in 0..<15 { try process.update(game: game) }
        XCTAssertEqual(process.phase, 3)
        XCTAssertEqual(process.stage, 1)
    }

    func testCashAnimationCountersMatchOriginal() throws {
        var (process, game) = try initial()
        try enterLower(&process, game: game)
        try process.update(pageTouch: .init(40, 232), game: game)
        for _ in 0..<31 { try process.update(pageTouch: .init(140, 232), game: game) }
        try process.update(game: game)
        try process.update(pageTouch: .init(20, 235), game: game)
        try process.update(game: game)
        try process.update(pageTouch: .init(20, 235), game: game)
        XCTAssertEqual(try process.update(game: game), [.award(23)])
        try game.apply(.addInventory(id: 23))
        try process.update(game: game, itemTextureReady: false)
        XCTAssertEqual(process.itemStage, 10)
        for name in ["shade_start", "shade10", "scale_start", "scale10", "scale20", "hold_start", "hold15", "response"] {
            let reference = try original("item-timing/\(name)"), base = 0x221A40
            let stage = Int(try reference.u16(base + 0x448))
            let timer = Int(try reference.u16(base + 0x44C))
            let shade = Int(try reference.u16(base + 0x548))
            for _ in 0..<200 {
                if process.itemStage == stage && process.timer == timer && process.itemShade == shade { break }
                try process.update(game: game)
            }
            XCTAssertEqual(process.itemStage, stage, name)
            XCTAssertEqual(process.timer, timer, name)
            XCTAssertEqual(process.itemShade, shade, name)
            XCTAssertEqual(process.itemVisible, try reference.u16(base + 0x54A) != 0, name)
            XCTAssertEqual(process.itemScale, Float(bitPattern: try reference.u32(base + 0x54C)), name)
        }
        XCTAssertTrue(process.awaitingResponse)
        let paused = process
        for _ in 0..<50 { try process.update(game: game) }
        XCTAssertEqual(process, paused)
        process.finishResponse()
        for _ in 0..<31 { try process.update(game: game) }
        XCTAssertEqual(process.stage, 1)
        XCTAssertEqual(process.itemShade, 0)
        XCTAssertFalse(process.itemVisible)
        XCTAssertNil(process.contents.selected)
    }

    func testBackNavigationAndExitWaitForFades() throws {
        var (process, game) = try initial()
        try enterLower(&process, game: game)
        process.goBack()
        XCTAssertEqual(try process.update(game: game), [.stopDragSound, .fadeOut(60)])
        try process.update(game: game, fadeComplete: false)
        XCTAssertEqual(process.phase, 3)
        XCTAssertEqual(try process.update(game: game), [.fadeIn(60)])
        XCTAssertEqual(process.phase, 1)
        process.goBack()
        try process.update(game: game)
        try process.update(game: game)
        for _ in 0..<60 { try process.update(game: game) }
        XCTAssertEqual(try process.update(game: game), [.fadeOut(60), .sound(archive: 1, entry: 55)])
        for _ in 0..<60 { try process.update(game: game, fadeComplete: false) }
        XCTAssertNil(process.result)
        XCTAssertEqual(try process.update(game: game), [.completed(0)])
    }
}
