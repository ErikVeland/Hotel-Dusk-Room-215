import Foundation

/// Process 24, overlay 32: the R102 counter bell. The factory 0x0200B334 case
/// 24 passes slot 32 to 0x0200B2D8, which the table at 0x020E92A4 maps to
/// overlay 32, constructor 0x021FCB40. Update is 0x021FD0A8, draw 0x021FD7B4.
/// Resources: `/data/trick/bell.wpf` members `bell01.bin` (the bell texture
/// and touch mask) and `bell02.bin` (the counter), from `bell.tbl`.
/// One update is one DS update. Offsets name the original object fields.
public struct OriginalBellProcess: Equatable, Codable, Sendable {
    public struct Touch: Equatable, Sendable {
        public let x: Int
        public let y: Int
        public init(x: Int, y: Int) { self.x = x; self.y = y }
    }
    public struct Input: Sendable {
        /// The touch manager's new-press flag (0x02009854), raw DS pixels.
        public var newTouch: Touch?
        public var leftHanded: Bool
        /// 0x02081550 on the fade manager at 0x0210BC08, screen 0.
        public var screen0FadeComplete: Bool
        public init(newTouch: Touch? = nil, leftHanded: Bool = false, screen0FadeComplete: Bool = false) {
            self.newTouch = newTouch; self.leftHanded = leftHanded
            self.screen0FadeComplete = screen0FadeComplete
        }
    }
    /// Arguments of 0x020812F0: fade manager, screen, layer mask, mode, target, duration.
    public struct Fade: Equatable, Sendable {
        public let screen: Int
        public let mask: UInt16
        public let mode: Int
        public let targetBits: UInt32
        public let duration: UInt16
    }
    public enum Effect: Equatable, Sendable {
        case fade(Fade)
        /// 0x0200A060 on the sound manager 0x020FDC60: (entry, archive).
        case sound(archive: Int, entry: Int)
        /// The trick base writes the result through its +0x288 pointer
        /// (0x02026E68). The talk controller reads it as the process return.
        case processReturn(Int16)
        /// 0x021FE468 writes mode 20 with this pair into the talk session
        /// (0x020282A4) and asks for the talk process. No recovered path
        /// sets the request field, so the host must stop if this occurs.
        case hintTalk(pairA: Int16, pairB: Int16)
        /// Calls into talk-screen presentation helpers that are not drawn.
        case presentation(address: UInt32)
    }
    /// Update return value: 0 running, 1 talk request, 2 finished.
    public struct Step: Equatable, Sendable {
        public let status: Int
        public let effects: [Effect]
    }

    public private(set) var stage: Int16 = 0            // +0x2AE
    public private(set) var ringStage: Int16 = 0        // +0x43E
    public private(set) var ringTimer: Int16 = 0        // +0x440
    public private(set) var bellAngle: Float = 0        // +0x444
    public private(set) var rings: Int16 = 0            // +0x448
    public private(set) var ringLimit: Int16 = 3        // +0x44A
    public private(set) var ringCooldown: Int16 = 0     // +0x44C
    public private(set) var ringCooldownReset: Int16 = 20 // +0x44E
    public private(set) var rang = false                // +0x450
    public private(set) var hintDelay: Int16 = 60       // +0x452
    public private(set) var quitting: Int16 = 0         // +0x43C
    public private(set) var touchDisabled = false       // +0x2AD
    public private(set) var flag2AC = false             // +0x2AC, never set in overlay 32
    public private(set) var hintRequest: Int16 = 0      // +0x466
    /// Trick base +0x10C: one enable bit per button slot (0x0202649C/0x020264D8).
    public private(set) var buttonEnable: UInt16 = 0
    public private(set) var processReturn: Int16?

    /// The trick base adds icon 0x27 to button slot 5 (0x02026330).
    public static let quitButtonSlot = 5
    /// Inclusive rectangle at 0x021FE7F8, written by the static initializer
    /// 0x021FE5AC, in handedness-adjusted coordinates (0x0200985C).
    public static let bellRect = (left: 56, top: 72, right: 96, bottom: 120)
    /// Slot 5 of 0x020267F0.
    public static let quitRect = (left: 228, top: 156, right: 252, bottom: 188)
    /// 0x021FD75C and 0x021FD764: radians per ring-timer step.
    static let swingScale = Float(bitPattern: 0x3CAC0831)
    static let settleScale = Float(bitPattern: 0x3BE56042)

    /// The initializer 0x021FCEA0 starts these one-update fades on both screens.
    public static var initialFades: [Fade] {
        [0, 1].map { Fade(screen: $0, mask: 63, mode: 3, targetBits: 0xC1800000, duration: 1) }
    }

    public init() {}

    /// 0x02009920 and 0x02009960: right-handed play mirrors x, left-handed mirrors y.
    static func adjusted(_ touch: Touch, leftHanded: Bool) -> (x: Int, y: Int)? {
        guard (0...255).contains(touch.x), (0...191).contains(touch.y) else { return nil }
        return (leftHanded ? touch.x : 255 - touch.x, leftHanded ? 191 - touch.y : touch.y)
    }

    /// 0x021FE3AC without its state guards: the rectangle, else the nonzero
    /// `bell01.bin` pixel at row y and column 255 - x (handedness-adjusted).
    public static func hitsBell(_ touch: Touch, leftHanded: Bool, mask: [UInt8]) -> Bool {
        guard let point = adjusted(touch, leftHanded: leftHanded) else { return false }
        if (bellRect.left...bellRect.right).contains(point.x),
           (bellRect.top...bellRect.bottom).contains(point.y) { return true }
        let index = point.y * 256 + 255 - point.x
        return mask.indices.contains(index) && mask[index] != 0
    }

    public static func hitsQuit(_ touch: Touch, leftHanded: Bool) -> Bool {
        guard let point = adjusted(touch, leftHanded: leftHanded) else { return false }
        return (quitRect.left...quitRect.right).contains(point.x)
            && (quitRect.top...quitRect.bottom).contains(point.y)
    }

    /// 0x021FE3AC: the bell accepts touches only while play is live.
    func bellTouched(_ input: Input, mask: [UInt8]) -> Bool {
        guard !touchDisabled, quitting == 0, !(2...4).contains(stage),
              let touch = input.newTouch else { return false }
        return Self.hitsBell(touch, leftHanded: input.leftHanded, mask: mask)
    }

    public var awaitingTouch: Bool { stage == 1 && ringStage == 1 && !touchDisabled && quitting == 0 }
    public var quitEnabled: Bool { buttonEnable & (1 << UInt16(Self.quitButtonSlot)) != 0 }

    /// 0x021FD0A8. `mask` is the 256 × 192 index array of `bell01.bin`.
    public mutating func update(_ input: Input, mask: [UInt8]) -> Step {
        var effects: [Effect] = []
        var status = 0
        switch stage {
        case 0:
            // 0x021FCBEC: resources, camera and fields, then a 60-update fade in.
            effects.append(.fade(Fade(screen: 0, mask: 1, mode: 3, targetBits: 0xC1800000, duration: 60)))
            buttonEnable = 0xFFFF   // 0x0202649C(-1)
            stage += 1
        case 1:
            updateRing(input, mask: mask, effects: &effects)
        case 2:
            hintDelay -= 1
            if hintDelay < 1 { hintDelay = 0; hintRequest = 1; stage = 3 }
        case 3:
            hintRequest = 2
            effects.append(.presentation(address: 0x02064B18))
            stage = 4
        case 4:
            if hintDelay == 0 { buttonEnable = 0xFFFF; hintDelay += 1 }
            else if hintDelay == 30 {
                effects.append(.presentation(address: 0x02064B18))
                hintDelay = 0; stage = 1
            } else { hintDelay += 1 }
        case 5:
            // 0x021FD768: wait for the screen-0 fade, then return 0.
            if input.screen0FadeComplete {
                processReturn = 0
                effects.append(.processReturn(0))
                stage += 1
                status = 2
            }
        default: break
        }
        // 0x0202778C slot 5: an enabled quit button pressed this update.
        if quitEnabled, let touch = input.newTouch, Self.hitsQuit(touch, leftHanded: input.leftHanded) {
            effects.append(.sound(archive: 8, entry: 2))
            effects.append(.fade(Fade(screen: 0, mask: 1, mode: 2, targetBits: 0, duration: 60)))
            buttonEnable = 0   // 0x020264D8(-1)
            quitting = 1
        }
        // The source queries the fade manager after this update's calls, so
        // a screen-0 fade started above is still running.
        let startedFade = effects.contains { if case .fade(let fade) = $0 { return fade.screen == 0 }; return false }
        if quitting != 0 && input.screen0FadeComplete && !startedFade {
            processReturn = quitting
            effects.append(.processReturn(quitting))
            status = 2
        }
        if hintRequest == 1 || hintRequest == 2 {
            // 0x021FE468 then clears the request field.
            effects.append(.hintTalk(pairA: 1, pairB: hintRequest))
            status = 1
        }
        hintRequest = 0
        return Step(status: status, effects: effects)
    }

    /// 0x021FD478: three rings, each a short swing, then a sound and a fade out.
    private mutating func updateRing(_ input: Input, mask: [UInt8], effects: inout [Effect]) {
        if ringStage < 4, bellTouched(input, mask: mask) {
            ringStage = 2
            rang = true
            ringTimer = 0
            rings += 1
            ringCooldown = ringCooldownReset
        }
        // 0x020258E0 clamps to [0, +0x44E].
        let lowered = ringCooldown - 1
        ringCooldown = lowered < 0 ? 0 : min(lowered, ringCooldownReset)
        switch ringStage {
        case 0:
            if input.screen0FadeComplete { ringTimer = -15; ringStage += 1 }
        case 1:
            if ringTimer < 0 { ringTimer += 1 }
        case 2:
            ringTimer += 1
            if ringTimer < 3 { bellAngle = Float(ringTimer) * Self.swingScale }
            else { effects.append(.sound(archive: 37, entry: 0)); ringStage += 1 }
        case 3:
            ringTimer -= 1
            if ringTimer < -1 { ringStage += 1 } else { bellAngle = Float(ringTimer) * Self.swingScale }
        case 4:
            ringTimer += 1
            if ringTimer < 0 {
                bellAngle = Float(ringTimer) * Self.settleScale
                ringTimer = 0
                ringStage += 1
            }
        case 5:
            if rings < ringLimit { ringTimer = 0; ringStage = 1 }
            else {
                effects.append(.fade(Fade(screen: 0, mask: 0x21, mode: 3, targetBits: 0x41800000, duration: 60)))
                touchDisabled = true
                buttonEnable = 0
                ringStage += 1
            }
        case 6:
            if ringTimer == 0 { effects.append(.sound(archive: 1, entry: 0)) }   // 0x02064DC4
            else if ringTimer >= 130 {
                if flag2AC {
                    ringTimer = 0; ringStage = 1
                    effects.append(.presentation(address: 0x02064DA0))
                } else {
                    ringStage = 0
                    let fade = Fade(screen: 0, mask: 1, mode: 2, targetBits: 0, duration: 60)
                    effects.append(.fade(fade))
                    stage = 5
                    effects.append(.fade(fade))
                }
            }
            ringTimer += 1
        default: break
        }
    }
}
