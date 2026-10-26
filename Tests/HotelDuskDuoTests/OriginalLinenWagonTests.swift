import XCTest
@testable import HotelDuskDuoKit

final class OriginalLinenWagonTests: XCTestCase {
    private struct Source: Decodable {
        struct Snapshot: Decodable {
            struct Piece: Decodable { let x: Int; let y: Int; let z: Int; let rotation: Float; let direction: Int }
            let stage: Int; let phase: Int; let returnValue: Int16
            let gunAlpha: Int; let coverAlpha: Int; let pieces: [Piece]
        }
        struct Throw: Decodable { let pageTouch: [Int]; let held: Snapshot; let released: Snapshot; let removed: Snapshot }
        struct Linen: Decodable { let seed: UInt32; let initial: Snapshot; let `throws`: [Throw]; let cover: Snapshot; let revealed: Snapshot; let taken: Snapshot }
        struct Doll: Decodable { let stitches: Int; let seamMask: Int; let successStage: Int }
        let kind: String; let romSHA256: String; let linen: Linen; let doll: Doll
    }
    private func source() throws -> Source {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/ChapterFiveComponents/source-trace.json")
        return try JSONDecoder().decode(Source.self, from: Data(contentsOf: url))
    }
    private func ready(seed: UInt32 = 0) -> OriginalLinenWagonProcess {
        var puzzle = OriginalLinenWagonProcess(seed: seed)
        for _ in 0..<34 { _ = puzzle.update() }
        XCTAssertEqual(puzzle.stage, 1); XCTAssertEqual(puzzle.phase, 1)
        return puzzle
    }
    private func frames(_ count: Int, _ puzzle: inout OriginalLinenWagonProcess, touch: SIMD2<Int>? = nil) {
        for _ in 0..<count { _ = puzzle.update(pageTouch: touch, gunAnimationComplete: true, fadeComplete: true) }
    }
    private func removeSheets(_ puzzle: inout OriginalLinenWagonProcess, trace: Source.Linen) throws {
        for (index, action) in trace.throws.enumerated() {
            let point = SIMD2(action.pageTouch[0], action.pageTouch[1])
            frames(3, &puzzle, touch: point)
            XCTAssertEqual(puzzle.selected, index)
            frames(3, &puzzle, touch: .init(0, point.y))
            XCTAssertEqual(puzzle.pieces[index].x, action.held.pieces[index].x)
            XCTAssertEqual(puzzle.pieces[index].y, action.held.pieces[index].y)
            XCTAssertEqual(puzzle.pieces[index].z, action.held.pieces[index].z)
            frames(3, &puzzle)
            XCTAssertEqual(puzzle.pieces[index].throwDirection, action.released.pieces[index].direction)
            XCTAssertEqual(puzzle.returnValue, action.released.returnValue)
            frames(60, &puzzle)
            XCTAssertEqual(puzzle.pieces[index].throwDirection, action.removed.pieces[index].direction)
            XCTAssertEqual(puzzle.pieces[index].x, action.removed.pieces[index].x)
            XCTAssertEqual(puzzle.pieces[index].y, action.removed.pieces[index].y)
        }
    }

    func testOriginalFactoryInitialPositionsDepthAndRandomRotation() throws {
        let source = try source()
        XCTAssertEqual(source.kind, "modified-checkpoint-component-test")
        XCTAssertEqual(source.romSHA256.count, 64)
        let puzzle = ready(seed: source.linen.seed)
        for (piece, original) in zip(puzzle.pieces, source.linen.initial.pieces) {
            XCTAssertEqual(piece.x, original.x); XCTAssertEqual(piece.y, original.y)
            XCTAssertEqual(piece.z, original.z); XCTAssertEqual(piece.rotation, original.rotation)
        }
        XCTAssertEqual(puzzle.hit(pageTouch: .init(85, 130)), 0, "The foreground sheet wins an overlapping hit")
        XCTAssertNil(puzzle.hit(pageTouch: .init(190, 250)))
    }

    func testActualOriginalTouchTraceRemovesAllSixSheets() throws {
        let trace = try source().linen
        var puzzle = ready(seed: trace.seed)
        try removeSheets(&puzzle, trace: trace)
        XCTAssertTrue(puzzle.allSheetsRemoved)
        XCTAssertEqual(puzzle.phase, 2)
        XCTAssertEqual(puzzle.returnValue, 1)
        frames(3, &puzzle, touch: .init(96, 170)); frames(35, &puzzle)
        XCTAssertEqual(puzzle.coverAlpha, trace.cover.coverAlpha)
        frames(3, &puzzle, touch: .init(96, 110)); frames(100, &puzzle)
        XCTAssertEqual(puzzle.phase, trace.revealed.phase)
        XCTAssertEqual(puzzle.gunAlpha, trace.revealed.gunAlpha)
        frames(1, &puzzle, touch: .init(110, 120))
        XCTAssertEqual(puzzle.returnValue, trace.taken.returnValue)
        frames(200, &puzzle)
        XCTAssertEqual(puzzle.result, 0)
    }

    func testReleaseInsideCartAndQuitPreserveOriginalResultCodes() throws {
        var blank = ready()
        frames(3, &blank, touch: .init(80, 100)); frames(3, &blank)
        XCTAssertEqual(blank.pieces[0].throwDirection, 0)
        XCTAssertEqual(blank.returnValue, 2)
        blank.quit(); frames(3, &blank)
        XCTAssertEqual(blank.result, 2)
        let trace = try source().linen
        var changed = ready(seed: trace.seed)
        frames(3, &changed, touch: .init(80, 100)); frames(3, &changed, touch: .init(0, 100)); frames(3, &changed)
        changed.quit(); frames(3, &changed)
        XCTAssertEqual(changed.result, 1)
    }

    func testThrowRectangleKeepsOriginalInclusiveAndExclusiveEdges() {
        XCTAssertEqual(OriginalLinenWagonProcess.throwDirection(x: -2304, y: 2517), 0)
        XCTAssertEqual(OriginalLinenWagonProcess.throwDirection(x: -2305, y: 0), 4)
        XCTAssertEqual(OriginalLinenWagonProcess.throwDirection(x: 2644, y: 0), 0)
        XCTAssertEqual(OriginalLinenWagonProcess.throwDirection(x: 2645, y: 0), 6)
        XCTAssertEqual(OriginalLinenWagonProcess.throwDirection(x: 0, y: 2518), 8)
        XCTAssertEqual(OriginalLinenWagonProcess.throwDirection(x: 0, y: -3413), 2)
        XCTAssertEqual(OriginalLinenWagonProcess.throwDirection(x: -2305, y: 2518), 7)
        XCTAssertEqual(OriginalLinenWagonProcess.throwDirection(x: 2645, y: -3413), 3)
    }

    func testDollRecognitionMatchesIndependentOriginalProcess() throws {
        let original = try source().doll
        var puzzle = OriginalDollRepairProcess()
        for _ in 0..<100 { _ = puzzle.update() }
        for index in 0...10 {
            for _ in 0..<3 { _ = puzzle.update(pageTouch: .init(index % 2 == 0 ? 150 : 180, 130 + index * 7)) }
        }
        for _ in 0..<18 { _ = puzzle.update() }
        XCTAssertEqual(puzzle.stitches.count, original.stitches)
        XCTAssertEqual(Int(puzzle.seamMask), original.seamMask)
        XCTAssertEqual(puzzle.stage, original.successStage)
        for _ in 0..<240 { _ = puzzle.update(fadeComplete: true) }
        XCTAssertEqual(puzzle.result, 0)
    }
}
