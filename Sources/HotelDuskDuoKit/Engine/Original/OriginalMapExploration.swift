import Foundation
import simd

/**
 * Recovered lobby and corridor walking, with the R102 counter. Coordinates use original 20.12 units.
 */
public struct OriginalMapExploration {
    private static let originalPi = Float(bitPattern: 0x40490FDB)
    public enum Mode: Equatable { case walking, counter }
    public let mapID: Int16
    public static let supportedMaps = OriginalMapCatalog.maps.mapValues(\.name)
    /**
     * Name order in 0x020FAB2C, used by 0x0209C04C to resolve model markers.
     */
    static let mapNames = ["NONE"] + (101...126).map { "R\($0)" }
        + (201...213).map { "R\($0)" } + (301...305).map { "R\($0)" } + ["R401", "R402"]
    // Walk-through exits still run the original departure event before loading the destination.
    private static let exitMaps = Dictionary(uniqueKeysWithValues: supportedMaps.map {
        ("in_" + $0.value.lowercased(), $0.key)
    })
    public private(set) var searchAreaID: UInt16
    public var mapName: String { Self.supportedMaps[mapID]! }
    /**
     * Map origin table 0x020E02AC, including the eight-pixel vertical marker offset.
     */
    public var mapOrigin: SIMD2<Float> { OriginalMapCatalog.maps[mapID]!.origin }

    /**
     * Pixels per world unit from the original map scale table at 0x020DFF60.
     */
    public var mapScale: Float { OriginalMapCatalog.maps[mapID]!.scale }

    /**
     * 0x02037020 loads tiles from pixel/8 minus (16,24). The rotated viewport starts at (96,192).
     */
    public var mapBitmapOffset: SIMD2<Float> {
        let point = mapOrigin + SIMD2(position.x, position.z) / 4096 * mapScale
        // 256×256 room maps omit the large-map tile origin offsets (0x02037020).
        let origin: SIMD2<Float> = OriginalMapCatalog.maps[mapID]!.compact ? SIMD2(-32, 0) : SIMD2(96, 192)
        let scroll = OriginalMapCatalog.maps[mapID]!.compact ? simd_clamp(point, SIMD2(repeating: -96), SIMD2(repeating: 96)) : point
        return origin - SIMD2(Float(Int(scroll.x)), Float(Int(scroll.y)))
    }
    public private(set) var mode: Mode = .walking
    public private(set) var position = SIMD3<Float>(-82, 12288, 21217)
    public private(set) var facing: Float = .pi
    /**
     * 0x0202CE5C retains the frame's starting heading in controller +0x14600 for state checkpoints.
     * The corridor arrival capture keeps this field at zero until the first walking update.
     */
    public private(set) var checkpointFacing: Float = 0
    public private(set) var pan: Float = 0
    public private(set) var selectedNode: String?
    public private(set) var selectedPoint: SIMD2<Float>?
    public let collision: OriginalMapCollision
    public let room: OriginalModel
    public private(set) var counter: OriginalModel
    public let restrictions: OriginalMapRestrictions
    public let objectVisibility: OriginalObjectVisibility
    private var target: SIMD3<Float>
    private var front: SIMD3<Float>
    private var camera1: OriginalModelCameraMarkers?
    private var camera2: OriginalModelCameraMarkers?
    private var previousPosition = SIMD3<Float>(-82, 12288, 21217)

    public init(collision: OriginalMapCollision, room: OriginalModel, counter: OriginalModel,
                restrictions: OriginalMapRestrictions, objectVisibility: OriginalObjectVisibility,
                mapID: Int16 = 2, previousMapID: Int16 = 1, savedGame: OriginalGameState? = nil) throws {
        guard Self.supportedMaps[mapID] != nil else { throw OriginalDataError.unsupported("Map \(mapID)") }
        self.mapID = mapID
        searchAreaID = OriginalMapCatalog.maps[mapID]!.searchArea
        self.collision = collision
        self.room = room
        self.counter = counter
        self.restrictions = restrictions
        self.objectVisibility = objectVisibility
        target = position
        front = position
        if searchAreaID != 0 {
            let marker = String(format: "s%02d", searchAreaID)
            guard let node = room.nodes.first(where: { $0.name == marker }),
                  let frontNode = room.nodes.first(where: { $0.name == marker + "f" }) else {
                throw OriginalDataError.missing("Map \(mapID) search markers")
            }
            target = SIMD3(Float(node.worldFixed[12]), 12288, Float(node.worldFixed[14]))
            front = SIMD3(Float(frontNode.worldFixed[12]), 12288, Float(frontNode.worldFixed[14]))
            camera1 = try counter.cameraMarkers(index: 1)
            camera2 = try counter.cameraMarkers(index: 2)
        }
        if let savedGame, savedGame.mapID == mapID {
            position = savedGame.mapPosition
            facing = savedGame.facing
        } else if !(mapID == 2 && previousMapID == 1) {
            guard let previousName = Self.supportedMaps[previousMapID]?.lowercased() else {
                throw OriginalDataError.missing("Previous map \(previousMapID)")
            }
            // 0x0202AF14 starts at the room origin when a scripted move has no entry marker.
            guard let marker = room.nodes.first(where: { $0.name == "out_\(previousName)" }) else {
                position = SIMD3(0, 12288, 0)
                facing = 0
                previousPosition = position
                return
            }
            position = SIMD3(Float(marker.worldFixed[12]), 12288, Float(marker.worldFixed[14]))
            // 0x0209D828: fixed-point normalised X axis, then signed acos.
            let x = Float(marker.worldFixed[0]), z = Float(marker.worldFixed[2])
            let length = hypot(x, z)
            guard length > 0 else { throw OriginalDataError.invalid("Map entry orientation") }
            facing = acos(min(1, max(-1, (x / length * 4096).rounded() / 4096)))
            if z > 0 { facing = -facing }
        }
        previousPosition = position
    }

    mutating func restoreCheckpointFacing(_ value: Float) {
        checkpointFacing = value
    }

    /**
     * 0x0202C264 request 9 moves Kyle to a hyde_pointNN marker through 0x0209D794.
     */
    public mutating func relocate(to markerID: Int) throws -> Bool {
        guard let marker = room.nodes.first(where: { $0.name == String(format: "hyde_point%02d", markerID) }) else { return false }
        let x = Float(marker.worldFixed[0]), z = Float(marker.worldFixed[2])
        let length = hypot(x, z)
        guard length > 0 else { throw OriginalDataError.invalid("Map placement orientation") }
        position = SIMD3(Float(marker.worldFixed[12]), 12288, Float(marker.worldFixed[14]))
        previousPosition = position
        facing = acos(min(1, max(-1, (x / length * 4096).rounded() / 4096)))
        if z > 0 { facing = -facing }
        checkpointFacing = facing
        return true
    }

    public static func bundled(mapID: Int16 = 2, previousMapID: Int16 = 1, savedGame: OriginalGameState? = nil) throws -> Self {
        guard Self.supportedMaps[mapID] != nil else { throw OriginalDataError.unsupported("Map \(mapID)") }
        let name = Self.supportedMaps[mapID]!
        let models = try OriginalModelLibrary.bundled()
        guard let root = Bundle.module.url(forResource: "GameData", withExtension: nil) else {
            throw OriginalDataError.missing("GameData")
        }
        struct Manifest: Decodable {
            struct File: Decodable { let name: String; let sha256: String }
            let files: [File]
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        let cellarPassage = mapID == 8 && savedGame?.value(for: .gameFlag(index: 31)) == true
        let variant = cellarPassage ? "a" : ""
        let collisionName = "\(name)\(variant).col"
        let data = try Data(contentsOf: root.appendingPathComponent(collisionName))
        guard let record = manifest.files.first(where: { $0.name == collisionName }),
              OriginalScriptCatalog.digest(data) == record.sha256 else { throw OriginalDataError.checksum(collisionName) }
        let area = String(format: "%02d", OriginalMapCatalog.maps[mapID]!.searchArea)
        let room = try models.load(path: "map/\(name)/\(name)\(variant)/\(name).mdf")
        let counter = area == "00" ? room : try models.load(path: "map/\(name)/\(name)_s\(area)\(variant)/\(name)_s\(area).mdf")
        return try Self(collision: .init(data: data), room: room, counter: counter, restrictions: .bundled(),
            objectVisibility: .bundled(), mapID: mapID, previousMapID: previousMapID, savedGame: savedGame)
    }

    /**
     * 0x0202E4B8 checks the search polygon and a 45-degree facing cone towards its model marker.
     */
    public var nearbySearchArea: UInt16? {
        guard mode == .walking else { return nil }
        for region in collision.matchingRegions(containing: position, prefix: "search").prefix(2) {
            guard let area = UInt16(region.dropFirst(6).prefix(2)),
                  let marker = room.nodes.first(where: { $0.name == String(format: "s%02d", area) }) else { continue }
            let delta = SIMD3(Float(marker.worldFixed[12]), 12288, Float(marker.worldFixed[14])) - position
            if simd_length_squared(delta) == 0 ||
                simd_dot(simd_normalize(delta), SIMD3(sin(facing), 0, cos(facing))) > cos(.pi / 4) { return area }
        }
        return nil
    }

    public var canInspectCounter: Bool { nearbySearchArea != nil }

    public func canInspectCounter(in game: OriginalGameState) -> Bool {
        guard let area = nearbySearchArea else { return false }
        return restrictions.permitsSearch(area: Int16(area), game: game)
    }

    /**
     * The host supplies the original model for the selected search area.
     */
    public mutating func prepareSearch(area: UInt16, model: OriginalModel) throws {
        guard nearbySearchArea == area,
              let marker = room.nodes.first(where: { $0.name == String(format: "s%02d", area) }),
              let frontMarker = room.nodes.first(where: { $0.name == String(format: "s%02df", area) }) else {
            throw OriginalDataError.invalid("Search area is not available")
        }
        let first = try model.cameraMarkers(index: 1), second = try model.cameraMarkers(index: 2)
        searchAreaID = area
        counter = model
        target = SIMD3(Float(marker.worldFixed[12]), 12288, Float(marker.worldFixed[14]))
        front = SIMD3(Float(frontMarker.worldFixed[12]), 12288, Float(frontMarker.worldFixed[14]))
        camera1 = first
        camera2 = second
    }

    public var eventRegion: UInt16? {
        guard mode == .walking, let name = collision.firstRegion(containing: position, prefix: "event") else { return nil }
        return UInt16(name.dropFirst(5).prefix(2))
    }

    public var exitMapID: Int16? {
        guard mode == .walking, let name = collision.firstRegion(containing: position, prefix: "in_") else { return nil }
        return Self.exitMaps[name]
    }

    /**
     * A cancelled departure restores the previous frame's position (+0x15520).
     */
    public mutating func cancelDeparture() { position = previousPosition }


    /**
     * Resolves original person records against this room's character markers.
     */
    public func people(in game: OriginalGameState) -> [(id: Int16, marker: Int, position: SIMD3<Float>)] {
        (0..<18).compactMap { person in
            guard let key = game.personMarker(person),
                  let node = room.nodes.first(where: { $0.name == String(format: "chara_point%04d", key) }) else { return nil }
            return (Int16(person), key, SIMD3(Float(node.worldFixed[12]), 0, Float(node.worldFixed[14])))
        }
    }

    /**
     * 0x0202E740 chooses a person within the distance limit and 45-degree cone.
     */
    public func nearbyPerson(in game: OriginalGameState) -> Int16? {
        guard mode == .walking else { return nil }
        var nearest: Float = 23757
        var selected: Int16?
        for person in people(in: game) {
            let distance = simd_length(person.position - position)
            let limit: Float = person.marker == 201 ? 20070 : nearest
            let delta = SIMD3(person.position.x - position.x, 0, person.position.z - position.z)
            guard distance < limit, simd_length_squared(delta) > 0,
                  simd_dot(simd_normalize(delta), SIMD3(sin(facing), 0, cos(facing))) > cos(.pi / 4) else { continue }
            nearest = distance
            selected = person.id
        }
        return selected
    }

    /**
     * 0x0209D3FC selects the first enabled door within 0x3000 units and a 60-degree cone.
     */
    public func nearbyDoor(in game: OriginalGameState, table: OriginalDoorTable) -> Int16? {
        guard mode == .walking else { return nil }
        for node in room.nodes where node.groupCount == 0 && node.name.hasPrefix("in_") {
            guard let index = Self.mapNames.firstIndex(of: String(node.name.dropFirst(3)).uppercased()) else { continue }
            let delta = SIMD3(Float(node.worldFixed[12]) - position.x, 0, Float(node.worldFixed[14]) - position.z)
            let distance = simd_length(delta)
            guard distance > 0, distance.rounded() <= 12288,
                  simd_dot(simd_normalize(delta), SIMD3(sin(facing), 0, cos(facing))) >= 0.5 else { continue }
            let destination = Int16(index)
            // A map marker without a door-table record is a walk-through exit.
            guard table.connection(from: mapID, to: destination) != nil else { continue }
            // A blocking collision marker must still expose its door interaction.
            // The original checks restrictions after choosing the first marker.
            return restrictions.permitsDoor(to: destination, table: table, game: game) ? destination : nil
        }
        return nil
    }

    /**
     * 0x0202CE5C uses a held page touch, an eight-pixel dead zone, and 16 movement directions.
     */
    public mutating func update(heldPageTouch: SIMD2<Float>?, people: [SIMD3<Float>] = []) {
        checkpointFacing = facing
        guard mode == .walking, let touch = heldPageTouch, touch.x.isFinite, touch.y.isFinite,
              touch.x >= 0, touch.x < 192, touch.y >= 0, touch.y < 256 else { return }
        let offset = touch - SIMD2<Float>(96, 128)
        let distance = simd_length(offset)
        guard distance > 8 else { return }
        previousPosition = position
        let angle = (atan2(offset.x, offset.y) / (Self.originalPi / 8)).rounded() * (Self.originalPi / 8)
        let direction = Self.fixedDirection(angle)
        /**
         * 0x0202CE5C scales the normalised lookup direction with a rounded fixed-point product.
         * Speeds are 143/246 times 1.1; corridor maps apply another factor of 1.35.
         */
        let corridorScale: Float = [17, 19, 39].contains(mapID) ? 1.35 : 1
        let speed = Float(Int(Float(distance > 64 ? 246 : 143) * 1.1 * corridorScale))
        let step = SIMD3<Float>(Float((direction.x * Int64(speed) + 2048) >> 12), 0,
                                Float((direction.y * Int64(speed) + 2048) >> 12))
        move(by: step, people: people)
        facing = Self.turn(from: facing, towards: angle)
    }

    /// Native controls turn in place without changing the player's position.
    public mutating func turnView(by radians: Float) {
        guard mode == .walking, radians.isFinite else { return }
        facing = atan2(sin(facing + radians), cos(facing + radians))
        checkpointFacing = facing
    }

    /// Smooth movement relative to the camera; backwards and strafing retain the view direction.
    public mutating func update(firstPersonMovement input: SIMD2<Float>, people: [SIMD3<Float>] = []) {
        checkpointFacing = facing
        guard mode == .walking, input.x.isFinite, input.y.isFinite else { return }
        let length = hypot(input.x, input.y)
        guard length > 0.12 else { return }
        let direction = input / max(1, length)
        let speed: Float = Float(Int(246 * 1.1 * ([17, 19, 39].contains(mapID) ? 1.35 : 1)))
        let forward = SIMD3<Float>(sin(facing), 0, cos(facing))
        let right = SIMD3<Float>(-cos(facing), 0, sin(facing))
        previousPosition = position
        move(by: (forward * direction.y + right * direction.x) * speed, people: people)
    }

    private mutating func move(by step: SIMD3<Float>, people: [SIMD3<Float>]) {
        let candidate = collision.resolve(Self.resolvePeople(position + step, people: people))
        // Other exits remain blocked until their map behaviour is recovered.
        let exit = collision.firstRegion(containing: candidate, prefix: "in_")
        if exit == nil || exit.flatMap({ Self.exitMaps[$0] }) != nil {
            position = candidate
        }
    }

    /**
     * 0x0202DA54 applies each character's 8192-unit floor radius before wall collision.
     * 0x020BD074 normalises with the DS integer square root and division results.
     */
    static func resolvePeople(_ position: SIMD3<Float>, people: [SIMD3<Float>]) -> SIMD3<Float> {
        var result = position
        for person in people {
            let x = Int64(result.x - person.x), z = Int64(result.z - person.z)
            let squared = x * x + z * z
            let root = Int64(Double(squared * 4).squareRoot())
            guard (root + 1) >> 1 <= 8192, squared > 0 else { continue }
            let scale = ((Int64(1) << 56) / squared) * root
            let normalX = (((scale * x) >> 32) + 4096) >> 13
            let normalZ = (((scale * z) >> 32) + 4096) >> 13
            result.x = person.x + Float(normalX * 2)
            result.z = person.z + Float(normalZ * 2)
        }
        return result
    }

    /**
     * 0x01FF8068 converts radians through the original descending angle table.
     * 0x020E272C contains rounded 20.12 sine/cosine pairs at 4096 angles.
     */
    private static func fixedDirection(_ angle: Float) -> SIMD2<Int64> {
        let turns: [(Int, Float)] = [
            (65536, 6.2831854820251465), (49152, 4.71238899230957),
            (32768, 3.1415927410125732), (16384, 1.5707963705062866),
            (8192, 0.7853981852531433), (4096, 0.39269909262657166),
            (2048, 0.19634954631328583), (1024, 0.09817477315664291),
            (512, 0.04908738657832146), (256, 0.024542121216654778),
            (128, 0.012271060608327389), (64, 0.006135530304163694),
            (32, 0.00306933606043458), (16, 0.001533097238279879),
            (8, 0.0007665486191399395), (4, 0.0003832743095699698)
        ]
        var remaining = angle
        while remaining < 0 { remaining += 2 * originalPi }
        while remaining >= 2 * originalPi { remaining -= 2 * originalPi }
        var index = 0
        for (increment, threshold) in turns where remaining >= threshold {
            remaining -= threshold
            index += increment
        }
        let radians = Double(index >> 4) * (2 * Double.pi / 4096)
        let x = Int64((sin(radians) * 4096).rounded())
        let z = Int64((cos(radians) * 4096).rounded())
        let square = x * x + z * z
        let factor = Int64(Double(square * 4).squareRoot()) * ((1 << 56) / square)
        return SIMD2((((factor * x) >> 32) + 4096) >> 13,
                     (((factor * z) >> 32) + 4096) >> 13)
    }

    /**
     * 0x0202CE5C turns through a fixed-point dot/cross product, then eases towards cardinal angles.
     */
    static func turn(from facing: Float, towards angle: Float) -> Float {
        let current = fixedDirection(facing), target = fixedDirection(angle)
        let dot = max(-4096, min(4096, (current.x * target.x + current.y * target.y + 2048) >> 12))
        let difference = Float(acos(Double(dot) / 4096))
        var step = min(difference, max(difference / 8, 0.085))
        if difference < 0.05 { step = 0 }
        if (current.y * target.x - current.x * target.y + 2048) >> 12 < 0 { step = -step }
        var wrapped = facing
        while wrapped < 0 { wrapped += 2 * originalPi }
        while wrapped > 2 * originalPi { wrapped -= 2 * originalPi }
        var result = (wrapped + (wrapped + step)) * 0.5
        for cardinal in [Float(0), originalPi / 2, originalPi, 3 * originalPi / 2, 2 * originalPi] {
            if result >= cardinal - 0.001, result <= cardinal + 0.001 { result = cardinal }
            else if result >= cardinal - 0.065, result <= cardinal + 0.065 {
                result = (result + cardinal) / 2
                break
            }
        }
        return result
    }

    @discardableResult
    public mutating func inspectCounter() -> Bool {
        guard nearbySearchArea == searchAreaID else { return false }
        mode = .counter
        // 0x0202F1D8 measures the signed angle from s02→s02f to s02→player.
        let arc = cameraArc
        let a = simd_normalize(front - target), b = simd_normalize(position - target)
        let entryRotation = atan2(simd_cross(a, b).y, simd_dot(a, b))
        pan = min(1, max(0, (entryRotation + arc / 2) / arc))
        return true
    }

    public mutating func leaveCounter() { mode = .walking; clearSelection() }
    public mutating func setPan(_ value: Float) {
        guard value.isFinite else { return }
        pan = min(1, max(0, value))
        clearSelection()
    }

    public mutating func clearSelection() { selectedNode = nil; selectedPoint = nil }

    /**
     * 0x0209AF40 confirms a repeated selection of the same picked object.
     */
    public mutating func selectCounterObject(page: SIMD2<Float>, visibleNodes: Set<Int>? = nil) throws -> UInt16? {
        guard let node = try pickedCounterNode(page: page, visibleNodes: visibleNodes), let subarea = Self.subarea(node: node) else {
            clearSelection()
            return nil
        }
        let confirmed = selectedNode == node
        selectedNode = node
        selectedPoint = page
        return confirmed ? subarea : nil
    }

    private func vector(_ values: [Int32]) -> SIMD3<Float> { SIMD3(Float(values[0]), Float(values[1]), Float(values[2])) }
    private var cameraArc: Float {
        guard let camera1, let camera2 else { return 0 }
        let centre = vector(camera1.targetFixed)
        let a = simd_normalize(vector(camera1.positionFixed) - centre)
        let b = simd_normalize(vector(camera2.positionFixed) - centre)
        return acos(min(1, max(-1, simd_dot(a, b))))
    }

    /**
     * 0x02038254/0x0203837C orbit between source camera markers about their shared target.
     */
    public var camera: (eye: SIMD3<Float>, target: SIMD3<Float>) {
        if mode == .walking {
            let eye = position / 4096
            return (eye, eye + SIMD3(sin(facing), 0, cos(facing)))
        }
        guard let camera1, let camera2 else {
            let eye = position / 4096
            return (eye, eye + SIMD3(sin(facing), 0, cos(facing)))
        }
        let centre = vector(camera1.targetFixed)
        let a = vector(camera1.positionFixed) - centre, b = vector(camera2.positionFixed) - centre
        let axis = simd_normalize(simd_cross(b, a))
        let rotation = simd_quatf(angle: cameraArc * pan, axis: axis)
        let radius = simd_length(b) + (simd_length(a) - simd_length(b)) * pan
        return ((centre + rotation.act(simd_normalize(b)) * radius) / 4096, centre / 4096)
    }

    /**
     * Uses the original hit display lists. The nearest surface occludes objects behind it.
     */
    public func pickedCounterNode(page: SIMD2<Float>, visibleNodes: Set<Int>? = nil) throws -> String? {
        guard mode == .counter, page.x >= 0, page.x < 192, page.y >= 0, page.y < 256 else { return nil }
        let projection = viewProjection
        let inverse = projection.inverse
        let ndc = SIMD2<Float>(page.x / 96 - 1, 1 - page.y / 128)
        let near = inverse * SIMD4(ndc.x, ndc.y, 0, 1)
        let far = inverse * SIMD4(ndc.x, ndc.y, 1, 1)
        let start = SIMD3(near.x, near.y, near.z) / near.w
        let end = SIMD3(far.x, far.y, far.z) / far.w
        var closest: Float = 1
        var name: String?
        for group in counter.groups {
            guard visibleNodes?.contains(group.node) != false else { continue }
            guard let mesh = group.hit else { continue }
            let matrix = Self.matrix(counter.nodes[group.node].worldFixed)
            let vertices = OriginalBytes(mesh.vertexData), indices = OriginalBytes(mesh.indexData)
            for triangle in 0..<mesh.triangleCount {
                let points = try (0..<3).map { corner -> SIMD3<Float> in
                    let index = Int(try indices.u32((triangle * 3 + corner) * 4))
                    let x = Float(Int16(bitPattern: try vertices.u16(index * 12))) / 4096
                    let y = Float(Int16(bitPattern: try vertices.u16(index * 12 + 2))) / 4096
                    let z = Float(Int16(bitPattern: try vertices.u16(index * 12 + 4))) / 4096
                    let p = matrix * SIMD4(x, y, z, 1)
                    return SIMD3(p.x, p.y, p.z)
                }
                if let t = OriginalMapCollision.intersection(start, end, points[0], points[1], points[2]), t < closest {
                    closest = t
                    name = counter.nodes[group.node].name
                }
            }
        }
        return name
    }

    /**
     * Picks a visible room object from its original hit mesh in the 3D view.
     */
    public func pickedRoomObject(page: SIMD2<Float>, visibleNodes: Set<Int>) throws -> String? {
        guard mode == .walking, page.x >= 0, page.x < 192, page.y >= 0, page.y < 256 else { return nil }
        let inverse = viewProjection.inverse
        let ndc = SIMD2<Float>(page.x / 96 - 1, 1 - page.y / 128)
        let near = inverse * SIMD4(ndc.x, ndc.y, 0, 1)
        let far = inverse * SIMD4(ndc.x, ndc.y, 1, 1)
        let start = SIMD3(near.x, near.y, near.z) / near.w
        let end = SIMD3(far.x, far.y, far.z) / far.w
        var closest: Float = 1
        var name: String?
        for group in room.groups where visibleNodes.contains(group.node) {
            guard let mesh = group.hit else { continue }
            let matrix = Self.roomMatrix(room.nodes[group.node].worldFixed)
            let vertices = OriginalBytes(mesh.vertexData), indices = OriginalBytes(mesh.indexData)
            for triangle in 0..<mesh.triangleCount {
                let points = try (0..<3).map { corner -> SIMD3<Float> in
                    let index = Int(try indices.u32((triangle * 3 + corner) * 4))
                    let x = Float(Int16(bitPattern: try vertices.u16(index * 12))) / 4096
                    let y = Float(Int16(bitPattern: try vertices.u16(index * 12 + 2))) / 4096
                    let z = Float(Int16(bitPattern: try vertices.u16(index * 12 + 4))) / 4096
                    let point = matrix * SIMD4(x, y, z, 1)
                    return SIMD3(point.x, point.y, point.z)
                }
                if let distance = OriginalMapCollision.intersection(start, end, points[0], points[1], points[2]),
                   distance < closest {
                    closest = distance
                    name = room.nodes[group.node].name
                }
            }
        }
        guard let name, let objectID = Self.subarea(node: name), objectID > 0 else { return nil }
        return name
    }

    private static func roomMatrix(_ fixed: [Int32]) -> simd_float4x4 {
        let values = fixed.map { Float($0) / 4096 }
        return simd_float4x4(columns: (
            SIMD4(values[0], values[1], values[2], values[3]),
            SIMD4(values[4], values[5], values[6], values[7]),
            SIMD4(values[8], values[9], values[10], values[11]),
            SIMD4(values[12], values[13], values[14], values[15])))
    }

    /**
     * The original search picker accepts obj followed by two decimal digits (0x02033528).
     */
    public static func subarea(node: String) -> UInt16? {
        let bytes = Array(node.utf8)
        guard bytes.count >= 5, bytes.starts(with: "obj".utf8),
              (48...57).contains(bytes[3]), (48...57).contains(bytes[4]) else { return nil }
        return UInt16(bytes[3] - 48) * 10 + UInt16(bytes[4] - 48)
    }

    public var viewProjection: simd_float4x4 {
        let (eye, target) = camera
        let back = simd_normalize(eye - target)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), back))
        let up = simd_cross(back, right)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, back.x, 0), SIMD4(right.y, up.y, back.y, 0),
            SIMD4(right.z, up.z, back.z, 0), SIMD4(-simd_dot(right, eye), -simd_dot(up, eye), -simd_dot(back, eye), 1)))
        // 0x0202FED8: 25-degree half-angle; DS aspect 255/191; near 0.1, far 40.
        let sx: Float = 1 / tan(25 * .pi / 180), sy = sx * 191 / 255
        let near: Float = 0.1, far: Float = 40
        let projection = simd_float4x4(columns: (
            SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, far / (near - far), -1), SIMD4(0, 0, near * far / (near - far), 0)))
        return projection * view
    }

    private static func matrix(_ values: [Int32]) -> simd_float4x4 {
        let v = values.map { Float($0) / 4096 }
        return simd_float4x4(columns: (SIMD4(v[0], v[1], v[2], v[3]), SIMD4(v[4], v[5], v[6], v[7]),
            SIMD4(v[8], v[9], v[10], v[11]), SIMD4(v[12], v[13], v[14], v[15])))
    }
}

/**
 * Original MDF_COL_100 world-space vertices and triangle groups.
 */
public struct OriginalMapCollision {
    struct Triangle { let a: SIMD3<Float>; let b: SIMD3<Float>; let c: SIMD3<Float> }
    private var regions: [String: [Triangle]] = [:]
    private var regionOrder: [String] = []
    private var walls: [Triangle] = []
    public private(set) var disabledDoorMarkers: Set<String> = []

    public init(data: Data) throws {
        let decoded = data.prefix(3) == Data([0x12, 0x3d, 0xda])
            ? try OriginalContainer.decode(data, hasDirectoryRecord: false) : data
        let r = OriginalBytes(decoded)
        guard try Data(r.range(0, 16)) == Data("MDF_COL_100".utf8) + Data(repeating: 0, count: 5) else {
            throw OriginalDataError.unsupported("Collision header")
        }
        let count = Int(try r.u32(32)), nodes = Int(try r.u32(40))
        guard count <= 1024 else { throw OriginalDataError.invalid("Collision node count") }
        _ = try r.range(nodes, count * 32)
        var inWalls = false
        for index in 0..<count {
            let at = nodes + index * 32
            let name = String(decoding: try r.range(at, 16).prefix(while: { $0 != 0 }), as: UTF8.self)
            if name == "wall" { inWalls = true }
            if name == "jump" { inWalls = false }
            let vertexCount = Int(try r.u32(at + 16)), groups = Int(try r.u32(at + 20))
            if name.hasPrefix("in_"), vertexCount != 0 { disabledDoorMarkers.insert(name) }
            let vertexAt = Int(try r.u32(at + 24)), groupAt = Int(try r.u32(at + 28))
            guard vertexCount <= 65536, groups <= 1024 else { throw OriginalDataError.invalid("Collision group count") }
            _ = try r.range(vertexAt, vertexCount * 12)
            _ = try r.range(groupAt, groups * 16)
            var triangles = [Triangle]()
            for group in 0..<groups {
                let offset = groupAt + group * 16
                let indices = Int(try r.u32(offset + 8)), indexCount = Int(try r.u32(offset + 12))
                guard indexCount <= 65536, indexCount % 3 == 0 else { throw OriginalDataError.invalid("Collision triangle count") }
                _ = try r.range(indices, indexCount * 2)
                for triangle in stride(from: 0, to: indexCount, by: 3) {
                    let p = try (0..<3).map { corner -> SIMD3<Float> in
                        let i = Int(try r.u16(indices + (triangle + corner) * 2))
                        guard i < vertexCount else { throw OriginalDataError.invalid("Collision vertex index") }
                        return try SIMD3(Float(Int32(bitPattern: r.u32(vertexAt + i * 12))),
                            Float(Int32(bitPattern: r.u32(vertexAt + i * 12 + 4))),
                            Float(Int32(bitPattern: r.u32(vertexAt + i * 12 + 8))))
                    }
                    triangles.append(Triangle(a: p[0], b: p[1], c: p[2]))
                }
            }
            regions[name] = triangles
            regionOrder.append(name)
            if inWalls { walls += triangles }
        }
        guard !walls.isEmpty else {
            throw OriginalDataError.missing("Map collision walls")
        }
    }

    public func contains(_ point: SIMD3<Float>, region: String) -> Bool {
        let a = SIMD3(point.x, -16384, point.z), b = SIMD3(point.x, 16384, point.z)
        return (regions[region] ?? []).contains { Self.intersection(a, b, $0.a, $0.b, $0.c) != nil }
    }

    public func matchingRegions(containing point: SIMD3<Float>, prefix: String) -> [String] {
        regionOrder.filter { $0.hasPrefix(prefix) && contains(point, region: $0) }
    }

    public func firstRegion(containing point: SIMD3<Float>, prefix: String) -> String? {
        regionOrder.first { $0.hasPrefix(prefix) && contains(point, region: $0) }
    }

    /**
     * 0x0202D8C4 casts eight radial wall probes with radius 0x99A and pushes out of contact.
     */
    public func resolve(_ candidate: SIMD3<Float>) -> SIMD3<Float> {
        var point = candidate
        let radius: Float = 2458
        for index in 0..<8 {
            let angle = Float(index) * .pi / 4
            let offset = SIMD3<Float>((sin(angle) * radius).rounded(), 0, (cos(angle) * radius).rounded())
            let end = point + offset
            if let t = walls.compactMap({ Self.intersection(point, end, $0.a, $0.b, $0.c) }).min() {
                point -= simd_normalize(offset) * (radius - simd_length(offset) * t)
                point = SIMD3(point.x.rounded(), point.y.rounded(), point.z.rounded())
            }
        }
        return point
    }

    static func intersection(_ start: SIMD3<Float>, _ end: SIMD3<Float>,
                             _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float? {
        let direction = end - start, ab = b - a, ac = c - a
        let p = simd_cross(direction, ac), determinant = simd_dot(ab, p)
        guard abs(determinant) > 0.000001 else { return nil }
        let inverse = 1 / determinant, t = start - a
        let u = simd_dot(t, p) * inverse
        guard u >= 0, u <= 1 else { return nil }
        let q = simd_cross(t, ab), v = simd_dot(direction, q) * inverse
        guard v >= 0, u + v <= 1 else { return nil }
        let distance = simd_dot(ac, q) * inverse
        return distance >= 0 && distance <= 1 ? distance : nil
    }
}
