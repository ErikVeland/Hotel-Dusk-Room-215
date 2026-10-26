import Foundation
import simd

/**
 * Overlay 12 wire-lock controller. Process 29 fails with thin wire. Process 33 opens the suitcase.
 */
public struct OriginalThinWireProcess: Equatable, Sendable {
    public enum Variant: UInt16, Equatable, Sendable {
        case thin = 29, thick = 33, door = 77, orderedDoor = 78
        var isDoor: Bool { self == .door || self == .orderedDoor }
    }

    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case sound(Int), stopSound(Int), scrapeVolume(Int)
        case pinLatched, markCompleted
        case caption(Int)
        case rumble
        case completed(Int16)
    }

    public struct Pin: Equatable, Sendable {
        public fileprivate(set) var position: SIMD2<Int32>
        public fileprivate(set) var depth = 0
        public fileprivate(set) var wasPushed = false
        public fileprivate(set) var reached = false
    }

    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var wire = SIMD3<Int32>(0, 393, 12288)
    public private(set) var drawnWire = SIMD3<Int32>(0, 393, 12288)
    public private(set) var eye = SIMD3<Int32>(-655, 8192, 8192)
    public private(set) var target = SIMD3<Int32>(-655, 393, 7373)
    public let variant: Variant
    public private(set) var lockRotation: Float = 0
    public private(set) var lidRotation: Float = 0
    private var lidVelocity: Float = 0
    private var latchedPins = 0
    public private(set) var cursor = SIMD2<Int32>.zero
    public private(set) var pins = [Pin(position: SIMD2(0, 1106)), Pin(position: SIMD2(492, 0)), Pin(position: SIMD2(0, -1065))]
    public private(set) var holding = false
    public private(set) var cursorVisible = false
    public private(set) var returnValue: Int16 = 2
    public private(set) var result: Int16?
    private var nextPhase = -1
    private var wasDown = false
    private var timer = 0
    private var cameraStart = SIMD3<Int32>.zero
    private var scrapePlaying = false
    private var previousScrapeTouch = SIMD2<Float>.zero
    private var latchElapsed: Double?

    public init(variant: Variant = .thin) {
        self.variant = variant
        if variant.isDoor { pins = pinOrigins.map { Pin(position: $0) } }
    }

    public var processID: UInt16 { variant.rawValue }
    public var contactRadius: Float { variant == .thin ? 0.05 : 0.1 }
    public var showsOpening: Bool { phase == 4 || phase == 8 }
    var frameCounter: Int { timer }

    public var showsLock: Bool { phase == 3 || phase == 7 || (phase == 0 && variant.isDoor) }
    public var canQuit: Bool { result == nil && (phase == 1 || (phase == 3 && stage == 1)) }

    public mutating func quit() {
        guard canQuit else { return }
        phase = phase == 1 ? 6 : 7
        stage = 0
        holding = false
        cursorVisible = false
    }

    /**
     * Page coordinates retain the original 192×256 rotation and fixed-point rounding.
     */
    @discardableResult
    public mutating func update(pageTouch: SIMD2<Float>? = nil, fadeComplete: Bool = false, elapsedSeconds: Double = 1 / 59.8261) -> [Effect] {
        guard result == nil else { return [] }
        let touch = pageTouch.flatMap { point -> SIMD2<Float>? in
            guard point.x.isFinite, point.y.isFinite, (0...191).contains(point.x), (0...255).contains(point.y) else { return nil }
            return SIMD2(point.x.rounded(.towardZero), point.y.rounded(.towardZero))
        }
        let pressed = touch != nil && !wasDown
        wasDown = touch != nil
        switch phase {
        case 0: phase = variant.isDoor ? 3 : 1; return [.fadeIn(60), .caption(-1)]
        case 1:
            drawnWire = wire
            if stage == 0 { stage = 1 }
            else if !holding {
                if pressed, let touch, hit(touch, radius: 2048) != nil { holding = true }
            } else if let touch {
                if let point = hit(touch, radius: 40960) {
                    wire.x += (point.x - wire.x) >> 2
                    wire.z = max(8192, wire.z + ((point.z - wire.z) >> 2))
                    let delta = SIMD3<Float>(wire) / 4096 - SIMD3<Float>(-0.16, 0.096, 1.8)
                    if simd_length_squared(delta) <= 0.25 {
                        phase = 2
                        stage = 0
                        holding = false
                        returnValue = 1
                    }
                }
            } else { holding = false }
        case 2:
            switch stage {
            case 0:
                if Float(wire.x) / 4096 > -0.15 { wire.x = Int32(Float(wire.x) - 40.96) }
                else if Float(wire.x) / 4096 < -0.17 { wire.x = Int32(Float(wire.x) + 40.96) }
                else { wire.x = -655; stage = 1 }
            case 1:
                if Float(wire.z) / 4096 > 1.81 { wire.z = Int32(Float(wire.z) - 40.96) }
                else if Float(wire.z) / 4096 < 1.79 { wire.z = Int32(Float(wire.z) + 40.96) }
                else { wire.z = 7373; stage = 2 }
            case 2:
                cameraStart = eye
                timer = 0
                stage = 3
            case 3:
                let amount = min(Float(timer) / 45, 1)
                let start = SIMD3<Float>(cameraStart) / 4096
                let end = SIMD3<Float>(-0.16, 0.096, 2.1)
                eye = Self.fixed(start + (end - start) * amount)
                timer += 1
                if timer > 60 { timer = 0; phase = 6; stage = 0; nextPhase = 3 }
            default: break
            }
            drawnWire = wire
        case 3:
            if stage == 0 { stage = 1 }
            else if stage == 1 {
                if variant == .door, let elapsed = latchElapsed {
                    let next = elapsed + (elapsedSeconds.isFinite ? max(0, elapsedSeconds) : 0)
                    if next >= 4 {
                        for index in pins.indices { pins[index].reached = false; pins[index].wasPushed = false }
                        latchElapsed = nil
                    } else { latchElapsed = next }
                }
                return updatePins(touch)
            }
            else if stage == 2 { stage = 3; timer = 0 }
            else if stage == 3 {
                timer += 1
                if timer > (variant == .thin ? 120 : 190) {
                    timer = 0
                    if variant == .thick {
                        nextPhase = 4
                        stage = 4
                        return [.pinLatched]
                    }
                    phase = 7
                    stage = 0
                }
            } else if stage == 4 {
                lockRotation += (0.5 - lockRotation) * 0.2
                timer += 1
                if lockRotation >= 0.5 || timer >= 51 { timer = 0; phase = 7; stage = 0 }
            }
        case 4: return updateOpening()
        case 6, 7, 8:
            if stage == 0 { stage = 1; return [.fadeOut(60)] }
            if fadeComplete {
                if nextPhase == -1 { result = returnValue; return [.stopSound(33), .completed(returnValue)] }
                phase = nextPhase
                nextPhase = -1
                stage = 0
                return [.fadeIn(60)]
            }
        default: break
        }
        return []
    }

    /**
     * 0x021FE1DC moves the camera, accelerates the lid and holds the open suitcase before exit.
     */
    private mutating func updateOpening() -> [Effect] {
        switch stage {
        case 0:
            eye = SIMD3(-655, 8192, 8192)
            target = SIMD3(-655, 393, 7373)
            stage = 1
            timer = 0
        case 1:
            let amount = (min(Float(timer) / 45, 1) * 4096).rounded(.toNearestOrAwayFromZero) / 4096
            let start = SIMD3<Float>(-0.16, 0.096, 2.1)
            eye = Self.fixed(start + (SIMD3<Float>(0, 4, 4) - start) * amount)
            timer += 1
            if timer > 60 { timer = 0; stage = 2 }
        case 2:
            lidRotation = 0
            lidVelocity = 0
            stage = 3
            return [.sound(55)]
        case 3:
            timer += 1
            if timer < 20 { lidVelocity += 0.0001 }
            else if timer < 40 { lidVelocity -= 0.0001 }
            else { lidVelocity = 0 }
            lidRotation += lidVelocity
            target.y = Int32((lidRotation * 5 * 4096).rounded(.toNearestOrAwayFromZero))
            if timer > 60 { timer = 0; stage = 5 }
        case 5:
            timer += 1
            if timer > 90 { timer = 0; phase = 8; stage = 0; nextPhase = -1 }
        default: break
        }
        return []
    }

    private func inCursorWindow(_ point: SIMD2<Float>) -> Bool {
        // Overlay initializer 0x02207E5C supplies different door and suitcase windows.
        let x: ClosedRange<Float> = variant.isDoor ? 88...104 : 85...106
        let y: ClosedRange<Float> = variant.isDoor ? 88...168 : 98...158
        return x.contains(point.x) && y.contains(point.y)
    }

    private func hit(_ point: SIMD2<Float>, radius: Int32) -> SIMD3<Int32>? {
        OriginalSuitcaseProjection.hit(page: point, eye: eye, target: target, centre: drawnWire, radius: radius)
    }

    /**
     * 0x02204D50 returns each pin before handling the cursor's next contact.
     */
    private mutating func updatePins(_ touch: SIMD2<Float>?) -> [Effect] {
        cursorVisible = touch.map(inCursorWindow) ?? false
        var effects: [Effect] = []
        for index in pins.indices {
            if variant != .thin && pins[index].reached { continue }
            if pins[index].depth > 0 && !pins[index].wasPushed {
                pins[index].depth -= 1
                let step = Self.pinStep(index)
                let value = SIMD2<Float>(pins[index].position) - step
                pins[index].position = SIMD2(Int32(value.x), Int32(value.y))
                let origin = pinOrigins[index]
                pins[index].position.x = step.x > 0 ? max(origin.x, pins[index].position.x) : min(origin.x, pins[index].position.x)
                pins[index].position.y = step.y > 0 ? max(origin.y, pins[index].position.y) : min(origin.y, pins[index].position.y)
            }
            pins[index].wasPushed = false
        }
        if !holding {
            if let touch, inCursorWindow(touch) {
                holding = true
                cursor = Self.lockPoint(touch)
                if contactPins() {
                    returnValue = 1
                    holding = false
                    scrapePlaying = false
                    effects.append(.stopSound(33))
                }
            }
        } else if let touch {
            let desired = Self.lockPoint(touch)
            if !scrapePlaying { scrapePlaying = true; effects.append(.sound(33)) }
            let moved = abs(touch.x - previousScrapeTouch.x) > 1 || abs(touch.y - previousScrapeTouch.y) > 1
            previousScrapeTouch = touch
            effects.append(.scrapeVolume(moved ? 127 : 0))
            let previous = cursor
            for axis in 0..<2 {
                if desired[axis] < cursor[axis] { cursor[axis] = Int32(Float(cursor[axis]) - 122.88) }
                if cursor[axis] < desired[axis] { cursor[axis] = Int32(Float(cursor[axis]) + 122.88) }
                if contactPins() { cursor[axis] = previous[axis] }
            }
        } else {
            holding = false
            scrapePlaying = false
            effects.append(.stopSound(33))
        }
        if latchedPins > 0 {
            effects += Array(repeating: .pinLatched, count: latchedPins)
            latchedPins = 0
        }
        if pins.allSatisfy(\.reached) {
            returnValue = 0
            cursorVisible = false
            stage = 2
            holding = false
            scrapePlaying = false
            effects += [.rumble, .completionFade(60), .stopSound(33)]
            if variant == .thick { effects += [.pinLatched, .markCompleted] }
        }
        return effects
    }

    private mutating func contactPins() -> Bool {
        var hit = false
        for index in pins.indices {
            let points = pinContours[index].map { $0 &+ pins[index].position }
            let repeated = points + Array(repeating: points[4], count: 5)
            let contact = (0..<10).contains { side in
                near(repeated[side]) || nearMidpoint(repeated[side], repeated[(side + 1) % 10])
            }
            if contact {
                hit = true
                if near(repeated[9]) || nearMidpoint(repeated[9], repeated[0]) || near(repeated[0]) {
                    pushPin(index)
                }
            }
        }
        return hit
    }

    private mutating func pushPin(_ index: Int) {
        let threshold = variant == .thin ? 8 : 16
        if pins[index].depth < threshold + 2 {
            pins[index].depth += 1
            pins[index].wasPushed = true
            let value = SIMD2<Float>(pins[index].position) + Self.pinStep(index)
            pins[index].position = SIMD2(Int32(value.x), Int32(value.y))
        }
        if pins[index].depth >= threshold {
            if variant != .thin && !pins[index].reached {
                latchedPins += 1
                if variant == .door, latchElapsed == nil { latchElapsed = 0 }
            }
            if variant == .orderedDoor, pins.indices.contains(where: { $0 > index && pins[$0].reached }) {
                for other in pins.indices { pins[other].reached = false; pins[other].wasPushed = false }
            }
            pins[index].reached = true
        }
    }

    private func near(_ point: SIMD2<Int32>) -> Bool {
        let delta = SIMD2<Float>(point) / 4096 - SIMD2<Float>(cursor) / 4096
        return delta.x * delta.x + delta.y * delta.y < contactRadius * contactRadius
    }

    private func nearMidpoint(_ a: SIMD2<Int32>, _ b: SIMD2<Int32>) -> Bool {
        let midpoint = (SIMD2<Float>(a) / 4096 + SIMD2<Float>(b) / 4096) * 0.5
        let delta = midpoint - SIMD2<Float>(cursor) / 4096
        return delta.x * delta.x + delta.y * delta.y < contactRadius * contactRadius
    }

    private static func lockPoint(_ page: SIMD2<Float>) -> SIMD2<Int32> {
        let point = SIMD2(page.x / 96 - 1, 1 - (page.y - 32) / 96)
        return SIMD2((0..<2).map { Int32((point[$0] * 4096).rounded(.toNearestOrAwayFromZero)) })
    }

    private static func pinStep(_ index: Int) -> SIMD2<Float> {
        let angle = Float(index) * 0.5 * Float.pi
        return SIMD2(Float(sin(Double(angle))) * 0.01 * 4096,
                     Float(cos(Double(angle))) * 0.01 * 4096)
    }

    private static func fixed(_ point: SIMD3<Float>) -> SIMD3<Int32> {
        SIMD3((0..<3).map { Int32((point[$0] * 4096).rounded(.toNearestOrAwayFromZero)) })
    }

    private var pinOrigins: [SIMD2<Int32>] {
        switch variant {
        case .door: return [.init(-410, 1352), .init(410, 410), .init(410, -1352), .init(-410, -410)]
        case .orderedDoor: return [.init(410, 1352), .init(410, -410), .init(-410, -1352), .init(-410, 410)]
        default: return [.init(0, 1106), .init(492, 0), .init(0, -1065)]
        }
    }
    // 0x02205AF4 derives these five contour points from the original lock dimensions.
    private var pinContours: [[SIMD2<Int32>]] { [
        [SIMD2(-512, 683), SIMD2(-512, -640), SIMD2(469, -640), SIMD2(469, 683), SIMD2(0, -640)],
        [SIMD2(-384, 299), SIMD2(-384, -256), SIMD2(384, -256), SIMD2(384, 299), SIMD2(-384, 0)],
        [SIMD2(-427, 512), SIMD2(-427, -469), SIMD2(341, -469), SIMD2(341, 512), SIMD2(0, 512)],
        [SIMD2(-384, 299), SIMD2(-384, -256), SIMD2(384, -256), SIMD2(384, 299), SIMD2(384, 0)]
    ] }
}
