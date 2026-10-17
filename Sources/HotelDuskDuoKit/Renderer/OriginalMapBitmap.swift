import Foundation
import CoreGraphics

/**
 * Tile dictionary and screen map loaded by 0x02068268. Output uses book-page orientation.
 */
public struct OriginalMapBitmap {
    public let width: Int
    public let height: Int
    public let rgba: Data

    public init(data: Data) throws {
        let decoded = data.prefix(3) == Data([0x12, 0x3d, 0xda])
            ? try OriginalContainer.decode(data, hasDirectoryRecord: false) : data
        let r = OriginalBytes(decoded)
        let w = Int(try r.u16(4)), h = Int(try r.u16(6)), count = Int(try r.u16(8))
        let mapCount = Int(try r.u16(10)), paletteSize = Int(try r.u32(12))
        guard try r.u16(0) == 0, try r.u16(2) == 256, paletteSize == 512,
              w > 0, h > 0, w <= 2048, h <= 2048, w % 8 == 0, h % 8 == 0,
              count > 0, count <= 1024, mapCount == w * h / 64,
              decoded.count == 16 + paletteSize + count * 64 + mapCount * 2 else {
            throw OriginalDataError.invalid("Original map bitmap sections")
        }
        let tileAt = 16 + paletteSize, mapAt = tileAt + count * 64
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let entry = try r.u16(mapAt + ((y / 8) * (w / 8) + x / 8) * 2)
                let tile = Int(entry & 0x3ff)
                guard tile < count else { throw OriginalDataError.invalid("Original map tile index") }
                let tx = entry & 0x400 == 0 ? x % 8 : 7 - x % 8
                let ty = entry & 0x800 == 0 ? y % 8 : 7 - y % 8
                let colourIndex = Int(decoded[tileAt + tile * 64 + ty * 8 + tx])
                let colour = try r.u16(16 + colourIndex * 2)
                // Source (x,y) becomes page (y,w-1-x).
                let destination = ((w - 1 - x) * h + y) * 4
                for (channel, shift) in [0, 5, 10].enumerated() {
                    let component = UInt8((colour >> shift) & 31)
                    pixels[destination + channel] = component << 3 | component >> 2
                }
                pixels[destination + 3] = 255
            }
        }
        width = h; height = w; rgba = Data(pixels)
    }

    public func makeCGImage() -> CGImage? {
        guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

extension OriginalBitmapLibrary {
    public func loadMap(path: String) throws -> OriginalMapBitmap {
        guard let record = manifest.images.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        let url = resourceRoot.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(resourceRoot.path + "/") else { throw OriginalDataError.invalid("Map path leaves source directory") }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return try OriginalMapBitmap(data: data)
    }
}
