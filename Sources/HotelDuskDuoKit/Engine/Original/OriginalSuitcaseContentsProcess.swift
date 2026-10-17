import Foundation

/**
 * Process 35, overlay 24: suitcase inspection, item acquisition and shared responses.
 */
public struct OriginalSuitcaseContentsProcess: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case fadeIn(Int)
        case fadeOut(Int)
        case sound(archive: Int, entry: Int)
        case stopDragSound
        case dragVolume(Int)
        case award(UInt8)
        case response(Int16)
        case completed(Int16)
    }

    public private(set) var contents: OriginalSuitcaseContents
    public private(set) var phase = 0
    public private(set) var stage = 0
    public private(set) var itemStage = 0
    public private(set) var timer = 0
    public private(set) var item: UInt8?
    public private(set) var itemShade = 0
    public private(set) var itemVisible = false
    public private(set) var itemScale: Float = 0
    public private(set) var lidRotation: Float = 0.46
    public private(set) var awaitingResponse = false
    public private(set) var result: Int16?
    private var responses: [Int16] = []
    private var wasTouchDown = false
    private var backRequested = false
    private var previousTouch: SIMD2<Float>?
    private var touchDelta = SIMD2<Int>.zero

    public init(contents: OriginalSuitcaseContents) { self.contents = contents }

    public var compartment: OriginalSuitcaseContents.Compartment? { .init(rawValue: phase) }
    public var canGoBack: Bool {
        !awaitingResponse && result == nil && ((phase == 1 && stage == 3) ||
            (compartment != nil && (stage == 1 || stage == 500)))
    }

    public mutating func goBack() {
        guard canGoBack else { return }
        backRequested = true
    }

    public mutating func finishResponse() { awaitingResponse = false }

    /**
     * Native resource upload completion is supplied separately from original animation counters.
     */
    @discardableResult
    public mutating func update(pageTouch: SIMD2<Float>? = nil, game: OriginalGameState,
                               fadeComplete: Bool = true, itemTextureReady: Bool = true) throws -> [Effect] {
        guard result == nil, !awaitingResponse else { return [] }
        let pageTouch = pageTouch.flatMap { point in
            point.x.isFinite && point.y.isFinite && point.x >= 0 && point.x < 192 && point.y >= 0 && point.y < 256 ? point : nil
        }
        defer {
            if let point = pageTouch, let previousTouch {
                let delta = SIMD2(Int(point.x) - Int(previousTouch.x), Int(point.y) - Int(previousTouch.y))
                let squared = delta.x * delta.x + delta.y * delta.y
                touchDelta = squared > 64 ? SIMD2(delta.x * 64 / squared, delta.y * 64 / squared) : delta
            } else { touchDelta = .zero }
            previousTouch = pageTouch
        }
        let newTouch = wasTouchDown ? nil : pageTouch
        wasTouchDown = pageTouch != nil
        if phase == 0 {
            phase = 1
            return [.fadeIn(60)]
        }
        if phase == 1 {
            switch stage {
            case 0: if fadeComplete { stage = 3 }
            case 3:
                if backRequested {
                    backRequested = false
                    stage = 1000
                } else if fadeComplete, let point = newTouch {
                    if point.x > 59 && point.x < 133 && point.y > 73 && point.y < 134 { stage = 800 }
                    else if point.x > 56 && point.x < 136 && point.y > 145 && point.y < 175 { stage = 900 }
                    if stage != 3 { return [.fadeOut(60)] }
                }
            case 800, 900:
                if fadeComplete {
                    phase = stage == 800 ? 2 : 3
                    stage = 0
                    return [.fadeIn(60)]
                }
            case 1000:
                stage = 1001
                timer = 60
            case 1001:
                if timer < 1 {
                    lidRotation = 0
                    stage = 1002
                    return [.fadeOut(60), .sound(archive: 1, entry: 55)]
                }
                timer -= 1
                lidRotation -= Float(bitPattern: 0x3BFB38AA)
            case 1002:
                if fadeComplete {
                    result = 0
                    return [.completed(0)]
                }
            default: break
            }
            return []
        }
        guard let compartment else { return [] }
        if backRequested {
            backRequested = false
            contents.endDrag()
            stage = 3
            return [.stopDragSound, .fadeOut(60)]
        }
        switch stage {
        case 0:
            if fadeComplete { stage = 1; timer = -15 }
        case 1:
            if timer < 0 { timer += 1 }
            else if let point = newTouch,
                    let selection = try contents.beginTouch(page: point, in: compartment, game: game) {
                switch selection {
                case .drag:
                    stage = 500
                    return [.sound(archive: 1, entry: 8), .sound(archive: 0, entry: 38)]
                case .describe(let response):
                    responses = [response]
                    stage = 100
                    timer = 30
                case .take(let taken, let responseIDs):
                    item = taken
                    responses = responseIDs
                    stage = 2
                    itemStage = 0
                }
                return [.sound(archive: 1, entry: 8)]
            }
        case 2: return updateItem(textureReady: itemTextureReady)
        case 3:
            if fadeComplete {
                phase = 1
                stage = 3
                lidRotation = 0.46
                return [.fadeIn(60)]
            }
        case 100:
            timer -= 1
            if timer < 1 {
                timer = 0
                stage = 200
                return startResponse()
            }
        case 200:
            if timer == 30 { timer = 0; stage = 1 }
            else { timer += 1 }
        case 500:
            if let pageTouch {
                contents.drag(page: pageTouch, in: compartment)
                return [.dragVolume(abs(touchDelta.x) >= 3 || abs(touchDelta.y) >= 3 ? 127 : 0)]
            }
            else {
                contents.endDrag()
                stage = 1
                return [.stopDragSound]
            }
        default: break
        }
        return []
    }

    private mutating func startResponse() -> [Effect] {
        guard !responses.isEmpty else { return [] }
        let response = responses.removeFirst()
        contents.clearSelection()
        awaitingResponse = true
        wasTouchDown = false
        return [.response(response)]
    }

    /**
     * 0x02202A6C controls the shade, scale, hold, dialogue and restoration counters.
     */
    private mutating func updateItem(textureReady: Bool) -> [Effect] {
        switch itemStage {
        case 0:
            timer = 0
            itemStage = 10
            return item.map { [.award($0)] } ?? []
        case 10: if textureReady { itemStage = 1 }
        case 1:
            itemShade += 1
            if itemShade > 14 {
                itemShade = 15
                itemVisible = true
                itemStage = 2
            }
        case 2:
            if itemScale < 1 { itemScale += 0.05 }
            timer += 1
            if timer > 39 { timer = 30; itemStage = 3 }
        case 3:
            timer -= 1
            if timer < 1 {
                timer = 0
                itemStage = 4
                return [.sound(archive: 0, entry: 7)] + startResponse()
            }
        case 4:
            if !responses.isEmpty { return startResponse() }
            itemVisible = false
            itemScale = 0
            timer = 30
            itemStage = 5
        case 5:
            if itemShade > 0 { itemShade -= 1 }
            timer -= 1
            if timer < 1 { itemStage = 0; stage = 1 }
        default: break
        }
        return []
    }
}
