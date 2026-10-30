import CoreGraphics
import Foundation

/// Original opening graphics data. These BIN files contain DTX texels, not
/// tiled bitmaps. The manifest retains ARM9 table bytes and independent hashes.
public struct OriginalOpeningGraphicsLibrary: Sendable {
    public struct Manifest: Decodable, Sendable {
        public let formatVersion: Int
        public let arm9SHA256: String
        public let textures: [TextureRecord]
        public let variants: [Card]
        public struct TextureRecord: Decodable, Sendable {
            public let source: String
            public let payloadSHA256: String
            public let decodedSHA256: String
            public let mode: Int
            public let width: Int
            public let height: Int
            public let paletteSHA256: String
            public let pixelDataSHA256: String
            public let rgbaSHA256: String
            public let portraitRGBA_SHA256: String
        }
        public struct Card: Codable, Equatable, Sendable {
            public let variant: Int
            public let duration: Int
            public let tail: Int
            public let pages: [[Line]]
            public let pageRGBA180: [String]
        }
        public struct Line: Codable, Equatable, Sendable {
            public let address: String
            public let rawHex: String
            public let polygonID: Int
            public let x: Int
            public let y: Int
            public let height: Int
            public let period: Int
            public let texture: String
            public let stripEnds: [Int]
        }
    }
    public let manifest: Manifest
    private let root: URL

    public init(resourceRoot: URL) throws {
        root = resourceRoot.standardizedFileURL
        manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf:
            root.appendingPathComponent("OriginalOpeningGraphicsManifest.json")))
        guard manifest.formatVersion == 1 else { throw OriginalDataError.unsupported("Opening graphics manifest") }
    }
    public static func bundled() throws -> Self {
        guard let root = Bundle.module.resourceURL else { throw OriginalDataError.missing("OriginalBitmaps") }
        return try .init(resourceRoot: root.appendingPathComponent("OriginalBitmaps"))
    }
    public func card(variant: Int) throws -> Manifest.Card {
        guard let card = manifest.variants.first(where: { $0.variant == variant }) else {
            throw OriginalDataError.unsupported("Opening card variant \(variant)")
        }
        return card
    }
    public func loadTexture(path: String) throws -> OriginalTexture {
        guard let record = manifest.textures.first(where: { $0.source == path }) else { throw OriginalDataError.missing(path) }
        let url = root.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else { throw OriginalDataError.invalid("Opening texture path") }
        let data = try Data(contentsOf: url)
        guard OriginalAnimationClip.digest(data) == record.payloadSHA256 else { throw OriginalDataError.checksum(path) }
        return try .init(data: data)
    }
}

public extension OriginalTexture {
    /// The default handedness branch of 02084d54 samples stored (width-1-y,x).
    /// The resulting image has storedHeight by storedWidth pixels.
    func openingPortraitRGBA() -> Data {
        let source = Array(rgba)
        var output = [UInt8](repeating: 0, count: source.count)
        for y in 0..<storedWidth {
            for x in 0..<storedHeight {
                let a = (x * storedWidth + storedWidth - 1 - y) * 4
                let b = (y * storedHeight + x) * 4
                output.replaceSubrange(b..<b + 4, with: source[a..<a + 4])
            }
        }
        return Data(output)
    }
}

/// Native translation of 020AD384/020AD634/020ADA00. The caller clocks this
/// once per original update and owns the shared fade and sound controllers.
public struct OriginalOpeningStripReveal: Sendable {
    public enum Phase: Int, Codable, Sendable { case uninitialized, revealing, waitingForFade, finished }
    public struct Checkpoint: Codable, Equatable, Sendable {
        public let variant: Int
        public let phase: Phase
        public let counter: Int
    }
    public enum Event: Equatable, Sendable {
        /// 020812f0(channel, layerMask, type, initialValue, duration).
        case fade(channel: Int, layerMask: Int, type: Int, initialValue: Float, duration: Int)
        /// The original 0200a060 call. Sound interpretation belongs to its controller.
        case soundSetup(channel: Int, index: Int)
        /// The original 02009f2c call, at most once per update.
        case playSound(channel: Int)
        case complete
    }
    public struct DrawCommand: Equatable, Sendable {
        public let texture: String
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int
        public let sourceX: Int
        public let sourceY: Int
        public let zFixed: Int
        public let alpha: Int
        public let polygonID: Int
        public let colour: Int
    }
    public let card: OriginalOpeningGraphicsLibrary.Manifest.Card
    public private(set) var phase: Phase = .uninitialized
    public private(set) var counter: Int = 0

    public init(card: OriginalOpeningGraphicsLibrary.Manifest.Card) throws {
        guard (0...2).contains(card.variant), card.duration == 181, card.tail == 50,
              card.pages.count == 2, card.pages[0].count == 4, card.pages[1].count == 2,
              card.pages.flatMap({ $0 }).allSatisfy({ line in
                  line.period > 0 && line.stripEnds.count <= 8 && !line.stripEnds.isEmpty &&
                  line.stripEnds.first! > 0 && zip(line.stripEnds, line.stripEnds.dropFirst()).allSatisfy({ $0 < $1 })
              }) else { throw OriginalDataError.invalid("Opening card table") }
        self.card = card
    }

    /// The first update initializes counter 1. State 1 checks sound at the old
    /// counter, increments it, and starts the closing fade at counter 231.
    public mutating func advance(fadeComplete: Bool = false) -> [Event] {
        switch phase {
        case .uninitialized:
            counter = 1
            phase = .revealing
            return [.fade(channel: 0, layerMask: 63, type: 3, initialValue: -16, duration: 30),
                    .soundSetup(channel: 0, index: 72)]
        case .revealing:
            var events = [Event]()
            if counter < card.duration && card.pages.flatMap({ $0 }).contains(where: { counter % $0.period == 0 }) {
                events.append(.playSound(channel: 1))
            }
            counter += 1
            if counter >= card.duration + card.tail {
                phase = .waitingForFade
                events.append(.fade(channel: 0, layerMask: 63, type: 2, initialValue: 0, duration: 30))
            }
            return events
        case .waitingForFade:
            guard fadeComplete else { return [] }
            counter = 0
            phase = .finished
            return [.complete]
        case .finished:
            return []
        }
    }

    /// Original upright 192 by 256 coordinates. Draw over the original black
    /// bank1/id1 background at zFixed 0x219a, alpha31, polygon10, colour0x7fff.
    public func drawCommands(page: Int) throws -> [DrawCommand] {
        guard card.pages.indices.contains(page) else { throw OriginalDataError.invalid("Opening page index") }
        return card.pages[page].flatMap { line -> [DrawCommand] in
            let count = min(counter / line.period, line.stripEnds.count)
            return (0..<count).map { strip in
                let start = strip == 0 ? 0 : line.stripEnds[strip - 1]
                return DrawCommand(texture: line.texture, x: line.x + start, y: line.y,
                                   width: line.stripEnds[strip] - start, height: line.height,
                                   sourceX: start, sourceY: 0, zFixed: 0x2000, alpha: 31,
                                   polygonID: line.polygonID, colour: 0x7fff)
            }
        }
    }

    public func checkpoint() -> Checkpoint { .init(variant: card.variant, phase: phase, counter: counter) }
    public mutating func restore(_ checkpoint: Checkpoint) throws {
        let validCounter: Bool
        switch checkpoint.phase {
        case .uninitialized, .finished: validCounter = checkpoint.counter == 0
        case .revealing: validCounter = (1..<card.duration + card.tail).contains(checkpoint.counter)
        case .waitingForFade: validCounter = checkpoint.counter == card.duration + card.tail
        }
        guard checkpoint.variant == card.variant, validCounter else { throw OriginalDataError.invalid("Opening card checkpoint") }
        phase = checkpoint.phase
        counter = checkpoint.counter
    }

    /// A native pixel surface for the recovered card. Shared display fades are
    /// applied by the caller. This does not claim DS rasterization parity.
    public func renderPortraitRGBA(page: Int, library: OriginalOpeningGraphicsLibrary) throws -> Data {
        var output = [UInt8](repeating: 0, count: 192 * 256 * 4)
        for offset in stride(from: 3, to: output.count, by: 4) { output[offset] = 255 }
        var cache = [String: (OriginalTexture, [UInt8])]()
        for command in try drawCommands(page: page) {
            let (texture, image): (OriginalTexture, [UInt8])
            if let cached = cache[command.texture] { (texture, image) = cached }
            else {
                texture = try library.loadTexture(path: command.texture)
                image = Array(texture.openingPortraitRGBA())
                cache[command.texture] = (texture, image)
            }
            guard command.x >= 0, command.y >= 0, command.x + command.width <= 192,
                  command.y + command.height <= 256,
                  command.sourceX + command.width <= texture.storedHeight,
                  command.sourceY + command.height <= texture.storedWidth else {
                throw OriginalDataError.invalid("Opening card references unavailable pixels")
            }
            for y in 0..<command.height {
                for x in 0..<command.width {
                    let a = ((command.sourceY + y) * texture.storedHeight + command.sourceX + x) * 4
                    let b = ((command.y + y) * 192 + command.x + x) * 4
                    let alpha = Int(image[a + 3])
                    for channel in 0..<3 {
                        output[b + channel] = UInt8((Int(image[a + channel]) * alpha + Int(output[b + channel]) * (255 - alpha) + 127) / 255)
                    }
                }
            }
        }
        return Data(output)
    }

    public func makePortraitImage(page: Int, library: OriginalOpeningGraphicsLibrary) throws -> CGImage {
        guard let context = OriginalArtwork.pageContext() else { throw OriginalDataError.invalid("Opening card context") }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 192, height: 256))
        for command in try drawCommands(page: page) {
            let texture = try library.loadTexture(path: command.texture)
            guard let source = OriginalArtwork.shared.image(rgba: texture.rgba, width: texture.storedWidth,
                height: texture.storedHeight, rotated: true),
                  let strip = source.croppingArtwork(to: CGRect(x: command.sourceX, y: command.sourceY,
                    width: command.width, height: command.height)) else {
                throw OriginalDataError.invalid("Opening card strip")
            }
            context.draw(strip, in: CGRect(x: command.x, y: 256 - command.y - command.height,
                width: command.width, height: command.height))
        }
        guard let image = context.makeImage() else { throw OriginalDataError.invalid("Opening card image") }
        return image
    }
}
