import Foundation

/// Overlay 23, process 47: rotate and tap the box, then ease out its bookmark.
/// Source input/state functions: 0x021FD43C, 0x022008D8, 0x021FECD4, 0x0220030C.
public struct OriginalBookmarkBoxProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case sound(archive: Int, entry: Int), ensureSound(archive: Int, entry: Int)
        case stopSound(archive: Int, entry: Int, frames: Int)
        case completed(Int16)
    }
    public private(set) var phase = 0
    public private(set) var stage = 4
    public private(set) var angles = SIMD3<Int>(repeating: 0)
    public private(set) var taps = 0
    public private(set) var shake: Float = 0
    public private(set) var bookmarkX: Float = 27
    public private(set) var itemAlpha = 0
    public private(set) var arrowAlpha = [0, 0, 0, 0]
    public private(set) var result: Int16?
    private var timer = 0
    private var rotationAxis: Int?
    private var velocity = 0
    private var previousTouch: SIMD2<Int>?
    private var pullDelta = 0
    private var quitting = false

    public init() {}
    public var isRotating: Bool { rotationAxis != nil }
    public var canQuit: Bool { !quitting && result == nil && ((phase == 1 && stage == 4) || (phase == 2 && [0, 1, 500].contains(stage))) }
    public mutating func quit() { if canQuit { quitting = true; stage = -1 } }
    public var openSideVisible: Bool {
        Self.openOrientations.contains(angles)
    }
    public var canDislodgeBookmark: Bool {
        !openSideVisible && Self.tapOrientations.contains(angles)
    }
    private static let openOrientations: [SIMD3<Int>] = [
        .init(0, 90, 90), .init(0, 270, 270), .init(90, 0, 0), .init(90, 180, 180),
        .init(180, 90, 90), .init(180, 270, 270), .init(270, 0, 180), .init(270, 180, 0)
    ]
    private static let tapOrientations: [SIMD3<Int>] = [
        .init(90, 0, 270), .init(0, 0, 270), .init(0, 90, 270), .init(0, 180, 270),
        .init(270, 0, 90), .init(180, 0, 90), .init(180, 180, 90), .init(180, 270, 90)
    ]
    /// Rectangles initialized at 0x02200AC8, in portrait page coordinates.
    public var boxHitRect: SIMD4<Int> {
        let x = angles.x / 90, y = angles.y / 90, z = angles.z / 90
        if x % 2 == 1 { return (y + z) % 2 == 0 ? .init(44, 74, 142, 202) : .init(64, 60, 124, 216) }
        if y % 2 == 1 { return z % 2 == 0 ? .init(23, 110, 168, 172) : .init(31, 90, 154, 186) }
        if x == 0 && y == 2 && z == 1 { return .init(44, 74, 142, 202) }
        return z % 2 == 0 ? .init(20, 110, 162, 176) : .init(64, 70, 124, 216)
    }
    private static let arrows: [SIMD4<Int>] = [.init(80, 0, 112, 32), .init(0, 112, 32, 144),
        .init(80, 224, 128, 256), .init(160, 112, 192, 144)]
    private static func contains(_ rect: SIMD4<Int>, _ point: SIMD2<Int>) -> Bool {
        (rect.x...rect.z).contains(point.x) && (rect.y...rect.w).contains(point.y)
    }
    private mutating func finishRotation() {
        for i in 0..<3 { angles[i] = (angles[i] % 360 + 360) % 360 }
        // The original converts the two gimbal configurations to equivalent Euler angles.
        if angles.x == 90 && (angles.y == 90 || angles.y == 270) {
            angles.z = (angles.z + (angles.y == 90 ? 270 : 90)) % 360
            angles.y = 0
        } else if angles.x == 270 && (angles.y == 90 || angles.y == 270) {
            angles.z = (angles.z + (angles.y == 90 ? 90 : 270)) % 360
            angles.y = 0
        }
        rotationAxis = nil
    }
    public mutating func update(pageTouch: SIMD2<Int>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let touch = pageTouch.flatMap { (0..<192).contains($0.x) && (0..<256).contains($0.y) ? $0 : nil }
        let pressed = touch != nil && previousTouch == nil
        defer { previousTouch = touch }
        if quitting {
            if stage == -1 { stage = -2; return [.fadeOut(60)] }
            if fadeComplete { result = 1; return [.completed(1)] }
            return []
        }
        if phase == 0 { phase = 1; return [.fadeIn(60)] }
        if phase == 1 {
            if stage == 5 {
                if fadeComplete { phase = 2; stage = 0; previousTouch = nil; pullDelta = 0; return [.fadeIn(60)] }
                return []
            }
            for i in 0..<4 {
                if arrowAlpha[i] < 16 { arrowAlpha[i] += 1 }
                if arrowAlpha[i] > 15 { arrowAlpha[i] -= 1 }
            }
            if pressed, let touch, openSideVisible, taps >= 10,
               Self.contains(.init(32, 80, 160, 176), touch) {
                stage = 5; return [.fadeOut(60)]
            }
            let arrow = pressed ? touch.flatMap { point in Self.arrows.firstIndex { Self.contains($0, point) } } : nil
            var effects: [Effect] = []
            if pressed, let touch, arrow == nil, Self.contains(boxHitRect, touch) {
                shake = min(2.5, shake + 0.3)
                if canDislodgeBookmark { taps += 1 }
                effects.append(.sound(archive: 4, entry: 16))
            } else { shake = max(0, shake - 0.5) }
            if let axis = rotationAxis {
                angles[axis] += velocity
                timer -= 1
                if timer <= 0 { finishRotation() }
            } else if let arrow {
                arrowAlpha[arrow] = 31
                timer = 45
                if arrow == 1 || arrow == 3 { rotationAxis = 1; velocity = arrow == 1 ? -2 : 2 }
                else {
                    let sign = arrow == 0 ? 1 : -1
                    if angles.y == 0 { rotationAxis = 0; velocity = -2 * sign }
                    else if angles.y == 180 { rotationAxis = 0; velocity = 2 * sign }
                    else if (angles.x == 0 && angles.y == 90) || (angles.x == 180 && angles.y == 270) {
                        rotationAxis = 2; velocity = -2 * sign
                    } else if (angles.x == 0 && angles.y == 270) || (angles.x == 180 && angles.y == 90) {
                        rotationAxis = 2; velocity = 2 * sign
                    }
                }
            }
            return effects
        }
        if phase == 2 {
            var effects: [Effect] = []
            switch stage {
            case 0: if fadeComplete { stage = 1 }
            case 1:
                if pressed, let touch, Self.contains(.init(Int(bookmarkX), 124, Int(bookmarkX) + 82, 186), touch) { stage = 500 }
            case 500:
                if touch == nil { stage = 1; effects.append(.stopSound(archive: 1, entry: 39, frames: 5)) }
                else {
                    bookmarkX += Float(pullDelta)
                    if pullDelta != 0 { effects.append(.ensureSound(archive: 1, entry: 39)) }
                    if bookmarkX - 27 >= 32 { stage = 2; timer = 30 }
                }
            case 2:
                if timer > 0 { timer -= 1; bookmarkX += 0.5 }
                else { stage = 3; effects.append(.completionFade(60)) }
            case 3: stage = 4; timer = 120; effects.append(.sound(archive: 0, entry: 1))
            case 4: if timer > 0 { timer -= 1 } else { stage = 5; timer = 0 }
            case 5:
                timer += 1
                if timer % 4 == 0 { itemAlpha = min(31, itemAlpha + 1) }
                if timer > 299 { stage = 6; effects.append(.fadeOut(60)) }
            case 6: if fadeComplete { phase = 3 }
            default: break
            }
            // The source uses the preceding frame's delta and only accepts a slow rightward pull.
            if let touch, let previousTouch {
                let dx = touch.x - previousTouch.x
                pullDelta = dx > 1 && dx * dx <= 36 ? 1 : 0
            } else { pullDelta = 0 }
            return effects
        }
        if fadeComplete { result = 0; return [.completed(0)] }
        return []
    }
}
