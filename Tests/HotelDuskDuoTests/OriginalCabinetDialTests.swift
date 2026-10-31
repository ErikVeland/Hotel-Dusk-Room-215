import XCTest
import ImageIO
@testable import HotelDuskDuoKit

final class OriginalCabinetDialTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func compare(_ process: OriginalCabinetDialProcess, _ name: String,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        let path = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original cabinet dial capture is unavailable") }
        let ram = OriginalBytes(try Data(contentsOf: path)), base = 0x258710
        XCTAssertEqual(process.phase, Int(try ram.u16(base + 0x2AA)), name, file: file, line: line)
        XCTAssertEqual(process.stage, Int(try ram.u16(base + 0x2AC)), name, file: file, line: line)
        XCTAssertEqual(process.nextPhase, Int(Int16(bitPattern: try ram.u16(base + 0x2AE))), name, file: file, line: line)
        XCTAssertEqual(process.holding, ram.bytes[base + 0x2ED] != 0, name, file: file, line: line)
        XCTAssertEqual(process.selected, Int(try ram.u16(base + 0x2EE)), name, file: file, line: line)
        XCTAssertEqual(process.timer, Int(try ram.u32(base + 0x688)), name, file: file, line: line)
        XCTAssertEqual(process.drawerOpening, Float(bitPattern: try ram.u32(base + 0x684)), name, file: file, line: line)
        for index in 0..<3 {
            XCTAssertEqual(process.angles[index], Float(bitPattern: try ram.u32(base + 0x4FC + index * 44)), name, file: file, line: line)
            XCTAssertEqual(process.wheelY[index], Int32(bitPattern: try ram.u32(base + 0x56C + index * 44)), name, file: file, line: line)
            let offset = try SIMD3<Int32>((0..<3).map { Int32(bitPattern: try ram.u32(base + 0x574 + index * 44 + $0 * 4)) })
            XCTAssertEqual(process.grabOffsets[index], offset, name, file: file, line: line)
            XCTAssertEqual(process.target[index], Int(ram.bytes[base + 0x68C + index]), name, file: file, line: line)
        }
    }

    private func update(_ process: inout OriginalCabinetDialProcess, page: SIMD2<Float>? = nil, count: Int) {
        for _ in 0..<count {
            process.update(touch: page.flatMap { OriginalCabinetDialProjection.touch(page: $0, process: process) })
        }
    }

    func testOriginalWheelDragAndAlignment() throws {
        var process = OriginalCabinetDialProcess(randomValue: 100, retainedValue: 0)
        update(&process, count: 2)
        try compare(process, "chapter-two-cabinet-combination-entry/ready")
        update(&process, page: SIMD2(30, 130), count: 3)
        try compare(process, "chapter-two-cabinet-wheel-drag/held")
        for (index, y) in [140, 150, 160].enumerated() {
            update(&process, page: SIMD2(30, Float(y)), count: 3)
            try compare(process, "chapter-two-cabinet-wheel-drag/drag\(index)")
        }
        update(&process, count: 120)
        try compare(process, "chapter-two-cabinet-wheel-drag/released")
        XCTAssertEqual(process.digits, [9, 9, 9])
    }

    private func enteredCode() throws -> OriginalCabinetDialProcess {
        var process = OriginalCabinetDialProcess(randomValue: 100, retainedValue: 0)
        update(&process, count: 2)
        for (wheel, count, y) in [(0, 2, 220), (1, 3, 220), (2, 2, 40)] {
            for index in 0..<count {
                let x = Float([30, 94, 156][wheel])
                update(&process, page: SIMD2(x, 130), count: 3)
                update(&process, page: SIMD2(x, Float(y)), count: 3)
                try compare(process, "chapter-two-cabinet-unlock/drag\(wheel)_\(index)")
                update(&process, count: 90)
                if wheel != 2 || index != 1 {
                    try compare(process, "chapter-two-cabinet-unlock/wheel\(wheel)_\(index)")
                }
            }
        }
        XCTAssertEqual(process.digits, [1, 2, 7])
        XCTAssertEqual(process.returnValue, 0)
        return process
    }

    func testOriginalCodeEntry() throws {
        _ = try enteredCode()
    }
    func testOriginalSuccessAnimation() throws {
        var process = try enteredCode()
        XCTAssertEqual(process.timer, 84)
        update(&process, count: 37)
        XCTAssertEqual(process.phase, 3)
        process.update()
        update(&process, count: 65)
        process.update(fadeComplete: true)
        update(&process, count: 11)
        try compare(process, "chapter-two-cabinet-success-motion/frame130")
        for (updates, frame) in [(21,150), (9,160), (10,170), (40,210), (21,230), (40,270)] {
            update(&process, count: updates)
            try compare(process, "chapter-two-cabinet-success-motion/frame\(frame)")
        }
        update(&process, count: 22)
        XCTAssertEqual(process.result, 0)
    }

    func testOriginalStoryReturnsAndRetainedDigits() throws {
        func state(_ name: String) throws -> OriginalGameState {
            let path = root.appendingPathComponent("extracted/reference/\(name)-ram.bin")
            guard FileManager.default.fileExists(atPath: path.path) else { throw XCTSkip("The original cabinet return capture is unavailable") }
            return try OriginalGameState(snapshot: Data(contentsOf: path).subdata(in: 0x11018C..<(0x11018C + OriginalGameState.byteCount)))
        }
        let catalog = try OriginalScriptCatalog.bundled()
        for (result, retained, name) in [(Int16(0), UInt16(0), "chapter-two-cabinet-unlock"),
                                         (Int16(1), UInt16(800), "chapter-two-cabinet-partial-quit"),
                                         (Int16(2), UInt16(0), "chapter-two-cabinet-quit")] {
            var runner = try OriginalEventRunner(program: catalog.loadProgram("EP2_R115"), game: state("chapter-two-cabinet-keypad/ready"))
            runner.lookInCloseup(area: 2, subarea: 5, event: 117)
            for _ in 0..<30 {
                switch runner.phase {
                case .dialogue, .itemNotice: runner.acknowledgeDialogue()
                case .waiting: runner.advanceWait()
                default: break
                }
            }
            XCTAssertEqual(runner.phase, .process(id: 31))
            runner.finishCabinetDial(returnValue: result, retainedValue: retained)
            let expected = try state(name + "/returned").bytes
            XCTAssertEqual(runner.game.bytes.indices.filter { runner.game.bytes[$0] != expected[$0] }, [], name)
        }
        var reopened = OriginalCabinetDialProcess(randomValue: 100,
            retainedValue: try state("chapter-two-cabinet-partial-quit/returned").cabinetDialRetainedValue)
        XCTAssertEqual(reopened.digits, [1, 9, 9])
        update(&reopened, count: 2)
        try compare(reopened, "chapter-two-cabinet-reopen/ready")
    }

    func testQuitAndRetainedNumber() {
        var process = OriginalCabinetDialProcess(randomValue: 100, retainedValue: 0)
        update(&process, count: 2)
        process.quit()
        process.update()
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(2)])
        XCTAssertEqual(process.retainedValue, 0)
        process = OriginalCabinetDialProcess(randomValue: 100, retainedValue: 800)
        update(&process, count: 2)
        update(&process, page: SIMD2(30, 130), count: 2)
        process.quit()
        process.update()
        XCTAssertEqual(process.update(fadeComplete: true), [.completed(1)])
        XCTAssertEqual(process.retainedValue, 800)
    }

    @MainActor func testOriginalRenderer() throws {
        let renderer = try OriginalCabinetDialRenderer()
        var process = OriginalCabinetDialProcess(randomValue: 100, retainedValue: 0)
        update(&process, count: 2)
        let image = try renderer.render(process)
        XCTAssertEqual(image.width, 768)
        XCTAssertEqual(image.height, 1024)
        if let folder = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            let url = URL(fileURLWithPath: folder).appendingPathComponent("dial-entry.png")
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
            var opened = try enteredCode()
            for _ in 0..<300 where !opened.showsDrawer { opened.update(fadeComplete: true) }
            for _ in 0..<52 { opened.update() }
            let drawerImage = try renderer.render(opened)
            let drawerURL = URL(fileURLWithPath: folder).appendingPathComponent("dial-drawer.png")
            let drawerOutput = try XCTUnwrap(CGImageDestinationCreateWithURL(drawerURL as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(drawerOutput, drawerImage, nil)
            XCTAssertTrue(CGImageDestinationFinalize(drawerOutput))
            for name in ["dial", "dial_cbnt"] {
                let texture = try OriginalTexture(data: OriginalBitmapLibrary.bundled().loadLinear(path: "trick/dial/\(name).bin").decodedPayload)
                let asset = try XCTUnwrap(texture.makeCGImage())
                let path = URL(fileURLWithPath: folder).appendingPathComponent("source-\(name).png")
                let out = try XCTUnwrap(CGImageDestinationCreateWithURL(path as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(out, asset, nil)
                XCTAssertTrue(CGImageDestinationFinalize(out))
            }

        }
    }

}
