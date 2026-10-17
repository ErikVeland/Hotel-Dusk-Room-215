import XCTest
@testable import HotelDuskDuoKit

final class OriginalSuitcaseContentsTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private let controller = 0x221A40

    private func capture(_ name: String) throws -> OriginalBytes {
        let url = root.appendingPathComponent("extracted/reference/chapter-two-suitcase-\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("The original suitcase contents capture is unavailable") }
        return OriginalBytes(try Data(contentsOf: url))
    }

    private func game(_ name: String = "open/lower") throws -> OriginalGameState {
        let source = try capture(name)
        return try OriginalGameState(snapshot: Data(source.range(0x11018C, OriginalGameState.byteCount)))
    }

    private func contents() throws -> OriginalSuitcaseContents {
        let library = try OriginalBitmapLibrary.bundled()
        let masks = try OriginalSuitcaseContents.lowerObjects.map { object in
            let texture = try OriginalTexture(data: library.loadLinear(path: "trick/searchbag/\(object.texture).bin").decodedPayload)
            XCTAssertEqual(texture.mode, 1)
            return texture.originalPixelData
        }
        return try OriginalSuitcaseContents(lowerHitMasks: masks)
    }

    func testInitialPositionsMatchBothOriginalCompartments() throws {
        let contents = try contents()
        for (compartment, name, offset) in [(OriginalSuitcaseContents.Compartment.upper, "upper/upper", 0x484),
                                            (.lower, "open/lower", 0x4BC)] {
            let original = try capture(name)
            for (index, position) in contents.positions(in: compartment).enumerated() {
                for axis in 0..<2 {
                    XCTAssertEqual(position[axis], Float(bitPattern: try original.u32(controller + offset + index * 8 + axis * 4)))
                }
            }
        }
    }

    func testPencilDragAndCashSelectionMatchOriginalInput() throws {
        var contents = try contents()
        let state = try game()
        let input = try String(contentsOf: root.appendingPathComponent("tools/reference/chapter-two-suitcase-cash.txt"), encoding: .utf8)
        var touch: SIMD2<Float>?, sampled: SIMD2<Float>?, wasDown = false
        var action: OriginalSuitcaseContents.Selection?
        for line in input.split(separator: "\n") {
            let fields = line.split(separator: " ")
            if fields.first == "touch", let x = Float(fields[1]), let y = Float(fields[2]) { touch = SIMD2(y, 255 - x) }
            else if fields.first == "release" { touch = nil }
            else if fields.first == "frames", let count = Int(fields[1]) {
                for _ in 0..<count {
                    if let heldPoint = sampled {
                        /**
                         * Held status is delayed one frame. Coordinates change during an existing hold.
                         */
                        let point = touch ?? heldPoint
                        if !wasDown { action = try contents.beginTouch(page: point, in: .lower, game: state) }
                        else { contents.drag(page: point, in: .lower) }
                    } else if wasDown { contents.endDrag() }
                    wasDown = sampled != nil
                    sampled = touch
                }
            } else if fields.first == "capture" {
                let name = String(fields[1])
                if name == "cash_notice" {
                    XCTAssertEqual(action, .take(item: 23, responses: [20]))
                    break
                }
                let original = try capture("cash/\(name)")
                XCTAssertEqual(contents.selected, Int(try original.u16(controller + 0x524)), name)
                let previous = Int16(bitPattern: try original.u16(controller + 0x526))
                XCTAssertEqual(contents.previousSelected, previous == -1 ? nil : Int(previous), name)
                for (index, position) in contents.lowerPositions.enumerated() {
                    for axis in 0..<2 {
                        XCTAssertEqual(position[axis], Float(bitPattern: try original.u32(controller + 0x4BC + index * 8 + axis * 4)), name)
                    }
                }
            }
        }
    }

    func testMasksAndUpperSelectionPriority() throws {
        var contents = try contents()
        let state = try game()
        XCTAssertEqual(try contents.hit(page: .init(20, 235), in: .lower, game: state), 5)
        XCTAssertNil(try contents.hit(page: .init(2, 192), in: .lower, game: state))
        XCTAssertEqual(try contents.beginTouch(page: .init(30, 100), in: .upper, game: state), .drag(index: 0))
        contents.endDrag()
        XCTAssertEqual(try contents.beginTouch(page: .init(30, 100), in: .upper, game: state), .describe(response: 5))
        XCTAssertEqual(try contents.hit(page: .init(80, 155), in: .upper, game: state), 0)
        for y in 167...183 { XCTAssertNil(try contents.hit(page: .init(80, Float(y)), in: .upper, game: state)) }
        XCTAssertNil(try contents.hit(page: .init(.nan, 100), in: .lower, game: state))
    }

    func testDragClampAndSelectionReset() throws {
        var contents = try contents()
        let state = try game()
        XCTAssertEqual(try contents.beginTouch(page: .init(40, 232), in: .lower, game: state), .drag(index: 5))
        contents.drag(page: .zero, in: .upper)
        XCTAssertEqual(contents.lowerPositions[5], SIMD2(1, 216))
        for _ in 0..<100 { contents.drag(page: .init(191, 255), in: .lower) }
        XCTAssertEqual(contents.lowerPositions[5], SIMD2(112, 224))
        for _ in 0..<100 { contents.drag(page: .zero, in: .lower) }
        XCTAssertEqual(contents.lowerPositions[5], .zero)
        contents.clearSelection()
        XCTAssertNil(contents.selected)
        XCTAssertFalse(contents.dragging)
        XCTAssertEqual(contents.grabOffset, .zero)
    }

    func testVisibilityUsesOriginalFlagsAndInventory() throws {
        let contents = try contents()
        var state = try game()
        XCTAssertEqual(try contents.visibleIndices(in: .lower, game: state), [0, 1, 2, 3, 5, 7, 8])
        XCTAssertEqual(try contents.visibleIndices(in: .upper, game: state), [0, 1, 2, 4, 5])
        for flag: UInt16 in [40, 44, 46, 47, 51] { try state.apply(.setFlag32(index: flag)) }
        try state.apply(.removeInventory(id: 49))
        XCTAssertEqual(try contents.visibleIndices(in: .lower, game: state), Array(0...10))
        XCTAssertEqual(try contents.visibleIndices(in: .upper, game: state), Array(0...5))
        for item: UInt16 in [13, 14, 18, 23, 28, 44, 45, 49] { try state.apply(.addInventory(id: item)) }
        XCTAssertEqual(try contents.visibleIndices(in: .lower, game: state), [0, 1, 2, 7, 8])
        XCTAssertEqual(try contents.visibleIndices(in: .upper, game: state), [0, 1, 2, 4])
    }

    func testCashAwardAndSharedResponseMatchOriginalGameState() throws {
        let catalog = try OriginalScriptCatalog.bundled()
        var state = try game()
        try state.apply(.addInventory(id: 23))
        let parent = try OriginalEventRunner(program: catalog.loadProgram("EP2_R205"), game: state)
        var response = try parent.processHint(catalog: catalog, pairA: 12, pairB: 20)
        for _ in 0..<200 {
            switch response.phase {
            case .dialogue, .itemNotice: response.acknowledgeDialogue()
            case .waiting: response.advanceWait()
            default: break
            }
        }
        XCTAssertEqual(response.phase, .exploration(mapID: 31))
        let expected = try game("cash/cash_advance2")
        XCTAssertEqual(response.game.bytes.indices.filter { response.game.bytes[$0] != expected.bytes[$0] }, [])
    }
}
