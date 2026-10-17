import XCTest
@testable import HotelDuskDuoKit

final class OriginalThinWireProcessTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func capture(_ name: String) throws -> OriginalBytes {
        let url = root.appendingPathComponent("extracted/reference/room215-thin-wire-\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("The original thin-wire capture is not available") }
        return OriginalBytes(try Data(contentsOf: url))
    }

    private func replay(_ name: String, puzzle: inout OriginalThinWireProcess,
                        checkpoint: (String, OriginalThinWireProcess) throws -> Void = { _, _ in }) throws {
        let commands = try String(contentsOf: root.appendingPathComponent("tools/reference/room215-thin-wire-\(name).txt"), encoding: .utf8)
        var touch: SIMD2<Float>?
        var sampledTouch: SIMD2<Float>?
        for line in commands.split(separator: "\n") {
            let fields = line.split(separator: " ")
            if fields.first == "touch", let x = Float(fields[1]), let y = Float(fields[2]) { touch = SIMD2(y, 255 - x) }
            else if fields.first == "release" { touch = nil }
            else if fields.first == "frames", let count = Int(fields[1]) {
                // The reference frontend changes input before the DS samples it for the next update.
                for _ in 0..<count {
                    puzzle.update(pageTouch: sampledTouch, fadeComplete: true)
                    sampledTouch = touch
                }
            } else if fields.first == "capture" { try checkpoint(String(fields[1]), puzzle) }
        }
    }

    private func inserted() throws -> OriginalThinWireProcess {
        var puzzle = OriginalThinWireProcess()
        puzzle.update()
        puzzle.update()
        try replay("insert", puzzle: &puzzle)
        XCTAssertEqual(puzzle.phase, 3)
        XCTAssertEqual(puzzle.stage, 1)
        XCTAssertEqual(puzzle.wire, SIMD3(-655, 393, 7373))
        XCTAssertEqual(puzzle.eye, SIMD3(-655, 393, 8602))
        XCTAssertEqual(puzzle.returnValue, 1)
        return puzzle
    }

    func testOriginalInsertionAndPinSequence() throws {
        var puzzle = try inserted()
        try replay("pins", puzzle: &puzzle) { name, state in
            guard name != "finished" else { return }
            let original = try capture("pins/\(name)"), base = 0x21F9C0
            XCTAssertEqual(state.phase, Int(try original.u16(base + 0x2A8)), name)
            XCTAssertEqual(state.stage, Int(try original.u16(base + 0x2AA)), name)
            for axis in 0..<2 {
                XCTAssertEqual(state.cursor[axis], Int32(bitPattern: try original.u32(base + 0x800 + axis * 4)), "\(name) cursor \(axis)")
            }
            for index in 0..<3 {
                let offset = base + 0xE9C + index * 52
                for axis in 0..<2 {
                    XCTAssertEqual(state.pins[index].position[axis], Int32(bitPattern: try original.u32(offset + axis * 4)), "\(name) pin \(index) axis \(axis)")
                }
                XCTAssertEqual(state.pins[index].depth, Int(try original.u32(offset + 44)), "\(name) pin \(index)")
                XCTAssertEqual(state.pins[index].reached, try original.range(offset + 49, 1).first != 0, "\(name) pin \(index)")
            }
        }
        XCTAssertEqual(puzzle.result, 0)
        XCTAssertTrue(puzzle.pins.allSatisfy(\.reached))
    }

    func testQuitBeforeAndAfterInsertion() throws {
        var untouched = OriginalThinWireProcess()
        untouched.update()
        untouched.quit()
        untouched.update()
        XCTAssertNil(untouched.result)
        untouched.update(fadeComplete: true)
        XCTAssertEqual(untouched.result, 2)
        var puzzle = try inserted()
        puzzle.quit()
        puzzle.update()
        puzzle.update(fadeComplete: true)
        XCTAssertEqual(puzzle.result, 1)
    }

    func testCompletedAndQuitAttemptsMatchOriginalStoryState() throws {
        func state(_ path: String) throws -> OriginalGameState {
            let bytes = try capture(path)
            return try OriginalGameState(snapshot: Data(bytes.range(0x11018C, OriginalGameState.byteCount)))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        for (result, path) in [(Int16(0), "aftermath"), (Int16(1), "quit-inserted"), (Int16(2), "quit-untouched")] {
            var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R205"), game: state("search/inspect"))
            XCTAssertEqual(runner.phase, .exploration(mapID: 31), "entry")
            runner.useItemInSearchView(9, area: 3, subarea: 4)
            let parent = runner
            runner = try XCTUnwrap(runner.searchFallback(catalog: catalog))
            for _ in 0..<100 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: break
                }
            }
            XCTAssertEqual(runner.phase, .process(id: 29))
            runner.finishThinWire(returnValue: result)
            for _ in 0..<200 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: break
                }
            }
            XCTAssertEqual(runner.phase, .exploration(mapID: 31))
            var resumed = parent
            resumed.resumeSearch(after: runner)
            XCTAssertEqual(resumed.game.bytes, runner.game.bytes)
            let original = try state("\(path)/step10").bytes
            XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != original[$0] }, [], path)
        }
    }

    func testInvalidTouchesDoNotMoveTheWire() {
        var puzzle = OriginalThinWireProcess()
        puzzle.update()
        puzzle.update()
        for point in [SIMD2<Float>(.nan, 2), SIMD2(200, 128), SIMD2(10, 10)] {
            for _ in 0..<10 { puzzle.update(pageTouch: point) }
        }
        XCTAssertFalse(puzzle.holding)
        XCTAssertEqual(puzzle.wire, SIMD3(0, 393, 12288))
        XCTAssertEqual(puzzle.returnValue, 2)
    }
}
