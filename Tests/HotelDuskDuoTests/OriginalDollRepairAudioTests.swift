import XCTest
@testable import HotelDuskDuoKit

final class OriginalDollRepairAudioTests: XCTestCase {
    func testStitchAndCompletionUseSourceArchiveThenEntry() throws {
        let archive = try OriginalSoundArchive.load()
        var puzzle = OriginalDollRepairProcess()
        _ = puzzle.update()
        _ = puzzle.update(pageTouch: .init(150, 130))
        _ = puzzle.update(pageTouch: .init(180, 137))
        let effects = puzzle.update()
        XCTAssertEqual(effects, [.sound(archive: 35, entry: 0)])
        for effect in effects {
            if case .sound(let id, let entry) = effect { _ = try archive.effect(archiveID: id, entryID: entry) }
        }
        // 0x02064DC4 calls 0x0200A060(manager, entry: 0, archive: 1).
        for point in (1...10).map({ SIMD2<Int>($0 % 2 == 0 ? 150 : 180, 130 + $0 * 7) }) {
            _ = puzzle.update(pageTouch: point)
        }
        _ = puzzle.update()
        var completion: [OriginalDollRepairProcess.Effect] = []
        for _ in 0..<8 { completion += puzzle.update(fadeComplete: true) }
        XCTAssertTrue(completion.contains(.sound(archive: 1, entry: 0)))
        _ = try archive.effect(archiveID: 1, entryID: 0)
    }
}
