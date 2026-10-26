import Foundation
import CoreGraphics

/**
 * Indexed close-up compositor and packed hit map from 0x02058A04.
 */
@MainActor
public struct OriginalUpViewImage {
    public let rgba: Data
    public let sourcePackedHitMap: [UInt8]
    public let packedHitMap: [UInt8]
    public let image: CGImage

    static let hitMargin = 2

    public init(bitmaps: [OriginalLinearBitmap], visible: [Bool]) throws {
        guard !bitmaps.isEmpty, bitmaps.count <= 16, visible.count == bitmaps.count, visible[0],
              bitmaps.allSatisfy({ $0.width == 256 && $0.height == 192 && [3, 4].contains($0.kind) }) else {
            throw OriginalDataError.invalid("Close-up bitmap layers")
        }
        var pixels = [UInt8](repeating: 0, count: 256 * 192 * 4)
        var hits = [UInt8](repeating: 0, count: 256 * 192 / 2)
        for (layer, bitmap) in bitmaps.enumerated() where visible[layer] {
            for (index, colour) in bitmap.indices.enumerated() where layer == 0 || colour != 0 {
                let packed = bitmap.palette[Int(colour)]
                for channel in 0..<3 {
                    let value = UInt8((packed >> (channel * 5)) & 31)
                    pixels[index * 4 + channel] = (value << 3) | (value >> 2)
                }
                pixels[index * 4 + 3] = 255
                let shift = (index % 2) * 4
                hits[index / 2] = (hits[index / 2] & ~(15 << shift)) | (UInt8(layer) << shift)
            }
        }
        rgba = Data(pixels)
        sourcePackedHitMap = hits
        packedHitMap = Self.expandingTransparentHitPixels(in: hits, width: 256, height: 192,
                                                           radius: Self.hitMargin)
        guard let rendered = OriginalEntrancePanels.rotated(rgba: rgba, width: 256, height: 192) else {
            throw OriginalDataError.invalid("Close-up image")
        }
        image = rendered
    }

    /**
     * 0x02059DEC uses page-X parity to select a nibble, including its original odd-row behaviour.
     * The native hit map adds a two-pixel margin in transparent pixels around visible objects.
     */
    public func hit(pageX: Int, pageY: Int) -> Int? {
        guard (8...183).contains(pageX), (8...247).contains(pageY) else { return nil }
        let byte = packedHitMap[((255 - pageY) + pageX * 256) / 2]
        return Int((byte >> ((pageX & 1) * 4)) & 15)
    }

    static func expandingTransparentHitPixels(in packed: [UInt8], width: Int, height: Int,
                                               radius: Int) -> [UInt8] {
        guard width > 0, height > 0, radius > 0,
              packed.count == (width * height + 1) / 2 else { return packed }
        var owners = (0..<(width * height)).map { index in
            (packed[index / 2] >> ((index & 1) * 4)) & 15
        }
        let source = owners
        let radiusSquared = radius * radius
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                guard source[index] == 0 else { continue }
                var nearestDistance = radiusSquared + 1
                var nearestOwner: UInt8 = 0
                for offsetY in -radius...radius {
                    let neighbourY = y + offsetY
                    guard (0..<height).contains(neighbourY) else { continue }
                    for offsetX in -radius...radius {
                        let distance = offsetX * offsetX + offsetY * offsetY
                        guard distance <= radiusSquared, distance <= nearestDistance else { continue }
                        let neighbourX = x + offsetX
                        guard (0..<width).contains(neighbourX) else { continue }
                        let owner = source[neighbourY * width + neighbourX]
                        guard owner != 0 else { continue }
                        if distance < nearestDistance || (distance == nearestDistance && owner > nearestOwner) {
                            nearestDistance = distance
                            nearestOwner = owner
                        }
                    }
                }
                owners[index] = nearestOwner
            }
        }
        var expanded = [UInt8](repeating: 0, count: packed.count)
        for (index, owner) in owners.enumerated() {
            expanded[index / 2] |= owner << ((index & 1) * 4)
        }
        return expanded
    }
}
