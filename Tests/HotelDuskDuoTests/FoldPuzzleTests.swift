import XCTest
import SwiftUI
@testable import HotelDuskDuoKit

@MainActor
final class FoldPuzzleTests: XCTestCase {
    func testOriginalAnimationBufferSurvivesClosingAndFirstPartialOpening() throws {
        let session = GameSession()
        try session.openAnimationPreview("Hy_hanas_")
        for _ in 0..<10 { try session.advanceAnimationPreview() }
        let checkpoint = try XCTUnwrap(session.animationCheckpoint)
        session.hingeManager.receiveHardwareState(.closed, angleDegrees: 0)
        try session.advanceAnimationPreview()
        XCTAssertEqual(session.animationCheckpoint, checkpoint)
        session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 12)
        XCTAssertEqual(session.animationCheckpoint, checkpoint)
        try session.advanceAnimationPreview()
        XCTAssertEqual(session.animationCheckpoint?.frameIndex, 8)
        XCTAssertEqual(session.animationCheckpoint?.loopCount, 1)
    }
    func testPieceMustBeAlignedAndUprightBeforeItSeats() throws {
        let puzzle = JigsawPuzzleManager()
        let piece = try XCTUnwrap(puzzle.manifest.pieces.first)
        orientUpright(piece.id, in: puzzle)
        let distantCorner = CGPoint(x: piece.centre.x < puzzle.manifest.boardWidth / 2 ? puzzle.manifest.boardWidth : 0,
                                    y: piece.centre.y < puzzle.manifest.boardHeight / 2 ? puzzle.manifest.boardHeight : 0)
        puzzle.movePiece(piece.id, to: distantCorner)
        XCTAssertFalse(puzzle.releasePiece(piece.id))
        XCTAssertEqual(puzzle.placements[piece.id]?.isPlaced, false)

        puzzle.movePiece(piece.id, to: piece.centre)
        puzzle.rotatePiece(piece.id)
        XCTAssertFalse(puzzle.releasePiece(piece.id), "A matching centre cannot seat a rotated piece")
        puzzle.rotatePiece(piece.id, clockwise: false)
        puzzle.movePiece(piece.id, to: CGPoint(x: piece.centre.x + 2, y: piece.centre.y + 2))
        XCTAssertTrue(puzzle.releasePiece(piece.id))
        let seated = try XCTUnwrap(puzzle.placements[piece.id])
        XCTAssertTrue(seated.isPlaced)
        XCTAssertEqual(seated.centre, piece.centre)
        XCTAssertEqual(seated.quarterTurns, 0)

        puzzle.movePiece(piece.id, to: distantCorner)
        puzzle.rotatePiece(piece.id)
        XCTAssertEqual(puzzle.placements[piece.id], seated, "Seated pieces cannot be displaced")
        XCTAssertEqual(puzzle.phase, .assembling)
    }

    func testAllTwentyPiecesMustBePlacedBeforeTheJigsawCanTurnOver() {
        let puzzle = JigsawPuzzleManager()
        XCTAssertEqual(puzzle.manifest.pieces.count, 20)
        for piece in puzzle.manifest.pieces.dropLast() {
            place(piece, in: puzzle)
        }
        XCTAssertEqual(puzzle.phase, .assembling)
        puzzle.onDeviceFoldedShut()
        XCTAssertFalse(puzzle.onDeviceReopened())
        XCTAssertFalse(puzzle.hasRevealedReverse)
        if let last = puzzle.manifest.pieces.last { place(last, in: puzzle) }
        XCTAssertEqual(puzzle.phase, .assembled)
        XCTAssertFalse(puzzle.onDeviceReopened(), "Opening without a close cannot turn the puzzle over")
        puzzle.onDeviceFoldedShut()
        XCTAssertEqual(puzzle.phase, .folded)
        XCTAssertTrue(puzzle.onDeviceReopened())
        XCTAssertTrue(puzzle.hasRevealedReverse)
        XCTAssertFalse(puzzle.onDeviceReopened(), "The reverse is revealed only once")
    }

    func testAngleOnlyReopeningRevealsAtFirstOpenPosture() {
        let session = GameSession()
        assemble(session.jigsawPuzzleManager)
        session.isJigsawPuzzleOpen = true
        let hinge = session.hingeManager
        hinge.receiveHardwareAngle(0)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .folded)
        for angle in [3.0, 12, 15] {
            hinge.receiveHardwareAngle(angle)
            XCTAssertTrue(session.isBookClosed)
            XCTAssertEqual(session.jigsawPuzzleManager.phase, .folded)
        }
        hinge.receiveHardwareAngle(16)
        XCTAssertFalse(session.isBookClosed)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .reverseRevealed)
        XCTAssertLessThan(hinge.hingeAngleDegrees, 180)
    }

    func testHardwarePartialOpeningRevealsEvenWithCoarseZeroAngle() {
        let session = GameSession()
        assemble(session.jigsawPuzzleManager)
        session.isJigsawPuzzleOpen = true
        let hinge = session.hingeManager
        hinge.receiveHardwareState(.partiallyOpen, angleDegrees: 0)
        XCTAssertFalse(session.isBookClosed)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .assembled)
        hinge.receiveHardwareState(.closed, angleDegrees: .nan)
        XCTAssertTrue(session.isBookClosed)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .folded)
        hinge.receiveHardwareState(.partiallyOpen, angleDegrees: 0)
        XCTAssertFalse(session.isBookClosed)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .reverseRevealed)
        let placements = session.jigsawPuzzleManager.placements
        hinge.receiveHardwareState(.fullyOpen, angleDegrees: .nan)
        XCTAssertEqual(session.jigsawPuzzleManager.placements, placements)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .reverseRevealed)
    }

    func testInactiveAndIncompletePuzzlesDoNotReactToFolding() {
        let session = GameSession()
        session.isJigsawPuzzleOpen = true
        session.hingeManager.receiveHardwareState(.closed, angleDegrees: 0)
        session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 40)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .assembling)
        assemble(session.jigsawPuzzleManager)
        session.isJigsawPuzzleOpen = false
        session.hingeManager.receiveHardwareState(.closed, angleDegrees: 0)
        session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 40)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .assembled)
        XCTAssertFalse(session.jigsawPuzzleManager.hasRevealedReverse)
    }

    func testDismissingPendingFoldPreservesAssemblyButRequiresAnotherClose() {
        let session = GameSession()
        assemble(session.jigsawPuzzleManager)
        let placements = session.jigsawPuzzleManager.placements
        session.isJigsawPuzzleOpen = true
        session.hingeManager.receiveHardwareAngle(0)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .folded)
        session.isJigsawPuzzleOpen = false
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .assembled)
        XCTAssertEqual(session.jigsawPuzzleManager.placements, placements)
        session.isJigsawPuzzleOpen = true
        session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 25)
        XCTAssertFalse(session.jigsawPuzzleManager.hasRevealedReverse)
        session.hingeManager.receiveHardwareState(.closed, angleDegrees: 0)
        session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 25)
        XCTAssertTrue(session.jigsawPuzzleManager.hasRevealedReverse)
    }

    func testStartingClosedDoesNotCountAsClosingAnAssembledJigsaw() {
        let hinge = DuoHingeManager()
        hinge.receiveHardwareAngle(0)
        let puzzle = JigsawPuzzleManager()
        assemble(puzzle)
        let session = GameSession(hingeManager: hinge, jigsawPuzzleManager: puzzle)
        session.isJigsawPuzzleOpen = true
        hinge.receiveHardwareState(.partiallyOpen, angleDegrees: 10)
        XCTAssertEqual(puzzle.phase, .assembled)
        XCTAssertFalse(puzzle.hasRevealedReverse)
    }

    func testRepeatedFoldsKeepUnfinishedPiecesSourceDataAndNotebook() throws {
        for handedness in Handedness.allCases {
            let session = GameSession(hingeManager: DuoHingeManager(initialHandedness: handedness))
            try session.loadOriginalProgram("EP3_R209")
            session.addMemoNote("Keep this clue")
            session.memoDraft.text = "An unfinished thought"
            session.memoDraft.lines = [[CGPoint(x: 10, y: 20), CGPoint(x: 25, y: 35)]]
            session.memoDraft.currentLine = [CGPoint(x: 40, y: 50)]
            session.isMemoPadOpen = true
            let puzzle = session.jigsawPuzzleManager
            place(try XCTUnwrap(puzzle.manifest.pieces.first), in: puzzle)
            let dragged = try XCTUnwrap(puzzle.manifest.pieces.dropFirst().first)
            puzzle.movePiece(dragged.id, to: CGPoint(x: 92, y: 135))
            puzzle.rotatePiece(dragged.id)
            // Leave the selected piece between drag updates, without releasing it.
            let placements = puzzle.placements
            let selectedPiece = puzzle.selectedPieceID
            let sourceProgram = try XCTUnwrap(session.originalProgram)
            let notes = session.memoNotes
            let draft = session.memoDraft

            session.isJigsawPuzzleOpen = true
            for _ in 0..<3 {
                for angle in [0.0, 12, 40, 110, 180] { session.hingeManager.receiveHardwareAngle(angle) }
                _ = DuoBookContainerView(session: session)
                _ = MemoPadView(session: session)
                XCTAssertTrue(session.jigsawPuzzleManager === puzzle)
                XCTAssertEqual(puzzle.placements, placements)
                XCTAssertEqual(puzzle.selectedPieceID, selectedPiece)
                XCTAssertEqual(puzzle.phase, .assembling)
                XCTAssertEqual(session.originalProgram?.name, sourceProgram.name)
                XCTAssertEqual(session.originalProgram?.blockData, sourceProgram.blockData)
                XCTAssertEqual(session.originalProgram?.conditionData, sourceProgram.conditionData)
                XCTAssertEqual(session.memoNotes, notes)
                XCTAssertEqual(session.memoDraft.text, "An unfinished thought")
                XCTAssertEqual(draft.lines, [[CGPoint(x: 10, y: 20), CGPoint(x: 25, y: 35)]])
                XCTAssertEqual(draft.currentLine, [CGPoint(x: 40, y: 50)])
                XCTAssertTrue(session.isMemoPadOpen)
                XCTAssertTrue(session.isJigsawPuzzleOpen)
                XCTAssertEqual(session.hingeManager.handedness, handedness)
            }
        }
    }

    func testRevealedReverseSurvivesDismissalAndRepeatedFolding() {
        let session = GameSession()
        assemble(session.jigsawPuzzleManager)
        let placements = session.jigsawPuzzleManager.placements
        let notes = session.memoNotes
        session.isJigsawPuzzleOpen = true
        session.hingeManager.receiveHardwareState(.closed, angleDegrees: 0)
        session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 20)
        XCTAssertTrue(session.jigsawPuzzleManager.hasRevealedReverse)
        session.isJigsawPuzzleOpen = false
        session.isJigsawPuzzleOpen = true
        for _ in 0..<3 {
            session.hingeManager.receiveHardwareState(.closed, angleDegrees: 0)
            session.hingeManager.receiveHardwareState(.partiallyOpen, angleDegrees: 20)
            XCTAssertEqual(session.jigsawPuzzleManager.phase, .reverseRevealed)
            XCTAssertEqual(session.jigsawPuzzleManager.placements, placements)
            XCTAssertEqual(session.memoNotes, notes, "Folding must not add invented clue text")
        }
    }

    func testHardwareAndExplicitAnglesCancelDelayedSimulation() async throws {
        let hinge = DuoHingeManager()
        hinge.performFoldGesture()
        XCTAssertTrue(hinge.isSimulatingFold)
        hinge.receiveHardwareAngle(45)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertFalse(hinge.isSimulatingFold)
        XCTAssertEqual(hinge.hingeAngleDegrees, 45)
        hinge.performFoldGesture()
        XCTAssertEqual(hinge.hingeAngleDegrees, 45, "Simulation must not override a hardware hinge")

        let simulated = DuoHingeManager()
        simulated.performFoldGesture()
        simulated.setHingeAngle(90)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(simulated.hingeAngleDegrees, 90)
    }

    func testSimulatedFoldUsesSameJigsawSequence() async throws {
        let session = GameSession()
        assemble(session.jigsawPuzzleManager)
        session.isJigsawPuzzleOpen = true
        session.hingeManager.performFoldGesture()
        session.hingeManager.performFoldGesture()
        XCTAssertTrue(session.isBookClosed)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .folded)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertFalse(session.isBookClosed)
        XCTAssertEqual(session.jigsawPuzzleManager.phase, .reverseRevealed)
    }

    private func orientUpright(_ id: String, in puzzle: JigsawPuzzleManager) {
        for _ in 0..<4 {
            if puzzle.placements[id]?.quarterTurns == 0 { break }
            puzzle.rotatePiece(id)
        }
    }

    private func place(_ piece: JigsawManifest.Piece, in puzzle: JigsawPuzzleManager,
                       file: StaticString = #filePath, line: UInt = #line) {
        puzzle.movePiece(piece.id, to: piece.centre)
        orientUpright(piece.id, in: puzzle)
        XCTAssertTrue(puzzle.releasePiece(piece.id), "Could not place \(piece.id)", file: file, line: line)
    }

    private func assemble(_ puzzle: JigsawPuzzleManager, file: StaticString = #filePath, line: UInt = #line) {
        for piece in puzzle.manifest.pieces { place(piece, in: puzzle, file: file, line: line) }
        XCTAssertEqual(puzzle.phase, .assembled, file: file, line: line)
    }
}
