import Foundation
import Metal

/// Original MDF_DS hierarchy and GX display lists. Scene state, camera and
/// object visibility remain the responsibility of the recovered game logic.
public struct OriginalModel: Sendable {
    public let name: String
    public let decodedPayload: Data
    public let materials: [Material]
    public let nodes: [Node]
    public let groups: [Group]

    public struct Material: Sendable {
        public let name: String
        public let texture: String
        public let originalRecord: Data
    }

    public struct Node: Sendable {
        public let name: String
        public let parent: Int
        /// Original Float32 matrix converted to signed 20.12 like ARM9 0208b0f4.
        public let localFixed: [Int32]
        /// Original fixed-point concatenation from ARM9 020bc948.
        public let worldFixed: [Int32]
        public let groupCount: Int
    }

    public struct Group: Sendable {
        public let node: Int
        public let material: Int
        public let flags: UInt16
        public let render: OriginalModelGeometry?
        public let hit: OriginalModelGeometry?
    }

    public init(data: Data) throws {
        let decoded = data.prefix(3) == Data([0x12, 0x3d, 0xda])
            ? try OriginalContainer.decode(data, hasDirectoryRecord: false) : data
        let reader = OriginalBytes(decoded)
        guard try Data(reader.range(0, 16)) == Data("MDF_DS_100".utf8) + Data(repeating: 0, count: 6) else {
            throw OriginalDataError.unsupported("MDF variant")
        }
        let count = Int(try reader.u32(32)), materialCount = Int(try reader.u32(36))
        let nodeOffset = Int(try reader.u32(40)), materialOffset = Int(try reader.u32(44))
        guard count <= 32768, materialCount <= 65536, materialOffset == 48,
              nodeOffset == 48 + materialCount * 48 else {
            throw OriginalDataError.invalid("MDF tables")
        }
        _ = try reader.range(nodeOffset, count * 96)
        func identifier(_ at: Int) throws -> String {
            // Preserve opaque exporter bytes, including non-ASCII model names.
            let bytes = try reader.range(at, 16).prefix(while: { $0 != 0 })
            return String(String.UnicodeScalarView(bytes.map { UnicodeScalar(Int($0))! }))
        }
        var recoveredMaterials = [Material]()
        for index in 0..<materialCount {
            let at = materialOffset + index * 48
            recoveredMaterials.append(try Material(name: identifier(at), texture: identifier(at + 16),
                                                     originalRecord: Data(reader.range(at, 48))))
        }
        var recoveredNodes = [Node]()
        var recoveredGroups = [Group]()
        for index in 0..<count {
            let at = nodeOffset + index * 96
            let nodeID = Int(Int16(bitPattern: try reader.u16(at + 16)))
            let parent = Int(Int16(bitPattern: try reader.u16(at + 18)))
            let groupOffset = Int(try reader.u32(at + 20)), groupCount = Int(try reader.u32(at + 24))
            guard nodeID == index, parent >= -1, parent < index,
                  try reader.u32(at + 28) == 0, groupCount <= 65536 else {
                throw OriginalDataError.invalid("MDF hierarchy")
            }
            var local = [Int32]()
            for element in 0..<16 {
                let value = Float(bitPattern: try reader.u32(at + 32 + element * 4))
                guard value.isFinite, abs(value) < 524288 else { throw OriginalDataError.invalid("MDF transform") }
                let scaled = value * 4096
                let rounded = scaled + (value > 0 ? Float(0.5) : Float(-0.5))
                guard Double(rounded) >= Double(Int32.min), Double(rounded) <= Double(Int32.max) else {
                    throw OriginalDataError.invalid("MDF transform exceeds fixed-point range")
                }
                local.append(Int32(rounded))
            }
            let world = parent < 0 ? local : Self.concatenate(recoveredNodes[parent].worldFixed, local)
            recoveredNodes.append(try Node(name: identifier(at), parent: parent, localFixed: local,
                                          worldFixed: world, groupCount: groupCount))
            _ = try reader.range(groupOffset, groupCount * 16)
            for group in 0..<groupCount {
                let offset = groupOffset + group * 16
                let drawOffset = Int(try reader.u32(offset)), hitOffset = Int(try reader.u32(offset + 4))
                let drawSize = Int(try reader.u16(offset + 8)), hitSize = Int(try reader.u16(offset + 10))
                let material = Int(try reader.u16(offset + 12)), flags = try reader.u16(offset + 14)
                guard material < materialCount, [0, 3, 4].contains(flags) else {
                    throw OriginalDataError.unsupported("MDF group record")
                }
                func geometry(_ start: Int, _ size: Int, textured: Bool) throws -> OriginalModelGeometry? {
                    guard (start == 0) == (size == 0) else { throw OriginalDataError.invalid("MDF display list range") }
                    if size == 0 { return nil }
                    return try OriginalModelGeometry(data: Data(reader.range(start, size)), textured: textured)
                }
                recoveredGroups.append(try Group(node: index, material: material, flags: flags,
                                                 render: geometry(drawOffset, drawSize, textured: true),
                                                 hit: geometry(hitOffset, hitSize, textured: false)))
            }
        }
        name = try identifier(16)
        decodedPayload = decoded
        materials = recoveredMaterials
        nodes = recoveredNodes
        groups = recoveredGroups
    }

    private static func concatenate(_ a: [Int32], _ b: [Int32]) -> [Int32] {
        (0..<16).map { index in
            let row = index / 4, column = index % 4
            var sum: Int64 = 0
            for k in 0..<4 { sum = sum &+ (Int64(a[row * 4 + k]) * Int64(b[k * 4 + column])) }
            return Int32(truncatingIfNeeded: sum >> 12)
        }
    }

    /// Canonical byte stream for comparison with the independent Python decoder.
    public var geometryData: Data {
        var result = Data()
        for group in groups {
            for geometry in [group.render, group.hit].compactMap({ $0 }) {
                result.append(geometry.vertexData)
                result.append(geometry.indexData)
            }
        }
        return result
    }

    /// Original marker positions from ARM9 0209d7ec. Fixed cameras occur in
    /// search scenes; free exploration scenes may have no such markers.
    public func cameraMarkers(index: Int) throws -> OriginalModelCameraMarkers {
        guard [1, 2].contains(index) else { throw OriginalDataError.invalid("Original camera index") }
        guard let eye = nodes.first(where: { $0.name == "cam_pos\(index)" }) else {
            throw OriginalDataError.missing("cam_pos\(index)")
        }
        let targetNames = index == 1 ? ["cam_at1", "cam_at"] : ["cam_at2", "cam_at1", "cam_at"]
        guard let target = targetNames.compactMap({ name in nodes.first { $0.name == name } }).first else {
            throw OriginalDataError.missing("Original camera target")
        }
        return OriginalModelCameraMarkers(positionName: eye.name, targetName: target.name,
            positionFixed: Array(eye.worldFixed[12...14]), targetFixed: Array(target.worldFixed[12...14]))
    }
}

public struct OriginalModelCameraMarkers: Sendable {
    public let positionName: String
    public let targetName: String
    public let positionFixed: [Int32]
    public let targetFixed: [Int32]
}

public struct OriginalModelGeometry: Sendable {
    public let originalCommands: Data
    /// Twelve bytes per vertex: five signed Int16 (x,y,z,u,v), then RGB555 UInt16.
    /// Position uses 4.12 fixed point and UV uses 12.4, with no axis or UV flip.
    public let vertexData: Data
    public let indexData: Data
    public let vertexCount: Int
    public let triangleCount: Int
    public let primitive: UInt32

    public init(data: Data, textured: Bool) throws {
        let reader = OriginalBytes(data)
        var cursor = 0, vertices = Data(), indices = [UInt32]()
        var colour: UInt16?, uv: UInt32?, activeStart: Int?, primitive: UInt32 = 0
        var vertexCount = 0
        func append16(_ value: UInt16) { vertices.append(UInt8(truncatingIfNeeded: value)); vertices.append(UInt8(value >> 8)) }
        while cursor < data.count {
            let commands = try reader.u32(cursor)
            cursor += 4
            for shift in stride(from: 0, through: 24, by: 8) {
                let command = (commands >> shift) & 255
                if command == 0 { continue }
                guard let parameterCount = [0x20: 1, 0x22: 1, 0x23: 2, 0x40: 1, 0x41: 0][Int(command)] else {
                    throw OriginalDataError.unsupported("GX command \(command)")
                }
                let parameters = try (0..<parameterCount).map { try reader.u32(cursor + $0 * 4) }
                cursor += parameterCount * 4
                switch command {
                case 0x20:
                    guard parameters[0] <= 0x7fff else { throw OriginalDataError.invalid("GX colour bits") }
                    colour = UInt16(parameters[0])
                case 0x22: uv = parameters[0]
                case 0x40:
                    guard activeStart == nil, parameters[0] <= 1 else { throw OriginalDataError.unsupported("GX primitive") }
                    primitive = parameters[0]
                    activeStart = vertexCount
                case 0x41:
                    guard let start = activeStart else { throw OriginalDataError.invalid("GX END without BEGIN") }
                    let size = primitive == 0 ? 3 : 4
                    guard (vertexCount - start) % size == 0 else { throw OriginalDataError.invalid("Incomplete GX primitive") }
                    for vertex in stride(from: start, to: vertexCount, by: size) {
                        let v = UInt32(vertex)
                        indices.append(contentsOf: [v, v + 1, v + 2])
                        if size == 4 { indices.append(contentsOf: [v, v + 2, v + 3]) }
                    }
                    activeStart = nil
                case 0x23:
                    guard activeStart != nil, parameters[1] <= 0xffff,
                          !textured || (colour != nil && uv != nil) else {
                        throw OriginalDataError.invalid("GX vertex or attributes")
                    }
                    append16(UInt16(truncatingIfNeeded: parameters[0]))
                    append16(UInt16(parameters[0] >> 16))
                    append16(UInt16(parameters[1]))
                    append16(UInt16(truncatingIfNeeded: uv ?? 0))
                    append16(UInt16((uv ?? 0) >> 16))
                    append16(colour ?? 0)
                    vertexCount += 1
                default: break
                }
            }
        }
        guard activeStart == nil, vertexCount > 0 else { throw OriginalDataError.invalid("Unclosed or empty GX geometry") }
        var indexBytes = Data()
        for index in indices {
            for shift in stride(from: 0, through: 24, by: 8) { indexBytes.append(UInt8(truncatingIfNeeded: index >> shift)) }
        }
        originalCommands = data
        vertexData = vertices
        indexData = indexBytes
        self.vertexCount = vertexCount
        triangleCount = indices.count / 3
        self.primitive = primitive
    }

    public func makeMetalBuffers(device: MTLDevice) throws -> OriginalModelMetalGeometry {
        func buffer(_ data: Data) throws -> MTLBuffer {
            let result = data.withUnsafeBytes { bytes in
                device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
            }
            guard let result else { throw OriginalDataError.invalid("Could not allocate original geometry") }
            return result
        }
        return try OriginalModelMetalGeometry(vertices: buffer(vertexData), indices: buffer(indexData),
                                              indexCount: triangleCount * 3)
    }
}

/// No camera, visibility flags or textures are invented by the buffer uploader.
public struct OriginalModelMetalGeometry {
    public let vertices: MTLBuffer
    public let indices: MTLBuffer
    public let indexCount: Int

    public func draw(encoder: MTLRenderCommandEncoder, vertexBufferIndex: Int = 0) {
        encoder.setVertexBuffer(vertices, offset: 0, index: vertexBufferIndex)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint32,
                                      indexBuffer: indices, indexBufferOffset: 0)
    }
}

public struct OriginalModelLibrary: Sendable {
    public let manifest: OriginalModelManifest
    private let resourceRoot: URL

    public init(resourceRoot: URL) throws {
        self.resourceRoot = resourceRoot
        manifest = try JSONDecoder().decode(OriginalModelManifest.self,
            from: Data(contentsOf: resourceRoot.appendingPathComponent("OriginalModelManifest.json")))
        guard manifest.formatVersion == 1 else { throw OriginalDataError.unsupported("Model manifest version") }
    }

    public static func bundled() throws -> OriginalModelLibrary {
        guard let root = Bundle.module.resourceURL?.appendingPathComponent("OriginalModels"),
              FileManager.default.fileExists(atPath: root.path) else { throw OriginalDataError.missing("OriginalModels") }
        return try .init(resourceRoot: root)
    }

    public func load(path: String) throws -> OriginalModel {
        guard let record = manifest.models.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        guard record.status == "decoded" else { throw OriginalDataError.unsupported(record.error ?? path) }
        let url = resourceRoot.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(resourceRoot.standardizedFileURL.path + "/") else {
            throw OriginalDataError.invalid("Model path leaves resource directory")
        }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return try OriginalModel(data: data)
    }
}

public struct OriginalModelManifest: Decodable, Sendable {
    public let formatVersion: Int
    public let coverage: Coverage
    public let models: [Record]
    public struct Coverage: Decodable, Sendable {
        public let models: Int
        public let decoded: Int
        public let unsupported: Int
        public let nodes: Int
        public let renderVertices: Int
        public let hitVertices: Int
    }
    public struct Record: Decodable, Sendable {
        public let source: String
        public let payloadSHA256: String
        public let status: String
        public let error: String?
        public let decodedSHA256: String?
        public let geometrySHA256: String?
        public let nodes: [Node]?
    }
    public struct Node: Decodable, Sendable {
        public let name: String
        public let parent: Int
        public let localFixed: [Int32]
        public let worldFixed: [Int32]
        public let groups: Int
    }
}
