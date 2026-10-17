import XCTest
@testable import HotelDuskDuoKit

final class OriginalThickWireProcessTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testSuitcaseApproachFromDoor() throws {
        var map = try OriginalMapExploration.bundled(mapID: 31, previousMapID: 39)
        for (point, count) in [(SIMD2<Float>(96, 210), 6), (.init(170, 128), 20), (.init(170, 128), 98), (.init(96, 210), 54)] {
            for _ in 0..<count { map.update(heldPageTouch: point) }
        }
        XCTAssertEqual(map.nearbySearchArea, 3, "\(map.position), facing \(map.facing)")
    }

    private func capture(_ path: String) throws -> OriginalBytes {
        let url = root.appendingPathComponent("extracted/reference/chapter-two-thick-wire-\(path)-ram.bin")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("The original thick-wire capture is unavailable") }
        return OriginalBytes(try Data(contentsOf: url))
    }

    private func replay(_ name: String, puzzle: inout OriginalThinWireProcess,
                        checkpoint: (String, OriginalThinWireProcess) throws -> Void = { _, _ in }) throws {
        let input = try String(contentsOf: root.appendingPathComponent("tools/reference/chapter-two-thick-wire-\(name).txt"), encoding: .utf8)
        var touch: SIMD2<Float>?, sampled: SIMD2<Float>?
        for line in input.split(separator: "\n") {
            let fields = line.split(separator: " ")
            if fields.first == "touch", let x = Float(fields[1]), let y = Float(fields[2]) { touch = SIMD2(y, 255 - x) }
            else if fields.first == "release" { touch = nil }
            else if fields.first == "frames", let count = Int(fields[1]) {
                for _ in 0..<count {
                    puzzle.update(pageTouch: sampled, fadeComplete: true)
                    sampled = touch
                }
            } else if fields.first == "capture" { try checkpoint(String(fields[1]), puzzle) }
        }
    }

    private func inserted() throws -> OriginalThinWireProcess {
        var puzzle = OriginalThinWireProcess(variant: .thick)
        puzzle.update()
        puzzle.update()
        try replay("insert", puzzle: &puzzle)
        XCTAssertEqual(puzzle.phase, 3)
        XCTAssertEqual(puzzle.stage, 1)
        XCTAssertEqual(puzzle.wire, SIMD3(-655, 393, 7373))
        XCTAssertEqual(puzzle.eye, SIMD3(-655, 393, 8602))
        return puzzle
    }

    func testOriginalInsertionAndLatchedPins() throws {
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
        var untouched = OriginalThinWireProcess(variant: .thick)
        untouched.update()
        untouched.quit()
        untouched.update()
        untouched.update(fadeComplete: true)
        XCTAssertEqual(untouched.result, 2)
        var inserted = try inserted()
        inserted.quit()
        inserted.update()
        inserted.update(fadeComplete: true)
        XCTAssertEqual(inserted.result, 1)
    }

    func testOriginalLockTurnAndOpeningCounters() throws {
        var puzzle = try inserted()
        var completedPins: OriginalThinWireProcess?
        try replay("pins", puzzle: &puzzle) { name, state in
            if name == "pin2" { completedPins = state }
        }
        puzzle = try XCTUnwrap(completedPins)
        for name in ["turn_start", "turn_mid", "camera_start", "camera_mid", "lid_start", "lid10", "lid20", "lid30", "lid40", "lid_done"] {
            let original = try capture("opening/\(name)"), base = 0x21F9C0
            let phase = Int(try original.u16(base + 0x2A8)), stage = Int(try original.u16(base + 0x2AA))
            let counter = phase == 3 ? Int(try original.u16(base + 0x2AE)) : Int(Float(bitPattern: try original.u32(base + 0xB08)))
            for _ in 0..<400 where puzzle.phase != phase || puzzle.stage != stage || puzzle.frameCounter != counter {
                puzzle.update(fadeComplete: true)
            }
            XCTAssertEqual(puzzle.phase, phase, name)
            XCTAssertEqual(puzzle.stage, stage, name)
            XCTAssertEqual(puzzle.frameCounter, counter, name)
            XCTAssertEqual(puzzle.lockRotation, Float(bitPattern: try original.u32(base + 0xFA0)), name)
            XCTAssertEqual(puzzle.lidRotation, Float(bitPattern: try original.u32(base + 0x980)), name)
            for axis in 0..<3 {
                XCTAssertEqual(puzzle.eye[axis], Int32(bitPattern: try original.u32(base + 0x2B0 + axis * 4)), "\(name) eye \(axis)")
                XCTAssertEqual(puzzle.target[axis], Int32(bitPattern: try original.u32(base + 0x2BC + axis * 4)), "\(name) target \(axis)")
            }
        }
    }

    func testOriginalStoryReturns() throws {
        func state(_ path: String) throws -> OriginalGameState {
            let bytes = try capture(path)
            return try OriginalGameState(snapshot: Data(bytes.range(0x11018C, OriginalGameState.byteCount)))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        for (result, path) in [(Int16(0), "opening"), (Int16(1), "quit-inserted"), (Int16(2), "quit-untouched")] {
            var runner = try OriginalEventRunner(program: catalog.loadProgram("EP2_R205"), game: state("approach/inspect"))
            runner.useItemInSearchView(16, area: 3, subarea: 4)
            runner = try XCTUnwrap(runner.searchFallback(catalog: catalog))
            for _ in 0..<100 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: break
                }
            }
            XCTAssertEqual(runner.phase, .process(id: 33))
            runner.finishThinWire(returnValue: result)
            for _ in 0..<200 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: break
                }
            }
            XCTAssertEqual(runner.phase, result == 0 ? .process(id: 35) : .exploration(mapID: 31))
            let expected = try state("\(path)/returned").bytes
            XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], path)
        }
    }
}
