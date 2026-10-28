import Foundation

/**
 * Advances overlay 11's ball and isolated ball-to-pin response for one source update.
 */
public struct OriginalBowlingBallPinSimulation: Equatable, Sendable {
    public private(set) var ballMotion: OriginalBowlingBallMotion
    public private(set) var pins: OriginalBowlingPinField
    public private(set) var resolvedContactsThisUpdate = [Int]()

    public init(ballState: OriginalBowlingBallMotion.State, pins: OriginalBowlingPinField = .init()) {
        ballMotion = OriginalBowlingBallMotion(state: ballState)
        self.pins = pins
    }

    /**
     * Runs ten ball substeps, resolves ball contacts, advances pins, and applies the outer speed rule.
     */
    public mutating func advanceOneUpdate() {
        var contacts = [Int]()
        for _ in 0..<OriginalBowlingBallMotion.substepCount {
            guard ballMotion.advanceOneSubstep() else { break }
            // Overlay 11 calls 0220308c from each ball substep.
            var velocity = ballMotion.state.velocityFixed20_12
            contacts += pins.resolveBallContacts(
                at: ballMotion.state.positionFixed20_12,
                ballVelocityFixed20_12: &velocity)
            ballMotion.setVelocityFixed20_12(velocity)
        }
        pins.resolvePinContacts()
        pins.advanceMotion()
        pins.resolveLaneBoundary()
        pins.resolvePinPositionalContacts()

        resolvedContactsThisUpdate = contacts
        ballMotion.applySourceFrameVelocityResponse()
    }
}
