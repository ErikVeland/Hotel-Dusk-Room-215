import CoreGraphics
import Foundation
import Metal

/// Decodes original DTX texels. Allocated, logical and stored dimensions remain
/// separate. Missing blocks remain transparent and are discarded by the renderer.
public struct OriginalTexture: Sendable {
    public let mode: Int
    public let allocatedWidth: Int
    public let allocatedHeight: Int
    public let logicalWidth: Int
    public let logicalHeight: Int
    public let storedWidth: Int
    public let storedHeight: Int
    public let decodedPayload: Data
    public let originalPaletteData: Data
    public let originalPixelData: Data
    public let rgba: Data

    public init(data: Data) throws {
        let decoded: Data
        if data.prefix(3) == Data([0x12, 0x3d, 0xda]) {
            decoded = try OriginalContainer.decode(data, hasDirectoryRecord: false)
        } else {
            decoded = data
        }
        let r = OriginalBytes(decoded)
        guard try Array(r.range(0, 16)) == [UInt8](repeating: 0, count: 16) else {
            throw OriginalDataError.unsupported("DTX header")
        }
        let aw = Int(try r.u16(16)), ah = Int(try r.u16(18))
        let lw = Int(try r.u16(20)), lh = Int(try r.u16(22))
        let format = Int(try r.u16(24)), paletteCount = Int(try r.u16(26))
        guard try r.u32(28) == 32, [1, 2, 3, 4, 7].contains(format),
              lw > 0, lh > 0, lw <= aw, lh <= ah, aw <= 1024, ah <= 1024,
              paletteCount > 0, paletteCount <= 32768 else {
            throw OriginalDataError.unsupported("DTX dimensions, format or palette offset")
        }
        if let expected = [1: 32, 2: 8, 3: 256, 4: 256][format], paletteCount != expected {
            throw OriginalDataError.invalid("DTX palette count")
        }
        let palette = Data(try r.range(32, paletteCount * 2))
        let pixelStart = 32 + paletteCount * 2
        let pixels = Array(try r.range(pixelStart, decoded.count - pixelStart))
        func encodedSize(_ w: Int, _ h: Int) -> Int { format == 7 ? w * h * 3 / 8 : w * h }
        var width = lw, height = lh
        if pixels.count != encodedSize(width, height) {
            guard pixels.count == encodedSize(aw, ah) else {
                throw OriginalDataError.invalid("DTX pixel size matches neither logical nor allocated dimensions")
            }
            width = aw
            height = ah
        }
        let blockCount = pixels.count / 6
        if format == 7 {
            // The descriptor at 0x02083CD0 uses allocated width for 4x4 block rows.
            // Cropped payloads can stop before that allocation is full. Keep only
            // their supplied blocks; the unprovided tail stays transparent.
            if width % 4 != 0 { width = aw }
            guard width % 4 == 0, pixels.count % 6 == 0,
                  height % 4 == 0 || width == aw else {
                throw OriginalDataError.unsupported("DTX compressed block layout")
            }
            // 0x02083534 uploads a linear block stream using allocated width.
            // Equal logical/allocated widths can end part-way through a block row.
            height = ((blockCount + width / 4 - 1) / (width / 4)) * 4
        }
        let paletteReader = OriginalBytes(palette)
        let colours: [[Int]] = try (0..<paletteCount).map { index in
            let packed = Int(try paletteReader.u16(index * 2))
            return [0, 5, 10].map { (packed >> $0) & 31 }
        }
        func colour(_ index: Int) throws -> [Int] {
            guard colours.indices.contains(index) else { throw OriginalDataError.invalid("DTX palette reference outside original data") }
            return colours[index]
        }
        func expand(_ value: Int) -> UInt8 { UInt8((value << 3) | (value >> 2)) }
        var output = [UInt8](repeating: 0, count: width * height * 4)
        func store(_ index: Int, _ rgb: [Int], _ alpha: Int) {
            let destination = index * 4
            output[destination] = expand(rgb[0])
            output[destination + 1] = expand(rgb[1])
            output[destination + 2] = expand(rgb[2])
            output[destination + 3] = expand(alpha)
        }
        if format != 7 {
            for (index, byte) in pixels.enumerated() {
                let value = Int(byte)
                if format == 1 {
                    let a3 = value >> 5
                    store(index, try colour(value & 31), (a3 << 2) | (a3 >> 1))
                } else if format == 2 {
                    store(index, try colour(value & 7), value >> 3)
                } else {
                    // ARM9 02083cd0 enables TEXIMAGE_PARAM colour-zero alpha
                    // only for mode 4. Palette RGB bits are retained either way.
                    store(index, try colour(value), format == 4 && value == 0 ? 0 : 31)
                }
            }
        } else {
            let blocks = blockCount
            let p = OriginalBytes(Data(pixels))
            for block in 0..<blocks {
                let texels = try p.u32(block * 4)
                let info = Int(try p.u16(blocks * 4 + block * 2))
                let compression = info >> 14
                let base = (info & 0x3fff) * 2
                let c0 = try colour(base), c1 = try colour(base + 1)
                var blockColours = [c0, c1]
                switch compression {
                case 0, 2:
                    blockColours.append(try colour(base + 2))
                    blockColours.append(compression == 2 ? try colour(base + 3) : [0, 0, 0])
                case 1:
                    blockColours.append(zip(c0, c1).map { ($0.0 + $0.1) / 2 })
                    blockColours.append([0, 0, 0])
                default:
                    blockColours.append(zip(c0, c1).map { ($0.0 * 5 + $0.1 * 3) / 8 })
                    blockColours.append(zip(c0, c1).map { ($0.0 * 3 + $0.1 * 5) / 8 })
                }
                let bx = block % (width / 4), by = block / (width / 4)
                for pixel in 0..<16 {
                    let value = Int((texels >> (pixel * 2)) & 3)
                    let x = bx * 4 + pixel % 4, y = by * 4 + pixel / 4
                    store(y * width + x, blockColours[value], compression < 2 && value == 3 ? 0 : 31)
                }
            }
        }
        mode = format
        allocatedWidth = aw
        allocatedHeight = ah
        logicalWidth = lw
        logicalHeight = lh
        storedWidth = width
        storedHeight = height
        decodedPayload = decoded
        originalPaletteData = palette
        originalPixelData = Data(pixels)
        rgba = Data(output)
    }

    public func makeCGImage() -> CGImage? {
        guard let provider = CGDataProvider(data: rgba as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: storedWidth, height: storedHeight, bitsPerComponent: 8,
                       bitsPerPixel: 32, bytesPerRow: storedWidth * 4, space: colorSpace,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// Upload only stored texels. The original material/UV decoder must choose
    /// sampling and placement; this function adds no border, filtering or fill.
    public func makeMetalTexture(device: MTLDevice) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                 width: storedWidth, height: storedHeight,
                                                                 mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw OriginalDataError.invalid("Could not allocate original texture")
        }
        rgba.withUnsafeBytes { data in
            texture.replace(region: MTLRegionMake2D(0, 0, storedWidth, storedHeight), mipmapLevel: 0,
                            withBytes: data.baseAddress!, bytesPerRow: storedWidth * 4)
        }
        return texture
    }
}

public struct OriginalTextureLibrary: Sendable {
    public let manifest: OriginalTextureManifest
    private let resourceRoot: URL

    public init(resourceRoot: URL) throws {
        self.resourceRoot = resourceRoot
        let data = try Data(contentsOf: resourceRoot.appendingPathComponent("OriginalTextureManifest.json"))
        manifest = try JSONDecoder().decode(OriginalTextureManifest.self, from: data)
        guard manifest.formatVersion == 1 else { throw OriginalDataError.unsupported("Texture manifest version") }
    }

    public static func bundled() throws -> OriginalTextureLibrary {
        guard let root = Bundle.module.resourceURL?.appendingPathComponent("OriginalTextures"),
              FileManager.default.fileExists(atPath: root.path) else {
            throw OriginalDataError.missing("OriginalTextures")
        }
        return try .init(resourceRoot: root)
    }

    /// Room search models share named textures with other members of the same map archive.
    /// Accept a shared name only when every candidate has the same decoded image.
    func mapTexturePath(modelPath: String, textureName: String) throws -> String {
        let directory = (modelPath as NSString).deletingLastPathComponent
        let requested = directory + "/" + textureName + ".dtx"
        let exact = manifest.textures.filter { $0.source.lowercased() == requested.lowercased() }
        if exact.count == 1 { return exact[0].source }
        let components = modelPath.split(separator: "/")
        guard components.count >= 3, components[0] == "map" else { throw OriginalDataError.missing(requested) }
        let archive = "map/" + components[1] + "/"
        let candidates = manifest.textures.filter {
            $0.source.hasPrefix(archive) && ($0.source as NSString).lastPathComponent.lowercased() == textureName.lowercased() + ".dtx"
                && $0.status == "decoded"
        }
        guard let first = candidates.first, first.rgbaSHA256 != nil,
              candidates.allSatisfy({ $0.rgbaSHA256 == first.rgbaSHA256 }) else {
            throw OriginalDataError.missing(requested)
        }
        return first.source
    }

    /// These names have no FILE entry in their original scene .def. The original
    /// lookup 02083A6C returns -1 and draw 0208B6F0 selects the default colour slot.
    static func unboundMapTextures(modelPath: String) -> Set<String> {
        switch modelPath {
        case "map/R123/R123/R123.mdf": return ["r123_lamp02"]
        case "map/R301/R301_s01/R301_s01.mdf": return ["denjou"]
        case "map/R302/R302/R302.mdf": return ["noicon"]
        case "map/R304/R304_s02/R304_s02.mdf": return ["yuka01"]
        default: return []
        }
    }

    public func load(path: String) throws -> OriginalTexture {
        guard let record = manifest.textures.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        guard record.status == "decoded" else { throw OriginalDataError.unsupported(record.error ?? path) }
        let url = resourceRoot.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(resourceRoot.standardizedFileURL.path + "/") else {
            throw OriginalDataError.invalid("Texture path leaves resource directory")
        }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return try OriginalTexture(data: data)
    }
}

public struct OriginalTextureManifest: Decodable, Sendable {
    public let formatVersion: Int
    public let coverage: Coverage
    public let textures: [Record]

    public struct Coverage: Decodable, Sendable {
        public let textures: Int
        public let decoded: Int
        public let unsupported: Int
    }
    public struct Record: Decodable, Sendable {
        public let source: String
        public let payloadSHA256: String
        public let status: String
        public let error: String?
        public let mode: Int?
        public let storedWidth: Int?
        public let storedHeight: Int?
        public let decodedSHA256: String?
        public let paletteSHA256: String?
        public let pixelDataSHA256: String?
        public let rgbaSHA256: String?
    }
}
