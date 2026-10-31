import Foundation

/// Overlay 29 edge-selection rules used by System processes 68 through 71.
public struct OriginalCoinEdgeProcess: Equatable, Sendable {
    public enum Variant: Int16, CaseIterable, Sendable {
        case squareTwoByThree = 68
        case squareThreeByThree = 69
        case triangleFourPreset = 70
        case triangleSixPreset = 71
    }

    public enum Orientation: UInt8, CaseIterable, Sendable {
        case horizontal
        case vertical
        case triangleA
        case triangleB
        case triangleC
    }

    public struct Edge: Hashable, Sendable {
        public let orientation: Orientation
        public let row: Int
        public let column: Int

        public init(orientation: Orientation, row: Int, column: Int) {
            self.orientation = orientation
            self.row = row
            self.column = column
        }
    }

    public struct PagePoint: Equatable, Sendable {
        public let x: Int
        public let y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public enum EdgeState: UInt8, Sendable {
        case absent = 0
        case available = 1
        case selected = 2
    }

    private struct Configuration: Equatable, Sendable {
        let rows: Int
        let columns: Int
        let xOffset: Int
        let yOffset: Int
        let drawValue: Int
        let targetCount: Int
        let ruleMode: Int
    }

    public let variant: Variant
    public let rows: Int
    public let columns: Int
    public let xOffset: Int
    public let yOffset: Int
    public let drawValue: Int
    public let targetCount: Int
    public let ruleMode: Int
    public private(set) var selectedCount = 0
    public private(set) var edgeStates: [Edge: EdgeState]
    public private(set) var inFlightEdge: Edge?
    public var canCheckResult: Bool { selectedCount >= drawValue && inFlightEdge == nil }

    private var isTriangleBoard: Bool { ruleMode != 0 }

    public init(variant: Variant) {
        let configuration: Configuration
        switch variant {
        case .squareTwoByThree: configuration = .init(rows: 2, columns: 3, xOffset: 6, yOffset: 4, drawValue: 6, targetCount: 2, ruleMode: 0)
        case .squareThreeByThree: configuration = .init(rows: 3, columns: 3, xOffset: 2, yOffset: 3, drawValue: 6, targetCount: 4, ruleMode: 0)
        case .triangleFourPreset: configuration = .init(rows: 3, columns: 3, xOffset: 1, yOffset: 8, drawValue: 4, targetCount: 3, ruleMode: 1)
        case .triangleSixPreset: configuration = .init(rows: 3, columns: 3, xOffset: -2, yOffset: 9, drawValue: 4, targetCount: 3, ruleMode: 1)
        }
        self.variant = variant
        rows = configuration.rows
        columns = configuration.columns
        xOffset = configuration.xOffset
        yOffset = configuration.yOffset
        drawValue = configuration.drawValue
        targetCount = configuration.targetCount
        ruleMode = configuration.ruleMode

        var states: [Edge: EdgeState] = [:]
        if configuration.ruleMode == 0 {
            for row in 0...configuration.rows {
                for column in 0..<configuration.columns {
                    states[.init(orientation: .horizontal, row: row, column: column)] = .available
                }
            }
            for row in 0..<configuration.rows {
                for column in 0...configuration.columns {
                    states[.init(orientation: .vertical, row: row, column: column)] = .available
                }
            }
        } else {
            for row in 0..<configuration.rows {
                for column in 0...row {
                    for orientation in [Orientation.triangleA, .triangleB, .triangleC] {
                        states[.init(orientation: orientation, row: row, column: column)] = .available
                    }
                }
            }
            let absent: [Edge]
            switch variant {
            case .triangleFourPreset:
                absent = [
                    .init(orientation: .triangleA, row: 2, column: 0),
                    .init(orientation: .triangleA, row: 2, column: 2),
                    .init(orientation: .triangleB, row: 2, column: 0),
                    .init(orientation: .triangleC, row: 2, column: 2)
                ]
            case .triangleSixPreset:
                absent = [
                    .init(orientation: .triangleA, row: 2, column: 0),
                    .init(orientation: .triangleA, row: 2, column: 2),
                    .init(orientation: .triangleB, row: 0, column: 0),
                    .init(orientation: .triangleB, row: 2, column: 0),
                    .init(orientation: .triangleC, row: 0, column: 0),
                    .init(orientation: .triangleC, row: 2, column: 2)
                ]
            default:
                absent = []
            }
            for edge in absent { states[edge] = .absent }
        }
        edgeStates = states
    }

    init(variant: Variant, edgeStateOverrides: [Edge: EdgeState], selectedCount: Int) {
        self.init(variant: variant)
        for (edge, state) in edgeStateOverrides where edgeStates[edge] != nil {
            edgeStates[edge] = state
        }
        self.selectedCount = selectedCount
    }

    /// Selects one available board edge. Overlay 29 records selection as state 2; it does not toggle it off.
    @discardableResult
    public mutating func select(_ edge: Edge) -> Bool {
        guard inFlightEdge == nil, let state = edgeStates[edge] else { return false }
        let selectable = isTriangleBoard ? state == .available : state != .absent
        guard selectable else { return false }
        edgeStates[edge] = .selected
        selectedCount += 1
        inFlightEdge = edge
        return true
    }

    /// Finishes the source fly-off, which clears the selected edge to state zero.
    public mutating func finishSelection() {
        guard let edge = inFlightEdge else { return }
        edgeStates[edge] = .absent
        inFlightEdge = nil
    }

    /// Reports success after the target-count gate and 021FEC04 board predicate both pass.
    public var isCorrect: Bool {
        canCheckResult && boardMatchesRule
    }

    /// Returns the first source-order edge hit by a page-coordinate point.
    public func edge(atPagePoint point: PagePoint) -> Edge? {
        if isTriangleBoard { return triangleEdge(atPagePoint: point) }
        for row in 0...rows {
            for column in 0..<columns {
                let edge = Edge(orientation: .horizontal, row: row, column: column)
                guard edgeStates[edge, default: .absent] != .absent else { continue }
                let x = (xOffset + column * 6 - 1)
                let y = yOffset + row * 6
                if point.x >= (x + 1) * 8 && point.x <= (x + 6) * 8 &&
                    point.y >= (y + 4) * 8 && point.y <= (y + 5) * 8 {
                    return edge
                }
            }
        }
        for row in 0..<rows {
            for column in 0...columns {
                let edge = Edge(orientation: .vertical, row: row, column: column)
                guard edgeStates[edge, default: .absent] != .absent else { continue }
                let x = xOffset + column * 6 - 1
                let y = yOffset + row * 6
                if point.x >= x * 8 && point.x <= (x + 1) * 8 &&
                    point.y >= (y + 5) * 8 && point.y <= (y + 10) * 8 {
                    return edge
                }
            }
        }
        return nil
    }

    /// Selects the first hit edge and records the source state transition.
    @discardableResult
    public mutating func select(atPagePoint point: PagePoint) -> Edge? {
        guard let edge = edge(atPagePoint: point), select(edge) else { return nil }
        return edge
    }

    private var boardMatchesRule: Bool {
        let shapes = isTriangleBoard ? triangleShapes : squareShapes
        var completedCount = 0
        var covered = Set<Edge>()
        for shape in shapes where shape.allSatisfy({ edgeStates[$0] == .available }) {
            completedCount += 1
            covered.formUnion(shape)
        }
        let unusedAvailable = edgeStates.contains { entry in
            entry.value == .available && !covered.contains(entry.key)
        }
        return completedCount == targetCount && !unusedAvailable
    }

    private var squareShapes: [Set<Edge>] {
        guard !isTriangleBoard else { return [] }
        var shapes: [Set<Edge>] = []
        for size in 1...min(rows, columns) {
            for row in 0...(rows - size) {
                for column in 0...(columns - size) {
                    var edges = Set<Edge>()
                    for step in 0..<size {
                        edges.insert(.init(orientation: .horizontal, row: row, column: column + step))
                        edges.insert(.init(orientation: .horizontal, row: row + size, column: column + step))
                        edges.insert(.init(orientation: .vertical, row: row + step, column: column))
                        edges.insert(.init(orientation: .vertical, row: row + step, column: column + size))
                    }
                    shapes.append(edges)
                }
            }
        }
        return shapes
    }

    private var triangleShapes: [Set<Edge>] {
        guard isTriangleBoard else { return [] }
        func edge(_ orientation: Orientation, _ index: Int) -> Edge {
            var row = 0
            var offset = index
            while offset > row {
                offset -= row + 1
                row += 1
            }
            return .init(orientation: orientation, row: row, column: offset)
        }
        func shape(_ ids: [Int]) -> Set<Edge> {
            Set(ids.map { index in
                let orientationIndex = index / 6
                let cellIndex = index % 6
                let orientation: Orientation = orientationIndex == 0 ? .triangleA : orientationIndex == 1 ? .triangleB : .triangleC
                return edge(orientation, cellIndex)
            })
        }

        var shapes = (0..<6).map { index in shape([index, 6 + index, 12 + index]) }
        for row in 0..<2 {
            for column in 0...row {
                let index = row * 2 + column
                let top = row + column
                shapes.append(shape([top, 6 + index + 2, 12 + index + 1]))
                shapes.append(shape([index + 1, index + 2, 6 + top, 6 + index + 1, 12 + top, 12 + index + 2]))
            }
        }
        return shapes
    }

    private func triangleEdge(atPagePoint point: PagePoint) -> Edge? {
        let masks: [(Orientation, Int, [(Int, Int)])] = [
            (.triangleA, 1, [(0, 0), (4, 0), (40, 4), (40, -4)]),
            (.triangleB, 0, [(0, 0), (21, 0), (21, -39), (0, -39)]),
            (.triangleC, 5, [(0, -8), (0, -39), (-14, -39), (-14, -8)])
        ]
        for row in 0..<rows {
            for column in 0...row {
                for (orientation, xAdjustment, mask) in masks {
                    let edge = Edge(orientation: orientation, row: row, column: column)
                    guard edgeStates[edge] == .available else { continue }
                    let relative = PagePoint(
                        x: point.x - (xOffset - row * 3 + column * 6 + xAdjustment) * 8,
                        y: point.y - 32 - (yOffset + (row + column + 1) * 6) * 8
                    )
                    if contains(relative, polygon: mask) { return edge }
                }
            }
        }
        return nil
    }

    private func contains(_ point: PagePoint, polygon: [(Int, Int)]) -> Bool {
        polygon.indices.allSatisfy { index in
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            let cross = (a.0 - point.x) * (b.1 - point.y) - (b.0 - point.x) * (a.1 - point.y)
            return cross <= 0
        }
    }
}
