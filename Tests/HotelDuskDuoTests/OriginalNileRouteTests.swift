import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalNileRouteTests: XCTestCase {
    func testDiagonalMovementAndLouieCollisionMatchOriginalUpdates() throws {
        let game = try state("chapter-two-office-exit-approach/page9")
        var map = try OriginalMapExploration.bundled(mapID: 3, previousMapID: 15, savedGame: game)
        let people = map.people(in: game).map(\.position)
        for frame in 3...44 {
            map.update(heldPageTouch: .init(60, 70), people: people)
            let expected = try position("chapter-two-louie-diagonal-motion/frame\(frame)")
            XCTAssertEqual(map.position, expected, "Original frame \(frame)")
        }
        map.update(heldPageTouch: .init(60, 70), people: people)
        XCTAssertEqual(map.position, try position("chapter-two-louie-approach-motion/west2"))
        for update in 1...40 {
            map.update(heldPageTouch: .init(20, 128), people: people)
            let capture: String?
            switch update {
            case 2: capture = "west4"
            case 8: capture = "west10"
            case 40: capture = "west40"
            default: capture = nil
            }
            if let capture {
                let expected = try position("chapter-two-louie-approach-motion/\(capture)")
                XCTAssertEqual(map.position, expected, capture)
            }
        }
    }

    private func position(_ name: String) throws -> SIMD3<Float> {
        let reader = try OriginalBytes(ram(name))
        return try SIMD3(Float(Int32(bitPattern: reader.u32(0x2924B4))),
                         Float(Int32(bitPattern: reader.u32(0x2924B8))),
                         Float(Int32(bitPattern: reader.u32(0x2924BC))))
    }

    private func ram(_ name: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("The original Nile conversation capture is unavailable")
        }
        return try Data(contentsOf: file)
    }

    private func state(_ name: String) throws -> OriginalGameState {
        try OriginalGameState(snapshot: ram(name).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    func testOfficeExitToNileConversation() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        let runner = try OriginalEventRunner(program: catalog.loadProgram("EP2_R103"),
            game: state("chapter-two-office-exit-approach/page9"),
            keywords: OriginalKeywordTable(decoded: catalog.decodedFile("EP2_.ttk")))
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
        defer { play.stop() }
        try OriginalNileRouteChecks.run(play) { actual, path in
            let expected = try self.state(path).bytes
            let differences = actual.bytes.indices.filter { actual.bytes[$0] != expected[$0] }
            let detail = differences.map { String(format: "%04X: %02X != %02X", $0, actual.bytes[$0], expected[$0]) }
            XCTAssertEqual(differences, [], "\(path): \(detail)")
        }
    }
}
