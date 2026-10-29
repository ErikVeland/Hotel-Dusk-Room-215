import XCTest
@testable import HotelDuskDuoKit

final class OriginalLinenWagonAudioTests: XCTestCase {
    func testThrowCueResolvesToTheLinenCartSourceEntry() throws {
        let archive = try OriginalSoundArchive.load()
        var puzzle = OriginalLinenWagonProcess(seed: 0x0F2B89E1)
        for _ in 0..<34 { _ = puzzle.update() }

        let throwTouch = SIMD2(80, 100)
        for _ in 0..<3 { _ = puzzle.update(pageTouch: throwTouch) }
        for _ in 0..<3 { _ = puzzle.update(pageTouch: .init(0, throwTouch.y)) }
        let throwEffects = puzzle.update()
        XCTAssertTrue(throwEffects.contains(.sound(archive: 53, entry: 0)))
        XCTAssertEqual(try archive.effect(archiveID: 53, entryID: 0).symbol,
                       "SE_NAZOTOKI_LINEN_CART")
    }
}
