import Foundation

/// Process 56, overlay 31: the original hotel entrance. Update and draw remain
/// separate, as they are at 0x021FD388 and 0x021FD5A8. One tick is one DS update.
public struct OriginalEntranceProcess: Equatable, Codable, Sendable {
    public struct Pose: Equatable, Codable, Sendable {
        public var x: Int32
        public var y: Int32
        public var z: Int32
        public var facingBits: UInt32
        public init(x: Int32, y: Int32, z: Int32, facingBits: UInt32) {
            self.x = x; self.y = y; self.z = z; self.facingBits = facingBits
        }
    }
    public struct Touch: Equatable, Sendable {
        public let x: Int
        public let y: Int
        public init(x: Int, y: Int) { self.x = x; self.y = y }
    }
    public struct Input: Sendable {
        /// The original touch manager's new-press flag, not a held touch.
        public var newTouch: Touch?
        public var leftHanded: Bool
        public var page0FadeComplete: Bool
        public var backgroundAnimationActive: Bool
        public var imageBuffersReady: Bool
        public init(newTouch: Touch? = nil, leftHanded: Bool = false,
                    page0FadeComplete: Bool = false, backgroundAnimationActive: Bool = false,
                    imageBuffersReady: Bool = true) {
            self.newTouch = newTouch; self.leftHanded = leftHanded
            self.page0FadeComplete = page0FadeComplete
            self.backgroundAnimationActive = backgroundAnimationActive
            self.imageBuffersReady = imageBuffersReady
        }
    }
    public struct Fade: Equatable, Sendable {
        public let screen: Int
        public let mask: UInt16
        public let mode: Int
        public let targetBits: UInt32
        public let duration: UInt16
    }
    public enum Effect: Equatable, Sendable {
        case fade(Fade)
        case actorPose(Pose)
        case sound(archive: Int, entry: Int)
        case optionalRumble(Int)
        case processReturn(Int16)
        case sceneVisible(Bool)
        case stopBackgroundAnimation
        case backgroundMask(screen: Int, mask: UInt16)
        /// Exact shared resource lifecycle calls at the two completion stages.
        case sharedResourceCall(address: UInt32)
    }
    public enum DrawEffect: Equatable, Sendable {
        /// 0x020BFADC: capture the live scene on an even source frame.
        case captureScene
        /// 0x020BFBAC: copy 0xC000 source bytes on an odd source frame.
        case copyImage(name: String, byteCount: Int)
        case slide(first: Int16, second: Int16, leftHanded: Bool)
        case scene(modelFrame: Float, actorPose: Pose?)
    }
    public struct Step: Equatable, Sendable {
        /// Original process manager statuses: 0 running, 1 ending, 3 finished.
        public let status: UInt8
        public let effects: [Effect]
    }

    public private(set) var stage: Int16 = 0          // +0x5E4
    public private(set) var phase: Int16 = 0          // +0x5E6
    public private(set) var movement: Int16 = 0       // +0x5E8
    public private(set) var timer: Int16 = 0          // +0x5EA
    public private(set) var velocity: Int32 = 0       // +0x634
    public private(set) var modelFrame: Float = 0     // +0x63C
    public private(set) var firstSlide: Int16 = -256  // +0x72C
    public private(set) var secondSlide: Int16 = 0    // +0x72E
    public private(set) var imagePhase: Int16 = 0     // +0x730
    public private(set) var imageFrame: UInt8 = 0     // +0x74C
    public private(set) var imageCounter: UInt32 = 0  // +0x750
    public private(set) var actorPose: Pose?
    public private(set) var sceneVisible = true
    public private(set) var processReturn: Int16 = 2

    /// Movement stage 3 is the only stage that reads a new press.
    public var movementAwaitingTouch: Bool { stage == 1 && phase == 3 && movement == 3 }

    /// Source allocation clears storage before construction (0x01FF93B8).
    /// The caller loads entrance.wpf and the original R101 map before updating.
    public init() {}

    /// The normal initializer also starts this one-update fade.
    public static var initialFade: Fade {
        Fade(screen: 1, mask: 63, mode: 2, targetBits: 0, duration: 1)
    }

    /// Original rotated-DS coordinate conversion and inclusive handle bounds.
    /// Source: 0x0200985C, 0x02009920, 0x02009960, overlay 0x021FDF54.
    public static func hitsHandle(_ touch: Touch, leftHanded: Bool) -> Bool {
        guard (0...255).contains(touch.x), (0...191).contains(touch.y) else { return false }
        let x = leftHanded ? touch.x : 255 - touch.x
        let y = leftHanded ? 191 - touch.y : touch.y
        return (150...200).contains(x) && (84...101).contains(y)
    }

    /// Do not call while the game is paused. Codable retains every local timer
    /// and animation stage when closing or restoring the book.
    public mutating func update(_ input: Input = .init()) -> Step {
        var effects: [Effect] = []
        var status: UInt8 = 0
        switch stage {
        case 0: stage = 1
        case 1:
            if updatePhase(input, effects: &effects) { stage = 2 }
        case 2:
            phase = 0
            stage = 3
        case 3:
            status = 1
            effects.append(.sharedResourceCall(address: 0x0205A2C8))
            stage = 4
        case 4:
            status = 3
            effects.append(.sharedResourceCall(address: 0x0205A1AC))
            stage = 0
        default: break
        }
        updateImages(ready: input.imageBuffersReady)
        return Step(status: status, effects: effects)
    }

    /// Source draw can acknowledge a pending upload independently of update.
    public mutating func draw(leftHanded: Bool = false) -> [DrawEffect] {
        var effects: [DrawEffect] = []
        if imagePhase == 2 {
            if imageFrame & 1 == 0 { effects.append(.captureScene) }
            else {
                let names = ["d01.bin", "u01.bin", "d02.bin", "u02.bin", "d03.bin", "u03.bin"]
                effects.append(.copyImage(name: names[Int(imageFrame)], byteCount: 0xC000))
            }
            imagePhase = 0
        } else if firstSlide < 0 {
            effects.append(.slide(first: firstSlide, second: secondSlide, leftHanded: leftHanded))
        }
        if sceneVisible { effects.append(.scene(modelFrame: modelFrame, actorPose: actorPose)) }
        return effects
    }

    private mutating func updatePhase(_ input: Input, effects: inout [Effect]) -> Bool {
        switch phase {
        case 0:
            effects.append(.fade(Fade(screen: 1, mask: 63, mode: 3,
                                      targetBits: 0xC1800000, duration: 80)))
            phase = 1
        case 1: phase = 2
        case 2:
            timer = 0
            actorPose = Pose(x: 512, y: 12288, z: 30648, facingBits: 0x40490FDB)
            effects.append(.actorPose(actorPose!))
            phase = 3
        case 3:
            if timer != -1 { timer &+= 1 }
            if timer > 196 { timer = -1 }
            if updateMovement(input, effects: &effects) { phase = 4 }
        case 4:
            timer &+= 1
            if input.page0FadeComplete {
                if input.backgroundAnimationActive { effects.append(.stopBackgroundAnimation) }
                sceneVisible = false
                effects.append(.sceneVisible(false))
                timer = 0
                phase = 5
            }
        case 5:
            timer &+= 1
            if timer >= 100 { phase = 0; return true }
        default: break
        }
        return false
    }

    private mutating func updateMovement(_ input: Input, effects: inout [Effect]) -> Bool {
        if firstSlide < 0 { firstSlide &+= 1; secondSlide &+= 1 }
        guard var pose = actorPose else { return false }
        switch movement {
        case 0:
            velocity = 6; modelFrame = 0; movement = 1
        case 1:
            pose.z &-= 26
            if firstSlide == 0 { movement = 2 }
        case 2: movement = 3
        case 3:
            if let touch = input.newTouch, Self.hitsHandle(touch, leftHanded: input.leftHanded) {
                effects.append(.sound(archive: 51, entry: 0))
                effects.append(.optionalRumble(1))
                processReturn = 0
                effects.append(.processReturn(0))
                timer = 0; movement = 4
            }
        case 4:
            modelFrame += 0.75
            pose.z &-= 1
            if modelFrame > 40 {
                movement = 5; velocity = 5
                effects.append(.fade(Fade(screen: 0, mask: 63, mode: 2, targetBits: 0, duration: 100)))
                effects.append(.fade(Fade(screen: 1, mask: 63, mode: 2, targetBits: 0, duration: 100)))
            }
        case 5:
            modelFrame += 0.75
            pose.z &-= velocity
            velocity &+= 1
            if input.page0FadeComplete {
                sceneVisible = false
                effects.append(.sceneVisible(false))
                effects.append(.backgroundMask(screen: 1, mask: 12))
                movement = 0; modelFrame = 0
                // The source exits before committing this update's local pose.
                return true
            }
        default:
            movement = 0; modelFrame = 0
            return true
        }
        actorPose = pose
        effects.append(.actorPose(pose))
        return false
    }

    private mutating func updateImages(ready: Bool) {
        if imagePhase == 0 {
            if ready { imagePhase = 1 }
        } else if imagePhase == 1 {
            imageCounter &+= 1
            if imageCounter > 4 {
                imageCounter = 0
                imageFrame &+= 1
                if imageFrame > 5 { imageFrame = 0 }
                imagePhase = 2
            }
        }
    }
}
