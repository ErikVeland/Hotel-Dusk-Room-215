import SwiftUI
import ImageIO

/// Talk-scene backdrop decoded from the ROM (`tools/decode_talk_bg.py`).
/// The source art is 96×128. Hotel Dusk shows these backdrops soft and out of focus
/// behind characters, so this view upscales with smooth filtering, not pixel doubling.
public struct RomBackgroundView: View {
    public enum Facing: String { case left = "L", right = "R" }

    let code: String
    let facing: Facing

    public init(code: String, facing: Facing = .left) {
        self.code = code
        self.facing = facing
    }

    public var body: some View {
        if let image = RomImageCache.shared.image(named: "\(code)_\(facing.rawValue)") {
            // Fill inside an overlay so the image never sets the layout size
            // (a bare aspect-fill image would grow its page beyond its half).
            Color.clear
                .overlay {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 0.6)
                }
                .clipped()
        }
    }
}

/// Loads PNGs from the package bundle once and keeps them in memory.
@MainActor
final class RomImageCache {
    static let shared = RomImageCache()
    private var cache: [String: CGImage] = [:]

    func image(named name: String) -> CGImage? {
        if let hit = cache[name] { return hit }
        if let image = OriginalArtwork.shared.namedImage(source: "Images/Backgrounds/\(name).png") {
            cache[name] = image
            return image
        }
        // `.process` may keep or flatten the folder structure, depending on the build system.
        let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Images/Backgrounds")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        guard let url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache[name] = image
        return image
    }
}
