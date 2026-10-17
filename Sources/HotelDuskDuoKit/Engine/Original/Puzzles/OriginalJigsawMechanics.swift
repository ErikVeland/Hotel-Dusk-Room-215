import Foundation

/// Native piece rules from overlay 2, 0x021FDB30 / 0x02200E04 / 0x02201130.
/// Positions are original signed 20.12 world coordinates, not screen pixels.
/// The caller supplies source positions and performs the original ray hit test.
public struct OriginalJigsawMechanics: Equatable, Codable, Sendable {
    public struct Position: Equatable, Codable, Sendable {
        public var x: Int32
        public var y: Int32
        public init(x: Int32, y: Int32) { self.x = x; self.y = y }
    }
    public struct Piece: Equatable, Codable, Sendable {
        public var position: Position
        public var depth: Int32
        /// Half-turn units: the source's seated orientation is exactly 1.5.
        public var rotation: Float
        public var loose: UInt8
        public init(position: Position, depth: Int32, rotation: Float, loose: UInt8) {
            self.position = position; self.depth = depth; self.rotation = rotation; self.loose = loose
        }
    }
    public private(set) var pieces: [Piece]
    public let targets: [Position]
    public private(set) var selected: Int?
    public private(set) var rotationTarget: Float?

    public init(pieces: [Piece], targets: [Position], selected: Int? = nil,
                rotationTarget: Float? = nil) throws {
        guard pieces.count == 20, targets.count == 20,
              pieces.allSatisfy({ $0.rotation.isFinite && (-0.5...2.5).contains($0.rotation) }),
              selected.map({ pieces.indices.contains($0) }) ?? true,
              rotationTarget.map({ $0.isFinite && (-0.5...2.5).contains($0) && selected != nil }) ?? true else {
            throw OriginalDataError.invalid("Original jigsaw state")
        }
        self.pieces = pieces; self.targets = targets
        self.selected = selected; self.rotationTarget = rotationTarget
    }

    private enum CodingKeys: String, CodingKey { case pieces, targets, selected, rotationTarget }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(pieces: values.decode([Piece].self, forKey: .pieces),
                      targets: values.decode([Position].self, forKey: .targets),
                      selected: values.decodeIfPresent(Int.self, forKey: .selected),
                      rotationTarget: values.decodeIfPresent(Float.self, forKey: .rotationTarget))
    }

    /// The hit-test layer provides the topmost original piece index.
    public mutating func select(hitIndex: Int) throws {
        guard pieces.indices.contains(hitIndex) else { throw OriginalDataError.invalid("Jigsaw hit index") }
        guard rotationTarget == nil, !isSeated(hitIndex) else { return }
        selected = hitIndex
        let oldDepth = pieces[hitIndex].depth
        if oldDepth != 4 {
            for index in pieces.indices where index != hitIndex && pieces[index].depth > oldDepth {
                pieces[index].depth &-= 4
            }
            pieces[hitIndex].depth = 4
        }
    }

    /// Original ray/plane intersection minus the original pointer grab offset.
    public mutating func drag(to position: Position) {
        guard let index = selected, rotationTarget == nil else { return }
        pieces[index].position.x = min(4096, max(-8192, position.x))
        pieces[index].position.y = min(4096, max(-12288, position.y))
    }

    /// Returns the original seat sound request when a placement succeeds.
    /// Overlay 2 calls SSAR archive 26, entry 0 at 0x021FDF90.
    @discardableResult
    public mutating func release() -> Bool {
        guard let index = selected, rotationTarget == nil else { return false }
        let sourceX = Float(pieces[index].position.x) / 4096 + 0.5
        let sourceY = Float(pieces[index].position.y) / 4096 + 0.5
        let targetX = Float(targets[index].x) / 4096 + Float(bitPattern: 0x3e99999a)
        let targetY = Float(targets[index].y) / 4096 + Float(bitPattern: 0x3e99999a)
        let dx = sourceX - targetX, dy = sourceY - targetY
        let distance = dx * dx + dy * dy
        guard distance < Float(bitPattern: 0x3db851ec), pieces[index].rotation == 1.5 else { return false }
        pieces[index].position = seatedPosition(index)
        pieces[index].loose = 0
        selected = nil
        return true
    }

    public mutating func rotate(increasing: Bool) {
        guard let index = selected, rotationTarget == nil else { return }
        rotationTarget = pieces[index].rotation + (increasing ? 0.5 : -0.5)
    }

    /// One original update; rotation is eased over frames, not changed instantly.
    public mutating func updateRotation() {
        guard let index = selected, let target = rotationTarget else { return }
        let angle = pieces[index].rotation
        let epsilon = Float(bitPattern: 0x3c23d70a)
        if target < angle + epsilon && target > angle - epsilon {
            var wrapped = target
            while wrapped < 0 { wrapped += 2 }
            while wrapped >= 2 { wrapped -= 2 }
            pieces[index].rotation = wrapped
            rotationTarget = nil
        } else {
            let delta = target - angle
            let step = Float(bitPattern: 0x3e99999a) * delta
            pieces[index].rotation = angle + step
        }
    }

    public func isSeated(_ index: Int) -> Bool {
        guard pieces.indices.contains(index) else { return false }
        return pieces[index].position == seatedPosition(index) && pieces[index].rotation == 1.5
    }
    public var isAssembled: Bool { pieces.indices.allSatisfy(isSeated) }

    private func seatedPosition(_ index: Int) -> Position {
        func fixed(_ source: Int32) -> Int32 {
            let center = Float(source) / 4096 + Float(bitPattern: 0x3e99999a)
            let origin = center - 0.5
            let scaled = origin * 4096
            return Int32(scaled + (origin > 0 ? 0.5 : -0.5))
        }
        return Position(x: fixed(targets[index].x), y: fixed(targets[index].y))
    }
}
