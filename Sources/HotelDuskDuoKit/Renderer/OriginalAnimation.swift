import CoreGraphics
import CryptoKit
import Foundation
import SwiftUI

public enum OriginalAnimationError: Error, LocalizedError, Equatable {
    case invalid(String)
    case missing(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let detail): return "Invalid original animation: \(detail)"
        case .missing(let name): return "Original animation resource is missing: \(name)"
        case .unsupported(let detail): return "Original animation requires further recovery: \(detail)"
        }
    }
}

/// Original ANM data. This contains no guessed playback rate or replacement art.
public struct OriginalAnimationClip: Sendable {
    public let id: String
    public let frameCount: Int
    public let nativeWidth: Int
    public let nativeHeight: Int
    public let clearWord: UInt32
    public let loopStartIndex: Int
    public let firstFrameNumber: Int
    public let lastFrameNumber: Int
    public let loopFrameNumber: Int
    public let payloadSHA256: String

    fileprivate let bytes: [UInt8]
    fileprivate let descriptors: [FrameDescriptor]

    fileprivate struct FrameDescriptor: Sendable {
        let offset: Int
        let size: Int
    }

    public init(data: Data, id: String = "") throws {
        let reader = AnimationBytes(data)
        try reader.require(reader.count >= 32, "truncated ANM header")
        try reader.require(reader.u32(0) == 1, "unsupported ANM version")
        let count = Int(reader.u32(4))
        let tableSize = Int(reader.u32(8))
        let width = reader.u16(16)
        let height = reader.u16(18)
        try reader.require((1...4096).contains(count), "invalid frame count")
        try reader.require((1...1024).contains(width) && (1...1024).contains(height), "invalid dimensions")
        try reader.require(tableSize == count * 16 && 32 + tableSize <= reader.count, "truncated descriptor table")
        try reader.require(reader.u16(26) == 0 && reader.u16(28) == 0 && reader.u16(30) == 0, "unknown header flags")
        let first = reader.u16(20)
        let last = reader.u16(22)
        let loop = reader.u16(24)
        let restart = loop - first + 1
        try reader.require((0..<count).contains(restart), "invalid loop restart")
        var records: [FrameDescriptor] = []
        var previousEnd = 32 + tableSize
        for index in 0..<count {
            let record = 32 + index * 16
            let offset = Int(reader.u32(record))
            let size = Int(reader.u32(record + 4))
            try reader.require(Array(reader.bytes[(record + 8)..<(record + 16)]) == [48, 49, 50, 51, 0, 0, 0, 0], "unknown frame tag")
            try reader.require(offset >= previousEnd && size >= 16 && offset <= reader.count - size, "invalid frame bounds")
            records.append(.init(offset: offset, size: size))
            previousEnd = offset + size
        }
        self.id = id
        frameCount = count
        nativeWidth = width
        nativeHeight = height
        clearWord = reader.u32(12)
        firstFrameNumber = first
        lastFrameNumber = last
        loopFrameNumber = loop
        loopStartIndex = restart
        bytes = reader.bytes
        descriptors = records
        payloadSHA256 = Self.digest(data)
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    fileprivate func initialPixels() -> [UInt8] {
        let word = (0..<4).map { UInt8(truncatingIfNeeded: clearWord >> ($0 * 8)) }
        return (0..<(nativeWidth * nativeHeight)).map { word[$0 % 4] }
    }

    fileprivate func apply(frame index: Int, to previous: [UInt8]) throws -> (pixels: [UInt8], palette: [UInt8]) {
        let reader = AnimationBytes(bytes: bytes)
        try reader.require((0..<frameCount).contains(index), "frame index outside animation")
        try reader.require(previous.count == nativeWidth * nativeHeight, "incorrect previous buffer size")
        let descriptor = descriptors[index]
        let offset = descriptor.offset
        let mode = reader.u32(offset)
        let streamSize = Int(reader.u32(offset + 4))
        let paletteSize = Int(reader.u32(offset + 8))
        let nextOffset = Int(reader.u32(offset + 12))
        try reader.require(mode == 0 || mode == 1, "unknown frame compression")
        try reader.require(paletteSize == 64, "unknown palette size")
        try reader.require(streamSize <= descriptor.size - 16 - paletteSize, "truncated frame stream")
        try reader.require(nextOffset == offset + descriptor.size, "invalid next-frame offset")
        let start = offset + 16
        let end = start + streamSize
        var pixels = previous
        var output = 0
        var cursor = start
        if mode == 1 {
            try reader.require(streamSize == pixels.count, "incorrect raw frame size")
            pixels = Array(bytes[start..<end])
            output = pixels.count
            cursor = end
        }
        while cursor < end {
            let command = Int(bytes[cursor])
            cursor += 1
            let count: Int
            if command & 0x80 != 0 {
                count = command - 0x80
                try reader.require(count > 0 && output + count <= pixels.count, "invalid skip in frame \(index)")
            } else if command & 0x40 != 0 {
                count = command - 0x40
                try reader.require(count > 0 && cursor < end && output + count <= pixels.count, "invalid repeat in frame \(index)")
                let value = bytes[cursor]
                cursor += 1
                for i in output..<(output + count) { pixels[i] = value }
            } else {
                count = command
                try reader.require(count > 0 && cursor + count <= end && output + count <= pixels.count, "invalid literal in frame \(index)")
                pixels.replaceSubrange(output..<(output + count), with: bytes[cursor..<(cursor + count)])
                cursor += count
            }
            output += count
        }
        try reader.require(cursor == end && output == pixels.count, "incorrect decoded size in frame \(index)")
        return (pixels, Array(bytes[end..<(end + paletteSize)]))
    }
}

/// Stores the original index buffer across delta frames and loop boundaries.
/// Advance from the recovered gameplay animation clock; an ANM has no FPS field.
public struct OriginalAnimationDecoder: Sendable {
    public let clip: OriginalAnimationClip
    public private(set) var frameIndex: Int = -1
    public private(set) var loopCount = 0
    private var pixels: [UInt8]
    private var palette = [UInt8](repeating: 0, count: 64)

    public init(clip: OriginalAnimationClip) {
        self.clip = clip
        pixels = clip.initialPixels()
    }

    @discardableResult
    public mutating func advance(loop: Bool = true) throws -> OriginalAnimationFrame? {
        var next = frameIndex + 1
        var nextLoopCount = loopCount
        if next >= clip.frameCount {
            guard loop else { return nil }
            next = clip.loopStartIndex
            nextLoopCount += 1
        }
        let result = try clip.apply(frame: next, to: pixels)
        pixels = result.pixels
        palette = result.palette
        frameIndex = next
        loopCount = nextLoopCount
        return frame()
    }

    @discardableResult
    public mutating func seek(frame index: Int) throws -> OriginalAnimationFrame {
        guard (0..<clip.frameCount).contains(index) else { throw OriginalAnimationError.invalid("frame index outside animation") }
        var rebuilt = OriginalAnimationDecoder(clip: clip)
        for next in 0...index {
            let result = try clip.apply(frame: next, to: rebuilt.pixels)
            rebuilt.pixels = result.pixels
            rebuilt.palette = result.palette
            rebuilt.frameIndex = next
        }
        self = rebuilt
        return frame()
    }

    public func checkpoint() -> OriginalAnimationCheckpoint {
        .init(payloadSHA256: clip.payloadSHA256, frameIndex: frameIndex, loopCount: loopCount,
              indexData: Data(pixels), paletteData: Data(palette))
    }

    public mutating func restore(_ checkpoint: OriginalAnimationCheckpoint) throws {
        guard checkpoint.payloadSHA256 == clip.payloadSHA256,
              (-1..<clip.frameCount).contains(checkpoint.frameIndex), checkpoint.loopCount >= 0,
              checkpoint.indexData.count == pixels.count, checkpoint.paletteData.count == 64 else {
            throw OriginalAnimationError.invalid("checkpoint does not match the original animation")
        }
        pixels = Array(checkpoint.indexData)
        palette = Array(checkpoint.paletteData)
        frameIndex = checkpoint.frameIndex
        loopCount = checkpoint.loopCount
    }

    public func frame() -> OriginalAnimationFrame {
        var colors = [[UInt8]]()
        for index in 0..<32 {
            let packed = UInt16(palette[index * 2]) | (UInt16(palette[index * 2 + 1]) << 8)
            colors.append([0, 5, 10].map { shift in
                let channel = UInt8((packed >> shift) & 31)
                return (channel << 3) | (channel >> 2)
            })
        }
        var rgba = [UInt8](repeating: 0, count: pixels.count * 4)
        for (index, pixel) in pixels.enumerated() {
            let a3 = pixel >> 5
            let a5 = (a3 << 2) | (a3 >> 1)
            let x = index % clip.nativeWidth
            let y = index / clip.nativeWidth
            let destination = ((clip.nativeWidth - 1 - x) * clip.nativeHeight + y) * 4
            let color = colors[Int(pixel & 31)]
            rgba[destination] = color[0]
            rgba[destination + 1] = color[1]
            rgba[destination + 2] = color[2]
            rgba[destination + 3] = (a5 << 3) | (a5 >> 2)
        }
        return .init(width: clip.nativeHeight, height: clip.nativeWidth,
                     frameIndex: frameIndex, rgba: Data(rgba),
                     originalIndexData: Data(pixels), originalPaletteData: Data(palette))
    }
}

public struct OriginalAnimationCheckpoint: Codable, Equatable, Sendable {
    public let payloadSHA256: String
    public let frameIndex: Int
    public let loopCount: Int
    public let indexData: Data
    public let paletteData: Data
}

public struct OriginalAnimationFrame: Sendable {
    public let width: Int
    public let height: Int
    public let frameIndex: Int
    public let rgba: Data
    public let originalIndexData: Data
    public let originalPaletteData: Data

    public func makeCGImage() -> CGImage? {
        OriginalArtwork.shared.image(rgba: rgba, width: width, height: height)
    }
}

/**
 * A stable pair of silhouette edges for text wrapping around an animation.
 */
struct OriginalAnimationContour {
    let width: Int
    let height: Int
    let leftEdge: [CGPoint]
    let rightEdge: [CGPoint]

    init(frame: OriginalAnimationFrame) {
        width = frame.width
        height = frame.height
        let pixels = [UInt8](frame.rgba)
        guard width > 0, height > 0, pixels.count >= width * height * 4 else {
            leftEdge = []
            rightEdge = []
            return
        }
        let rowStep = max(1, height / 72)
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for y in stride(from: 0, to: height, by: rowStep) {
            var first: Int?
            var last: Int?
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 24 {
                if first == nil { first = x }
                last = x
            }
            guard let first, let last else { continue }
            let pointY = CGFloat(y) / CGFloat(max(1, height - 1))
            left.append(CGPoint(x: CGFloat(first) / CGFloat(max(1, width - 1)), y: pointY))
            right.append(CGPoint(x: CGFloat(last) / CGFloat(max(1, width - 1)), y: pointY))
        }
        leftEdge = left
        rightEdge = right
    }
}

/// A decoded frame, using its enhanced master when one is available.
public struct OriginalAnimationFrameView: View {
    public let frame: OriginalAnimationFrame
    @AppStorage("pencilCharacterAnimations") private var pencilCharacterAnimations = true

    public init(frame: OriginalAnimationFrame) { self.frame = frame }

    public var body: some View {
        if let image = frame.makeCGImage() {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(pencilCharacterAnimations || image.width > frame.width ? .high : .none)
                .scaledToFit()
                .saturation(pencilCharacterAnimations ? 0 : 1)
                .opacity(pencilCharacterAnimations ? 0.88 : 1)
                .blendMode(pencilCharacterAnimations ? .multiply : .normal)
                .accessibilityHidden(true)
        }
    }
}

private struct AnimationBytes {
    let bytes: [UInt8]
    var count: Int { bytes.count }
    init(_ data: Data) { bytes = Array(data) }
    init(bytes: [UInt8]) { self.bytes = bytes }
    func u16(_ offset: Int) -> Int { Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8) }
    func u32(_ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
    }
    func require(_ condition: Bool, _ detail: String) throws {
        if !condition { throw OriginalAnimationError.invalid(detail) }
    }
}
