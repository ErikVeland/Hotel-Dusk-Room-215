import Foundation

/**
 * Sequences the two players' bowling throws and the recovered early-finish check.
 */
public struct OriginalBowlingMatchProcess: Equatable, Sendable {
    public static let resultAnimationFrames = 221
    public static let resultPresentationFrames = 60

    public enum Phase: Equatable, Sendable {
        case ready
        case dragging
        case rolling
        case betweenThrows
        case showingResult
        case presentingResult
        case completed
    }

    public static let initialBallPositionFixed20_12 = SIMD3<Int32>(0, 1_556, 10_240)

    public private(set) var results = OriginalBowlingResult()
    public private(set) var turn: OriginalBowlingTurnProcess
    public private(set) var phase = Phase.ready
    public private(set) var returnValue: Int16?
    public private(set) var presentationFramesRemaining = 0
    private var commentaryRequests: [Int16] = []

    public var throwIndex: Int? { results.nextThrow }
    public var currentScore: Int32? { turn.score }
    public var nextCommentaryRequest: Int16? { commentaryRequests.first }

    public init() {
        self.init(results: OriginalBowlingResult())
    }

    init(results: OriginalBowlingResult) {
        self.results = results
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
        if phase == .showingResult {
            presentationFramesRemaining = max(0, presentationFramesRemaining - 1)
            if presentationFramesRemaining == 0 {
                beginResultPresentation()
            }
            return
        }
        if phase == .presentingResult {
            presentationFramesRemaining = max(0, presentationFramesRemaining - 1)
            if presentationFramesRemaining == 0 {
                returnValue = 2
                phase = .completed
            }
            return
        }
        guard phase == .rolling else { return }
        turn.advanceOneUpdate()
        guard turn.phase == .complete, let score = turn.score else { return }
        guard let slot = results.record(score) else { return }
        commentaryRequests.append(Self.throwCommentaryRequest(player: slot.player, score: score))
        if slot.player == 0 {
            commentaryRequests.append(4)
        } else if let status = results.roundStatuses[slot.round] {
            commentaryRequests.append(Self.roundCommentaryRequest(round: slot.round, status: status))
        }
        if results.shouldFinish {
            presentationFramesRemaining = Self.resultAnimationFrames
            phase = .showingResult
        } else if results.nextThrow == nil {
            beginResultPresentation()
        } else {
            phase = .betweenThrows
        }
    }

    /**
     * Holds the final scene action for the recovered 60-frame callback.
     */
    private mutating func beginResultPresentation() {
        presentationFramesRemaining = Self.resultPresentationFrames
        phase = .presentingResult
    }

    /**
     * Starts the next alternating throw after the session completes its result presentation.
     */
    @discardableResult
    public mutating func beginNextThrow() -> Bool {
        guard phase == .betweenThrows, commentaryRequests.isEmpty else { return false }
        turn = OriginalBowlingTurnProcess(ballPositionFixed20_12: Self.initialBallPositionFixed20_12)
        phase = .ready
        return true
    }

    /**
     * Marks one recovered System dialogue response complete.
     */
    @discardableResult
    public mutating func finishCommentaryResponse() -> Bool {
        guard !commentaryRequests.isEmpty else { return false }
        commentaryRequests.removeFirst()
        return true
    }

    private static func throwCommentaryRequest(player: Int, score: Int32) -> Int16 {
        switch (player, score < 5) {
        case (0, true): return 2
        case (0, false): return 3
        case (1, true): return 5
        default: return 6
        }
    }

    private static func roundCommentaryRequest(round: Int, status: Int16) -> Int16 {
        Int16(6 + round * 3) + status
    }
}
