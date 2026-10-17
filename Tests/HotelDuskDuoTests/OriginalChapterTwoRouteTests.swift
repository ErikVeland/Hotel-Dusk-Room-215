import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalChapterTwoRouteTests: XCTestCase {
    private func state(_ name: String) throws -> OriginalGameState {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("The original Chapter 2 capture is unavailable") }
        return try OriginalGameState(snapshot: Data(contentsOf: url).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
    }

    private func capture(_ image: CGImage?, name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let image else { return }
        let root = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let output = root.appendingPathComponent(name + ".png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    @MainActor private func advance(_ play: OriginalPlaySession) {
        for _ in 0..<200 {
            switch play.runner.phase {
            case .dialogue, .itemNotice: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: return
            }
        }
        XCTFail("The conversation did not finish")
    }

    private func compare(_ actual: OriginalGameState, _ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try state(name).bytes
        XCTAssertEqual(actual.bytes.indices.filter { actual.bytes[$0] != expected[$0] }, [], file: file, line: line)
    }

    func testLinensMapUsesOriginalScaleAndFloorPlan() throws {
        let map = try OriginalMapExploration.bundled(mapID: 37, previousMapID: 39)
        XCTAssertEqual(map.position, .init(-182, 12288, -23166))
        XCTAssertEqual(map.facing, 0)
        XCTAssertEqual(map.mapOrigin, .init(0, 5))
        XCTAssertEqual(map.mapScale, 14)
        let bitmap = try OriginalBitmapLibrary.bundled().loadMap(path: "map/fmapscr/R211.bin")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/chapter-two-linens-room/room-bottom.ppm")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original Linens Closet capture is unavailable") }
        let capture = try Data(contentsOf: file), header = Data("P6\n256 192\n255\n".utf8)
        XCTAssertTrue(capture.starts(with: header))
        let pixels = Array(capture.dropFirst(header.count)), rgba = Array(bitmap.rgba)
        for point in [SIMD2(45, 100), .init(70, 130), .init(140, 130), .init(90, 200), .init(155, 220)] {
            let reference = (point.x * 256 + 255 - point.y) * 3
            let native = ((point.y - Int(map.mapBitmapOffset.y)) * bitmap.width + point.x - Int(map.mapBitmapOffset.x)) * 4
            for channel in 0..<3 {
                XCTAssertEqual(pixels[reference + channel] >> 3, rgba[native + channel] >> 3, "Page \(point)")
            }
        }
    }

    @MainActor func testChapterTwoRosaLinensAndHelenGuideRoute() throws {
        let checkpoint = try OriginalChapterSave(game: state("chapter-one-review-final/page32"), savedAt: Date())
        let audio = AudioController()
        audio.isMuted = true
        let play = try OriginalPlaySession.restoring(checkpoint, audio: audio,
            saveStore: OriginalChapterFileStore(directory: FileManager.default.temporaryDirectory), puzzleSeed: { 0xE657DCF9 })
        defer { play.stop() }
        play.continueChapterTitle()
        for _ in 0..<100 {
            switch play.runner.phase {
            case .dialogue: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            default: break
            }
        }
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<114 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.nearbyDoor, 39)
        play.inspectNearbyDoor()
        XCTAssertEqual(play.runner.program.name, "EP2_R213")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        play.holdLobbyTouch(x: 96, y: 45)
        for _ in 0..<17 { play.advanceFrame() }
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<145 {
            if case .exploration = play.runner.phase { play.advanceFrame() }
        }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.runner.eventIndex, 0)
        advance(play)
        XCTAssertEqual(play.runner.game.facing, try state("chapter-two-rosa-approach/page4").facing)
        try compare(play.runner.game, "chapter-two-rosa-approach/page4")
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<85 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.lobby?.nearbyPerson(in: play.runner.game), 3)
        play.talkToNearbyPerson()
        XCTAssertEqual(play.runner.eventIndex, 1)
        advance(play)
        guard case .questions(let topics) = play.runner.phase else { return XCTFail("Expected Rosa's questions: \(play.runner.phase)") }
        XCTAssertEqual(topics.map(\.keyword), [0, 1])
        try compare(play.runner.game, "chapter-two-rosa-talk/page29")
        play.ask(0)
        var answers: [UInt16] = []
        var interrupts: Set<UInt16> = []
        for _ in 0..<250 {
            switch play.runner.phase {
            case .dialogue where play.runner.interruptAvailable && !interrupts.contains(play.runner.interrupt.event):
                interrupts.insert(play.runner.interrupt.event)
                play.interrupt()
            case .dialogue: play.advanceDialogue()
            case .waiting: play.advanceFrame()
            case .choice(let choices):
                guard let answer = choices.first(where: { [UInt16(1), 3, 4].contains($0.id) }) else { return XCTFail("Expected Rosa's guide answer") }
                if answer.id == 1 { try compare(play.runner.game, "chapter-two-rosa-stories-interrupt/page1") }
                if answer.id == 3 { try compare(play.runner.game, "chapter-two-rosa-cant-talk-choice/choice") }
                if answer.id == 4 { try compare(play.runner.game, "chapter-two-rosa-relent-choice/choice") }
                answers.append(answer.id)
                play.choose(answer.id)
            case .questions: break
            default: return XCTFail("Rosa's conversation stopped: \(play.runner.phase)")
            }
            if case .questions = play.runner.phase { break }
        }
        XCTAssertEqual(answers, [1, 3, 4])
        guard case .questions(let remaining) = play.runner.phase else { return XCTFail("Expected Mila's question") }
        XCTAssertEqual(remaining.map(\.keyword), [1])
        try compare(play.runner.game, "chapter-two-rosa-relent/page16")
        play.ask(1)
        advance(play)
        guard case .choice(let choices) = play.runner.phase else { return XCTFail("Expected the bracelet choice") }
        XCTAssertEqual(choices.map(\.id), [6, 7])
        try compare(play.runner.game, "chapter-two-rosa-mila/page20")
        play.choose(7)
        advance(play)
        play.leaveConversation()
        advance(play)
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 39))
        XCTAssertNil(play.runner.game.personMarker(3))
        try compare(play.runner.game, "chapter-two-rosa-departure-finish/page14")
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<125 {
            if case .exploration = play.runner.phase { play.advanceFrame() }
        }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.runner.eventIndex, 27, "\(play.runner.phase)")
        advance(play)
        try compare(play.runner.game, "chapter-two-whistle/page8")
        play.holdLobbyTouch(x: 170, y: 128)
        for _ in 0..<365 { play.advanceFrame() }
        play.holdLobbyTouch(x: 96, y: 210)
        for _ in 0..<12 { play.advanceFrame() }
        play.releaseLobbyTouch()
        XCTAssertEqual(play.nearbyDoor, 37, "\(String(describing: play.lobby?.position)), \(play.runner.phase)")
        play.inspectNearbyDoor()
        XCTAssertEqual(play.door?.destination, 37)
        advance(play)
        XCTAssertEqual(play.doorImage?.hit(pageX: 158, pageY: 180), 2)
        play.selectDoorComponent(x: 158, y: 180)
        play.confirmDoorComponent()
        advance(play)
        XCTAssertEqual(play.runner.program.name, "EP2_R211")
        XCTAssertEqual(play.runner.phase, .exploration(mapID: 37))
        XCTAssertEqual(play.lobby?.mapID, 37)
        try capture(play.lobbyImage, name: "linens_entry_room")
        try compare(play.runner.game, "chapter-two-linens-entry/page22")
        try OriginalLinensRouteChecks.run(play,
            compare: { try self.compare($0, $1) },
            captureImage: { try self.capture($0, name: $1) })
        try OriginalHelenRouteChecks.run(play, compare: { try self.compare($0, $1) })
        try OriginalHangerRouteChecks.inspect(play,
            compare: { try self.compare($0, $1) },
            captureImage: { try self.capture($0, name: $1) })
        try OriginalHangerRouteChecks.exerciseRetries(play, compare: { try self.compare($0, $1) })
        try OriginalHangerRouteChecks.cut(play,
            compare: { try self.compare($0, $1) },
            captureImage: { try self.capture($0, name: $1) })
        try OriginalThickWireRouteChecks.run(play,
            compare: { try self.compare($0, $1) },
            captureImage: { try self.capture($0, name: $1) })
    }

}
