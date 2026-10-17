import XCTest
@testable import HotelDuskDuoKit

final class OriginalHangerProcessTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func compare(_ process: OriginalHangerProcess, _ name: String) throws {
        let file = root.appendingPathComponent("extracted/reference/chapter-two-hanger-\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original hanger timing capture is unavailable") }
        let bytes = OriginalBytes(try Data(contentsOf: file)), base = 0x258850
        XCTAssertEqual(process.phase, Int(try bytes.u16(base + 0x2A8)), name)
        XCTAssertEqual(process.stage, Int(try bytes.u16(base + 0x2AA)), name)
        XCTAssertEqual(Float(process.animationFrame), Float(bitPattern: try bytes.u32(base + 0xAD4)), name)
        for axis in 0..<4 {
            XCTAssertEqual(process.cameraBounds[axis], Int32(bitPattern: try bytes.u32(base + 0x984 + axis * 4)), name)
        }
        XCTAssertEqual(process.pliersOpening, Float(bitPattern: try bytes.u32(base + 0x95C)), name)
        for axis in 0..<3 {
            XCTAssertEqual(process.pliersPosition[axis], Int32(bitPattern: try bytes.u32(base + 0x66C + axis * 4)), name)
        }
        XCTAssertEqual(process.pliersRotation, Float(bitPattern: try bytes.u32(base + 0x68C)), accuracy: 0.000001, name)
        for index in 0..<2 {
            XCTAssertEqual(process.severed.contains(index), bytes.bytes[base + 0x741 + index * 44] != 0, name)
        }
    }

    private func beginCut(_ point: SIMD2<Float>, process: inout OriginalHangerProcess) {
        process.update(pageTouch: point)
        process.update(pageTouch: point)
    }

    func testCutAnimationCheckpointsMatchOriginal() throws {
        var process = OriginalHangerProcess()
        XCTAssertEqual(process.update(), [.fadeIn(60)])
        beginCut(.init(45, 148), process: &process)
        /**
         * The DS can run zero or two controller updates in one captured video frame.
         * Match its animation counter, then compare the remaining controller state.
         */
        func checkpoint(_ name: String) throws {
            let file = root.appendingPathComponent("extracted/reference/chapter-two-hanger-\(name)-ram.bin")
            guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original hanger timing capture is unavailable") }
            let bytes = OriginalBytes(try Data(contentsOf: file)), base = 0x258850
            let phase = Int(try bytes.u16(base + 0x2A8)), stage = Int(try bytes.u16(base + 0x2AA))
            let frame = Float(bitPattern: try bytes.u32(base + 0xAD4))
            for _ in 0..<200 {
                if process.phase == phase && process.stage == stage && Float(process.animationFrame) == frame { break }
                process.update()
            }
            try compare(process, name)
        }
        try checkpoint("cut/first_contact")
        for kind in ["first", "second"] {
            for frame in [30, 60, 61, 62, 92, 93, 123, 124, 184, 185] {
                try checkpoint("timing-\(kind)/frame\(frame)")
            }
            if kind == "first" {
                XCTAssertTrue(process.canQuit)
                beginCut(.init(145, 148), process: &process)
                try compare(process, "cut/second_contact")
            }
        }
        for _ in 0..<200 { process.update(fadeComplete: true) }
        XCTAssertEqual(process.result, 0)
    }

    func testCameraAndCutDurationsUseOriginalUpdateCounts() {
        var process = OriginalHangerProcess()
        process.update()
        beginCut(.init(45, 148), process: &process)
        for _ in 0..<60 { process.update() }
        XCTAssertEqual(process.stage, 1)
        XCTAssertEqual(process.animationFrame, 60)
        process.update()
        XCTAssertEqual(process.stage, 2)
        process.update()
        XCTAssertEqual(process.stage, 3)
        for _ in 0..<30 { XCTAssertTrue(process.update().isEmpty) }
        XCTAssertEqual(process.update(), [.sound(32)])
        for _ in 0..<30 { process.update() }
        XCTAssertEqual(process.stage, 4)
        XCTAssertEqual(process.severed, [0])
        process.update()
        for _ in 0..<60 { process.update() }
        XCTAssertEqual(process.phase, 3)
        process.update()
        XCTAssertEqual(process.phase, 1)
    }

    func testPliersPlacementOnUpperWiresMatchesOriginal() throws {
        for (point, name) in [(SIMD2<Float>(45, 138), "upper"), (.init(145, 138), "upper-right")] {
            var process = OriginalHangerProcess()
            process.update()
            beginCut(point, process: &process)
            for _ in 0..<300 { process.update() }
            try compare(process, "\(name)/first_cut")
        }
    }

    func testSuccessAndFailureMatchOriginalStoryState() throws {
        func state(_ name: String) throws -> OriginalGameState {
            let file = root.appendingPathComponent("extracted/reference/chapter-two-hanger-\(name)-ram.bin")
            guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original hanger story capture is unavailable") }
            return try OriginalGameState(snapshot: Data(contentsOf: file).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        }
        func drain(_ runner: inout OriginalEventRunner) {
            for _ in 0..<200 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: return
                }
            }
        }
        let catalog = try OriginalScriptCatalog.bundled()
        for fromCloseup in [false, true] {
            for (result, name) in [(Int16(0), "cut"), (Int16(1), "short"), (Int16(1), "upper-right"),
                                   (Int16(1), "quit-cut"), (Int16(2), "quit-untouched")] {
                var parent = try OriginalEventRunner(program: catalog.loadProgram("EP2_R205"), game: state("inspect/hanger"))
                if fromCloseup { parent.useItemInCloseup(15, event: 259) }
                else { parent.useItemInSearchView(15, area: 4, subarea: 2) }
                var runner = try XCTUnwrap(parent.searchFallback(catalog: catalog))
                XCTAssertEqual(runner.eventIndex, 996)
                drain(&runner)
                XCTAssertEqual(runner.phase, .process(id: 32))
                runner.finishHanger(returnValue: result)
                drain(&runner)
                XCTAssertEqual(runner.phase, .exploration(mapID: 31))
                parent.resumeSearch(after: runner)
                let expected = try state("\(name)/returned")
                XCTAssertEqual(parent.game.bytes.indices.filter { parent.game.bytes[$0] != expected.bytes[$0] }, [], name)
            }
        }
    }

    func testQuitResultsAndFadeWait() {
        for touched in [false, true] {
            var process = OriginalHangerProcess()
            process.update()
            if touched {
                beginCut(.init(45, 148), process: &process)
                for _ in 0..<300 { process.update() }
            }
            process.quit()
            XCTAssertEqual(process.update(), [.fadeOut(60)])
            for _ in 0..<90 { process.update() }
            XCTAssertNil(process.result)
            process.update(fadeComplete: true)
            for _ in 0..<29 { process.update() }
            XCTAssertNil(process.result)
            XCTAssertEqual(process.update(), [.completed(touched ? 1 : 2)])
        }
    }

    func testFailedCutsReturnOneAndDoNotMarkCompletion() {
        for second in [SIMD2<Float>(75, 148), .init(145, 138)] {
            var process = OriginalHangerProcess()
            var effects = process.update()
            beginCut(.init(45, 148), process: &process)
            for _ in 0..<300 { effects += process.update() }
            beginCut(second, process: &process)
            for _ in 0..<600 { effects += process.update(fadeComplete: true) }
            XCTAssertEqual(process.result, 1)
            XCTAssertFalse(effects.contains(.markCompleted))
            XCTAssertEqual(effects.filter { $0 == .sound(32) }.count, 2)
        }
    }
}
