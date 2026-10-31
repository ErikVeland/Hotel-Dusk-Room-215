import XCTest
@testable import HotelDuskDuoKit

final class OriginalCoinEdgeProcessTests: XCTestCase {
    func testSourceTableRowsAndInitialEdgeMasks() {
        let expected: [(OriginalCoinEdgeProcess.Variant, Int, Int, Int, Int, Int, Int, Int)] = [
            (.squareTwoByThree, 2, 3, 6, 4, 6, 2, 0),
            (.squareThreeByThree, 3, 3, 2, 3, 6, 4, 0),
            (.triangleFourPreset, 3, 3, 1, 8, 4, 3, 1),
            (.triangleSixPreset, 3, 3, -2, 9, 4, 3, 1)
        ]
        for row in expected {
            let process = OriginalCoinEdgeProcess(variant: row.0)
            XCTAssertEqual(process.rows, row.1)
            XCTAssertEqual(process.columns, row.2)
            XCTAssertEqual(process.xOffset, row.3)
            XCTAssertEqual(process.yOffset, row.4)
            XCTAssertEqual(process.drawValue, row.5)
            XCTAssertEqual(process.targetCount, row.6)
            XCTAssertEqual(process.ruleMode, row.7)
        }

        XCTAssertEqual(OriginalCoinEdgeProcess(variant: .squareTwoByThree).edgeStates.count, 17)
        XCTAssertEqual(OriginalCoinEdgeProcess(variant: .squareThreeByThree).edgeStates.count, 24)

        let firstTriangle = OriginalCoinEdgeProcess(variant: .triangleFourPreset)
        XCTAssertEqual(firstTriangle.edgeStates.count, 18)
        XCTAssertEqual(firstTriangle.edgeStates.values.filter { $0 == .absent }.count, 4)
        XCTAssertEqual(firstTriangle.edgeStates.values.filter { $0 == .available }.count, 14)
        XCTAssertEqual(OriginalCoinEdgeProcess(variant: .triangleSixPreset).edgeStates.values
            .filter { $0 == .absent }.count, 6)
    }

    func testSelectionFliesOneEdgeAtATimeThenRemovesIt() {
        var square = OriginalCoinEdgeProcess(variant: .squareTwoByThree)
        let squareEdge = edge(.horizontal, row: 0, column: 0)
        XCTAssertTrue(square.select(squareEdge))
        XCTAssertEqual(square.edgeStates[squareEdge], .selected)
        XCTAssertEqual(square.selectedCount, 1)
        XCTAssertEqual(square.inFlightEdge, squareEdge)
        XCTAssertFalse(square.canCheckResult)
        XCTAssertFalse(square.select(edge(.horizontal, row: 0, column: 1)))
        square.finishSelection()
        XCTAssertEqual(square.edgeStates[squareEdge], .absent)
        XCTAssertNil(square.inFlightEdge)
        for column in 1..<6 {
            let edge = self.edge(.horizontal, row: column / 3, column: column % 3)
            XCTAssertTrue(square.select(edge))
            square.finishSelection()
        }
        XCTAssertEqual(square.selectedCount, 6)
        XCTAssertTrue(square.canCheckResult)
        XCTAssertTrue(square.select(edge(.horizontal, row: 2, column: 0)), "Input selection has no target-count cap")
        square.finishSelection()
        XCTAssertEqual(square.selectedCount, 7)

        var triangle = OriginalCoinEdgeProcess(variant: .triangleFourPreset)
        let unavailableEdge = edge(.triangleA, row: 2, column: 0)
        XCTAssertEqual(triangle.edgeStates[unavailableEdge], .absent)
        XCTAssertFalse(triangle.select(unavailableEdge))
        let availableEdge = edge(.triangleA, row: 0, column: 0)
        XCTAssertTrue(triangle.select(availableEdge))
        XCTAssertEqual(triangle.edgeStates[availableEdge], .selected)
        XCTAssertFalse(triangle.select(availableEdge), "Triangle input selects only state 1")
        XCTAssertEqual(triangle.selectedCount, 1)
        triangle.finishSelection()
        XCTAssertEqual(triangle.edgeStates[availableEdge], .absent)
    }

    func testPagePointHitTestingUsesRecoveredSquareAndTriangleGeometry() {
        var square = OriginalCoinEdgeProcess(variant: .squareTwoByThree)
        let horizontal = edge(.horizontal, row: 0, column: 0)
        XCTAssertEqual(square.edge(atPagePoint: .init(x: 68, y: 68)), horizontal)
        XCTAssertEqual(square.select(atPagePoint: .init(x: 68, y: 68)), horizontal)
        square.finishSelection()
        XCTAssertNil(square.edge(atPagePoint: .init(x: 10, y: 10)))

        var triangle = OriginalCoinEdgeProcess(variant: .triangleFourPreset)
        let triangleEdge = edge(.triangleA, row: 0, column: 0)
        XCTAssertEqual(triangle.edge(atPagePoint: .init(x: 36, y: 144)), triangleEdge)
        XCTAssertEqual(triangle.select(atPagePoint: .init(x: 36, y: 144)), triangleEdge)
        triangle.finishSelection()
    }

    func testSquareBoardPredicateCountsAllCompletedSizesAndRejectsUncoveredLines() {
        let twoSquares = squareEdges([(0, 0, 1), (1, 2, 1)])
        let first = process(.squareTwoByThree, selected: twoSquares)
        XCTAssertTrue(first.isCorrect)

        let fourSquares = squareEdges([(0, 0, 1), (0, 2, 1), (2, 0, 1), (2, 2, 1)])
        let second = process(.squareThreeByThree, selected: fourSquares)
        XCTAssertTrue(second.isCorrect)

        var squareOverrides = first.edgeStates
        squareOverrides[edge(.horizontal, row: 2, column: 1)] = .available
        let withUncoveredLine = OriginalCoinEdgeProcess(variant: .squareTwoByThree,
            edgeStateOverrides: squareOverrides, selectedCount: first.selectedCount)
        XCTAssertFalse(withUncoveredLine.isCorrect)
    }

    func testRecoveredLineRemovalSequencesSolveAllFourVariants() {
        let squareTwoByThree = solve(.squareTwoByThree, removing: [
            edge(.horizontal, row: 0, column: 0), edge(.horizontal, row: 1, column: 1),
            edge(.horizontal, row: 1, column: 2), edge(.vertical, row: 0, column: 0),
            edge(.vertical, row: 0, column: 2), edge(.vertical, row: 1, column: 2)
        ])
        XCTAssertTrue(squareTwoByThree.isCorrect)

        let squareThreeByThree = solve(.squareThreeByThree, removing: [
            edge(.horizontal, row: 0, column: 0), edge(.horizontal, row: 1, column: 2),
            edge(.horizontal, row: 2, column: 0), edge(.vertical, row: 0, column: 0),
            edge(.vertical, row: 0, column: 2), edge(.vertical, row: 2, column: 1)
        ])
        XCTAssertTrue(squareThreeByThree.isCorrect)

        let triangleFourPreset = solve(.triangleFourPreset, removing: [
            edge(.triangleA, row: 0, column: 0), edge(.triangleA, row: 2, column: 1),
            edge(.triangleB, row: 1, column: 1), edge(.triangleC, row: 1, column: 0)
        ])
        XCTAssertTrue(triangleFourPreset.isCorrect)

        let triangleSixPreset = solve(.triangleSixPreset, removing: [
            edge(.triangleA, row: 0, column: 0), edge(.triangleA, row: 2, column: 1),
            edge(.triangleB, row: 1, column: 0), edge(.triangleC, row: 1, column: 0)
        ])
        XCTAssertTrue(triangleSixPreset.isCorrect)
    }

    func testTriangleBoardPredicateUsesRecoveredCellAndCompositeShapes() {
        let triangles = triangleEdges(cellIndices: [0, 3, 5])
        for variant in [OriginalCoinEdgeProcess.Variant.triangleFourPreset, .triangleSixPreset] {
            let process = process(variant, selected: triangles)
            XCTAssertTrue(process.isCorrect)
        }

        let withUncoveredEdgeBase = process(.triangleFourPreset, selected: triangles)
        let spare = edge(.triangleA, row: 1, column: 0)
        var triangleOverrides = withUncoveredEdgeBase.edgeStates
        triangleOverrides[spare] = .available
        let withUncoveredEdge = OriginalCoinEdgeProcess(variant: .triangleFourPreset,
            edgeStateOverrides: triangleOverrides, selectedCount: withUncoveredEdgeBase.selectedCount)
        XCTAssertFalse(withUncoveredEdge.isCorrect)
    }

    private func process(_ variant: OriginalCoinEdgeProcess.Variant,
                         selected: Set<OriginalCoinEdgeProcess.Edge>) -> OriginalCoinEdgeProcess {
        let baseline = OriginalCoinEdgeProcess(variant: variant)
        var overrides = Dictionary(uniqueKeysWithValues: baseline.edgeStates.keys.map {
            ($0, OriginalCoinEdgeProcess.EdgeState.absent)
        })
        for edge in selected { overrides[edge] = OriginalCoinEdgeProcess.EdgeState.available }
        return OriginalCoinEdgeProcess(variant: variant, edgeStateOverrides: overrides,
                                       selectedCount: baseline.drawValue)
    }

    private func solve(_ variant: OriginalCoinEdgeProcess.Variant,
                       removing edges: [OriginalCoinEdgeProcess.Edge]) -> OriginalCoinEdgeProcess {
        var process = OriginalCoinEdgeProcess(variant: variant)
        for edge in edges {
            XCTAssertTrue(process.select(edge))
            process.finishSelection()
        }
        XCTAssertEqual(process.selectedCount, process.drawValue)
        return process
    }

    private func squareEdges(_ squares: [(row: Int, column: Int, size: Int)]) -> Set<OriginalCoinEdgeProcess.Edge> {
        var edges = Set<OriginalCoinEdgeProcess.Edge>()
        for square in squares {
            for offset in 0..<square.size {
                edges.insert(edge(.horizontal, row: square.row, column: square.column + offset))
                edges.insert(edge(.horizontal, row: square.row + square.size, column: square.column + offset))
                edges.insert(edge(.vertical, row: square.row + offset, column: square.column))
                edges.insert(edge(.vertical, row: square.row + offset, column: square.column + square.size))
            }
        }
        return edges
    }

    private func triangleEdges(cellIndices: [Int]) -> Set<OriginalCoinEdgeProcess.Edge> {
        var edges = Set<OriginalCoinEdgeProcess.Edge>()
        for index in cellIndices {
            let row = index == 0 ? 0 : index < 3 ? 1 : 2
            let column = index - row * (row + 1) / 2
            for orientation in [OriginalCoinEdgeProcess.Orientation.triangleA, .triangleB, .triangleC] {
                edges.insert(edge(orientation, row: row, column: column))
            }
        }
        return edges
    }

    private func edge(_ orientation: OriginalCoinEdgeProcess.Orientation, row: Int, column: Int)
        -> OriginalCoinEdgeProcess.Edge {
        .init(orientation: orientation, row: row, column: column)
    }
}
