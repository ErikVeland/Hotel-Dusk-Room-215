import XCTest
import SwiftUI
@testable import HotelDuskDuoKit

// Temporary visual check for portrait text wrap; delete after use.
@MainActor
final class ZZWrapCheckTests: XCTestCase {
    func render(_ play: OriginalPlaySession, _ name: String) throws {
        let size = CGSize(width: 951, height: 669)
        let host = NSHostingView(rootView: NotebookDialogueSpread(play: play, notebook: play.dialogueNotebook))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        host.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: dir.appendingPathComponent("\(name).png"))
    }

    func testWrapCheck() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = GameSession(saveStore: OriginalChapterFileStore(directory: root),
                                  resumeStore: OriginalResumeFileStore(directory: root))
        session.startOriginalGame()
        defer { session.endOriginalGame() }
        let play = try XCTUnwrap(session.play)
        var shots = 0, lastSignature = "", lastPages: [NSRange] = []
        for step in 0..<400 where shots < 8 {
            guard case .dialogue = play.runner.phase else { play.advanceFrame(); continue }
            for _ in 0..<8 { play.advanceFrame() }
            play.dialogueNotebook.finishWriting()
            let signature = play.encounterPortraits.map { "\($0.screen):\($0.person):\($0.pose)" }.joined(separator: ",")
            if !play.encounterPortraits.isEmpty, signature != lastSignature {
                try render(play, String(format: "wrap_%02d_step%03d", shots, step))
                let pages = play.dialogueNotebook.reader.pages
                let shared = zip(lastPages, pages).prefix { $0.0.location == $0.1.location }.count
                print("WRAP shot \(shots) step \(step) portraits [\(signature)] pages \(pages.count) unchanged-prefix \(shared)/\(lastPages.count) revealed \(play.dialogueNotebook.reader.revealedEnd)")
                lastPages = pages
                shots += 1
            }
            lastSignature = signature
            play.advanceDialogue()
        }
        print("WRAP done shots \(shots)")
    }
}
