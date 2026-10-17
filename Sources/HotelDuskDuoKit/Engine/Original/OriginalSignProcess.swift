import Foundation

/// Process 25, overlay 1 (`CSign`): Kyle signs the R102 registration card.
/// The factory 0x0200B334 case 25 passes slot 0 to 0x0200B2D8; the table at
/// 0x020E92A4 maps it to overlay 1, constructor 0x021FCB40. Update is
/// 0x021FCFEC. Resources: `/data/trick/sign.wpf` members `signnote.bin` and
/// `signnote02.bin`. One update is one DS update; offsets name object fields.
public struct OriginalSignProcess: Equatable, Codable, Sendable {
    public typealias Touch = OriginalBellProcess.Touch
    public typealias Fade = OriginalBellProcess.Fade
    public typealias Effect = OriginalBellProcess.Effect
    public typealias Step = OriginalBellProcess.Step

    public struct Input: Sendable {
        /// The held touch (0x020097DC), raw DS pixels, or nil when released.
        public var heldTouch: Touch?
        /// The new-press flag, used by the trick base quit button.
        public var newTouch: Touch?
        public var leftHanded: Bool
        public var screen0FadeComplete: Bool
        public init(heldTouch: Touch? = nil, newTouch: Touch? = nil, leftHanded: Bool = false,
                    screen0FadeComplete: Bool = false) {
            self.heldTouch = heldTouch; self.newTouch = newTouch
            self.leftHanded = leftHanded; self.screen0FadeComplete = screen0FadeComplete
        }
    }

    /// Field rectangles at 0x021FE708 (x), 0x021FE718 (y), 0x021FE700 (width)
    /// and 0x021FE710 (height), in 0x02009920/0x02009960 coordinates: x′ is
    /// the rotated page column (0–191) and y′ its row (0–255). Inclusive.
    public static let fieldX: [Int16] = [48, 12, 48, 24]
    public static let fieldY: [Int16] = [80, 138, 167, 191]
    public static let fieldWidth: [Int16] = [174, 208, 151, 87]
    public static let fieldHeight: [Int16] = [47, 14, 22, 20]
    /// 0x021FD648 points at the same table as the widths: stroke limits.
    public static var strokeLimit: [Int16] { fieldWidth }

    public private(set) var stage: Int16 = 0          // +0x2A8
    public private(set) var substage: Int16 = 0       // +0x2AA
    public private(set) var waitTimer: Int32 = 0      // +0x2AC
    public private(set) var finishTimer: Int32 = 0    // +0x2B0
    public private(set) var previousX: Int16 = 0xC0   // +0x2B4
    public private(set) var previousY: Int16 = 0x100  // +0x2B6
    public private(set) var strokes: [Int16] = [0, 0, 0, 0]   // +0x2B8
    public private(set) var filled: [Bool] = [false, false, false, false]  // +0x2C0
    public private(set) var soundDelay: Int16 = 0     // +0xC704
    public private(set) var delayedSound: Int16 = -1  // +0xC706
    public private(set) var presentedFirstStroke = false  // +0xC304
    /// Trick base +0x10C: one enable bit per button slot.
    public private(set) var buttonEnable: UInt16 = 0
    /// The initializer 0x021FCC94 writes 2 before any input (0x02026E68).
    public private(set) var processReturn: Int16 = 2

    public init() {}

    public var quitEnabled: Bool { buttonEnable & (1 << UInt16(OriginalBellProcess.quitButtonSlot)) != 0 }
    public var awaitingStroke: Bool { stage == 1 }

    /// 0x02009920 and 0x02009960 for a held touch.
    static func adjusted(_ touch: Touch, leftHanded: Bool) -> (x: Int16, y: Int16)? {
        guard (0...255).contains(touch.x), (0...191).contains(touch.y) else { return nil }
        return (Int16(leftHanded ? 191 - touch.y : touch.y), Int16(leftHanded ? touch.x : 255 - touch.x))
    }

    /// 0x021FCFEC.
    public mutating func update(_ input: Input) -> Step {
        var effects: [Effect] = []
        var status = 0
        switch stage {
        case 0:
            stage = 3
            buttonEnable = 0xFFFF      // 0x0202649C(-1)
        case 1: updateInput(input)
        case 2: updateStrokes(input, effects: &effects)
        case 3:
            waitTimer += 1
            if waitTimer > 30 { stage = 1; waitTimer = 0 }
        case 4:
            // 0x021FD64C: disable the buttons, then wait for the screen-0 fade.
            if substage == 0 { buttonEnable = 0; substage = 1 }
            else if substage == 1, input.screen0FadeComplete { status = 2 }
        default: break
        }
        // 0x0202778C slot 5 runs after every stage: sound, fade, result.
        if quitEnabled, let touch = input.newTouch, OriginalBellProcess.hitsQuit(touch, leftHanded: input.leftHanded) {
            effects.append(.sound(archive: 8, entry: 2))
            effects.append(.fade(Fade(screen: 0, mask: 1, mode: 2, targetBits: 0, duration: 60)))
            stage = 4
            substage = 0
            processReturn = filled[0] || filled[1] || filled[2] ? 1 : 2
            effects.append(.processReturn(processReturn))
        }
        return Step(status: status, effects: effects)
    }

    /// 0x021FD234: a held touch that moves right by more than one pixel inside
    /// an unfilled field fills it. A release resets the previous point.
    private mutating func updateInput(_ input: Input) {
        guard let touch = input.heldTouch, let point = Self.adjusted(touch, leftHanded: input.leftHanded) else {
            previousX = 0xC0; previousY = 0x100
            return
        }
        if point.x - previousX > 1 {
            for field in 0..<4 where !filled[field]
                && (Self.fieldX[field]...(Self.fieldX[field] + Self.fieldWidth[field])).contains(point.x)
                && (Self.fieldY[field]...(Self.fieldY[field] + Self.fieldHeight[field])).contains(point.y) {
                filled[field] = true
                stage = 2
                substage = 0
            }
        }
        previousX = point.x; previousY = point.y
    }

    /// 0x021FD344: each newly filled field draws its stroke, two pixels per update.
    private mutating func updateStrokes(_ input: Input, effects: inout [Effect]) {
        switch substage {
        case 0:
            substage = 2
            for field in 0..<4 where filled[field] && strokes[field] < Self.strokeLimit[field] {
                switch field {
                case 0: effects.append(.sound(archive: 25, entry: 0))
                case 1: soundDelay = 0x1A; delayedSound = 1
                case 2: soundDelay = 2; delayedSound = 2
                default: effects.append(.sound(archive: 25, entry: 3))
                }
                if !presentedFirstStroke {
                    effects.append(.presentation(address: 0x02064B18))
                    presentedFirstStroke = true
                }
            }
        case 2:
            if soundDelay > 0 {
                soundDelay -= 1
                if soundDelay == 0, delayedSound != -1 {
                    effects.append(.sound(archive: 25, entry: Int(delayedSound)))
                    delayedSound = -1
                }
            }
            var grew = false
            for field in 0..<4 where filled[field] && strokes[field] < Self.strokeLimit[field] {
                grew = true
                strokes[field] += 2
            }
            if !grew { substage = 3 }
        case 3:
            if filled.allSatisfy({ $0 }) {
                substage = 4
                effects.append(.fade(Fade(screen: 0, mask: 0x21, mode: 3, targetBits: 0x41800000, duration: 60)))
                buttonEnable = 0
            } else {
                stage = 1
                substage = 0
            }
        case 4:
            finishTimer += 1
            substage = 0
            finishTimer = 0
            if filled.allSatisfy({ $0 }) {
                substage = 5
                effects.append(.sound(archive: 1, entry: 0))   // 0x02064DC4
            }
        case 5:
            finishTimer += 1
            if finishTimer > 0x78 {
                finishTimer = 0
                effects.append(.fade(Fade(screen: 0, mask: 1, mode: 2, targetBits: 0, duration: 60)))
                stage = 4
                substage = 0
                processReturn = 0
                effects.append(.processReturn(0))
            }
        default: break
        }
    }
}
