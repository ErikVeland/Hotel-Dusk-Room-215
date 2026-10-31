import XCTest
@testable import HotelDuskDuoKit

final class OriginalJigsawProcessTests: XCTestCase {
    func testSoftwareFoldAvailableOnlyWhenReversePuzzleAwaitsFold() {
        var puzzle = OriginalJigsawProcess(seed: 1, variant: .reverse)
        XCTAssertFalse(puzzle.awaitsFold)
        for _ in 0..<10 where !puzzle.awaitsFold { _ = puzzle.update(screen0FadeComplete: true) }
        XCTAssertTrue(puzzle.awaitsFold)
        puzzle.receiveFold(isClosed: true)
        puzzle.receiveFold(isClosed: false)
        _ = puzzle.update(screen0FadeComplete: true)
        XCTAssertFalse(puzzle.awaitsFold)
        XCTAssertFalse(ready().awaitsFold)
    }

    private func ready() -> OriginalJigsawProcess {
        var puzzle = OriginalJigsawProcess(seed: 0x3DEAC027)
        for _ in 0..<4 { _ = puzzle.update() }
        return puzzle
    }

    func testOriginalInitialMaskAndRandomisation() {
        let puzzle = ready()
        XCTAssertEqual(puzzle.phase, 1)
        XCTAssertEqual(puzzle.placedCount, 15)
        XCTAssertEqual(puzzle.looseMask, 0x668)
        XCTAssertEqual(puzzle.seed, 0xC1DA6164)
        let indices = [3, 5, 6, 9, 10]
        let positions: [OriginalJigsawProcess.Point] = [.init(-6267, -12288), .init(-3318, -12288),
            .init(-369, -12288), .init(-1475, -11469), .init(-5530, -10240)]
        XCTAssertEqual(indices.map { puzzle.pieces[$0].position }, positions)
        XCTAssertEqual(indices.map { puzzle.pieces[$0].angle }, [0, 1.5, 1.5, 0, 1.5])
    }

    func testInitialPiecesMatchOriginalRAM() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/r117-louie-help/puzzle-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original jigsaw capture is not available") }
        let bytes = try OriginalBytes(Data(contentsOf: file)), puzzle = ready()
        for index in 0..<20 {
            let at = 0x257DA0 + 0x470 + index * 32
            let original = try OriginalJigsawProcess.Point(Int32(bitPattern: bytes.u32(at)), Int32(bitPattern: bytes.u32(at + 4)))
            XCTAssertEqual(puzzle.pieces[index].position, original, "Piece \(index)")
            XCTAssertEqual(puzzle.pieces[index].depth, Int32(bitPattern: try bytes.u32(at + 8)))
            XCTAssertEqual(puzzle.pieces[index].angle, Float(bitPattern: try bytes.u32(at + 24)))
            XCTAssertEqual(puzzle.pieces[index].movable, bytes.bytes[at + 28] == 1)
        }
    }

    func testCapturedPieceFiveDragAndPartialQuit() {
        var puzzle = ready()
        // Original selected capture: piece 5, grab offset (2051,1964).
        puzzle.beginTouch(world: .init(-1267, -10324))
        XCTAssertEqual(puzzle.selected, 5)
        XCTAssertTrue(puzzle.holding)
        XCTAssertEqual(puzzle.pieces[5].depth, 4)
        let target = OriginalJigsawProcess.target(5)
        puzzle.moveTouch(world: .init(target.x + 2051, target.y + 1964))
        XCTAssertEqual(puzzle.endTouch(), [.sound(archive: 26, entry: 0)])
        XCTAssertEqual(puzzle.pieces[5].position, .init(-819, -4505))
        XCTAssertTrue(puzzle.isPlaced(5))
        XCTAssertNil(puzzle.selected)
        XCTAssertEqual(puzzle.placedCount, 16)
        _ = puzzle.update(); _ = puzzle.update()
        puzzle.quit()
        XCTAssertEqual(puzzle.update(), [.fadeOut(updates: 60)])
        XCTAssertEqual(puzzle.update(screen0FadeComplete: true), [.completed(1)])
    }

    func testWrongRotationDoesNotSnapAndRotationUsesOriginalSteps() {
        var puzzle = ready()
        puzzle.beginTouch(world: .init(-6200, -12000))
        XCTAssertEqual(puzzle.selected, 3)
        let target = OriginalJigsawProcess.target(3)
        puzzle.moveTouch(world: .init(target.x + 167, target.y + 288))
        XCTAssertEqual(puzzle.endTouch(), [])
        XCTAssertFalse(puzzle.isPlaced(3))
        _ = puzzle.update(); _ = puzzle.update()
        XCTAssertEqual(puzzle.rotate(increasing: false), [.sound(archive: 26, entry: 1)])
        for _ in 0..<20 { _ = puzzle.update() }
        XCTAssertEqual(puzzle.pieces[3].angle, 1.5)
        puzzle.beginTouch(world: .init(target.x + 100, target.y + 100))
        XCTAssertEqual(puzzle.selected, 3)
        XCTAssertEqual(puzzle.endTouch(), [.sound(archive: 26, entry: 0)])
        XCTAssertTrue(puzzle.isPlaced(3))
    }

    func testQuitAndSavedMask() {
        var puzzle = ready()
        puzzle.quit()
        _ = puzzle.update()
        XCTAssertEqual(puzzle.update(screen0FadeComplete: true), [.completed(2)])
        let restored = OriginalJigsawProcess(seed: 9, savedLooseMask: 0x648)
        XCTAssertTrue(restored.isPlaced(5))
        XCTAssertEqual(restored.placedCount, 16)
        XCTAssertEqual(restored.looseMask, 0x648)
    }

    func testCompleteAllFivePiecesAndOriginalCompletionCue() {
        var puzzle = ready()
        for index in [3, 5, 6, 9, 10] {
            let piece = puzzle.pieces[index]
            puzzle.beginTouch(world: piece.position)
            XCTAssertEqual(puzzle.selected, index)
            if piece.angle != 1.5 {
                _ = puzzle.endTouch()
                _ = puzzle.update(); _ = puzzle.update()
                _ = puzzle.rotate(increasing: false)
                for _ in 0..<20 { _ = puzzle.update() }
                puzzle.beginTouch(world: piece.position)
            }
            puzzle.moveTouch(world: OriginalJigsawProcess.target(index))
            XCTAssertEqual(puzzle.endTouch(), [.sound(archive: 26, entry: 0)])
            _ = puzzle.update()
            if index != 10 { _ = puzzle.update() }
        }
        XCTAssertEqual(puzzle.placedCount, 20)
        XCTAssertEqual(puzzle.looseMask, 0)
        XCTAssertEqual(puzzle.update(), [.completionFade(updates: 60)])
        XCTAssertEqual(puzzle.update(), [.sound(archive: 1, entry: 0)])
        for _ in 0..<121 { _ = puzzle.update() }
        XCTAssertEqual(puzzle.update(), [.fadeOut(updates: 60)])
        XCTAssertEqual(puzzle.update(screen0FadeComplete: true), [.completed(0)])
    }

    func testHintUsesSystemTextAndPreservesStoryProgress() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(17, previous: 3)
        let story = try OriginalEventRunner(program: catalog.loadProgram("EP1_R117"), game: game)
        for pair: Int16 in [1, 2] {
            var hint = try story.processHint(catalog: catalog, pairA: 3, pairB: pair)
            XCTAssertEqual(hint.eventIndex, pair == 1 ? 1501 : 1502)
            guard case .dialogue = hint.phase else { return XCTFail("Expected original hint dialogue") }
            for _ in 0..<10 {
                guard case .dialogue = hint.phase else { break }
                hint.acknowledgeDialogue()
            }
            XCTAssertEqual(hint.phase, .exploration(mapID: 17))
            XCTAssertEqual(hint.game.snapshot, story.game.snapshot)
        }
    }

    func testSavedMaskMatchesOriginalPartialQuit() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("extracted/reference/jigsaw-partial-quit/quit-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original partial-quit capture is not available") }
        let data = try Data(contentsOf: file)
        var game = try OriginalGameState(snapshot: data.subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        XCTAssertEqual(game.chapterOneJigsawMask, 0x648)
        let original = game.bytes
        game.chapterOneJigsawMask = 0x668
        XCTAssertEqual(game.chapterOneJigsawMask, 0x668)
        XCTAssertEqual(game.bytes.indices.filter { game.bytes[$0] != original[$0] }, [0x14AC])
    }

    func testProcessResultsSelectTheComparedOriginalEvents() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(17, previous: 3)
        let selection = OriginalEventSelectionContext(sceneID: 11, blockID: 2, modeID: 15,
                                                       eventID: 48, nowTime: 0, mapID: 17)
        for (result, mask, event): (Int16, UInt32, Int) in [(0, 0, 51), (1, 0x648, 49), (2, 0x668, 50)] {
            var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R117"), game: game, selection: selection)
            XCTAssertEqual(runner.phase, .process(id: 26))
            runner.finishJigsaw(returnValue: result, looseMask: mask)
            XCTAssertEqual(runner.eventIndex, event)
            XCTAssertEqual(runner.game.chapterOneJigsawMask, mask)
            guard case .dialogue = runner.phase else { return XCTFail("Expected the original result conversation") }
        }
    }

    func testSnapThresholdAndDragClamp() {
        for (distance, expected) in [(1228, true), (1230, false)] {
            var puzzle = ready()
            puzzle.beginTouch(world: .init(-1267, -10324))
            let target = OriginalJigsawProcess.target(5)
            puzzle.moveTouch(world: .init(target.x + 2051 + Int32(distance), target.y + 1964))
            _ = puzzle.endTouch()
            XCTAssertEqual(puzzle.isPlaced(5), expected)
        }
        var puzzle = ready()
        puzzle.beginTouch(world: .init(-1267, -10324))
        puzzle.moveTouch(world: .init(100_000, -100_000))
        XCTAssertEqual(puzzle.pieces[5].position, .init(4096, -12288))
        puzzle.moveTouch(world: .init(-100_000, 100_000))
        XCTAssertEqual(puzzle.pieces[5].position, .init(-8192, 4096))
    }

    func testIdleHintUsesElapsedTimeAndWaitsForConversation() throws {
        var puzzle = ready()
        puzzle.beginTouch(world: .init(-1267, -10324))
        _ = puzzle.endTouch()
        _ = puzzle.update(elapsedSeconds: 0)
        _ = puzzle.update(elapsedSeconds: 0)
        _ = puzzle.update(elapsedSeconds: 4.9)
        XCTAssertEqual(puzzle.phase, 1)
        _ = puzzle.update(elapsedSeconds: 0.2)
        XCTAssertEqual(puzzle.phase, 5)
        var effects: [OriginalJigsawProcess.Effect] = []
        for _ in 0..<30 { effects += puzzle.update() }
        guard case .hint(let a, let b) = try XCTUnwrap(effects.last) else { return XCTFail("Expected an original hint request") }
        XCTAssertEqual(a, 3)
        XCTAssertTrue([1, 2].contains(b))
        for _ in 0..<100 { XCTAssertEqual(puzzle.update(), []) }
        puzzle.finishHint()
        for _ in 0..<32 { _ = puzzle.update() }
        XCTAssertEqual(puzzle.phase, 1)
        let restored = try JSONDecoder().decode(OriginalJigsawProcess.self, from: JSONEncoder().encode(puzzle))
        XCTAssertEqual(restored, puzzle)
    }
}
