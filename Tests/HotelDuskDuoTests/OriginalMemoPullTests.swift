import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalMemoPullTests: XCTestCase {
    @MainActor func testRendererUsesOriginalCabinetAndPaper() throws {
        let renderer = try OriginalMemoPullRenderer()
        let image = try renderer.render(ready())
        XCTAssertEqual(image.width, 192)
        XCTAssertEqual(image.height, 256)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = root.appendingPathComponent("extracted/reference/chapter-two-memo-pull-ready/page9-bottom.ppm")
        guard FileManager.default.fileExists(atPath: source.path) else { throw XCTSkip("The original memo image is unavailable") }
        let capture = try Data(contentsOf: source), header = Data("P6\n256 192\n255\n".utf8)
        XCTAssertTrue(capture.starts(with: header))
        let original = Array(capture.dropFirst(header.count))
        let rgba = try XCTUnwrap(image.dataProvider?.data) as Data
        for point in [SIMD2(30, 30), .init(100, 50), .init(140, 100), .init(90, 180), .init(20, 210)] {
            for channel in 0..<3 {
                /**
                 * The shared model renderer does not reproduce DS colour modulation or rasterisation exactly.
                 */
                let native = Int(rgba[point.y * image.bytesPerRow + point.x * 4 + channel] >> 3)
                let reference = Int(original[(point.x * 256 + 255 - point.y) * 3 + channel] >> 3)
                XCTAssertLessThanOrEqual(abs(native - reference), 3, "Page \(point)")
            }
        }
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let url = URL(fileURLWithPath: directory).appendingPathComponent("memo-pull.png")
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }

    func testSmallSidewaysMovementsMatchOriginalController() throws {
        var puzzle = OriginalMemoPullProcess()
        puzzle.update()
        puzzle.update()
        try compare(puzzle, capture: "chapter-two-memo-pull-ready/page9")
        for _ in 0..<2 { update(&puzzle, page: SIMD2(106, 162)) }
        try compare(puzzle, capture: "chapter-two-memo-pull-wiggle/held")
        for index in 0...12 {
            /**
             * The original pauses its controller after the threshold update to start the shared completion presentation.
             */
            for _ in 0..<(index == 12 ? 1 : 2) { update(&puzzle, page: SIMD2(index % 2 == 0 ? 102 : 110, 162)) }
            try compare(puzzle, capture: "chapter-two-memo-pull-wiggle/wiggle\(index)")
        }
        XCTAssertEqual(puzzle.phase, 2)
        XCTAssertEqual(puzzle.returnValue, 0)
    }

    func testReleaseAndMissPreserveProgress() {
        var puzzle = ready()
        let hit = OriginalMemoPullProjection.touch(page: SIMD2(106, 162), paper: puzzle.position)
        puzzle.update(touch: hit)
        puzzle.update(touch: hit)
        XCTAssertTrue(puzzle.holding)
        let pull = puzzle.pull
        puzzle.update()
        XCTAssertFalse(puzzle.holding)
        XCTAssertEqual(puzzle.pull, pull)
        update(&puzzle, page: SIMD2(10, 10))
        XCTAssertFalse(puzzle.holding)
        XCTAssertEqual(puzzle.pull, pull)
        XCTAssertNil(OriginalMemoPullProjection.touch(page: SIMD2(.nan, 0), paper: puzzle.position))
        XCTAssertNil(OriginalMemoPullProjection.touch(page: SIMD2(192, 0), paper: puzzle.position))
    }

    func testLargeDragLosesThePaperAtTheOriginalPosition() throws {
        var puzzle = ready()
        for _ in 0..<2 { update(&puzzle, page: SIMD2(106, 162)) }
        for _ in 0..<10 { update(&puzzle, page: SIMD2(145, 195)) }
        try compare(puzzle, capture: "chapter-two-memo-pull-drag/drag0")
        XCTAssertFalse(puzzle.holding)
    }

    func testTearMotionAndExitDelayMatchOriginal() throws {
        var puzzle = ready()
        for _ in 0..<2 { update(&puzzle, page: SIMD2(106, 162)) }
        for index in 0...12 { update(&puzzle, page: SIMD2(index % 2 == 0 ? 102 : 110, 162)) }
        XCTAssertEqual(puzzle.update(), [.sound(archive: 2, entry: 29)])
        XCTAssertEqual(puzzle.update(), [.torn, .sound(archive: 0, entry: 6)])
        XCTAssertEqual(puzzle.position, SIMD3(4, 2048, -82))
        XCTAssertEqual(puzzle.angle, 2.344695568084717)
        XCTAssertEqual(puzzle.tearSpeed, 0.054999999701976776)
        for _ in 0..<120 { puzzle.update() }
        XCTAssertEqual(puzzle.phase, 2)
        puzzle.update()
        XCTAssertEqual(puzzle.phase, 3)
        puzzle.update()
        XCTAssertEqual(puzzle.update(fadeComplete: true), [.completed(0)])
    }

    func testOriginalStoryReturns() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func state(_ name: String) throws -> OriginalGameState {
            let path = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
            guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original memo story capture is unavailable") }
            return try OriginalGameState(snapshot: Data(contentsOf: path).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        for (result, path) in [(Int16(0), "chapter-two-memo-torn-return/returned"),
                               (Int16(1), "chapter-two-memo-partial-quit/finished"),
                               (Int16(2), "chapter-two-memo-quit/finished")] {
            var runner = try OriginalEventRunner(program: catalog.loadProgram("EP2_R115"), game: state("chapter-two-memo-inspect/closeup"))
            runner.lookInCloseup(area: 2, subarea: 2, event: 121)
            for _ in 0..<30 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: break
                }
            }
            XCTAssertEqual(runner.phase, .process(id: 27))
            runner.finishMemoPull(returnValue: result)
            if result != 0 {
                for _ in 0..<30 {
                    switch runner.phase {
                    case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                    case .waiting: runner.advanceWait()
                    default: break
                    }
                }
            }
            let expected = try state(path).bytes
            XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], path)
        }
    }

    func testQuitReportsUntouchedAndPartialPull() {
        for moved in [false, true] {
            var puzzle = ready()
            if moved {
                update(&puzzle, page: SIMD2(106, 162))
                update(&puzzle, page: SIMD2(106, 162))
            }
            puzzle.quit()
            XCTAssertEqual(puzzle.update(), [.hideCaption, .fadeOut(60)])
            XCTAssertNil(puzzle.result)
            XCTAssertEqual(puzzle.update(fadeComplete: true), [.completed(moved ? 1 : 2)])
            XCTAssertEqual(puzzle.update(), [])
        }
    }

    private func ready() -> OriginalMemoPullProcess {
        var puzzle = OriginalMemoPullProcess()
        puzzle.update()
        puzzle.update()
        return puzzle
    }

    private func update(_ puzzle: inout OriginalMemoPullProcess, page: SIMD2<Float>) {
        puzzle.update(touch: OriginalMemoPullProjection.touch(page: page, paper: puzzle.position))
    }

    private func compare(_ puzzle: OriginalMemoPullProcess, capture: String,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("extracted/reference/\(capture)-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original memo capture is unavailable") }
        let data = OriginalBytes(try Data(contentsOf: path)), base = 0x258710
        XCTAssertEqual(puzzle.phase, Int(try data.u16(base + 0x2A8)), capture, file: file, line: line)
        XCTAssertEqual(puzzle.stage, Int(try data.u16(base + 0x2AA)), capture, file: file, line: line)
        XCTAssertEqual(puzzle.holding, try data.range(base + 0x2ED, 1).first! != 0, capture, file: file, line: line)
        for axis in 0..<3 {
            XCTAssertEqual(puzzle.position[axis], Int32(bitPattern: try data.u32(base + 0x450 + axis * 4)), capture, file: file, line: line)
            XCTAssertEqual(puzzle.grabOffset[axis], Int32(bitPattern: try data.u32(base + 0x45C + axis * 4)), capture, file: file, line: line)
        }
        XCTAssertEqual(puzzle.angle, Float(bitPattern: try data.u32(base + 0x470)), accuracy: 0.000001, capture, file: file, line: line)
        XCTAssertEqual(puzzle.grabAngle, Float(bitPattern: try data.u32(base + 0x474)), capture, file: file, line: line)
        XCTAssertEqual(puzzle.pull, Float(bitPattern: try data.u32(base + 0x538)), capture, file: file, line: line)
        XCTAssertEqual(puzzle.soundStage, Int(try data.u32(base + 0x534)), capture, file: file, line: line)
    }
}
