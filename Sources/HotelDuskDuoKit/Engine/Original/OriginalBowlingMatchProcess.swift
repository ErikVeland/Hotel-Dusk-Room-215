import Foundation

/**
 * Sequences the two players' bowling throws and the recovered early-finish check.
 */
public struct OriginalBowlingMatchProcess: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case ready
        case dragging
        case rolling
        case betweenThrows
        case completed
        case unresolvedOutcome
    }

    public static let initialBallPositionFixed20_12 = SIMD3<Int32>(0, 1_556, 10_240)

    public private(set) var results = OriginalBowlingResult()
    public private(set) var turn: OriginalBowlingTurnProcess
    public private(set) var phase = Phase.ready
    public private(set) var returnValue: Int16?

    public var throwIndex: Int? { results.nextThrow }
    public var currentScore: Int32? { turn.score }

    public init() {
        turn = OriginalBowlingTurnProcess(ballPositionFixed20_12: Self.initialBallPositionFixed20_12)
    }

    /**
     * Begins a throw after the session confirms the visible ball was selected.
     */
    @discardableResult
    public mutating func beginDrag(at lanePointFixed20_12: SIMD3<Int32>, ballWasHit: Bool) -> Bool {
        guard phase == .ready, turn.beginDrag(at: lanePointFixed20_12, ballWasHit: ballWasHit) else {
            return false
        }
        phase = .dragging
        return true
    }

    /**
     * Applies one touch update to the active throw.
     */
    public mutating func updateDrag(to lanePointFixed20_12: SIMD3<Int32>) {
        guard phase == .dragging else { return }
        turn.updateDrag(to: lanePointFixed20_12)
        if turn.phase == .rolling { phase = .rolling }
    }

    /**
     * Releases the ball and starts a valid source roll.
     */
    @discardableResult
    public mutating func endDrag() -> Bool {
        guard phase == .dragging else { return false }
        let started = turn.endDrag()
        phase = started ? .rolling : .ready
        return started
    }

    /**
     * Advances a roll and records its pin count once the ball and pins stop.
     */
    public mutating func advanceOneUpdate() {
        guard phase == .rolling else { return }
        turn.advanceOneUpdate()
        guard turn.phase == .complete, let score = turn.score else { return }
        _ = results.record(score)
        if results.shouldFinish {
            returnValue = 2
            phase = .completed
        } else if results.nextThrow == nil {
            phase = .unresolvedOutcome
        } else {
            phase = .betweenThrows
        }
    }

    /**
     * Starts the next alternating throw after the session completes its result presentation.
     */
    @discardableResult
    public mutating func beginNextThrow() -> Bool {
        guard phase == .betweenThrows else { return false }
        turn = OriginalBowlingTurnProcess(ballPositionFixed20_12: Self.initialBallPositionFixed20_12)
        phase = .ready
        return true
    }
}
