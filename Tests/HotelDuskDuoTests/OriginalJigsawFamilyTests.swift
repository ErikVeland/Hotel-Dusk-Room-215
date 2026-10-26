import XCTest
@testable import HotelDuskDuoKit

final class OriginalJigsawFamilyTests: XCTestCase {
    private func ready(_ variant: OriginalJigsawProcess.Variant) -> OriginalJigsawProcess {
        var puzzle = OriginalJigsawProcess(seed: 0x3DEAC027, variant: variant)
        for _ in 0..<5 { _ = puzzle.update() }
        return puzzle
    }

    func testFactoryVariantsUseTheOriginalIndependentMasks() throws {
        XCTAssertEqual(ready(.incomplete).placedCount, 15)
        XCTAssertEqual(ready(.full).placedCount, 0)
        XCTAssertEqual(ready(.reverse).placedCount, 20)
        XCTAssertEqual(ready(.restored).placedCount, 15)
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        let before = game.bytes
        game.setJigsawMask(0x12345, for: .incomplete)
        game.setJigsawMask(0x23456, for: .full)
        game.setJigsawMask(0x34567, for: .restored)
        game.setJigsawMask(0xFFFFF, for: .reverse)
        XCTAssertEqual(game.chapterOneJigsawMask, 0x12345)
        XCTAssertEqual(game.jigsawMask(for: .full), 0x23456)
        XCTAssertEqual(game.jigsawMask(for: .restored), 0x34567)
        XCTAssertEqual(game.jigsawMask(for: .reverse), 0)
        XCTAssertTrue(game.bytes.indices.filter { game.bytes[$0] != before[$0] }.allSatisfy { (0x14AC..<0x14B8).contains($0) })
        XCTAssertEqual(OriginalJigsawProcess(seed: 9, savedLooseMask: 0x648, variant: .full).looseMask, 0x648)
    }

    func testRestoredJigsawUsesTheOriginalReverseCompletionFlag() throws {
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.markPuzzleCompleted(processID: 84)
        XCTAssertEqual(game.value(for: .trickFlag(index: 16)), true)
        XCTAssertEqual(game.value(for: .trickFlag(index: 60)), false)
    }

    func testFullAssemblySeatsAllTwentyThroughDragAndRotation() {
        var puzzle = ready(.full)
        for _ in 0..<20 {
            let index = puzzle.pieces.indices.filter { !puzzle.isPlaced($0) }.max { puzzle.pieces[$0].depth < puzzle.pieces[$1].depth }!
            puzzle.beginTouch(world: puzzle.pieces[index].position)
            XCTAssertEqual(puzzle.selected, index)
            if puzzle.pieces[index].angle != 1.5 {
                _ = puzzle.endTouch()
                _ = puzzle.update(); _ = puzzle.update()
                for _ in 0..<4 where puzzle.pieces[index].angle != 1.5 {
                    _ = puzzle.rotate(increasing: true)
                    for _ in 0..<20 { _ = puzzle.update() }
                }
                puzzle.beginTouch(world: puzzle.pieces[index].position)
            }
            puzzle.moveTouch(world: OriginalJigsawProcess.target(index))
            XCTAssertEqual(puzzle.endTouch(), [.sound(archive: 26, entry: 0)])
            _ = puzzle.update(); _ = puzzle.update()
        }
        XCTAssertEqual(puzzle.placedCount, 20)
        for _ in 0..<500 where puzzle.result == nil { _ = puzzle.update(screen0FadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
        XCTAssertEqual(puzzle.looseMask, 0)
    }

    func testReverseRequiresANewFoldAndWaitsForTheOriginalFadeAndHold() {
        var puzzle = OriginalJigsawProcess(seed: 1, variant: .reverse)
        puzzle.receiveFold(isClosed: true)
        puzzle.receiveFold(isClosed: false)
        for _ in 0..<10 { _ = puzzle.update() }
        XCTAssertEqual(puzzle.stage, 1)
        XCTAssertFalse(puzzle.reverseVisible)
        puzzle.receiveFold(isClosed: false)
        XCTAssertEqual(puzzle.update(), [])
        puzzle.receiveFold(isClosed: true)
        puzzle.receiveFold(isClosed: false)
        XCTAssertEqual(puzzle.update(), [.fadeOut(updates: 5)])
        _ = puzzle.update()
        XCTAssertFalse(puzzle.reverseVisible)
        _ = puzzle.update(screen0FadeComplete: true)
        XCTAssertTrue(puzzle.reverseVisible)
        _ = puzzle.update()
        for _ in 0..<59 { XCTAssertEqual(puzzle.update(), []) }
        XCTAssertEqual(puzzle.update(), [.completionFade(updates: 60), .sound(archive: 1, entry: 0)])
        XCTAssertNil(puzzle.result)
        for _ in 0..<241 { _ = puzzle.update() }
        XCTAssertEqual(puzzle.phase, 4)
        XCTAssertEqual(puzzle.update(), [.fadeOut(updates: 60)])
        XCTAssertEqual(puzzle.update(screen0FadeComplete: true), [.completed(0)])
    }

    func testReverseQuitAndCancelledFoldsDoNotSolveThePuzzle() {
        for variant: OriginalJigsawProcess.Variant in [.full, .reverse, .restored] {
            var puzzle = ready(variant)
            puzzle.receiveFold(isClosed: true)
            puzzle.cancelPendingFold()
            puzzle.receiveFold(isClosed: false)
            for _ in 0..<30 { _ = puzzle.update() }
            XCTAssertFalse(puzzle.reverseVisible)
            puzzle.quit()
            _ = puzzle.update()
            XCTAssertEqual(puzzle.update(screen0FadeComplete: true), [.completed(1)])
        }
    }

    @MainActor func testOriginalChapterThreeProcessEntriesStartTheCorrectVariants() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        try game.beginChapter(2)
        game.applyTimeChange(2)
        game.setMap(35, previous: 39)
        let program = try catalog.loadProgram("EP3_R209")
        let graph = try program.blocks
        for (event, variant): (Int, OriginalJigsawProcess.Variant) in [(8, .full), (11, .reverse), (14, .restored)] {
            let group = try XCTUnwrap(graph.tables[1].first { group in
                let bytes = OriginalBytes(group.raw)
                let start = Int(try bytes.u32(4)) / 20
                let count = Int(try bytes.u32(8))
                return (start..<(start + count)).contains(event)
            })
            let block = try OriginalBytes(group.raw).u16(0)
            let selection = OriginalEventSelectionContext(sceneID: 0xFFFE, blockID: block, modeID: 15,
                eventID: UInt16(event), nowTime: game.nowTime, mapID: game.mapID)
            let runner = try OriginalEventRunner(program: program, game: game, selection: selection)
            let audio = AudioController(); audio.isMuted = true
            let play = OriginalPlaySession(runner: runner, audio: audio, catalog: catalog)
            defer { play.stop() }
            XCTAssertEqual(play.runner.phase, .process(id: variant.rawValue))
            XCTAssertEqual(play.jigsaw?.variant, variant)
        }
    }
}
