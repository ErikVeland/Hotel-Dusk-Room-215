import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalEntranceSessionTests: XCTestCase {
    private final class RecordingRumbleFeedback: RumbleFeedback {
        private(set) var durations: [Int?] = []

        func playRumble(durationFrames: Int?) {
            durations.append(durationFrames)
        }

        func stopRumble() {}
    }

    func testEntranceHandleCueKeepsItsOneFrameDuration() throws {
        let feedback = RecordingRumbleFeedback()
        let audio = originalRouteTestAudio()
        let play = try OriginalPlaySession.chapterOne(
            audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)),
            rumbleFeedback: feedback
        )
        defer { play.stop() }

        while case .dialogue = play.runner.phase { play.advanceDialogue() }
        XCTAssertEqual(play.runner.phase, .process(id: 56))
        for _ in 0..<261 { play.advanceFrame() }
        play.touchEntrance(pageX: 92, pageY: 175)
        play.advanceFrame()

        XCTAssertEqual(feedback.durations, [1])
    }
}
