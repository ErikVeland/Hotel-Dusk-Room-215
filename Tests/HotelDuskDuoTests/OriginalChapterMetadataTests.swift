import XCTest
@testable import HotelDuskDuoKit

final class OriginalChapterMetadataTests: XCTestCase {
    func testAllChapterClocksAndCheckpoints() throws {
        let defaults = try OriginalStateDefaults.bundled()
        let clocks = [" 05:00PM", " 05:30PM", " 06:00PM", " 07:00PM", " 08:00PM",
                      " 09:00PM", " 10:00PM", " 11:00PM", " 12:00AM", " 02:00AM"]
        for index: UInt16 in 0..<10 {
            let chapter = try OriginalChapter(index)
            XCTAssertEqual(chapter.clockLabel, clocks[Int(index)])
            var game = try OriginalGameState.newGame(defaults: defaults, timestamp: nil)
            game.setMap(31, previous: 31)
            try game.beginChapter(index)
            if index > 0 {
                let checkpoint = try OriginalChapterSave(game: game, savedAt: Date())
                XCTAssertEqual(try checkpoint.gameState(), game)
                XCTAssertEqual(checkpoint.chapterNumber, Int(index) + 1)
            }
            try game.beginChapterTitle(label: chapter.clockLabel)
            XCTAssertThrowsError(try OriginalChapterSave(game: game, savedAt: Date()))
            let resume = try OriginalResumeSave(game: game, checkpointFacing: 0, musicSequenceID: nil, savedAt: Date())
            XCTAssertEqual(try resume.gameState(), game)
        }
        XCTAssertThrowsError(try OriginalChapter(10))
        XCTAssertEqual(try OriginalChapter(8).dateLabel, "December 29th 1979")
        XCTAssertEqual(try OriginalChapter(7).timeRange, "11:00 P.M.–12:00 A.M.")
    }

    @MainActor func testAllChapterArtworkLoads() throws {
        let library = try OriginalBitmapLibrary.bundled()
        for chapter: UInt16 in 0..<10 {
            let images = try OriginalChapterTitleImages(library: library, chapter: chapter)
            XCTAssertGreaterThan(images.clock.width, 0)
            XCTAssertGreaterThan(images.item.height, 0)
        }
    }
}
