import Foundation
import simd

/**
 * Process 28, overlay 9. Three joint groups straighten through drag-driven angle changes.
 */
public struct OriginalPaperclipProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int)
        case fadeOut(Int)
        case completionFade(Int)
        case sound(Int)
        case springBack
        case completed(Int16)
    }

    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var points: [SIMD3<Float>]
    public private(set) var angles: [Float]
    public let lengths: [Float]
    public private(set) var holding = false
    public private(set) var returnValue: Int16 = 2
    public private(set) var result: Int16?
    public private(set) var translation = SIMD3<Int32>.zero
    public private(set) var rotation: Float = 0
    private var limits: [Float]
    private var handle = SIMD3<Int32>.zero
    private var grabOffset = SIMD3<Int32>.zero
    private var wasDown = false
    private var previousStage = 0
    private var springCount = 0
    private var springTick = false
    private var timer = 0
    private static let pi = Float(bitPattern: 0x40490FDB)
    private static let anglePi = Float(bitPattern: 0x40490FD9)
    private static let step: Float = 0.015

    public init() {
        points = Self.initialPoints
        lengths = (0..<15).map { index in
            let delta = Self.initialPoints[index] - Self.initialPoints[index + 1]
            return sqrt(delta.x * delta.x + delta.z * delta.z)
        }
        angles = (0..<14).map { Self.angle(Self.initialPoints, at: $0) }
        limits = angles
        change(0...3, straighten: true, count: 20)
        limits = angles
        handle = Self.fixed(points[0])
    }

    public var canQuit: Bool { result == nil && phase < 3 && stage < 8 }
    public var activePoint: Int? {
        guard phase == 2 else { return nil }
        switch stage {
        case 0: return 0
        case 2: return 4
        case 4: return 15
        default: return nil
        }
    }

    public mutating func quit() {
        guard canQuit else { return }
        phase = 3
        stage = 0
        holding = false
    }

    /**
     * The host supplies the original touch-ray intersection with the horizontal interaction plane.
     */
    @discardableResult
    public mutating func update(touch: SIMD3<Int32>? = nil, isTouchDown: Bool = false,
                                fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let down = touch != nil || isTouchDown
        let pressed = down && !wasDown
        wasDown = down
        if phase == 0 { phase = 1; return [.fadeIn(60)] }
        if phase == 1 { phase = 2; return [] }
        if phase == 3 {
            switch stage {
            case 0: stage = 2; return [.fadeOut(60)]
            case 2: stage = 4
            case 4 where fadeComplete: result = returnValue; return [.completed(returnValue)]
            default: break
            }
            return []
        }
        rebuild(0...13)
        switch stage {
        case 0, 2, 4:
            let range = jointRange(stage)
            let point = stage == 0 ? 0 : stage == 2 ? 4 : 15
            if !holding {
                handle = Self.fixed(points[point])
                if let touch, (stage != 0 || pressed),
                   abs(touch.x - handle.x) <= 2048, abs(touch.z - handle.z) <= 2048 {
                    holding = true
                    grabOffset = touch &- handle
                    if stage == 0 { returnValue = 1 }
                }
            } else if down {
                if let touch {
                    handle.x = touch.x - grabOffset.x
                    handle.z = touch.z - grabOffset.z
                    let direction = bestDirection(range, point: point)
                    if direction == 1 { change(range, straighten: false) }
                    else if direction == 2 { change(range, straighten: true) }
                }
                let away = distance(points[point], from: handle) > 1
                if away {
                    if bestDirection(range, point: point) == 2 {
                        change(range, straighten: false, count: 20)
                        previousStage = stage
                        stage = 6
                        holding = false
                        return [.sound(28), .springBack]
                    }
                    holding = false
                }
            } else { holding = false }
            if reached(range, threshold: 0.1 + Float(bitPattern: 0x404B1293) * 0.98) {
                stage += 1
                holding = false
            }
        case 1, 3, 5:
            let range = jointRange(stage - 1)
            change(range, straighten: true)
            if reached(range, threshold: Float(bitPattern: 0x404B1293) * 0.94) {
                if stage == 5 {
                    stage = 8
                    returnValue = 0
                    return [.completionFade(60)]
                }
                stage += 1
            }
        case 6:
            if springCount == 0 { springCount = 20 }
            if springTick {
                let range = jointRange(previousStage)
                change(range, straighten: springCount % 2 != 0, count: springCount)
                springCount -= 1
                change(range, straighten: springCount % 2 == 0, count: springCount)
                springTick = false
                if springCount == 0 { stage = previousStage }
            } else { springTick = true }
        case 8:
            stage = 9
            timer = 0
            return [.sound(1)]
        case 9:
            timer += 1
            translation.x += (-8929 - translation.x) >> 4
            translation.z += (3113 - translation.z) >> 4
            rotation += 0.1 * (-0.24 - rotation)
            if timer > 120 { phase = 3; stage = 0; timer = 0 }
        default: break
        }
        return []
    }

    private func jointRange(_ stage: Int) -> ClosedRange<Int> {
        stage == 0 ? 0...3 : stage == 2 ? 4...7 : 8...13
    }

    private func reached(_ range: ClosedRange<Int>, threshold: Float) -> Bool {
        let middle = (range.lowerBound + range.upperBound) / 2
        return range.allSatisfy { $0 == middle || angles[$0] <= threshold }
    }

    /**
     * 0x021FDDE8 compares the current shape with one step in each direction.
     */
    private mutating func bestDirection(_ range: ClosedRange<Int>, point: Int) -> Int {
        let current = distance(points[point], from: handle)
        change(range, straighten: false)
        let bent = distance(points[point], from: handle)
        change(range, straighten: true, count: 2)
        let straight = distance(points[point], from: handle)
        change(range, straighten: false)
        if current > bent { return bent >= straight ? 2 : 1 }
        return current > straight ? 2 : 0
    }

    private func distance(_ point: SIMD3<Float>, from handle: SIMD3<Int32>) -> Float {
        let x = point.x - Float(handle.x) / 4096, z = point.z - Float(handle.z) / 4096
        return x * x + z * z
    }

    /**
     * 0x02200994 leaves the middle joint fixed when straightening. Bending updates every joint.
     */
    private mutating func change(_ range: ClosedRange<Int>, straighten: Bool, count: Int = 1) {
        let middle = (range.lowerBound + range.upperBound) / 2
        for _ in 0..<count {
            for index in range where !straighten || index != middle {
                angles[index] = min(limits[index], angles[index] + (straighten ? -Self.step : Self.step))
            }
        }
        rebuild(range)
    }

    private mutating func rebuild(_ range: ClosedRange<Int>) {
        for index in range {
            let difference = Self.angle(points, at: index) - angles[index]
            if difference * difference > 0.001, difference <= 0 { angles[index] -= 0.01 }
        }
        points[8].x = Self.initialPoints[8].x
        points[8].z = Self.initialPoints[8].z
        points[9].x = Self.initialPoints[9].x
        points[9].z = Self.initialPoints[9].z
        var angle: Float = 0
        var x = points[8].x, z = points[8].z
        for index in stride(from: 7, through: 0, by: -1) {
            angle += Self.pi - angles[index]
            x += lengths[index] * Float(cos(Double(angle)))
            z += lengths[index] * Float(sin(Double(angle)))
            points[index].x = x
            points[index].z = z
        }
        angle = 0
        x = points[9].x
        z = points[9].z
        for index in 10..<16 {
            angle -= Self.pi - angles[index - 2]
            x -= lengths[index - 1] * Float(cos(Double(angle)))
            z -= lengths[index - 1] * Float(sin(Double(angle)))
            points[index].x = x
            points[index].z = z
        }
    }

    private static func angle(_ points: [SIMD3<Float>], at index: Int) -> Float {
        let a = points[index] - points[index + 1], b = points[index + 2] - points[index + 1]
        let lengthA = sqrt(a.x * a.x + a.z * a.z), lengthB = sqrt(b.x * b.x + b.z * b.z)
        let ax = a.x / lengthA, az = a.z / lengthA, bx = b.x / lengthB, bz = b.z / lengthB
        let angle = Float(acos(Double(min(1, max(-1, bx * ax + bz * az)))))
        return bz * ax - bx * az < 0 ? anglePi + (anglePi - angle) : angle
    }

    private static func fixed(_ point: SIMD3<Float>) -> SIMD3<Int32> {
        SIMD3((0..<3).map { Int32((point[$0] * 4096).rounded(.toNearestOrAwayFromZero)) })
    }

    /**
     * Original vertex table at overlay address 0x02201D08.
     */
    private static let initialPoints: [SIMD3<Float>] = [
        SIMD3(0.970973014831543, -0.005125999916344881, 0.4615490138530731),
        SIMD3(-1.18982994556427, -0.041120998561382294, 0.41039401292800903),
        SIMD3(-1.3845429420471191, -0.041124001145362854, 0.25840499997138977),
        SIMD3(-1.3766189813613892, -0.041124001145362854, -0.3140290081501007),
        SIMD3(-1.2267019748687744, -0.041124001145362854, -0.4676569998264313),
        SIMD3(1.1918950080871582, -0.041124001145362854, -0.4555619955062866),
        SIMD3(1.3756649494171143, -0.041124001145362854, -0.2841559946537018),
        SIMD3(1.3781460523605347, -0.041124001145362854, 0.1848040074110031),
        SIMD3(1.216863989830017, -0.041124001145362854, 0.33864301443099976),
        SIMD3(-0.5431830286979675, -0.041124001145362854, 0.3179660141468048),
        SIMD3(-0.7416849732398987, -0.041124001145362854, 0.17405200004577637),
        SIMD3(-0.7375490069389343, -0.041124001145362854, -0.22708599269390106),
        SIMD3(-0.5167160034179688, -0.041124001145362854, -0.3478420078754425),
        SIMD3(0.7751979827880859, -0.041124001145362854, -0.33708900213241577),
        SIMD3(0.9331719875335693, -0.041124001145362854, -0.2130260020494461),
        SIMD3(0.9960309863090515, -0.005125000141561031, 0.0830719992518425),
    ]
}
