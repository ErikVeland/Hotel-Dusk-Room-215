import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalCrowbarTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private let base = 0x21F410

    private func capture(_ name: String) throws -> OriginalBytes {
        let path = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original crowbar capture is unavailable") }
        return OriginalBytes(try Data(contentsOf: path))
    }

    private func compare(_ process: OriginalCrowbarProcess, _ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let ram = try capture(name)
        func vector(_ offset: Int) throws -> SIMD3<Int32> {
            try SIMD3((0..<3).map { Int32(bitPattern: try ram.u32(base + offset + $0 * 4)) })
        }
        func float(_ offset: Int) throws -> Float { Float(bitPattern: try ram.u32(base + offset)) }
        XCTAssertEqual(process.phase, Int(try ram.u16(base + 0x2A8)), name, file: file, line: line)
        XCTAssertEqual(process.stage, Int(try ram.u16(base + 0x2AA)), name, file: file, line: line)
        XCTAssertEqual(process.position, try vector(0x4A4), name, file: file, line: line)
        XCTAssertEqual(process.handle, try vector(0x4D0), name, file: file, line: line)
        XCTAssertEqual(process.grabOffset, try vector(0x4DC), name, file: file, line: line)
        XCTAssertEqual(process.angle, try float(0x4C0), name, file: file, line: line)
        XCTAssertEqual(process.cabinetAngle, try float(0x498), name, file: file, line: line)
        XCTAssertEqual(process.dropSeverity, try float(0x300), name, file: file, line: line)
        XCTAssertEqual(process.soundTimer, Int(try ram.u16(base + 0x30A)), name, file: file, line: line)
        XCTAssertEqual(process.rumbleTimer, Int(try ram.u16(base + 0x30C)), name, file: file, line: line)
        XCTAssertEqual(process.markerVisible, ram.bytes[base + 0x72C] != 0, name, file: file, line: line)
        XCTAssertEqual(process.marker, SIMD2(Int(try ram.u16(base + 0x72E)), Int(try ram.u16(base + 0x730))), name, file: file, line: line)
        XCTAssertEqual(process.holding, ram.bytes[base + 0x305] != 0, name, file: file, line: line)
        XCTAssertEqual(process.lifting, ram.bytes[base + 0x306] != 0, name, file: file, line: line)
        XCTAssertEqual(process.moved, ram.bytes[base + 0x307] != 0, name, file: file, line: line)
        XCTAssertEqual(process.speed, try float(0x310), name, file: file, line: line)
        XCTAssertEqual(process.paperSpeed, try float(0x314), name, file: file, line: line)
        XCTAssertEqual(process.paperY, Int32(bitPattern: try ram.u32(base + 0x500)), name, file: file, line: line)
        XCTAssertEqual(process.timer, Int(try ram.u32(base + 0x318)), name, file: file, line: line)
        XCTAssertEqual(Float(process.animationFrame), try float(0x728), name, file: file, line: line)

    }

    private func update(_ process: inout OriginalCrowbarProcess, page: SIMD2<Float>?, count: Int) {
        for _ in 0..<count {
            let touch = page.flatMap { OriginalCrowbarProjection.touch(page: $0, process: process) }
            process.update(touch: touch)
        }
    }

    func testPlacementMatchesOriginal() throws {
        _ = try placedProcess()
    }

    private func placedProcess() throws -> OriginalCrowbarProcess {
        var process = OriginalCrowbarProcess()
        update(&process, page: nil, count: 2)
        try compare(process, "chapter-two-crowbar-entry/ready")
        update(&process, page: SIMD2(115, 93), count: 2)
        try compare(process, "chapter-two-crowbar-place/held")
        var previous = SIMD2<Float>(115, 93)
        for (i, point) in [SIMD2<Float>(112,105), .init(108,125), .init(103,145), .init(98,165),
                           .init(93,185), .init(88,205), .init(83,225)].enumerated() {
            update(&process, page: previous, count: 1)
            update(&process, page: point, count: 19)
            previous = point
            try compare(process, "chapter-two-crowbar-place/drag\(i)")
        }
        update(&process, page: nil, count: 120)
        try compare(process, "chapter-two-crowbar-place/placed")
        return process
    }

    private func liftedProcess(through last: Int) throws -> OriginalCrowbarProcess {
        var process = try placedProcess()
        update(&process, page: SIMD2(112, 88), count: 3)
        try compare(process, "chapter-two-crowbar-lift/held")
        var previous = SIMD2<Float>(112, 88)
        for (i, point) in [SIMD2<Float>(116,95), .init(120,102), .init(124,109), .init(128,116),
                           .init(132,123), .init(136,130), .init(140,137)].enumerated() where i <= last {
            update(&process, page: previous, count: 1)
            update(&process, page: point, count: i == 6 ? 1 : 2)
            previous = point
            try compare(process, "chapter-two-crowbar-lift/lift\(i)")
        }
        return process
    }

    func testLiftMatchesOriginal() throws {
        _ = try liftedProcess(through: 6)
    }
    func testDropMatchesOriginal() throws {
        var process = try liftedProcess(through: 3)
        for (updates, frame) in [(1, 3), (2, 5), (4, 8), (1, 10), (3, 12), (8, 20), (8, 28), (2, 30), (2, 32)] {
            update(&process, page: nil, count: updates)
            try compare(process, "chapter-two-crowbar-drop-motion/frame\(frame)")
        }
        XCTAssertEqual(process.returnValue, 3)
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(3)])
    }

    func testLowReleaseAllowsAnotherAttempt() throws {
        var process = try liftedProcess(through: 0)
        for (updates, frame) in [(1, 3), (3, 5), (3, 8), (1, 10), (10, 20), (6, 25), (5, 30)] {
            update(&process, page: nil, count: updates)
            try compare(process, "chapter-two-crowbar-low-drop/frame\(frame)")
        }
        XCTAssertEqual(process.phase, 1)
        XCTAssertEqual(process.stage, 3)
        XCTAssertNil(process.result)
    }

    func testSuccessAnimationMatchesOriginal() throws {
        var process = try liftedProcess(through: 6)
        for (updates, frame) in [(114, 123), (2, 125), (59, 185), (1, 186), (2, 187),
                                (20, 208), (23, 230), (107, 338), (2, 339), (4, 343)] {
            update(&process, page: nil, count: updates)
            try compare(process, "chapter-two-crowbar-success-motion/frame\(frame)")
        }
        XCTAssertEqual(process.returnValue, 0)
        update(&process, page: nil, count: 5)
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(0)])
    }

    func testQuitPreservesOriginalResultUntilRegrab() throws {
        for regrab in [false, true] {
            var process = OriginalCrowbarProcess()
            update(&process, page: nil, count: 2)
            if regrab {
                update(&process, page: SIMD2(115, 93), count: 2)
                update(&process, page: nil, count: 1)
                update(&process, page: SIMD2(115, 93), count: 1)
            }
            process.quit()
            update(&process, page: nil, count: 3)
            XCTAssertEqual(process.update(fadeComplete: true), [.completed(regrab ? 1 : 2)])
        }
        var placed = try placedProcess()
        placed.quit()
        update(&placed, page: nil, count: 3)
        XCTAssertEqual(placed.update(fadeComplete: true), [.completed(2)])
    }

    func testOriginalStoryReturns() throws {
        func state(_ name: String) throws -> OriginalGameState {
            let ram = try capture(name)
            return try OriginalGameState(snapshot: Data(ram.bytes[0x11018C..<(0x11018C + OriginalGameState.byteCount)]))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        for (result, path) in [(Int16(0), "chapter-two-crowbar-lift/returned"),
                               (Int16(1), "chapter-two-crowbar-regrab-quit/returned"),
                               (Int16(2), "chapter-two-crowbar-quit/returned"),
                               (Int16(3), "chapter-two-crowbar-drop/returned")] {
            var runner = try OriginalEventRunner(program: catalog.loadProgram("EP2_R115"), game: state("chapter-two-crowbar-closeup/torn"))
            runner.useItemInCloseup(10, event: 125)
            for _ in 0..<30 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: break
                }
            }
            XCTAssertEqual(runner.phase, .process(id: 30))
            runner.finishCrowbar(returnValue: result)
            let expected = try state(path).bytes
            XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], path)
        }
    }

    @MainActor func testRendererUsesOriginalAssets() throws {
        let renderer = try OriginalCrowbarRenderer(tornPaper: true)
        let states = [("entry", OriginalCrowbarProcess()), ("placed", try placedProcess()), ("lifted", try liftedProcess(through: 6))]
        for (name, state) in states {
            let image = try renderer.render(state)
            XCTAssertEqual(image.width, 192)
            XCTAssertEqual(image.height, 256)
            if let folder = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
                try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                let path = URL(fileURLWithPath: folder).appendingPathComponent("crowbar-\(name).png")
                let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(path as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                XCTAssertTrue(CGImageDestinationFinalize(destination))
            }
        }
    }

}

