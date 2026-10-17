import XCTest
@testable import HotelDuskDuoKit

final class OriginalHangerCutsTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private let controller = 0x258850

    private func capture(_ name: String) throws -> OriginalBytes {
        let file = root.appendingPathComponent("extracted/reference/chapter-two-hanger-\(name)-ram.bin")
        guard FileManager.default.fileExists(atPath: file.path) else { throw XCTSkip("The original hanger capture is unavailable") }
        return OriginalBytes(try Data(contentsOf: file))
    }

    private func compare(_ cuts: OriginalHangerCuts, _ name: String) throws {
        let original = try capture(name)
        for index in 0..<2 {
            let offset = controller + 0x71C + index * 44
            XCTAssertEqual(original.bytes[offset + 36] != 0, index < cuts.cuts.count)
            guard index < cuts.cuts.count else { continue }
            let cut = cuts.cuts[index]
            XCTAssertEqual(cut.position.x, Int32(bitPattern: try original.u32(offset)), name)
            XCTAssertEqual(cut.position.y, Int32(bitPattern: try original.u32(offset + 4)), name)
            XCTAssertEqual(cut.region, Int(try original.u32(offset + 40)), name)
        }
        XCTAssertEqual(cuts.lastTouch.x, Int32(try original.u16(controller + 0x610)))
        XCTAssertEqual(cuts.lastTouch.y, Int32(try original.u16(controller + 0x612)))
    }

    func testInitialHitQuadsMatchOriginalController() throws {
        let original = try capture("use/puzzle")
        for (index, quad) in OriginalHangerCuts.hitQuads.enumerated() {
            for (corner, vertex) in [0, 1, 5, 4].enumerated() {
                let offset = controller + 0x2F8 + index * 72 + vertex * 12
                XCTAssertEqual(quad[corner].x, Int32(bitPattern: try original.u32(offset)))
                XCTAssertEqual(quad[corner].y, Int32(bitPattern: try original.u32(offset + 4)))
            }
        }
    }

    func testWideLowerCutsMatchOriginalAndProduceUsableWire() throws {
        var cuts = OriginalHangerCuts()
        XCTAssertNotNil(cuts.cut(at: .init(45, 148)))
        try compare(cuts, "cut/first_contact")
        XCTAssertFalse(cuts.producesUsableWire)
        XCTAssertNotNil(cuts.cut(at: .init(145, 148)))
        try compare(cuts, "cut/second_contact")
        XCTAssertTrue(cuts.producesUsableWire)
        XCTAssertNil(cuts.cut(at: .init(96, 148)))
    }

    func testRepeatedCutIsIgnoredAndShortWireFails() throws {
        var cuts = OriginalHangerCuts()
        cuts.cut(at: .init(45, 148))
        XCTAssertNil(cuts.cut(at: .init(45, 148)))
        try compare(cuts, "short/repeat")
        XCTAssertNil(cuts.cut(at: .init(61, 148)))
        XCTAssertNotNil(cuts.cut(at: .init(75, 148)))
        try compare(cuts, "short/second_contact")
        XCTAssertFalse(cuts.producesUsableWire)
    }

    func testOutsideTouchAndUpperCutMatchOriginal() throws {
        var cuts = OriginalHangerCuts()
        XCTAssertNil(cuts.cut(at: .init(96, 200)))
        try compare(cuts, "upper/miss")
        XCTAssertNotNil(cuts.cut(at: .init(45, 138)))
        try compare(cuts, "upper/first_contact")
        XCTAssertNotNil(cuts.cut(at: .init(145, 148)))
        XCTAssertFalse(cuts.producesUsableWire)
    }

    func testInvalidInputDoesNotChangeCutState() {
        var cuts = OriginalHangerCuts()
        for point in [SIMD2<Float>(.nan, 148), .init(45, .infinity), .init(-1, 148), .init(192, 148), .init(45, 256)] {
            XCTAssertNil(cuts.cut(at: point))
        }
        XCTAssertEqual(cuts, OriginalHangerCuts())
    }

    func testRightUpperCutMatchesOriginal() throws {
        var cuts = OriginalHangerCuts()
        XCTAssertNotNil(cuts.cut(at: .init(145, 138)))
        try compare(cuts, "upper-right/first_contact")
        XCTAssertNotNil(cuts.cut(at: .init(45, 148)))
        try compare(cuts, "upper-right/second_contact")
        XCTAssertFalse(cuts.producesUsableWire)
    }

    func testMinimumUsableLengthIncludesItsBoundary() {
        for (right, usable) in [(120, true), (119, false)] {
            var cuts = OriginalHangerCuts()
            cuts.cut(at: .init(72, 148))
            cuts.cut(at: .init(Float(right), 148))
            XCTAssertEqual(cuts.producesUsableWire, usable)
        }
    }
}
