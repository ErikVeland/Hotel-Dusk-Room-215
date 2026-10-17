import Foundation

/**
 * Process 32, overlay 4. Cut selection and animation timing remain separate from rendering.
 */
public struct OriginalHangerProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int), fadeOut(Int), completionFade(Int)
        case sound(Int), markCompleted, completed(Int16)
    }

    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var animationFrame = 0
    public private(set) var cutting = OriginalHangerCuts()
    public private(set) var severed: Set<Int> = []
    public private(set) var cameraBounds = SIMD4<Int32>(-5468, -4096, 5468, 4096)
    public private(set) var pliersOpening: Float = 0
    public private(set) var pliersPosition = SIMD3<Int32>(0, 0, 20480)
    public private(set) var pliersRotation: Float = 0
    public private(set) var returnValue: Int16 = 2
    public private(set) var result: Int16?
    private var wasDown = false
    private var exitDelay = 0

    public init() {}

    public var canQuit: Bool { phase == 1 && result == nil }

    public mutating func quit() {
        guard canQuit else { return }
        phase = 5
        stage = 0
    }

    /**
     * 0x021FD44C dispatches idle, cut and exit updates. The caller supplies fade completion.
     */
    @discardableResult
    public mutating func update(pageTouch: SIMD2<Float>? = nil, fadeComplete: Bool = false) -> [Effect] {
        guard result == nil else { return [] }
        let pressed = pageTouch != nil && !wasDown
        wasDown = pageTouch != nil
        switch phase {
        case 0:
            phase = 1
            return [.fadeIn(60)]
        case 1:
            if pressed, let pageTouch, cutting.cut(at: pageTouch) != nil {
                phase = 3
                stage = 0
                returnValue = 1
            }
        case 3: return advanceCut()
        case 5:
            if stage == 0 { stage = 1; return [.fadeOut(60)] }
            if stage == 1, fadeComplete { stage = 2; exitDelay = 30 }
            else if stage == 2 {
                exitDelay -= 1
                if exitDelay < 1 {
                    stage = 0
                    result = returnValue
                    return [.completed(returnValue)]
                }
            }
        default: break
        }
        return []
    }

    /**
     * 0x021FD95C moves the camera in, cuts the wire, then moves the camera out.
     */
    private mutating func advanceCut() -> [Effect] {
        var effects: [Effect] = []
        switch stage {
        case 0:
            stage = 1
        case 1:
            moveCamera(returning: false)
            animationFrame += 1
            if animationFrame > 60 { animationFrame = 0; stage = 2 }
        case 2:
            positionPliers()
            pliersOpening = 0.2
            stage = 3
        case 3:
            if pliersOpening > 0, animationFrame < 15 { pliersOpening -= 0.01 }
            if animationFrame == 30 {
                effects.append(.sound(32))
                if cutting.producesUsableWire {
                    returnValue = 0
                    effects.append(.completionFade(60))
                }
            }
            if animationFrame > 30 { pliersOpening = 0 }
            animationFrame += 1
            if animationFrame > (cutting.producesUsableWire ? 30 : 60) {
                animationFrame = 0
                stage = 4
                severed.insert(cutting.cuts.count - 1)
                if cutting.producesUsableWire { effects.append(.markCompleted) }
            }
        case 4:
            stage = 5
        case 5:
            if animationFrame < 60 { moveCamera(returning: true) }
            animationFrame += 1
            if animationFrame > (cutting.cuts.count == 2 ? 120 : 60) {
                animationFrame = 0
                stage = 0
                phase = cutting.cuts.count == 2 ? 5 : 1
            }
        default: break
        }
        return effects
    }

    /**
     * 0x021FE51C stores rounded orthographic bounds in DS screen order.
     * The return path retains its frame-59 camera after the movement ends.
     */
    private mutating func moveCamera(returning: Bool) {
        guard let cut = cutting.cuts.last else { return }
        let fraction = min(Float(animationFrame) / 45, 1)
        let amount = Int64((fraction * 4096).rounded(.toNearestOrAwayFromZero))
        let start = returning ? cut.position : SIMD2<Int32>.zero
        let delta = returning ? SIMD2<Int32>.zero &- cut.position : cut.position
        let centre = SIMD2<Float>((0..<2).map {
            Float(start[$0] + Int32((Int64(delta[$0]) * amount + 2048) >> 12)) / 4096
        })
        let zoom: Float = returning ? 5 - Float(animationFrame) / 15 : 1 + Float(animationFrame) / 15
        let horizontal = Float(bitPattern: 0x3FAAE3DA) / zoom
        let vertical: Float = 1 / zoom
        let bounds = SIMD4(-horizontal + centre.y, -vertical + centre.x,
                          horizontal + centre.y, vertical + centre.x)
        cameraBounds = SIMD4((0..<4).map { Int32((bounds[$0] * 4096).rounded(.toNearestOrAwayFromZero)) })
    }

    /**
     * 0x02203C5C offsets the pliers by 0.08 units along the selected wire's normal.
     * Its rotation uses the signed angle calculation at 0x02025464.
     */
    private mutating func positionPliers() {
        guard let cut = cutting.cuts.last else { return }
        let quad = OriginalHangerCuts.hitQuads[cut.region]
        let start = SIMD2<Float>(quad[0] &+ quad[1]) * 0.5 / 4096
        let end = SIMD2<Float>(quad[2] &+ quad[3]) * 0.5 / 4096
        let direction = end - start
        let factor: Float = 0.08 / (direction.x * direction.x + direction.y * direction.y).squareRoot()
        let normal = SIMD2(direction.y * factor, -direction.x * factor)
        let point = SIMD2<Float>(cut.position) / 4096
        let position = cut.region >= 2 ? point + normal : point - normal
        pliersPosition.x = Int32((position.x * 4096).rounded(.toNearestOrAwayFromZero))
        pliersPosition.y = Int32((position.y * 4096).rounded(.toNearestOrAwayFromZero))
        let towardsCut = point - position
        let length = (towardsCut.x * towardsCut.x + towardsCut.y * towardsCut.y).squareRoot()
        let cosine = -towardsCut.y / length
        var angle = Float(acos(Double(min(1, max(-1, cosine)))))
        if towardsCut.x > 0 { angle = Float.pi + (Float.pi - angle) }
        pliersRotation = 1.5 + angle / Float.pi
    }
}
