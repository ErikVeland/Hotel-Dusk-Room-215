import Foundation

/**
 * Overlay 24 object selection and dragging, independent of process timing and presentation.
 */
public struct OriginalSuitcaseContents: Equatable, Sendable {
    public enum Compartment: Int, Sendable {
        case upper = 2
        case lower = 3
    }

    public struct Object: Equatable, Sendable {
        public let texture: String
        public let drawingOrigin: SIMD2<Float>
        public let textureSize: SIMD2<Float>
        public let initialPosition: SIMD2<Float>
        public let hitSize: SIMD2<Float>

        fileprivate init(_ texture: String, _ x: Float, _ y: Float, _ width: Float, _ height: Float,
                         _ positionX: Float, _ positionY: Float, _ hitWidth: Float, _ hitHeight: Float) {
            self.texture = texture
            drawingOrigin = SIMD2(x, y)
            textureSize = SIMD2(width, height)
            initialPosition = SIMD2(positionX, positionY)
            hitSize = SIMD2(hitWidth, hitHeight)
        }
    }

    public enum Selection: Equatable, Sendable {
        case drag(index: Int)
        case describe(response: Int16)
        case take(item: UInt8, responses: [Int16])
    }

    /**
     * 0x02203560 and 0x022038CC supply the upper layout and texture names.
     */
    public static let upperObjects: [Object] = [
        .init("_05map", 8, 64, 128, 152, 8, 64, 104, 152),
        .init("_06pamph", 121, 116, 64, 92, 121, 116, 64, 92),
        .init("_08receipt", 26, 123, 128, 64, 26, 123, 55, 105),
        .init("_13memo", 128, 128, 64, 50, 128, 128, 50, 64),
        .init("_15paper02", 74, 77, 128, 74, 74, 77, 74, 115),
        .init("_12photo", 46, 150, 64, 64, 46, 150, 64, 64)
    ]

    /**
     * 0x02203620 and 0x022038FC supply the lower layout and texture names.
     */
    public static let lowerObjects: [Object] = [
        .init("_02shirt", 64, 32, 128, 200, 64, 32, 128, 200),
        .init("_03tie", 74, 92, 128, 106, 74, 92, 106, 128),
        .init("_01Wisky", 9, 113, 64, 38, 9, 113, 38, 64),
        .init("_04money", 1, 192, 64, 48, 1, 192, 48, 64),
        .init("_07belt", 1, 103, 128, 80, 1, 103, 80, 128),
        .init("_09pencil", 1, 224, 16, 80, 1, 216, 80, 32),
        .init("_10key217", 91, 139, 64, 44, 91, 139, 44, 64),
        .init("_11sock", 1, 40, 64, 64, 1, 40, 64, 64),
        .init("_16shaver", 77, 158, 64, 36, 77, 158, 36, 64),
        .init("_17bundle", 111, 36, 64, 77, 111, 36, 77, 64),
        .init("_18redbox", 1, 62, 64, 74, 1, 62, 74, 64)
    ]

    public private(set) var upperPositions = upperObjects.map(\.initialPosition)
    public private(set) var lowerPositions = lowerObjects.map(\.initialPosition)
    public private(set) var selected: Int?
    public private(set) var previousSelected: Int?
    public private(set) var grabOffset = SIMD2<Float>.zero
    public private(set) var dragging = false
    private var dragCompartment: Compartment?
    private let lowerHitMasks: [Data]

    /**
     * Supply the original A3I5 texels, before colour expansion or image rotation.
     */
    public init(lowerHitMasks: [Data]) throws {
        guard lowerHitMasks.count == Self.lowerObjects.count,
              zip(lowerHitMasks, Self.lowerObjects).allSatisfy({ mask, object in
                  mask.count >= Int(object.textureSize.x * object.textureSize.y)
              }) else {
            throw OriginalDataError.invalid("Suitcase contents hit masks")
        }
        self.lowerHitMasks = lowerHitMasks
    }

    public static func objects(in compartment: Compartment) -> [Object] {
        compartment == .upper ? upperObjects : lowerObjects
    }

    public func positions(in compartment: Compartment) -> [SIMD2<Float>] {
        compartment == .upper ? upperPositions : lowerPositions
    }

    /**
     * 0x02201EA4 and 0x02202084 share the drawing visibility conditions.
     */
    public func visibleIndices(in compartment: Compartment, game: OriginalGameState) throws -> [Int] {
        let held = Set(try game.inventory.items)
        func flag(_ index: UInt16) -> Bool { game.value(for: .gameFlag(index: index)) == true }
        return Self.objects(in: compartment).indices.filter { index in
            if compartment == .upper {
                switch index {
                case 3: return (flag(44) || flag(45)) && !held.contains(13) && !held.contains(63)
                case 5: return !held.contains(18)
                default: return true
                }
            }
            switch index {
            case 3: return !held.contains(23)
            case 4: return flag(51) && !held.contains(49)
            case 5: return !held.contains(44)
            case 6: return flag(47) && !held.contains(45)
            case 9: return game.chapter < 5 && flag(40) && !held.contains(28)
            case 10: return flag(46) && !held.contains(14)
            default: return true
            }
        }
    }

    /**
     * Upper objects use rectangles. Lower objects use alpha, except for the pencil.
     */
    public func hit(page point: SIMD2<Float>, in compartment: Compartment,
                    game: OriginalGameState) throws -> Int? {
        guard point.x.isFinite, point.y.isFinite, point.x >= 0, point.x < 192,
              point.y >= 0, point.y < 256 else { return nil }
        let x = Int(point.x), y = Int(point.y)
        if compartment == .upper && y > 166 && y < 184 { return nil }
        let objects = Self.objects(in: compartment), positions = positions(in: compartment)
        let visible = try visibleIndices(in: compartment, game: game)
        let order = compartment == .upper ? Array(visible.reversed()) : visible
        var found: Int?
        for index in order {
            let position = positions[index], size = objects[index].hitSize
            guard x >= Int(position.x), x <= Int(position.x + size.x),
                  y >= Int(position.y), y <= Int(position.y + size.y) else { continue }
            if compartment == .lower && index != 5 {
                let dx = x - Int(position.x), dy = y - Int(position.y)
                let offset = index == 0 ? Int(size.x) * dy + dx : Int(size.y) * (dx + 1) - dy
                let mask = lowerHitMasks[index]
                guard mask.indices.contains(offset), mask[offset] >> 5 != 0 else { continue }
            }
            found = index
        }
        return found
    }

    /**
     * A second selection inspects the same object, even after the double-tap timer expires.
     */
    public mutating func beginTouch(page point: SIMD2<Float>, in compartment: Compartment,
                                   game: OriginalGameState) throws -> Selection? {
        previousSelected = selected
        selected = try hit(page: point, in: compartment, game: game)
        dragging = false
        dragCompartment = nil
        guard let selected else { return nil }
        grabOffset = SIMD2(Float(Int(point.x)), Float(Int(point.y))) - positions(in: compartment)[selected]
        guard selected == previousSelected else {
            dragging = true
            dragCompartment = compartment
            return .drag(index: selected)
        }
        return action(for: selected, in: compartment, game: game)
    }

    /**
     * 0x02202D90 moves one quarter of the remaining distance and clamps the hit rectangle.
     */
    public mutating func drag(page point: SIMD2<Float>, in compartment: Compartment) {
        guard dragging, dragCompartment == compartment, let selected, point.x.isFinite, point.y.isFinite,
              point.x >= 0, point.x < 192, point.y >= 0, point.y < 256 else { return }
        var position = positions(in: compartment)[selected]
        let size = Self.objects(in: compartment)[selected].hitSize
        let touch = SIMD2(Float(Int(point.x)), Float(Int(point.y)))
        position += (touch - position - grabOffset) * 0.25
        position.x = min(max(position.x, 0), 192 - size.x)
        position.y = min(max(position.y, 0), 256 - size.y)
        if compartment == .upper { upperPositions[selected] = position }
        else { lowerPositions[selected] = position }
    }

    public mutating func endDrag() {
        dragging = false
        dragCompartment = nil
        grabOffset = .zero
    }

    /**
     * 0x021FD19C clears selection when control passes to the shared response script.
     */
    public mutating func clearSelection() {
        selected = nil
        endDrag()
    }

    /**
     * 0x02202518 selects System mode 20 with pair A = 12 and these response IDs.
     */
    private func action(for index: Int, in compartment: Compartment, game: OriginalGameState) -> Selection {
        func flag(_ id: UInt16) -> Bool { game.value(for: .gameFlag(index: id)) == true }
        if compartment == .upper {
            if index == 5 && flag(6) { return .take(item: 18, responses: [13, 17]) }
            if index == 3 && flag(45) { return .take(item: 63, responses: [21]) }
            if index == 3 && flag(44) { return .take(item: 13, responses: [21]) }
            return .describe(response: [5, 6, 8, 104, 15, 12][index])
        }
        if index == 3 { return .take(item: 23, responses: [20]) }
        if index == 5 && flag(29) { return .take(item: 44, responses: [10]) }
        if index == 9 && flag(40) { return .take(item: 28, responses: [4]) }
        if index == 10 && flag(46) { return .take(item: 14, responses: [22]) }
        if index == 6 && flag(47) { return .take(item: 45, responses: [23]) }
        return .describe(response: [2, 3, 1, 19, 7, 9, 100, 11, 16, 18, 102][index])
    }
}
