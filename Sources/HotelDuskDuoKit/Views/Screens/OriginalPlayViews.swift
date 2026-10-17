import SwiftUI
import CoreGraphics

/// Visible text from an original dialogue page. Glyph bytes are shown as
/// Latin-1; control codes other than colour are not drawn.
struct OriginalDialogueLines {
    struct Run: Hashable { let text: String; let colour: UInt8 }
    let lines: [[Run]]

    init(page: OriginalDialoguePacket.Page) {
        var lines: [[Run]] = [[]]
        var colour: UInt8 = 0, bytes: [UInt8] = []
        func flush() {
            guard !bytes.isEmpty else { return }
            lines[lines.count - 1].append(Run(text: String(bytes: bytes, encoding: .isoLatin1) ?? "", colour: colour))
            bytes = []
        }
        for token in page.tokens {
            switch token.kind {
            case .glyph(10): flush(); lines.append([])
            case .glyph(let byte): bytes.append(byte)
            case .control(.color(let value)): flush(); colour = value
            case .control: break
            }
        }
        flush()
        while let last = lines.last, last.isEmpty { lines.removeLast() }
        self.lines = lines
    }

    var isEmpty: Bool { lines.allSatisfy { $0.allSatisfy { $0.text.trimmingCharacters(in: .whitespaces).isEmpty } } }
}

/// Colour 1 marks emphasised names and colour 2 Kyle's private thoughts in
/// the source text. These ink tones approximate them; the original palette
/// entries have not been recovered.
private func ink(_ colour: UInt8) -> Color {
    switch colour {
    case 1: NovelStyle.redInk
    case 2: Color(red: 0.20, green: 0.27, blue: 0.42)
    default: NovelStyle.ink
    }
}

struct OriginalDialoguePageView: View {
    let page: OriginalDialoguePacket.Page

    var body: some View {
        let text = OriginalDialogueLines(page: page)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.lines.enumerated()), id: \.offset) { _, line in
                line.reduce(Text("")) { $0 + Text($1.text).foregroundColor(ink($1.colour)) }
                    .font(NovelStyle.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The original entrance panels, rotated from DS framebuffer orientation to
/// the right-handed book page (raw x becomes 255 − page y).
@MainActor
enum OriginalEntrancePanels {
    private static var cache: [String: CGImage] = [:]

    static func image(upper: Bool, panel: Int) -> CGImage? {
        let path = "trick/entrance/\(upper ? "u" : "d")0\(min(max(panel, 0), 2) + 1).bin"
        if let cached = cache[path] { return cached }
        guard let bitmap = try? OriginalBitmapLibrary.bundled().load(path: path),
              let image = rotated(bitmap) else { return nil }
        cache[path] = image
        return image
    }

    private static func rotated(_ bitmap: OriginalBitmap) -> CGImage? {
        let source = [UInt8](bitmap.rgba(transparentPaletteZero: false))
        let width = bitmap.height, height = bitmap.width
        var output = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let from = (x * bitmap.width + (bitmap.width - 1 - y)) * 4
                let to = (y * width + x) * 4
                output[to..<to + 4] = source[from..<from + 4]
            }
        }
        guard let provider = CGDataProvider(data: Data(output) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

struct OriginalEntrancePanelView: View {
    @ObservedObject var play: OriginalPlaySession
    let upper: Bool

    var body: some View {
        if let scene = play.entrance {
            GeometryReader { proxy in
                let size = fittedSize(in: proxy.size)
                ZStack {
                    if scene.sceneVisible, let image = OriginalEntrancePanels.image(upper: upper, panel: scene.panel) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.none)
                    } else {
                        Color.black
                    }
                    if !upper, scene.awaitingHandle {
                        handleMarker(in: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in
                    guard !upper else { return }
                    play.touchEntrance(pageX: Int(tap.location.x / size.width * 192),
                                       pageY: Int(tap.location.y / size.height * 256))
                })
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private func fittedSize(in space: CGSize) -> CGSize {
        let scale = min(space.width / 192, space.height / 256)
        return CGSize(width: 192 * scale, height: 256 * scale)
    }

    /// The 3D door is not rendered yet, so the original handle rectangle at
    /// 0x021FE1D4 ([150, 84, 200, 101] after rotation) is outlined instead.
    private func handleMarker(in size: CGSize) -> some View {
        let sx = size.width / 192, sy = size.height / 256
        return RoundedRectangle(cornerRadius: 3)
            .strokeBorder(Color.black.opacity(0.7), lineWidth: 4)
            .overlay(RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
            .frame(width: 18 * sx, height: 51 * sy)
            .position(x: (84 + 9) * sx, y: (150 + 25.5) * sy)
            .allowsHitTesting(false)
            .accessibilityLabel("Door handle")
    }
}

/// Shown where the recovered game ends or a system is missing.
struct OriginalPlayStatusView: View {
    @ObservedObject var session: GameSession
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack(spacing: 16) {
            switch play.runner.phase {
            case .exploration(let mapID):
                Text("End of the recovered opening").font(NovelStyle.title)
                Text("Kyle is free to explore map \(mapID) here. Exploration, movement and closeups are not recovered yet.")
                    .font(NovelStyle.body)
            case .halted(let halt):
                Text("Play stopped").font(NovelStyle.title)
                Text(halt.reason).font(NovelStyle.body)
                Text("\(halt.program)\(halt.eventIndex.map { ", event \($0)" } ?? "")\(halt.sourceOffset.map { ", offset \($0)" } ?? "")")
                    .font(NovelStyle.document)
                    .foregroundStyle(NovelStyle.fadedInk)
            default:
                EmptyView()
            }
            Button("Start again") { session.startOriginalGame() }
                .buttonStyle(BookTextButtonStyle())
            Button("Close") { session.endOriginalGame() }
                .buttonStyle(BookTextButtonStyle())
        }
        .multilineTextAlignment(.center)
    }
}
