import XCTest
@testable import HotelDuskDuoKit

final class OriginalJigsawMechanicsTests: XCTestCase {
    private func state(x: Int32 = -819, angle: Float = 1.5) throws -> OriginalJigsawMechanics {
        var pieces: [OriginalJigsawMechanics.Piece] = []
        for i in 0..<20 {
            let position = OriginalJigsawMechanics.Position(x: i == 0 ? x : 0, y: -819)
            let rotation: Float = i == 0 ? angle : 0
            pieces.append(.init(position: position, depth: Int32(-4 * i), rotation: rotation, loose: 1))
        }
        return try .init(pieces: pieces, targets: Array(repeating: .init(x: 0, y: 0), count: 20))
    }

    func testSourceFixedPointSeatRadiusAndOrientation() throws {
        var inside = try state(x: 409)
        try inside.select(hitIndex: 0)
        XCTAssertTrue(inside.release())
        XCTAssertEqual(inside.pieces[0].position, .init(x: -819, y: -819))
        XCTAssertTrue(inside.isSeated(0))
        XCTAssertEqual(inside.pieces[0].loose, 0)
        XCTAssertNil(inside.selected)
        XCTAssertFalse(inside.isAssembled)
        var outside = try state(x: 410)
        try outside.select(hitIndex: 0)
        XCTAssertFalse(outside.release(), "The original strict radius boundary falls between these fixed coordinates")
        var wrongRotation = try state(angle: 0)
        try wrongRotation.select(hitIndex: 0)
        XCTAssertFalse(wrongRotation.release())
    }

    func testSourceRotationEasesAndWrapsWithoutLosingSelection() throws {
        var puzzle = try state(angle: 1.5)
        try puzzle.select(hitIndex: 1)
        puzzle.rotate(increasing: false)
        puzzle.updateRotation()
        XCTAssertEqual(puzzle.pieces[1].rotation, -0.15)
        XCTAssertFalse(puzzle.release(), "Placement is unavailable while the original rotation phase is active")
        for _ in 0..<32 { puzzle.updateRotation() }
        XCTAssertEqual(puzzle.pieces[1].rotation, 1.5)
        XCTAssertNil(puzzle.rotationTarget)
        XCTAssertEqual(puzzle.selected, 1)
    }

    func testSourceDragBoundsAndDepthOrderingSurviveCheckpoint() throws {
        var puzzle = try state(angle: 0)
        try puzzle.select(hitIndex: 2)
        XCTAssertEqual(puzzle.pieces[2].depth, 4)
        XCTAssertEqual(puzzle.pieces[0].depth, -4)
        XCTAssertEqual(puzzle.pieces[1].depth, -8)
        XCTAssertEqual(puzzle.pieces[3].depth, -12)
        puzzle.drag(to: .init(x: .max, y: .min))
        XCTAssertEqual(puzzle.pieces[2].position, .init(x: 4096, y: -12288))
        puzzle.rotate(increasing: true)
        puzzle.updateRotation()
        let restored = try JSONDecoder().decode(OriginalJigsawMechanics.self, from: JSONEncoder().encode(puzzle))
        XCTAssertEqual(restored, puzzle)
    }
}
