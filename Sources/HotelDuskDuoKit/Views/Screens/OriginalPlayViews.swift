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
        rotated(rgba: bitmap.rgba(transparentPaletteZero: false), width: bitmap.width, height: bitmap.height)
    }

    /// Source pixel (column c, row r) goes to page (x: r, y: width − 1 − c).
    static func rotated(rgba: Data, width sourceWidth: Int, height sourceHeight: Int) -> CGImage? {
        let source = [UInt8](rgba)
        let width = sourceHeight, height = sourceWidth
        var output = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let from = (x * sourceWidth + (sourceWidth - 1 - y)) * 4
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

/// Process 24 on the touch page: `bell02` (the counter) under `bell01` (the
/// bell, palette index 0 transparent), both drawn on the 3D screen by
/// 0x021FD7B4. The bell's swing (+0x444) and the trick-button sprites are
/// not drawn; outlines mark the original bell rectangle and quit button.
struct OriginalBellPageView: View {
    @ObservedObject var play: OriginalPlaySession
    let upper: Bool
    private static var images: [String: CGImage] = [:]

    private static func image(_ name: String) -> CGImage? {
        if let cached = images[name] { return cached }
        guard let bitmap = try? OriginalBitmapLibrary.bundled().loadLinear(path: "trick/bell/\(name).bin"),
              let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: name == "bell01"),
                                                         width: bitmap.width, height: bitmap.height) else { return nil }
        images[name] = image
        return image
    }

    var body: some View {
        if let scene = play.bell, !upper {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                let size = CGSize(width: 192 * scale, height: 256 * scale)
                ZStack(alignment: .topLeading) {
                    ForEach(["bell02", "bell01"], id: \.self) { name in
                        if let image = Self.image(name) {
                            Image(decorative: image, scale: 1).resizable().interpolation(.none)
                                .frame(width: size.width, height: size.height)
                        }
                    }
                    if scene.awaitingTouch {
                        // 0x021FE7F8: x′ 56–96, y′ 72–120 → page x 72–120, y 56–96.
                        marker(x: 72, y: 56, width: 49, height: 41, scale: scale)
                            .accessibilityLabel("Bell")
                    }
                    if scene.quitEnabled {
                        // 0x020267F0 slot 5: x′ 228–252, y′ 156–188.
                        marker(x: 156, y: 228, width: 33, height: 25, scale: scale)
                            .accessibilityLabel("Quit")
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in
                    play.touchEntrance(pageX: Int(tap.location.x / scale), pageY: Int(tap.location.y / scale))
                })
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private func marker(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .strokeBorder(Color.black.opacity(0.7), lineWidth: 4)
            .overlay(RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
            .frame(width: width * scale, height: height * scale)
            .offset(x: x * scale, y: y * scale)
            .allowsHitTesting(false)
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
                Text("Kyle is free to explore map \(mapID) here. Map movement (the walk to a search point) and the 3D search view (model-node picking at 0x02033528) are not recovered yet.")
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

/// Options from an original choice prompt (opcode 10 kind 5), in the order
/// the command lists them. The original menu graphics are not drawn yet.
struct OriginalChoiceView: View {
    @ObservedObject var play: OriginalPlaySession
    let choices: [OriginalEventRunner.Choice]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(choices, id: \.id) { choice in
                Button(choice.label) { play.choose(choice.id) }
                    .buttonStyle(BookTextButtonStyle())
            }
        }
    }
}

/// Process 25. The blank card `signnote` is shown, and each field reveals the
/// completed card `signnote02` up to its stroke length, as the draw at
/// 0x021FD728 grows each field's quad. Fades and the pen sprite are not drawn.
struct OriginalSignPageView: View {
    @ObservedObject var play: OriginalPlaySession
    let upper: Bool
    @State private var dragging = false
    private static var images: [String: CGImage] = [:]

    private static func image(_ name: String) -> CGImage? {
        if let cached = images[name] { return cached }
        guard let bitmap = try? OriginalBitmapLibrary.bundled().loadLinear(path: "trick/sign/\(name).bin"),
              let image = OriginalEntrancePanels.rotated(rgba: bitmap.rgba(transparentPaletteZero: false),
                                                         width: bitmap.width, height: bitmap.height) else { return nil }
        images[name] = image
        return image
    }

    var body: some View {
        if let scene = play.sign, !upper {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 192, proxy.size.height / 256)
                let size = CGSize(width: 192 * scale, height: 256 * scale)
                ZStack(alignment: .topLeading) {
                    if let blank = Self.image("signnote") {
                        Image(decorative: blank, scale: 1).resizable().interpolation(.none)
                            .frame(width: size.width, height: size.height)
                    }
                    if let written = Self.image("signnote02") {
                        Image(decorative: written, scale: 1).resizable().interpolation(.none)
                            .frame(width: size.width, height: size.height)
                            .mask(alignment: .topLeading) { reveal(scene.strokes, scale: scale) }
                    }
                    if scene.awaitingStroke {
                        ForEach(0..<4, id: \.self) { field in
                            if scene.strokes[field] == 0 {
                                Rectangle().fill(Color.blue.opacity(0.12))
                                    .frame(width: CGFloat(min(OriginalSignProcess.fieldWidth[field], 191 - OriginalSignProcess.fieldX[field])) * scale,
                                           height: CGFloat(OriginalSignProcess.fieldHeight[field]) * scale)
                                    .offset(x: CGFloat(OriginalSignProcess.fieldX[field]) * scale,
                                            y: CGFloat(OriginalSignProcess.fieldY[field]) * scale)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    if scene.quitEnabled {
                        // Trick base slot 5: x′ 228–252, y′ 156–188 → page x 156–188, y 228–252.
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .frame(width: 33 * scale, height: 25 * scale)
                            .offset(x: 156 * scale, y: 228 * scale)
                            .allowsHitTesting(false)
                            .accessibilityLabel("Quit")
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    let x = Int(drag.location.x / scale), y = Int(drag.location.y / scale)
                    if !dragging { dragging = true; play.touchEntrance(pageX: x, pageY: y) }
                    play.holdTouch(pageX: x, pageY: y)
                }.onEnded { _ in
                    dragging = false
                    play.releaseTouch()
                })
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private func reveal(_ strokes: [Int16], scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { field in
                Rectangle()
                    .frame(width: CGFloat(strokes[field]) * scale,
                           height: CGFloat(OriginalSignProcess.fieldHeight[field] + 1) * scale)
                    .offset(x: CGFloat(OriginalSignProcess.fieldX[field]) * scale,
                            y: CGFloat(OriginalSignProcess.fieldY[field]) * scale)
            }
        }
    }
}

/// The question menu of event modes 7 and 8: the partner's open keywords
/// from the chapter `.ttk`, and leaving the conversation. The original menu
/// graphics and the item list are not drawn.
struct OriginalQuestionMenuView: View {
    @ObservedObject var play: OriginalPlaySession
    let topics: [OriginalEventRunner.Topic]

    var body: some View {
        VStack(spacing: 10) {
            Text("Ask about").font(NovelStyle.caption).foregroundStyle(NovelStyle.fadedInk)
            ForEach(topics, id: \.keyword) { topic in
                Button(topic.label) { play.ask(topic.keyword) }
                    .buttonStyle(BookTextButtonStyle())
            }
            InkRule().padding(.vertical, 6)
            Button("Leave") { play.leaveConversation() }
                .buttonStyle(BookTextButtonStyle())
        }
    }
}
